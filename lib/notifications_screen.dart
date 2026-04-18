import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'social_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SocialService _socialService = SocialService();

  Widget _buildNotificationItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] ?? 'unknown';
    final senderUsername = data['senderUsername'] ?? 'Someone';
    final notificationId = doc.id;

    if (type == 'friend_request') {
      return _buildFriendRequestItem(notificationId, data, senderUsername);
    } else if (type == 'group_invite') {
      return _buildGroupInviteItem(notificationId, data, senderUsername);
    } else if (type == 'join_request') {
      return _buildJoinRequestItem(notificationId, data, senderUsername);
    }

    return const SizedBox.shrink();
  }

  Widget _buildFriendRequestItem(
    String notificationId,
    Map<String, dynamic> data,
    String senderUsername,
  ) {
    return _buildCardWrapper(
      icon: Icons.person_add,
      title: 'Friend Request',
      subtitle: '@$senderUsername wants to be friends',
      onAccept: () async {
        try {
          await _socialService.acceptFriendRequest(
            notificationId,
            data['senderId'],
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Friend request accepted!')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to accept: ${e.toString()}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
      onDecline: () async {
        try {
          await _socialService.declineNotification(notificationId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to decline: ${e.toString()}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildGroupInviteItem(
    String notificationId,
    Map<String, dynamic> data,
    String senderUsername,
  ) {
    final groupName = data['groupName'] ?? 'a group';
    return _buildCardWrapper(
      icon: Icons.group_add,
      title: 'Group Invite',
      subtitle: '@$senderUsername invited you to $groupName',
      onAccept: () async {
        try {
          await _socialService.acceptGroupInvite(notificationId, data['groupId']);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Joined group!')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to join: ${e.toString()}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
      onDecline: () async {
        try {
          await _socialService.declineNotification(notificationId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to decline: ${e.toString()}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildJoinRequestItem(
    String notificationId,
    Map<String, dynamic> data,
    String senderUsername,
  ) {
    final groupName = data['groupName'] ?? 'your group';
    return _buildCardWrapper(
      icon: Icons.group_add,
      title: 'Join Request',
      subtitle: '@$senderUsername wants to join $groupName',
      onAccept: () async {
        try {
          await _socialService.acceptJoinRequest(
            notificationId,
            data['groupId'],
            data['senderId'],
          );
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Request accepted!')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to accept: ${e.toString()}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
      onDecline: () async {
        try {
          await _socialService.declineNotification(notificationId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to decline: ${e.toString()}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildCardWrapper({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white70, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onDecline,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _socialService.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Error: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final rawDocs = snapshot.data?.docs ?? [];
          final docs = List<QueryDocumentSnapshot>.from(rawDocs);
          
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "You have no new notifications.",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              return _buildNotificationItem(docs[index]);
            },
          );
        },
      ),
    );
  }
}
