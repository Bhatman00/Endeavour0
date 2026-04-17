import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  final Map<String, double> _levelMultipliers = {
    'Beginner (1x)': 1.0,
    'Intermediate (1.5x)': 1.5,
    'Advanced (2x)': 2.0,
    'Professional (2.25x)': 2.25,
  };

  String _selectedLevel = 'Intermediate (1.5x)';

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

            if (_artSkillElo > 0 ||
                _artEffortElo > 0 ||
                data.containsKey('artMultiplier')) {
              _baselineSet = true;
            }
          });
        }
      } catch (e) {
        print("Error fetching art data: $e");
      }
    }
  }

  String getRankName(int elo) {
    if (elo < 500) return "NOVICE ARTIST";
    if (elo < 1500) return "DEDICATED CREATOR";
    if (elo < 3500) return "SKILLED ARTISAN";
    if (elo < 7000) return "MASTER VIRTUOSO";
    return "CHIEF VISIONARY";
  }

  Color getRankColor(int elo) {
    if (elo < 500) return Colors.blueGrey;
    if (elo < 1500) return Colors.pinkAccent;
    if (elo < 3500) return Colors.deepOrangeAccent;
    if (elo < 7000) return Colors.amberAccent;
    return Colors.tealAccent;
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
      setState(() {
        _artEffortElo += mins;
        _effort.clear();
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
        child: _baselineSet
            ? _Dashboard(
                rankName: getRankName(_totalElo),
                totalElo: _totalElo,
                rankColor: getRankColor(_totalElo),
                formatElo: _formatElo(_totalElo),
                effortController: _effort,
                onAddEffort: _addEffort,
              )
            : _Onboarding(
                selectedLevel: _selectedLevel,
                levelMultipliers: _levelMultipliers,
                gradeController: _gradeController,
                onLevelChanged: (val) => setState(() => _selectedLevel = val!),
                onCalculate: _calculateArtBaseline,
              ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final String rankName;
  final int totalElo;
  final Color rankColor;
  final String formatElo;
  final TextEditingController effortController;
  final VoidCallback onAddEffort;

  const _Dashboard({
    required this.rankName,
    required this.totalElo,
    required this.rankColor,
    required this.formatElo,
    required this.effortController,
    required this.onAddEffort,
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
              rankName,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: rankColor,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Icon(Icons.palette, size: 120, color: rankColor),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatElo,
              style: const TextStyle(
                fontSize: 100,
                fontWeight: FontWeight.w900,
                height: 0.9,
                color: Colors.white,
              ),
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
                    backgroundColor: rankColor,
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
