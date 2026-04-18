import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GymDashboard extends StatefulWidget {
  const GymDashboard({super.key});

  @override
  State<GymDashboard> createState() => _GymDashboardState();
}

class _GymDashboardState extends State<GymDashboard> {
  final TextEditingController _bench = TextEditingController();
  final TextEditingController _squat = TextEditingController();
  final TextEditingController _deadlift = TextEditingController();
  final TextEditingController _effort = TextEditingController();

  bool _prsSet = false;
  int _skillElo = 0;
  int _effortElo = 0;

  int get _totalElo => _skillElo + _effortElo;

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
            _skillElo = data['skillElo'] ?? 0;
            _effortElo = data['effortElo'] ?? 0;

            if (_skillElo > 0 ||
                _effortElo > 0 ||
                data.containsKey('bench') ||
                data.containsKey('squat') ||
                data.containsKey('deadlift')) {
              _prsSet = true;
            }
          });
        }
      } catch (e) {
        print("Error fetching user data: $e");
      }
    }
  }

  String getRankName(int elo) {
    if (elo < 500) return "IRON NOVICE";
    if (elo < 1500) return "BRONZE GRINDER";
    if (elo < 3500) return "SILVER LIFTER";
    if (elo < 7000) return "GOLD CRUSHER";
    if (elo < 12000) return "PLATINUM POWER";
    if (elo < 20000) return "DIAMOND ELITE";
    if (elo < 35000) return "MASTER TITAN";
    if (elo < 55000) return "GRANDMASTER LEGEND";
    if (elo < 85000) return "MYTHIC VANGUARD";
    return "CELESTIAL CHAMPION";
  }

  Color getRankColor(int elo) {
    if (elo < 500) return Colors.blueGrey;
    if (elo < 1500) return Colors.brown;
    if (elo < 3500) return Colors.grey;
    if (elo < 7000) return Colors.orange;
    if (elo < 12000) return Colors.cyan;
    return Colors.purpleAccent;
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

  void _calculateBaseline() async {
    int b = int.tryParse(_bench.text) ?? 0;
    int s = int.tryParse(_squat.text) ?? 0;
    int d = int.tryParse(_deadlift.text) ?? 0;

    if (b == 0 && s == 0 && d == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your stats first!")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      int initialSkill = (b + s + d) * 5;
      String? uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'bench': b,
          'squat': s,
          'deadlift': d,
          'skillElo': initialSkill,
        }, SetOptions(merge: true));

        if (mounted) Navigator.of(context).pop();

        setState(() {
          _skillElo = initialSkill;
          _prsSet = true;
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
        _effortElo += mins;
        _effort.clear();
      });

      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'effortElo': FieldValue.increment(mins),
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
        child: _prsSet
            ? _Dashboard(
                totalElo: _totalElo,
                effortController: _effort,
                onAddEffort: _addEffort,
                rankName: getRankName(_totalElo),
                rankColor: getRankColor(_totalElo),
                formatElo: _formatElo(_totalElo),
              )
            : _Onboarding(
                bench: _bench,
                squat: _squat,
                deadlift: _deadlift,
                onCalculate: _calculateBaseline,
              ),
      ),
    );
  }
}

class _StaticStickMan extends StatelessWidget {
  final Color rankColor;

  const _StaticStickMan({required this.rankColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: 150,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 60,
            child: Row(
              children: [
                Container(width: 20, height: 20, color: Colors.black),
                Container(width: 100, height: 4, color: Colors.grey),
                Container(width: 20, height: 20, color: Colors.black),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: rankColor, width: 3),
                ),
              ),
              Container(width: 3, height: 40, color: rankColor),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: 0.5,
                    child: Container(width: 3, height: 30, color: rankColor),
                  ),
                  const SizedBox(width: 10),
                  Transform.rotate(
                    angle: -0.5,
                    child: Container(width: 3, height: 30, color: rankColor),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 50,
            child: Row(
              children: [
                Transform.rotate(
                  angle: 0.5,
                  child: Container(width: 3, height: 30, color: rankColor),
                ),
                const SizedBox(width: 40),
                Transform.rotate(
                  angle: -0.5,
                  child: Container(width: 3, height: 30, color: rankColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final int totalElo;
  final TextEditingController effortController;
  final VoidCallback onAddEffort;
  final String rankName;
  final Color rankColor;
  final String formatElo;

  const _Dashboard({
    required this.totalElo,
    required this.effortController,
    required this.onAddEffort,
    required this.rankName,
    required this.rankColor,
    required this.formatElo,
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
        const SizedBox(height: 20),
        _StaticStickMan(rankColor: rankColor),
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
          "TOTAL ELO",
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
                        hintText: "Minutes...",
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

class _StyledInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _StyledInput({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white38),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _Onboarding extends StatelessWidget {
  final TextEditingController bench;
  final TextEditingController squat;
  final TextEditingController deadlift;
  final VoidCallback onCalculate;

  const _Onboarding({
    required this.bench,
    required this.squat,
    required this.deadlift,
    required this.onCalculate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(30.0),
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
                  const Icon(Icons.fitness_center, size: 80, color: Colors.white24),
                  const SizedBox(height: 20),
                  const Text(
                    "GYM BASELINE",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _StyledInput(controller: bench, label: "Bench Press (kg)", icon: Icons.remove),
                  const SizedBox(height: 15),
                  _StyledInput(controller: squat, label: "Squat (kg)", icon: Icons.keyboard_arrow_down),
                  const SizedBox(height: 15),
                  _StyledInput(controller: deadlift, label: "Deadlift (kg)", icon: Icons.vertical_align_top),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: onCalculate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("START MY JOURNEY", style: TextStyle(fontWeight: FontWeight.bold)),
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
