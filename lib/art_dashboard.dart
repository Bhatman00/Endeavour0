import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'art_service.dart';
import 'art_model.dart';
import 'user_model.dart';
import 'rank_utils.dart';
import 'juice_widgets.dart';

class ArtDashboard extends StatefulWidget {
  const ArtDashboard({super.key});

  @override
  State<ArtDashboard> createState() => _ArtDashboardState();
}

class _ArtDashboardState extends State<ArtDashboard> {
  final ArtService _artService = ArtService();
  final TextEditingController _effortController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  UserModel? _currentUser;
  List<ArtModel> _assessmentFeed = [];
  bool _isLoading = true;
  File? _selectedImage;
  ArtModel? _currentRatingArt;
  bool _showRatingDialog = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchAssessmentFeed();
  }

  Future<void> _fetchUserData() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() {
          _currentUser = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        });
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchAssessmentFeed() async {
    _assessmentFeed = await _artService.getAssessmentFeed();
    setState(() {});
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadArt() async {
    if (_selectedImage == null) return;

    try {
      bool canUpload = await _artService.canUploadArt();
      if (!canUpload) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough critique tokens!')),
        );
        return;
      }

      // For now, just use a placeholder URL. In real app, upload to storage
      String imageUrl = 'placeholder_${DateTime.now().millisecondsSinceEpoch}';

      bool isPlacement = _currentUser != null && !_currentUser!.isRankedInArt;

      await _artService.uploadArt(imageUrl, isPlacement);
      await _artService.spendTokensForUpload();

      if (isPlacement && _currentUser != null) {
        // Check if now have 5 placements
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
        UserModel updatedUser = UserModel.fromMap(userDoc.data() as Map<String, dynamic>, userDoc.id);
        if (updatedUser.placementArtIds.length == 5) {
          await _artService.calculateStartingSkillElo(_currentUser!.uid);
        }
      }

      _fetchUserData();
      setState(() => _selectedImage = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Art uploaded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading art: $e')),
      );
    }
  }

  void _showRatingDialogForArt(ArtModel art) {
    setState(() {
      _currentRatingArt = art;
      _showRatingDialog = true;
    });
  }

  Future<void> _submitRating(int rating) async {
    if (_currentRatingArt == null) return;

    try {
      await _artService.rateArt(_currentRatingArt!.id, rating, _commentController.text.isEmpty ? null : _commentController.text);
      _fetchAssessmentFeed();
      _fetchUserData();
      setState(() {
        _showRatingDialog = false;
        _currentRatingArt = null;
        _commentController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating submitted! +1 Critique Token')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _logEffort() async {
    int minutes = int.tryParse(_effortController.text) ?? 0;
    if (minutes <= 0) return;

    try {
      await _artService.logEffortTime(minutes);
      _fetchUserData();
      _effortController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Effort logged!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging effort: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentUser == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F13),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Art Dashboard', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Stats
            _buildStatsCard(),
            const SizedBox(height: 20),

            // Upload Section
            _buildUploadSection(),
            const SizedBox(height: 20),

            // Assessment Feed
            _buildAssessmentFeed(),
            const SizedBox(height: 20),

            // Effort Logging
            _buildEffortSection(),

            // Rating Dialog
            if (_showRatingDialog && _currentRatingArt != null) _buildRatingDialog(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    Rank? rank = RankUtils.getRank(_currentUser!.artElo, RankUtils.artRanks);
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Art Stats', style: TextStyle(color: rank?.color ?? Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem('Skill Elo', _currentUser!.artSkillElo.toString()),
                _statItem('Effort Elo', _currentUser!.artEffortElo.toString()),
                _statItem('Total Elo', _currentUser!.artElo.toString()),
                _statItem('Tokens', _currentUser!.critiqueTokens.toString()),
              ],
            ),
            if (!_currentUser!.isRankedInArt) ...[
              const SizedBox(height: 10),
              Text('Unranked - Complete 5 placement uploads to get ranked!', style: TextStyle(color: Colors.yellow)),
              LinearProgressIndicator(value: _currentUser!.placementArtIds.length / 5),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildUploadSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Upload Art', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_selectedImage != null)
              Image.file(_selectedImage!, height: 200, fit: BoxFit.cover)
            else
              Container(
                height: 200,
                color: Colors.grey[800],
                child: const Center(child: Text('No image selected', style: TextStyle(color: Colors.white54))),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Pick Image'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _uploadArt,
                    child: Text(_currentUser!.isRankedInArt ? 'Upload (3 tokens)' : 'Upload Placement'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentFeed() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Assessment Feed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_assessmentFeed.isEmpty)
              const Text('No art to rate', style: TextStyle(color: Colors.white54))
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _assessmentFeed.length,
                  itemBuilder: (context, index) {
                    ArtModel art = _assessmentFeed[index];
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              color: Colors.grey[800],
                              child: const Center(child: Text('Art Image', style: TextStyle(color: Colors.white))),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text('${art.ratings.length}/3 ratings', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ElevatedButton(
                            onPressed: () => _showRatingDialogForArt(art),
                            child: const Text('Rate'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffortSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Log Practice Time', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _effortController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutes practiced (max 120/day)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _logEffort,
              child: Text('Log Effort (+${((_currentUser!.artSkillMultiplier * 120).round())} Elo max)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingDialog() {
    return Dialog(
      backgroundColor: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Rate this Art', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              height: 200,
              color: Colors.grey[800],
              child: const Center(child: Text('Art Image', style: TextStyle(color: Colors.white))),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                int star = index + 1;
                return IconButton(
                  icon: Icon(
                    Icons.star,
                    color: Colors.yellow,
                    size: 30,
                  ),
                  onPressed: () => _submitRating(star),
                );
              }),
            ),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Optional comment',
                labelStyle: TextStyle(color: Colors.white54),
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => setState(() => _showRatingDialog = false),
              child: const Text('Cancel'),
            ),
          ],
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
