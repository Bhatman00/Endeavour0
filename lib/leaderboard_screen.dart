import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LeaderboardUser {
  final String username;
  final int totalElo;
  final String topEndeavour;
  final String region;

  LeaderboardUser({
    required this.username,
    required this.totalElo,
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
    if (gym >= academic) {
      return gym == 0 && academic == 0 ? 'Unknown' : 'Gym';
    }
    return 'Academic';
  }

  Future<List<LeaderboardUser>> _loadUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final users = snapshot.docs.map((doc) {
      final data = doc.data();
      final username = (data['username'] as String?)?.trim();
      final region = (data['region'] as String?)?.trim() ?? 'Unknown';
      final totalElo =
          _toInt(data['skillElo']) +
          _toInt(data['effortElo']) +
          _toInt(data['academicSkillElo']) +
          _toInt(data['academicEffortElo']);
      return LeaderboardUser(
        username: username != null && username.isNotEmpty
            ? username
            : 'Unknown',
        totalElo: totalElo,
        topEndeavour: _topEndeavour(data),
        region: region.isNotEmpty ? region : 'Unknown',
      );
    }).toList();

    users.sort((a, b) => b.totalElo.compareTo(a.totalElo));
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
            future: _loadUsers(),
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
              final regionalUsers = _filterByRegion(users);

              return TabBarView(
                children: [
                  _buildLeaderboardList(users),
                  Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildRegionSelector(),
                      const SizedBox(height: 10),
                      Expanded(child: _buildLeaderboardList(regionalUsers)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRegionSelector() {
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
                value: _selectedRegion,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C1C21),
                icon: const Icon(Icons.public, color: Colors.white54),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                items: _regions.map((String region) {
                  return DropdownMenuItem<String>(
                    value: region,
                    child: Text(region == 'All' ? 'All Regions' : region),
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
    );
  }

  Widget _buildLeaderboardList(List<LeaderboardUser> users) {
    if (users.isEmpty) {
      return const Center(
        child: Text('No users found.', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: users.length,
      itemBuilder: (context, index) =>
          _buildGlassUserCard(users[index], index + 1),
    );
  }

  Widget _buildGlassUserCard(LeaderboardUser user, int rank) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
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
                  _formatElo(user.totalElo),
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
    );
  }
}
