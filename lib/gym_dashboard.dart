import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'rank_utils.dart';
import 'juice_widgets.dart';
import 'lifting_utils.dart';

class GymDashboard extends StatefulWidget {
  const GymDashboard({super.key});

  @override
  State<GymDashboard> createState() => _GymDashboardState();
}

class _GymDashboardState extends State<GymDashboard> {
  final TextEditingController _bench = TextEditingController();
  final TextEditingController _squat = TextEditingController();
  final TextEditingController _deadlift = TextEditingController();
  final TextEditingController _bodyweight = TextEditingController();
  final TextEditingController _effort = TextEditingController();
  String _gender = 'male';

  bool _prsSet = false;
  int _skillElo = 0;
  int _effortElo = 0;
  String? _previousRankName;
  bool _showCelebration = false;
  Rank? _currentRank;

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
            _gender = data['gender'] ?? 'male';
            _bodyweight.text = (data['bodyweight'] ?? 0.0).toString();
            _bench.text = (data['bench'] ?? 0).toString();
            _squat.text = (data['squat'] ?? 0).toString();
            _deadlift.text = (data['deadlift'] ?? 0).toString();
            _currentRank = RankUtils.getRank(_totalElo, RankUtils.gymRanks);
            _previousRankName = _currentRank?.name;

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

  void _calculateBaseline() async {
    int b = int.tryParse(_bench.text) ?? 0;
    int s = int.tryParse(_squat.text) ?? 0;
    int d = int.tryParse(_deadlift.text) ?? 0;
    double bw = double.tryParse(_bodyweight.text) ?? 0.0;

    if (b == 0 && s == 0 && d == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your stats first!")),
      );
      return;
    }

    if (bw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your bodyweight!")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      double totalKg = (b + s + d).toDouble();
      double wilksScore = LiftingUtils.calculateWilksScore(totalKg, bw, _gender);
      int initialSkill = (wilksScore * 5).toInt(); // Scale for Elo system

      String? uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'bench': b,
          'squat': s,
          'deadlift': d,
          'bodyweight': bw,
          'gender': _gender,
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

  void _uploadPRPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          // Upload to Firebase Storage
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('pr_photos')
              .child('$uid.jpg');
          
          await storageRef.putFile(File(image.path));
          
          // Get download URL
          final downloadUrl = await storageRef.getDownloadURL();
          
          // Save to Firestore
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'prPhotoUrl': downloadUrl,
            'prVerified': true,
          }, SetOptions(merge: true));
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("PR verified with photo!")),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to upload: $e")),
          );
        }
      }
    }
  }

  void _addEffort() async {
    int mins = int.tryParse(_effort.text) ?? 0;

    if (mins > 0) {
      // Haptic Feedback on Add
      HapticFeedback.heavyImpact();
      
      final int newTotal = _totalElo + mins;
      final newRank = RankUtils.getRank(newTotal, RankUtils.gymRanks);
      
      setState(() {
        _effortElo += mins;
        _effort.clear();
        
        if (_previousRankName != null && newRank.name != _previousRankName) {
          _showCelebration = true;
          _currentRank = newRank;
        }
        _previousRankName = newRank.name;
      });

      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'effortElo': FieldValue.increment(mins),
        }, SetOptions(merge: true));
      }
    }
  }

  void _showEditLiftsDialog() {
    // Create temporary controllers with current values
    final TextEditingController benchController = TextEditingController(text: _bench.text);
    final TextEditingController squatController = TextEditingController(text: _squat.text);
    final TextEditingController deadliftController = TextEditingController(text: _deadlift.text);
    final TextEditingController bodyweightController = TextEditingController(text: _bodyweight.text);
    String selectedGender = _gender;

    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Update Your Lifts',
            style: TextStyle(color: Colors.white),
          ),
          content: isLoading
              ? const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StyledInput(controller: benchController, label: "Bench Press (kg)", icon: Icons.remove),
                      const SizedBox(height: 10),
                      _StyledInput(controller: squatController, label: "Squat (kg)", icon: Icons.keyboard_arrow_down),
                      const SizedBox(height: 10),
                      _StyledInput(controller: deadliftController, label: "Deadlift (kg)", icon: Icons.vertical_align_top),
                      const SizedBox(height: 10),
                      _StyledInput(controller: bodyweightController, label: "Bodyweight (kg)", icon: Icons.monitor_weight),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            "Gender:",
                            style: TextStyle(color: Colors.white38, fontSize: 16),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: DropdownButton<String>(
                              value: selectedGender,
                              dropdownColor: Colors.black,
                              style: const TextStyle(color: Colors.white),
                              items: const [
                                DropdownMenuItem(value: 'male', child: Text('Male')),
                                DropdownMenuItem(value: 'female', child: Text('Female')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => selectedGender = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          actions: isLoading
              ? null
              : [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      int b = int.tryParse(benchController.text) ?? 0;
                      int s = int.tryParse(squatController.text) ?? 0;
                      int d = int.tryParse(deadliftController.text) ?? 0;
                      double bw = double.tryParse(bodyweightController.text) ?? 0.0;

                      if (b == 0 && s == 0 && d == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter your stats!")),
                        );
                        return;
                      }

                      if (bw <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter your bodyweight!")),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        double totalKg = (b + s + d).toDouble();
                        double wilksScore = LiftingUtils.calculateWilksScore(totalKg, bw, selectedGender);
                        int newSkill = (wilksScore * 5).toInt();

                        String? uid = FirebaseAuth.instance.currentUser?.uid;

                        if (uid != null) {
                          await FirebaseFirestore.instance.collection('users').doc(uid).set({
                            'bench': b,
                            'squat': s,
                            'deadlift': d,
                            'bodyweight': bw,
                            'gender': selectedGender,
                            'skillElo': newSkill,
                          }, SetOptions(merge: true));

                          if (mounted) Navigator.of(context).pop();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Lifts updated successfully!")),
                            );
                          }

                          if (mounted) {
                            setState(() {
                              _skillElo = newSkill;
                              _gender = selectedGender;
                              _bench.text = b.toString();
                              _squat.text = s.toString();
                              _deadlift.text = d.toString();
                              _bodyweight.text = bw.toString();
                            });
                          }
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to update: $e")),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Update'),
                  ),
                ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditLiftsDialog,
            tooltip: 'Edit Lifts',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _prsSet
                ? _Dashboard(
                    totalElo: _totalElo,
                    effortController: _effort,
                    onAddEffort: _addEffort,
                    onUploadPRPhoto: _uploadPRPhoto,
                    rank: RankUtils.getRank(_totalElo, RankUtils.gymRanks),
                  )
                : _Onboarding(
                    bench: _bench,
                    squat: _squat,
                    deadlift: _deadlift,
                    bodyweight: _bodyweight,
                    gender: _gender,
                    onGenderChanged: (value) => setState(() => _gender = value),
                    onCalculate: _calculateBaseline,
                  ),
            if (_showCelebration && _currentRank != null)
              RankUpCelebration(
                newRank: _currentRank!,
                onDismiss: () => setState(() => _showCelebration = false),
              ),
          ],
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
  final VoidCallback onUploadPRPhoto;
  final Rank rank;

  const _Dashboard({
    required this.totalElo,
    required this.effortController,
    required this.onAddEffort,
    required this.onUploadPRPhoto,
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
        const SizedBox(height: 20),
        _StaticStickMan(rankColor: rank.color),
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
              child: Column(
                children: [
                  Row(
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
                        backgroundColor: rank.color,
                        elevation: 0,
                        child: const Icon(Icons.add, color: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: onUploadPRPhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Verify PR with Photo"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
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

class _Onboarding extends StatefulWidget {
  final TextEditingController bench;
  final TextEditingController squat;
  final TextEditingController deadlift;
  final TextEditingController bodyweight;
  final String gender;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onCalculate;

  const _Onboarding({
    required this.bench,
    required this.squat,
    required this.deadlift,
    required this.bodyweight,
    required this.gender,
    required this.onGenderChanged,
    required this.onCalculate,
  });

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {

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
                  _StyledInput(controller: widget.bench, label: "Bench Press (kg)", icon: Icons.remove),
                  const SizedBox(height: 15),
                  _StyledInput(controller: widget.squat, label: "Squat (kg)", icon: Icons.keyboard_arrow_down),
                  const SizedBox(height: 15),
                  _StyledInput(controller: widget.deadlift, label: "Deadlift (kg)", icon: Icons.vertical_align_top),
                  const SizedBox(height: 15),
                  _StyledInput(controller: widget.bodyweight, label: "Bodyweight (kg)", icon: Icons.monitor_weight),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Text(
                        "Gender:",
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: DropdownButton<String>(
                          value: widget.gender,
                          dropdownColor: Colors.black,
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              widget.onGenderChanged(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: widget.onCalculate,
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
