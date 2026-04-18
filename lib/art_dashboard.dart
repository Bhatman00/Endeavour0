import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'rank_utils.dart';
import 'juice_widgets.dart';

class ArtDashboard extends StatefulWidget {
  const ArtDashboard({super.key});

  @override
  State<ArtDashboard> createState() => _ArtDashboardState();
}

class _ArtDashboardState extends State<ArtDashboard> {
  final TextEditingController _effort = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();

  bool _baselineSet = false;
  int _artSkillElo = 0;
  int _artEffortElo = 0;
  String? _previousRankName;
  bool _showCelebration = false;
  bool _showGlow = false;
  Color _glowColor = Colors.white;
  Rank? _currentRank;

  final Map<String, double> _levelMultipliers = {
    'Beginner': 1.0,
    'Intermediate': 1.5,
    'Advanced': 2.0,
    'Professional': 2.25,
  };

  String _selectedLevel = 'Intermediate';

  int get _totalElo => _artSkillElo + _artEffortElo;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists && mounted) {
          var data = doc.data() as Map<String, dynamic>;
          setState(() {
            _artSkillElo = data['artSkillElo'] ?? 0;
            _artEffortElo = data['artEffortElo'] ?? 0;
            _currentRank = RankUtils.getRank(_totalElo, RankUtils.artRanks);
            _previousRankName = _currentRank?.name;
            _glowColor = _currentRank?.color ?? Colors.white;

            if (_artSkillElo > 0 ||
                _artEffortElo > 0 ||
                data.containsKey('artMultiplier')) {
              _baselineSet = true;
            }
          });
          if (_baselineSet) {
            setState(() => _showGlow = true);
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) setState(() => _showGlow = false);
            });
          }
        }
      } catch (e) {
        print("Error fetching art data: $e");
      }
    }
  }

  // Rank methods now handled by RankUtils

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

  void _calculateArtBaseline() async {
    int grade = int.tryParse(_gradeController.text) ?? 0;

    if (grade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid skill rating!")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      double multiplier = _levelMultipliers[_selectedLevel]!;
      int initialSkill = (grade * multiplier).round();
      String? uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'artSkillElo': initialSkill,
          'artGrade': grade,
          'artMultiplier': multiplier,
          'artLevelString': _selectedLevel,
        }, SetOptions(merge: true));

        if (mounted) Navigator.of(context).pop();

        setState(() {
          _artSkillElo = initialSkill;
          _baselineSet = true;
        });
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
    }
  }

  void _addEffort() async {
    int mins = int.tryParse(_effort.text) ?? 0;

    if (mins > 0) {
      // Haptic Feedback on Add
      HapticFeedback.heavyImpact();

      final int newTotal = _totalElo + mins;
      final newRank = RankUtils.getRank(newTotal, RankUtils.artRanks);

      setState(() {
        _artEffortElo += mins;
        _effort.clear();

        if (_previousRankName != null && newRank.name != _previousRankName) {
          _showCelebration = true;
          _currentRank = newRank;
          _glowColor = newRank.color;
          _showGlow = true;
        }
        _previousRankName = newRank.name;
      });

      // Glow for input
      setState(() => _showGlow = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _showGlow = false);
      });

      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'artEffortElo': FieldValue.increment(mins),
        }, SetOptions(merge: true));
      }
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
      ),
      body: SafeArea(
        child: Container(
          decoration: _showGlow
              ? BoxDecoration(
                  border: Border.all(color: _glowColor.withOpacity(0.7), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: _glowColor.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                )
              : null,
          child: Stack(
            children: [
              if (_baselineSet)
                _Dashboard(
                    totalElo: _totalElo,
                    effortController: _effort,
                    onAddEffort: _addEffort,
                    rank: RankUtils.getRank(_totalElo, RankUtils.artRanks),
                  )
              else
                _Onboarding(
                    selectedLevel: _selectedLevel,
                    levelMultipliers: _levelMultipliers,
                    gradeController: _gradeController,
                    onLevelChanged: (val) => setState(() => _selectedLevel = val!),
                    onCalculate: _calculateArtBaseline,
                  ),
              if (_showCelebration && _currentRank != null)
                RankUpCelebration(
                  newRank: _currentRank!,
                  onDismiss: () => setState(() => _showCelebration = false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final int totalElo;
  final TextEditingController effortController;
  final VoidCallback onAddEffort;
  final Rank rank;

  const _Dashboard({
    required this.totalElo,
    required this.effortController,
    required this.onAddEffort,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              rank.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: rank.color,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Icon(Icons.palette, size: 120, color: rank.color),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: RollingEloCounter(
              value: totalElo,
            ),
          ),
        ),
        const Text(
          "ART ELO",
          style: TextStyle(color: Colors.white38, letterSpacing: 2),
        ),
        const Spacer(),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: effortController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.timer_outlined,
                          color: Colors.white38,
                        ),
                        hintText: "Minutes practiced...",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  FloatingActionButton(
                    onPressed: onAddEffort,
                    backgroundColor: rank.color,
                    elevation: 0,
                    child: const Icon(Icons.add, color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Onboarding extends StatelessWidget {
  final String selectedLevel;
  final Map<String, double> levelMultipliers;
  final TextEditingController gradeController;
  final Function(String?) onLevelChanged;
  final VoidCallback onCalculate;

  const _Onboarding({
    required this.selectedLevel,
    required this.levelMultipliers,
    required this.gradeController,
    required this.onLevelChanged,
    required this.onCalculate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.palette, size: 80, color: Colors.white24),
                    const SizedBox(height: 20),
                    const Text(
                      "ART BASELINE",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    DropdownButtonFormField<String>(
                      value: selectedLevel,
                      dropdownColor: const Color(0xFF1A1A21),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.brush,
                          color: Colors.white38,
                        ),
                        labelText: "Skill Level",
                        labelStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: levelMultipliers.keys.map((String level) {
                        return DropdownMenuItem<String>(
                          value: level,
                          child: Text(level),
                        );
                      }).toList(),
                      onChanged: onLevelChanged,
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: gradeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.star, color: Colors.white38),
                        labelText: "Self-Assessed Skill Rating",
                        labelStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: onCalculate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "SET ART ELO",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
