import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SocialService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> sendFriendRequest(String targetUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || targetUid == uid) return;

    final userDoc = await _db.collection('users').doc(uid).get();
    final username = userDoc.data()?['username'] ?? 'Someone';

    // Prevent duplicates
    final existing = await _db
        .collection('users')
        .doc(targetUid)
        .collection('notifications')
        .where('senderId', isEqualTo: uid)
        .where('type', isEqualTo: 'friend_request')
        .get();

    final isPending = existing.docs.any((d) => d.data()['status'] == 'pending');
    if (isPending) return;

    await _db
        .collection('users')
        .doc(targetUid)
        .collection('notifications')
        .add({
          'type': 'friend_request',
          'senderId': uid,
          'senderUsername': username,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> acceptFriendRequest(
    String notificationId,
    String requesterUid,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final batch = _db.batch();

    // Mark notification as accepted
    final notifRef = _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId);
    batch.update(notifRef, {'status': 'accepted'});

    // Add friend to my list
    final myFriendRef = _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .doc(requesterUid);
    batch.set(myFriendRef, {
      'friendUid': requesterUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Add me to their list
    final theirFriendRef = _db
        .collection('users')
        .doc(requesterUid)
        .collection('friends')
        .doc(uid);
    batch.set(theirFriendRef, {
      'friendUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> declineNotification(String notificationId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'status': 'declined'});
  }

  Future<void> sendGroupInvite(
    String targetUid,
    String groupId,
    String groupName,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || targetUid == uid) return;

    final userDoc = await _db.collection('users').doc(uid).get();
    final username = userDoc.data()?['username'] ?? 'Someone';

    // Prevent duplicate invites for same group
    final existing = await _db
        .collection('users')
        .doc(targetUid)
        .collection('notifications')
        .where('groupId', isEqualTo: groupId)
        .where('type', isEqualTo: 'group_invite')
        .get();

    final isPending = existing.docs.any((d) => d.data()['status'] == 'pending');
    if (isPending) return;

    await _db
        .collection('users')
        .doc(targetUid)
        .collection('notifications')
        .add({
          'type': 'group_invite',
          'senderId': uid,
          'senderUsername': username,
          'groupId': groupId,
          'groupName': groupName,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> acceptGroupInvite(String notificationId, String groupId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final groupRef = _db.collection('groups').doc(groupId);
    final userRef = _db.collection('users').doc(uid);

    try {
      await _db.runTransaction((transaction) async {
        final groupSnapshot = await transaction.get(groupRef);
        final userSnapshot = await transaction.get(userRef);

        if (groupSnapshot.exists) {
          final groupPath = groupRef.path;

          final List<String> currentPaths = List<String>.from(
            userSnapshot.data()?['groupPaths'] ?? [],
          );
          if (!currentPaths.contains(groupPath)) {
            transaction.update(groupRef, {
              'members': FieldValue.arrayUnion([uid]),
              'memberCount': FieldValue.increment(1),
            });

            transaction.update(userRef, {
              'groupPaths': FieldValue.arrayUnion([groupPath]),
            });
          }
        }
      });

      // Update notification
      await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'status': 'accepted'});
    } catch (e) {
      print("Failed to join group: $e");
    }
  }

  Stream<QuerySnapshot> getNotificationsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }
}
