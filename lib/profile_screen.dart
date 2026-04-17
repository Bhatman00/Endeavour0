import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'social_service.dart';

class ProfileScreen extends StatefulWidget {
  final String targetUid;

  const ProfileScreen({super.key, required this.targetUid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  int _globalRank = 0;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUid)
          .get();

      if (!doc.exists) {
        setState(() {
          _errorMessage = "User not found.";
          _isLoading = false;
        });
        return;
      }

      final allSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      int toInt(dynamic value) {
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is num) return value.toInt();
        return 0;
      }

      int calculateElo(Map<String, dynamic> data) {
        return toInt(data['skillElo']) +
            toInt(data['effortElo']) +
            toInt(data['academicSkillElo']) +
            toInt(data['academicEffortElo']) +
            toInt(data['artSkillElo']) +
            toInt(data['artEffortElo']);
      }

      List<Map<String, dynamic>> allUsers = allSnapshot.docs
          .map((d) => {'uid': d.id, 'elo': calculateElo(d.data())})
          .toList();

      allUsers.sort((a, b) => (b['elo'] as int).compareTo(a['elo'] as int));

      int rank = allUsers.indexWhere((u) => u['uid'] == widget.targetUid) + 1;

      setState(() {
        _userData = doc.data() as Map<String, dynamic>;
        _globalRank = rank;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "Unknown";
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
    }
    return "Unknown";
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return 0;
  }

  Widget _buildSkillCard(
    String title,
    IconData icon,
    int pts,
    Color glowColor,
  ) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.white70, size: 28),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  pts.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
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
    final bool isMe =
        FirebaseAuth.instance.currentUser?.uid == widget.targetUid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage.isNotEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Image
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                        color: Colors.white.withValues(alpha: 0.1),
                        image: _userData?['photoUrl'] != null
                            ? DecorationImage(
                                image: NetworkImage(_userData!['photoUrl']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _userData?['photoUrl'] == null
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white54,
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Username & Region
                    Text(
                      _userData?['username'] ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _userData?['region'] ?? 'Unknown Region',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Rank Banner
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.withValues(alpha: 0.2),
                                Colors.amber.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  const Text(
                                    "Global Rank",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "#$_globalRank",
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white24,
                              ),
                              Column(
                                children: [
                                  const Text(
                                    "Member Since",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(_userData?['createdAt']),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Social Actions
                    if (!isMe)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await SocialService().sendFriendRequest(
                                    widget.targetUid,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Friend request sent!"),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Failed: ${e.toString()}"),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.person_add,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Add Friend",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  final myUid =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  if (myUid == null) return;
                                  final userDoc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(myUid)
                                      .get();
                                  final paths = List<String>.from(
                                    userDoc.data()?['groupPaths'] ?? [],
                                  );
                                  if (paths.isEmpty) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "You aren't in any groups yet!",
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  final groupDoc = await FirebaseFirestore
                                      .instance
                                      .doc(paths.first)
                                      .get();
                                  final groupData =
                                      groupDoc.data() as Map<String, dynamic>?;
                                  if (groupData != null) {
                                    await SocialService().sendGroupInvite(
                                      widget.targetUid,
                                      groupDoc.id,
                                      groupData['name'] ?? 'Group',
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Invited to ${groupData['name']}!",
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Failed: ${e.toString()}"),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.group_add,
                                color: Colors.black,
                              ),
                              label: const Text(
                                "Invite",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!isMe) const SizedBox(height: 25),

                    // Skills Breakdown
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Skills Breakdown",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _buildSkillCard(
                          "Gym",
                          Icons.fitness_center,
                          _toInt(_userData?['skillElo']) +
                              _toInt(_userData?['effortElo']),
                          Colors.redAccent,
                        ),
                        const SizedBox(width: 10),
                        _buildSkillCard(
                          "Academic",
                          Icons.school,
                          _toInt(_userData?['academicSkillElo']) +
                              _toInt(_userData?['academicEffortElo']),
                          Colors.blueAccent,
                        ),
                        const SizedBox(width: 10),
                        _buildSkillCard(
                          "Art",
                          Icons.palette,
                          _toInt(_userData?['artSkillElo']) +
                              _toInt(_userData?['artEffortElo']),
                          Colors.purpleAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
