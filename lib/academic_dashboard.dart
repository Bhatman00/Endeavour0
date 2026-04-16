import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AcademicDashboard extends StatefulWidget {
  const AcademicDashboard({super.key});

  @override
  State<AcademicDashboard> createState() => _AcademicDashboardState();
}

class _AcademicDashboardState extends State<AcademicDashboard> {
  final TextEditingController _effort = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();

  bool _baselineSet = false;
  int _academicSkillElo = 0;
  int _academicEffortElo = 0;

  final Map<String, double> _levelMultipliers = {
    'Primary (1x)': 1.0,
    'Secondary (1.5x)': 1.5,
    'Bachelors (2x)': 2.0,
    'Above Bachelors (2.25x)': 2.25,
  };
  
  String _selectedLevel = 'Bachelors (2x)'; 

  int get _totalElo => _academicSkillElo + _academicEffortElo;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && mounted) {
          var data = doc.data() as Map<String, dynamic>;
          setState(() {
            _academicSkillElo = data['academicSkillElo'] ?? 0;
            _academicEffortElo = data['academicEffortElo'] ?? 0;
            
            if (_academicSkillElo > 0 || _academicEffortElo > 0 || data.containsKey('academicMultiplier')) {
              _baselineSet = true;
            }
          });
        }
      } catch (e) {
        print("Error fetching academic data: $e");
      }
    }
  }

  String getRankName(int elo) {
    if (elo < 500) return "NOVICE SCHOLAR";
    if (elo < 1500) return "DEDICATED STUDENT";
    if (elo < 3500) return "HONOURS RESEARCHER";
    if (elo < 7000) return "MASTER INNOVATOR";
    return "CHIEF ARCHITECT";
  }

  Color getRankColor(int elo) {
    if (elo < 500) return Colors.blueGrey;
    if (elo < 1500) return Colors.lightBlue;
    if (elo < 3500) return Colors.blueAccent;
    if (elo < 7000) return Colors.indigoAccent;
    return Colors.deepPurpleAccent;
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

  void _calculateAcademicBaseline() async {
    int grade = int.tryParse(_gradeController.text) ?? 0;

    if (grade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid grade!")));
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
          'academicSkillElo': initialSkill,
          'academicGrade': grade,
          'academicMultiplier': multiplier,
          'academicLevelString': _selectedLevel,
        }, SetOptions(merge: true));

        if (mounted) Navigator.of(context).pop();

        setState(() {
          _academicSkillElo = initialSkill;
          _baselineSet = true;
        });
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
    }
  }

  void _addEffort() async {
    int mins = int.tryParse(_effort.text) ?? 0;

    if (mins > 0) {
      setState(() {
        _academicEffortElo += mins;
        _effort.clear();
      });

      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'academicEffortElo': FieldValue.increment(mins),
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
        child: _baselineSet ? _buildDashboard() : _buildOnboarding(),
      ),
    );
  }

  Widget _buildDashboard() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              getRankName(_totalElo),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: getRankColor(_totalElo), letterSpacing: 3),
            ),
          ),
        ),
        const SizedBox(height: 40),
        
        Icon(
          Icons.computer, 
          size: 120, 
          color: getRankColor(_totalElo)
        ),

        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatElo(_totalElo),
              style: const TextStyle(fontSize: 100, fontWeight: FontWeight.w900, height: 0.9, color: Colors.white)
            ),
          ),
        ),
        const Text("ACADEMIC ELO", style: TextStyle(color: Colors.white38, letterSpacing: 2)),
        const Spacer(),

        // Liquid Glass Bottom Bar
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _effort,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.timer_outlined, color: Colors.white38),
                        hintText: "Minutes studied...",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  FloatingActionButton(
                    onPressed: _addEffort,
                    backgroundColor: getRankColor(_totalElo),
                    elevation: 0,
                    child: const Icon(Icons.add, color: Colors.black),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnboarding() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                  const Icon(Icons.school, size: 80, color: Colors.white24),
                  const SizedBox(height: 20),
                  const Text("ACADEMIC BASELINE", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 40),
                  
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLevel,
                    dropdownColor: const Color(0xFF1A1A21),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.account_balance, color: Colors.white38),
                      labelText: "Education Level",
                      labelStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                    items: _levelMultipliers.keys.map((String level) {
                      return DropdownMenuItem<String>(
                        value: level,
                        child: Text(level),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedLevel = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: _gradeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.grade, color: Colors.white38),
                      labelText: "Current Grade (e.g. WAM/Average)",
                      labelStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _calculateAcademicBaseline,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("SET ACADEMIC ELO", style: TextStyle(fontWeight: FontWeight.bold)),
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