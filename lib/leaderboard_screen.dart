import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';

class LeaderboardUser {
  final String uid;
  final String username;
  final String? photoUrl;
  final int totalElo;
  final int gymElo;
  final int academicElo;
  final int artElo;
  final String topEndeavour;
  final String region;

  LeaderboardUser({
    required this.uid,
    required this.username,
    this.photoUrl,
    required this.totalElo,
    required this.gymElo,
    required this.academicElo,
    required this.artElo,
    required this.topEndeavour,
    required this.region,
  });
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _selectedRegion = 'All';
  final List<String> _regions = [
    'All',
    'OCE',
    'Asia',
    'Europe',
    'NA',
    'SA',
    'Unknown',
  ];

  String _selectedSort = 'Total Elo';
  final List<String> _sortOptions = [
    'Total Elo',
    'Gym Elo',
    'Academic Elo',
    'Art Elo',
  ];

  late Future<List<LeaderboardUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return 0;
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

  String _topEndeavour(Map<String, dynamic> data) {
    final int gym = _toInt(data['skillElo']) + _toInt(data['effortElo']);
    final int academic =
        _toInt(data['academicSkillElo']) + _toInt(data['academicEffortElo']);
    final int art = _toInt(data['artSkillElo']) + _toInt(data['artEffortElo']);

    if (gym == 0 && academic == 0 && art == 0) return 'Unknown';
    if (gym >= academic && gym >= art) return 'Gym';
    if (academic >= gym && academic >= art) return 'Academic';
    return 'Art';
  }

  Future<List<LeaderboardUser>> _loadUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final users = snapshot.docs
        .where((doc) => doc.data()['isPrivate'] != true)
        .map((doc) {
      final data = doc.data();
      final uid = doc.id;
      final username = (data['username'] as String?)?.trim();
      final region = (data['region'] as String?)?.trim() ?? 'Unknown';
      final gymElo = _toInt(data['skillElo']) + _toInt(data['effortElo']);
      final academicElo =
          _toInt(data['academicSkillElo']) + _toInt(data['academicEffortElo']);
      final artElo = _toInt(data['artSkillElo']) + _toInt(data['artEffortElo']);
      final totalElo = gymElo + academicElo + artElo;

      return LeaderboardUser(
        uid: uid,
        username: username != null && username.isNotEmpty
            ? username
            : 'Unknown',
        photoUrl: data['photoUrl'],
        totalElo: totalElo,
        gymElo: gymElo,
        academicElo: academicElo,
        artElo: artElo,
        topEndeavour: _topEndeavour(data),
        region: region.isNotEmpty ? region : 'Unknown',
      );
    }).toList();

    return users;
  }

  List<LeaderboardUser> _filterByRegion(List<LeaderboardUser> users) {
    if (_selectedRegion == 'All') return users;
    return users.where((user) => user.region == _selectedRegion).toList();
  }

  IconData _getSkillIcon(String skill) {
    switch (skill.toLowerCase()) {
      case 'gym':
        return Icons.fitness_center;
      case 'academic':
        return Icons.school;
      case 'art':
        return Icons.palette;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F13),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'LEADERBOARDS',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(text: 'GLOBAL'),
              Tab(text: 'REGIONAL'),
            ],
          ),
        ),
        body: SafeArea(
          child: FutureBuilder<List<LeaderboardUser>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load leaderboard: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }
              final users = snapshot.data ?? [];
              
              // Sort users based on selected criteria
              final sortedUsers = [...users];
              sortedUsers.sort((a, b) {
                if (_selectedSort == 'Gym Elo') return b.gymElo.compareTo(a.gymElo);
                if (_selectedSort == 'Academic Elo') return b.academicElo.compareTo(a.academicElo);
                if (_selectedSort == 'Art Elo') return b.artElo.compareTo(a.artElo);
                return b.totalElo.compareTo(a.totalElo);
              });

              final regionalUsers = _filterByRegion(sortedUsers);

              return TabBarView(
                children: [
                  _buildTabContent(sortedUsers, isRegional: false),
                  _buildTabContent(regionalUsers, isRegional: true),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(
    List<LeaderboardUser> allUsersList, {
    required bool isRegional,
  }) {
    List<LeaderboardUser> displayUsers = allUsersList.take(500).toList();

    String? myUid = FirebaseAuth.instance.currentUser?.uid;
    int myRank = allUsersList.indexWhere((u) => u.uid == myUid) + 1;
    LeaderboardUser? me;
    if (myRank > 0) me = allUsersList[myRank - 1];

    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 10),
            isRegional ? _buildFilters() : _buildSortSelector(),
            const SizedBox(height: 10),
            Expanded(
              child: _buildLeaderboardList(
                displayUsers,
                bottomPadding: me != null ? 120 : 20,
              ),
            ),
          ],
        ),
        if (me != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0F0F13).withValues(alpha: 0.0),
                    const Color(0xFF0F0F13).withValues(alpha: 0.95),
                    const Color(0xFF0F0F13),
                  ],
                ),
              ),
              child: LeaderboardCard(
                user: me,
                rank: myRank,
                selectedSort: _selectedSort,
                isMine: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSortSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSort,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C1C21),
                icon: const Icon(Icons.sort, color: Colors.white54),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                items: _sortOptions.map((String sortStr) {
                  return DropdownMenuItem<String>(
                    value: sortStr,
                    child: Text(sortStr),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedSort = newValue);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRegion,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1C1C21),
                      icon: const Icon(Icons.public, color: Colors.white54),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      items: _regions.map((String region) {
                        return DropdownMenuItem<String>(
                          value: region,
                          child: Text(
                            region == 'All' ? 'All Regions' : region,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedRegion = newValue);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSort,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1C1C21),
                      icon: const Icon(Icons.sort, color: Colors.white54),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      items: _sortOptions.map((String sortStr) {
                        return DropdownMenuItem<String>(
                          value: sortStr,
                          child: Text(sortStr, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedSort = newValue);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(
    List<LeaderboardUser> users, {
    double bottomPadding = 20,
  }) {
    if (users.isEmpty) {
      return const Center(
        child: Text('No users found.', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      itemCount: users.length,
      itemBuilder: (context, index) => LeaderboardCard(
        user: users[index],
        rank: index + 1,
        selectedSort: _selectedSort,
      ),
    );
  }
}

class LeaderboardCard extends StatelessWidget {
  final LeaderboardUser user;
  final int rank;
  final String selectedSort;
  final bool isMine;

  const LeaderboardCard({
    super.key,
    required this.user,
    required this.rank,
    required this.selectedSort,
    this.isMine = false,
  });

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

  IconData _getSkillIcon(String skill) {
    switch (skill.toLowerCase()) {
      case 'gym':
        return Icons.fitness_center;
      case 'academic':
        return Icons.school;
      case 'art':
        return Icons.palette;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(targetUid: user.uid),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isMine
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isMine
                      ? Colors.amber.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: rank == 1 ? Colors.amber : Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                      image: user.photoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(user.photoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: user.photoUrl == null
                        ? const Icon(Icons.person, size: 20, color: Colors.white24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _getSkillIcon(user.topEndeavour),
                              size: 14,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              user.topEndeavour,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                user.region,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatElo(
                      selectedSort == 'Gym Elo'
                          ? user.gymElo
                          : selectedSort == 'Academic Elo'
                              ? user.academicElo
                              : selectedSort == 'Art Elo'
                                  ? user.artElo
                                  : user.totalElo,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
