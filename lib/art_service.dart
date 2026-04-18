import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'art_model.dart';
import 'user_model.dart';

class ArtService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload art for placement or regular
  Future<String> uploadArt(String imageUrl, bool isPlacement) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    String artId = _firestore.collection('art').doc().id;
    ArtModel art = ArtModel(
      id: artId,
      artistId: uid,
      imageUrl: imageUrl,
      uploadedAt: DateTime.now(),
      isPlacement: isPlacement,
    );

    await _firestore.collection('art').doc(artId).set(art.toMap());

    // If placement, add to user's placementArtIds
    if (isPlacement) {
      await _addPlacementArtId(uid, artId);
    }

    return artId;
  }

  Future<void> _addPlacementArtId(String uid, String artId) async {
    await _firestore.collection('users').doc(uid).update({
      'placementArtIds': FieldValue.arrayUnion([artId]),
    });
  }

  // Get assessment feed: art with <3 ratings, prioritize those
  Future<List<ArtModel>> getAssessmentFeed() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    QuerySnapshot snapshot = await _firestore
        .collection('art')
        .where('isInAssessmentFeed', isEqualTo: true)
        .where('artistId', isNotEqualTo: uid) // Don't show own art
        .orderBy('artistId') // Required for isNotEqualTo
        .get();

    List<ArtModel> artList = snapshot.docs
        .map((doc) => ArtModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    // Sort by number of ratings (prioritize <3)
    artList.sort((a, b) {
      int aRatingCount = a.ratings.length;
      int bRatingCount = b.ratings.length;
      if (aRatingCount < 3 && bRatingCount >= 3) return -1;
      if (bRatingCount < 3 && aRatingCount >= 3) return 1;
      return aRatingCount.compareTo(bRatingCount);
    });

    return artList;
  }

  // Rate art
  Future<void> rateArt(String artId, int rating, String? comment) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    // Check if already rated
    DocumentSnapshot artDoc = await _firestore.collection('art').doc(artId).get();
    if (!artDoc.exists) throw Exception('Art not found');

    ArtModel art = ArtModel.fromMap(artDoc.data() as Map<String, dynamic>, artDoc.id);
    bool alreadyRated = art.ratings.any((r) => r['userId'] == uid);
    if (alreadyRated) throw Exception('Already rated this art');

    // Add rating
    Map<String, dynamic> newRating = {
      'userId': uid,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.now(),
    };

    await _firestore.collection('art').doc(artId).update({
      'ratings': FieldValue.arrayUnion([newRating]),
    });

    // Check if now has 3 ratings
    List<Map<String, dynamic>> updatedRatings = [...art.ratings, newRating];
    if (updatedRatings.length >= 3) {
      await _graduateToGlobalGallery(artId);
    }

    // Award token to rater
    await _awardCritiqueToken(uid);

    // Update artist's skill Elo if not placement
    if (!art.isPlacement) {
      await _updateArtistSkillElo(art.artistId);
    }
  }

  Future<void> _graduateToGlobalGallery(String artId) async {
    await _firestore.collection('art').doc(artId).update({
      'isInAssessmentFeed': false,
      'isInGlobalGallery': true,
    });
  }

  Future<void> _awardCritiqueToken(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'critiqueTokens': FieldValue.increment(1),
    });
  }

  Future<void> _updateArtistSkillElo(String artistId) async {
    // Get all non-placement art by artist
    QuerySnapshot artSnapshot = await _firestore
        .collection('art')
        .where('artistId', isEqualTo: artistId)
        .where('isPlacement', isEqualTo: false)
        .where('isInGlobalGallery', isEqualTo: true)
        .get();

    List<ArtModel> artList = artSnapshot.docs
        .map((doc) => ArtModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    if (artList.isEmpty) return;

    // Calculate average rating across all art
    double totalRating = 0.0;
    int totalRatings = 0;
    for (var art in artList) {
      totalRating += art.calculatedAverageRating * art.ratings.length;
      totalRatings += art.ratings.length;
    }
    double overallAverage = totalRatings > 0 ? totalRating / totalRatings : 0.0;

    // Skill Elo = (average / 5) * 100
    int skillElo = ((overallAverage / 5.0) * 100).round();

    // Skill Multiplier = average / 5 (0.2 to 1.0)
    double multiplier = overallAverage / 5.0;
    multiplier = multiplier.clamp(0.2, 1.0);

    await _firestore.collection('users').doc(artistId).update({
      'artSkillElo': skillElo,
      'artSkillMultiplier': multiplier,
    });
  }

  // Check if user can upload (has tokens or is unranked)
  Future<bool> canUploadArt() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return false;

    UserModel user = UserModel.fromMap(userDoc.data() as Map<String, dynamic>, userDoc.id);

    if (!user.isRankedInArt) return true; // Unranked can upload placements

    return user.critiqueTokens >= 3;
  }

  // Spend tokens to upload
  Future<void> spendTokensForUpload() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
    UserModel user = UserModel.fromMap(userDoc.data() as Map<String, dynamic>, userDoc.id);

    if (user.isRankedInArt && user.critiqueTokens < 3) {
      throw Exception('Not enough tokens');
    }

    if (user.isRankedInArt) {
      await _firestore.collection('users').doc(uid).update({
        'critiqueTokens': FieldValue.increment(-3),
      });
    }
  }

  // Calculate starting skill Elo from placements
  Future<void> calculateStartingSkillElo(String uid) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
    UserModel user = UserModel.fromMap(userDoc.data() as Map<String, dynamic>, userDoc.id);

    if (user.placementArtIds.length != 5) return;

    double totalRating = 0.0;
    for (String artId in user.placementArtIds) {
      DocumentSnapshot artDoc = await _firestore.collection('art').doc(artId).get();
      if (artDoc.exists) {
        ArtModel art = ArtModel.fromMap(artDoc.data() as Map<String, dynamic>, artDoc.id);
        totalRating += art.calculatedAverageRating;
      }
    }

    double averageRating = totalRating / 5.0;
    int startingSkillElo = ((averageRating / 5.0) * 100).round();
    double multiplier = averageRating / 5.0;
    multiplier = multiplier.clamp(0.2, 1.0);

    await _firestore.collection('users').doc(uid).update({
      'artSkillElo': startingSkillElo,
      'artSkillMultiplier': multiplier,
      'isRankedInArt': true,
    });
  }

  // Get global gallery
  Future<List<ArtModel>> getGlobalGallery() async {
    QuerySnapshot snapshot = await _firestore
        .collection('art')
        .where('isInGlobalGallery', isEqualTo: true)
        .orderBy('uploadedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ArtModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // Log effort time
  Future<void> logEffortTime(int minutes) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    // Cap at 120 per day
    int cappedMinutes = minutes > 120 ? 120 : minutes;

    DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
    UserModel user = UserModel.fromMap(userDoc.data() as Map<String, dynamic>, userDoc.id);

    int effortElo = (cappedMinutes * user.artSkillMultiplier).round();

    await _firestore.collection('users').doc(uid).update({
      'artEffortElo': FieldValue.increment(effortElo),
    });
  }
}