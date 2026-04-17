import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GroupLeaderboardScreen extends StatefulWidget {
  final String groupName;
  final String groupCode;
  final List<dynamic> memberIds;

  const GroupLeaderboardScreen({
    super.key,
    required this.groupName,
    required this.groupCode,
    required this.memberIds,
  });

  @override
  State<GroupLeaderboardScreen> createState() => _GroupLeaderboardScreenState();
}

class _GroupLeaderboardScreenState extends State<GroupLeaderboardScreen> {
  String _selectedSort = 'Total Elo';
  final List<String> _sortOptions = [
    'Total Elo',
    'Gym Elo',
    'Academic Elo',
    'Art Elo',
  ];

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return 0;
  }

  int _userElo(Map<String, dynamic>? data) {
    if (data == null) return 0;
    return _toInt(data['skillElo']) +
        _toInt(data['effortElo']) +
        _toInt(data['academicSkillElo']) +
        _toInt(data['academicEffortElo']) +
        _toInt(data['artSkillElo']) +
        _toInt(data['artEffortElo']);
  }

  String _topEndeavour(Map<String, dynamic>? data) {
    if (data == null) return 'Unknown';

    final int gym = _toInt(data['skillElo']) + _toInt(data['effortElo']);
    final int academic =
        _toInt(data['academicSkillElo']) + _toInt(data['academicEffortElo']);
    final int art = _toInt(data['artSkillElo']) + _toInt(data['artEffortElo']);

    if (gym == 0 && academic == 0 && art == 0) return 'Unknown';
    if (gym >= academic && gym >= art) return 'Gym';
    if (academic >= gym && academic >= art) return 'Academic';
    return 'Art';
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

  Future<List<Map<String, dynamic>>> _loadLeaderboardMembers() async {
    final ids = widget.memberIds.whereType<String>().toList();
    final futures = ids.map((id) async {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .get();
      if (!doc.exists) {
        return <String, dynamic>{
          'username': 'Unknown',
          'elo': 0,
          'gymElo': 0,
          'academicElo': 0,
          'artElo': 0,
          'topEndeavour': 'Unknown',
        };
      }
      final data = doc.data() as Map<String, dynamic>;
      final username = (data['username'] as String?)?.trim();
      return {
        'username': username != null && username.isNotEmpty
            ? username
            : 'Unknown',
        'elo': _userElo(data),
        'gymElo': _toInt(data['skillElo']) + _toInt(data['effortElo']),
        'academicElo':
            _toInt(data['academicSkillElo']) +
            _toInt(data['academicEffortElo']),
        'artElo': _toInt(data['artSkillElo']) + _toInt(data['artEffortElo']),
        'topEndeavour': _topEndeavour(data),
      };
    });
    final members = await Future.wait(futures);
    members.sort((a, b) {
      if (_selectedSort == 'Gym Elo')
        return (b['gymElo'] as int).compareTo(a['gymElo'] as int);
      if (_selectedSort == 'Academic Elo')
        return (b['academicElo'] as int).compareTo(a['academicElo'] as int);
      if (_selectedSort == 'Art Elo')
        return (b['artElo'] as int).compareTo(a['artElo'] as int);
      return (b['elo'] as int).compareTo(a['elo'] as int);
    });
    return members;
  }

  IconData _endeavourIcon(String endeavour) {
    switch (endeavour.toLowerCase()) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Leaderboard • ${widget.groupName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadLeaderboardMembers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load leaderboard: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }
              final members = snapshot.data ?? [];
              final total = members.fold(
                0,
                (acc, member) => acc + (member['elo'] as int),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.groupName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Code: ${widget.groupCode}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Group Elo',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatElo(total),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
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
                  const SizedBox(height: 10),
                  if (members.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No members in this group yet.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 40,
                                        child: Text(
                                          '#${index + 1}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: index == 0
                                                ? Colors.amber
                                                : Colors.white70,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '@${member['username']}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  _endeavourIcon(
                                                    member['topEndeavour']
                                                        as String,
                                                  ),
                                                  size: 16,
                                                  color: Colors.white54,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  member['topEndeavour']
                                                      as String,
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12,
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
                                          _selectedSort == 'Gym Elo'
                                              ? member['gymElo'] as int
                                              : _selectedSort == 'Academic Elo'
                                              ? member['academicElo'] as int
                                              : _selectedSort == 'Art Elo'
                                              ? member['artElo'] as int
                                              : member['elo'] as int,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
