import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'group_leaderboard_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  String? _uid;
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController = TextEditingController();
  String? _joinError;
  String? _createError;
  String? _createdGroupCode;
  bool _isJoining = false;
  bool _isCreating = false;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return 0;
  }

  int _userElo(Map<String, dynamic>? data) {
    if (data == null) return 0;
    int gymSkill = _toInt(data['skillElo']);
    int gymEffort = _toInt(data['effortElo']);
    int academicSkill = _toInt(data['academicSkillElo']);
    int academicEffort = _toInt(data['academicEffortElo']);
    return gymSkill + gymEffort + academicSkill + academicEffort;
  }

  String _formatElo(int elo) {
    if (elo < 1000) return elo.toString();
    if (elo < 1000000) {
      return '${(elo / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
    }
    if (elo < 1000000000) {
      return '${(elo / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    }
    return '${(elo / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}B';
  }

  String _topEndeavour(Map<String, dynamic>? data) {
    if (data == null) return 'Unknown';
    int gym = _toInt(data['skillElo']) + _toInt(data['effortElo']);
    int academic = _toInt(data['academicSkillElo']) + _toInt(data['academicEffortElo']);

    if (gym == 0 && academic == 0) {
      return 'Unknown';
    }
    return gym >= academic ? 'Gym' : 'Academic';
  }

  String _normalizeGroupCode(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String _generateGroupCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  Future<String> _buildUniqueGroupCode() async {
    final groups = FirebaseFirestore.instance.collection('groups');
    for (int i = 0; i < 10; i++) {
      final code = _generateGroupCode();
      final doc = await groups.doc(code).get();
      if (!doc.exists) return code;
    }
    throw Exception('Could not generate unique group code.');
  }

  Future<void> _createGroup(String name, String description) async {
    if (_uid == null) return;

    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      setState(() => _createError = 'Enter a valid group name.');
      return;
    }

    setState(() {
      _isCreating = true;
      _createError = null;
      _createdGroupCode = null;
    });

    try {
      final code = await _buildUniqueGroupCode();
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(code);
      final groupData = {
        'name': cleanName,
        'description': description.trim().isEmpty ? 'Join with your friends using the code below.' : description.trim(),
        'groupScore': 0,
        'memberCount': 1,
        'members': [_uid],
        'ownerId': _uid,
        'groupCode': code,
        'groupCodeLower': code.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await groupRef.set(groupData);
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'groupPaths': FieldValue.arrayUnion([groupRef.path]),
      });

      if (!mounted) return;
      setState(() {
        _createdGroupCode = code;
        _groupNameController.clear();
        _groupDescriptionController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group created successfully.')));
    } catch (e) {
      if (!mounted) return;
      final explanation = e.toString().contains('permission-denied')
          ? 'Could not create group: Firebase permission denied. Check Firestore rules for /groups and /users.'
          : 'Could not create group: ${e.toString()}';
      setState(() => _createError = explanation);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explanation)));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _joinGroupByCode() async {
    if (_uid == null) return;
    final code = _normalizeGroupCode(_joinCodeController.text);
    if (code.isEmpty) {
      setState(() => _joinError = 'Enter a valid group code.');
      return;
    }

    setState(() {
      _isJoining = true;
      _joinError = null;
    });

    try {
      final query = await FirebaseFirestore.instance.collection('groups')
          .where('groupCodeLower', isEqualTo: code.toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _joinError = 'Group not found with that code.');
        return;
      }

      final groupDoc = query.docs.first;
      final groupPath = groupDoc.reference.path;
      final userRef = FirebaseFirestore.instance.collection('users').doc(_uid);
      final userSnapshot = await userRef.get();
      final currentPaths = List<String>.from((userSnapshot.data()?['groupPaths'] ?? []) as List<dynamic>);
      if (currentPaths.contains(groupPath)) {
        setState(() => _joinError = 'You are already a member of this group.');
        return;
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final groupSnapshot = await transaction.get(groupDoc.reference);
        if (!groupSnapshot.exists) throw Exception('Group no longer exists.');
        transaction.update(groupDoc.reference, {
          'members': FieldValue.arrayUnion([_uid]),
          'memberCount': FieldValue.increment(1),
        });
        transaction.update(userRef, {
          'groupPaths': FieldValue.arrayUnion([groupPath]),
        });
      });

      if (!mounted) return;
      _joinCodeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined group successfully.')));
    } catch (e) {
      if (!mounted) return;
      final explanation = e.toString().contains('permission-denied')
          ? 'Could not join group: Firebase permission denied.'
          : 'Could not join group: ${e.toString()}';
      setState(() => _joinError = explanation);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explanation)));
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  // These features were removed to keep the group flow focused on joining by code and viewing My Groups.

  Future<List<Map<String, dynamic>>> _loadGroupMembers(List<dynamic> memberIds) async {
    final ids = memberIds.whereType<String>().toList();
    final futures = ids.map((id) async {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (!doc.exists) {
        return <String, dynamic>{
          'username': 'Unknown',
          'elo': 0,
          'topEndeavour': 'Unknown',
        };
      }
      final data = doc.data() as Map<String, dynamic>;
      final username = (data['username'] as String?)?.trim();
      return {
        'username': username != null && username.isNotEmpty ? username : 'Unknown',
        'elo': _userElo(data),
        'topEndeavour': _topEndeavour(data),
      };
    });
    final members = await Future.wait(futures);
    members.sort((a, b) => (b['elo'] as int).compareTo(a['elo'] as int));
    return members;
  }

  void _openGroupLeaderboard(Map<String, dynamic> group) {
    final members = List<String>.from(group['members'] ?? []);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupLeaderboardScreen(
          groupName: group['name'] ?? 'Group',
          groupCode: group['groupCode'] ?? 'UNKNOWN',
          memberIds: members,
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group, bool isMember) {
    final String name = group['name'] ?? 'Group';
    final String description = group['description'] ?? 'Join this team to compete with friends.';
    final int memberCount = _toInt(group['memberCount']);
    final String groupCode = group['groupCode'] ?? '??????';
    final bool isOwner = group['ownerId'] == _uid;

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
                onPressed: isMember ? () => _openGroupLeaderboard(group) : () => _joinCodeController.text = groupCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMember ? Colors.greenAccent : Colors.white24,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(isMember ? 'Leaderboard' : 'Copy code'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 15),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadGroupMembers(group['members'] ?? []),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                );
              }

              final members = snapshot.data ?? [];
              final int totalGroupElo = members.fold(0, (sum, member) => sum + (member['elo'] as int));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _infoChip(Icons.code, groupCode),
                      _infoChip(Icons.star, '${_formatElo(totalGroupElo)} Elo'),
                      _infoChip(Icons.group, '$memberCount members'),
                      if (isOwner) _infoChip(Icons.shield, 'Owner'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (members.isNotEmpty) ...members.map((member) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 18, color: Colors.white70),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('@${member['username']}', style: const TextStyle(color: Colors.white)),
                          ),
                          Text('${_formatElo(member['elo'] as int)} Elo', style: const TextStyle(color: Colors.white54)),
                        ],
                      ),
                    );
                  }) else
                    const Text('No members found yet.', style: TextStyle(color: Colors.white54)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMyGroupCard(QueryDocumentSnapshot groupDoc) {
    final group = groupDoc.data() as Map<String, dynamic>;
    final groupWithId = {
      ...group,
      'id': groupDoc.id,
      'path': groupDoc.reference.path,
    };
    return _buildGroupCard(groupWithId, true);
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
    final groupsRef = FirebaseFirestore.instance.collection('groups');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F13),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.greenAccent,
            tabs: [
              Tab(text: 'Browse'),
              Tab(text: 'My Groups'),
            ],
          ),
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
              final List<String> joinedGroups = List<String>.from(userData?['groupPaths'] ?? []);

              return StreamBuilder<QuerySnapshot>(
                stream: groupsRef.snapshots(),
                builder: (context, groupsSnapshot) {
                  if (groupsSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoading();
                  }

                  final groups = groupsSnapshot.data?.docs ?? [];
                  final sortedGroups = [...groups];
                  sortedGroups.sort((a, b) {
                    final aCount = _toInt((a.data() as Map<String, dynamic>)['memberCount']);
                    final bCount = _toInt((b.data() as Map<String, dynamic>)['memberCount']);
                    return bCount.compareTo(aCount);
                  });

                  return TabBarView(
                    children: [
                      RefreshIndicator(
                        onRefresh: () async {
                          await userRef.get();
                          await groupsRef.get();
                        },
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          children: [
                            const Text('GROUPS', style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 14)),
                            const SizedBox(height: 10),
                            const Text('Join a group with code or create your own', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
                                      Text(_formatElo(currentElo), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Icon(Icons.leaderboard, size: 32, color: Colors.greenAccent),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Join a group', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _joinCodeController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.qr_code, color: Colors.white38),
                                      hintText: 'Enter group code',
                                      hintStyle: const TextStyle(color: Colors.white24),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.05),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _isJoining ? null : _joinGroupByCode,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.greenAccent,
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      minimumSize: const Size.fromHeight(50),
                                    ),
                                    child: Text(_isJoining ? 'Joining...' : 'Join group'),
                                  ),
                                  if (_joinError != null) ...[
                                    const SizedBox(height: 12),
                                    Text(_joinError!, style: const TextStyle(color: Colors.redAccent)),
                                  ],
                                  const SizedBox(height: 12),
                                  if (_createdGroupCode != null) ...[
                                    const Text('Last created code:', style: TextStyle(color: Colors.white54)),
                                    const SizedBox(height: 8),
                                    _infoChip(Icons.lock, _createdGroupCode!),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Create a group', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _groupNameController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.edit, color: Colors.white38),
                                      hintText: 'Group name',
                                      hintStyle: const TextStyle(color: Colors.white24),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.05),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _groupDescriptionController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.description_outlined, color: Colors.white38),
                                      hintText: 'Optional description',
                                      hintStyle: const TextStyle(color: Colors.white24),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.05),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _isCreating ? null : () => _createGroup(_groupNameController.text, _groupDescriptionController.text),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.greenAccent,
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      minimumSize: const Size.fromHeight(50),
                                    ),
                                    child: Text(_isCreating ? 'Creating...' : 'Create group'),
                                  ),
                                  if (_createError != null) ...[
                                    const SizedBox(height: 12),
                                    Text(_createError!, style: const TextStyle(color: Colors.redAccent)),
                                  ],
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
                                children: sortedGroups
                                    .where((group) => joinedGroups.contains(group.reference.path))
                                    .map((group) {
                                      final groupData = group.data() as Map<String, dynamic>;
                                      return Chip(
                                        backgroundColor: Colors.greenAccent.withValues(alpha: 0.18),
                                        label: Text(groupData['name'] ?? 'Group', style: const TextStyle(color: Colors.white)),
                                      );
                                    }).toList(),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (groups.isEmpty) ...[
                              const Text('No groups created yet.', style: TextStyle(color: Colors.white54)),
                              const SizedBox(height: 20),
                              const Text('Create a group to start building your squad.', style: TextStyle(color: Colors.white38)),
                            ] else ...[
                              const Text('Available Groups', style: TextStyle(color: Colors.white54, fontSize: 16, letterSpacing: 1.5)),
                              const SizedBox(height: 10),
                              ...sortedGroups.map((groupDoc) {
                                final data = groupDoc.data() as Map<String, dynamic>;
                                final groupPath = groupDoc.reference.path;
                                final bool isMember = joinedGroups.contains(groupPath);
                                final groupWithId = {...data, 'id': groupDoc.id, 'path': groupPath};
                                return _buildGroupCard(groupWithId, isMember);
                              }),
                            ],
                            const SizedBox(height: 20),
                            const Text('Pull to refresh groups', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: () async {
                          await userRef.get();
                          await groupsRef.get();
                        },
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          children: [
                            const Text('MY GROUPS', style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 14)),
                            const SizedBox(height: 10),
                            const Text('Your joined groups and members', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            if (joinedGroups.isEmpty) ...[
                              const Text('You haven’t joined any groups yet.', style: TextStyle(color: Colors.white54)),
                              const SizedBox(height: 20),
                              const Text('Use the Join group tab to enter a group code.', style: TextStyle(color: Colors.white38)),
                            ] else ...[
                              ...sortedGroups
                                  .where((groupDoc) => joinedGroups.contains(groupDoc.reference.path))
                                  .map(_buildMyGroupCard)
                                  ,
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
