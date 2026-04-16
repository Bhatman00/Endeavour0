import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  int _userElo(Map<String, dynamic>? data) {
    if (data == null) return 0;
    int gymSkill = data['skillElo'] ?? 0;
    int gymEffort = data['effortElo'] ?? 0;
    int academicSkill = data['academicSkillElo'] ?? 0;
    int academicEffort = data['academicEffortElo'] ?? 0;
    return gymSkill + gymEffort + academicSkill + academicEffort;
  }

  Future<void> _toggleMembership(String groupId, bool isMember, int currentElo) async {
    if (_uid == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(_uid);
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final groupSnapshot = await transaction.get(groupRef);

      if (!userSnapshot.exists || !groupSnapshot.exists) return;

      if (isMember) {
        transaction.update(userRef, {
          'groupIds': FieldValue.arrayRemove([groupId]),
        });
        transaction.update(groupRef, {
          'members': FieldValue.arrayRemove([_uid]),
          'memberCount': FieldValue.increment(-1),
          'groupScore': FieldValue.increment(-currentElo),
        });
      } else {
        transaction.update(userRef, {
          'groupIds': FieldValue.arrayUnion([groupId]),
        });
        transaction.update(groupRef, {
          'members': FieldValue.arrayUnion([_uid]),
          'memberCount': FieldValue.increment(1),
          'groupScore': FieldValue.increment(currentElo),
        });
      }
    });
  }

  Future<void> _createSampleGroups() async {
    final groups = [
      {
        'name': 'Iron Pack',
        'description': 'Lift hard and climb the Group Elo ladder together.',
        'groupScore': 0,
        'memberCount': 0,
        'members': [],
      },
      {
        'name': 'Focus Crew',
        'description': 'Study, train, and outpace your rivals as a team.',
        'groupScore': 0,
        'memberCount': 0,
        'members': [],
      },
      {
        'name': 'Legend League',
        'description': 'Bring your friends and battle for the top rank.',
        'groupScore': 0,
        'memberCount': 0,
        'members': [],
      },
    ];

    final batch = FirebaseFirestore.instance.batch();
    for (final group in groups) {
      final doc = FirebaseFirestore.instance.collection('groups').doc(group['name'].toString().toLowerCase().replaceAll(' ', '-'));
      batch.set(doc, group);
    }
    await batch.commit();
  }

  Widget _buildGroupCard(Map<String, dynamic> group, bool isMember, int currentElo) {
    final String groupId = group['id'] ?? '';
    final String name = group['name'] ?? 'Group';
    final String description = group['description'] ?? 'Join this team to compete with friends.';
    final int memberCount = group['memberCount'] ?? 0;
    final int groupScore = group['groupScore'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () => _toggleMembership(groupId, isMember, currentElo),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMember ? Colors.white : Colors.greenAccent,
                  foregroundColor: isMember ? Colors.black : Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(isMember ? 'Leave' : 'Join'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 15),
          Row(
            children: [
              _infoChip(Icons.star, '$groupScore Elo'),
              const SizedBox(width: 10),
              _infoChip(Icons.group, '$memberCount members'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F13),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text('Sign in to view groups', style: TextStyle(color: Colors.white))),
      );
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(_uid);
    final groupsRef = FirebaseFirestore.instance.collection('groups').orderBy('groupScore', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: userRef.snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoading();
            }

            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
            final int currentElo = _userElo(userData);
            final List<String> joinedGroups = List<String>.from(userData?['groupIds'] ?? []);

            return StreamBuilder<QuerySnapshot>(
              stream: groupsRef.snapshots(),
              builder: (context, groupsSnapshot) {
                if (groupsSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoading();
                }

                final groups = groupsSnapshot.data?.docs ?? [];
                return RefreshIndicator(
                  onRefresh: () async {
                    await userRef.get();
                    await groupsRef.get();
                  },
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    children: [
                      const Text('GROUPS', style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 14)),
                      const SizedBox(height: 10),
                      const Text('Challenge friends and build group Elo', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Your Elo', style: TextStyle(color: Colors.white54, letterSpacing: 1.5)),
                                const SizedBox(height: 8),
                                Text('$currentElo', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const Icon(Icons.group, size: 40, color: Colors.greenAccent),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (joinedGroups.isNotEmpty) ...[
                        const Text('Joined Groups', style: TextStyle(color: Colors.white54, fontSize: 16, letterSpacing: 1.5)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: groups
                              .where((group) => joinedGroups.contains(group.id))
                              .map((group) {
                                final groupData = group.data() as Map<String, dynamic>;
                                return Chip(
                                  backgroundColor: Colors.greenAccent.withValues(alpha: 0.18),
                                  label: Text(groupData['name'] ?? 'Group', style: const TextStyle(color: Colors.white)),
                                );
                              })
                              .toList(),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (groups.isEmpty) ...[
                        const Text('No groups created yet.', style: TextStyle(color: Colors.white54)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _createSampleGroups,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            minimumSize: const Size.fromHeight(55),
                          ),
                          child: const Text('Create sample groups'),
                        ),
                      ] else ...[
                        const Text('Available Groups', style: TextStyle(color: Colors.white54, fontSize: 16, letterSpacing: 1.5)),
                        const SizedBox(height: 10),
                        ...groups.map((group) {
                          final data = group.data() as Map<String, dynamic>;
                          final bool isMember = joinedGroups.contains(group.id);
                          final groupWithId = {...data, 'id': group.id};
                          return _buildGroupCard(groupWithId, isMember, currentElo);
                        }),
                      ],
                      const SizedBox(height: 20),
                      const Text('Pull to refresh groups', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
