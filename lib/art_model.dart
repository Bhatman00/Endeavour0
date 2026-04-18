import 'package:cloud_firestore/cloud_firestore.dart';

class ArtModel {
  final String id;
  final String artistId;
  final String imageUrl;
  final List<Map<String, dynamic>> ratings; // [{'userId': String, 'rating': int (1-5), 'comment': String?, 'isConstructive': bool?}]
  final double averageRating;
  final bool isInAssessmentFeed;
  final bool isInGlobalGallery;
  final DateTime uploadedAt;
  final bool isPlacement; // true for placement matches

  ArtModel({
    required this.id,
    required this.artistId,
    required this.imageUrl,
    this.ratings = const [],
    this.averageRating = 0.0,
    this.isInAssessmentFeed = true,
    this.isInGlobalGallery = false,
    required this.uploadedAt,
    this.isPlacement = false,
  });

  // Calculate average rating
  double get calculatedAverageRating {
    if (ratings.isEmpty) return 0.0;
    double sum = ratings.fold(0.0, (sum, rating) => sum + (rating['rating'] as int));
    return sum / ratings.length;
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'artistId': artistId,
      'imageUrl': imageUrl,
      'ratings': ratings,
      'averageRating': calculatedAverageRating,
      'isInAssessmentFeed': isInAssessmentFeed,
      'isInGlobalGallery': isInGlobalGallery,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'isPlacement': isPlacement,
    };
  }

  // Create ArtModel from Firestore Document
  factory ArtModel.fromMap(Map<String, dynamic> map, String docId) {
    return ArtModel(
      id: docId,
      artistId: map['artistId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      ratings: List<Map<String, dynamic>>.from(map['ratings'] ?? []),
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      isInAssessmentFeed: map['isInAssessmentFeed'] ?? true,
      isInGlobalGallery: map['isInGlobalGallery'] ?? false,
      uploadedAt: map['uploadedAt'] is Timestamp ? (map['uploadedAt'] as Timestamp).toDate() : DateTime.now(),
      isPlacement: map['isPlacement'] ?? false,
    );
  }
}