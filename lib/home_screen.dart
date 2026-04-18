import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gym_dashboard.dart';
import 'academic_dashboard.dart';
import 'art_dashboard.dart';
import 'groups_screen.dart';
import 'leaderboard_screen.dart';
import 'notifications_screen.dart';
import 'social_service.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Backend logic untouched
  void _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "ENDEAVOUR",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            color: Colors.white,
          ),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: SocialService().getNotificationsStream(),
            builder: (context, snapshot) {
              int count = snapshot.data?.docs.length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white54,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: _signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Fix 1: Replaced SizedBox with Positioned.fill to prevent the Stack crash
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "CHOOSE YOUR ENDEAVOUR",
                      style: TextStyle(
                        color: Colors.white54,
                        letterSpacing: 2,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 50),

                    Wrap(
                      spacing: 40,
                      runSpacing: 40,
                      alignment: WrapAlignment.center,
                      children: const [
                        PathCircle(
                          title: "GYM",
                          icon: Icons.fitness_center,
                          color: Colors.orange,
                          destination: GymDashboard(),
                        ),
                        PathCircle(
                          title: "ACADEMICS",
                          icon: Icons.school,
                          color: Colors.blueAccent,
                          destination: AcademicDashboard(),
                        ),
                        PathCircle(
                          title: "ART",
                          icon: Icons.palette,
                          color: Colors.purpleAccent,
                          destination: ArtDashboard(),
                        ),
                        PathCircle(
                          title: "LEADERBOARD",
                          icon: Icons.emoji_events,
                          color: Colors.amber,
                          destination: LeaderboardScreen(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Fix 2: Moved the right spacing to the Positioned widget to stop the ClipOval from cutting off
            Positioned(
              right: 4,
              top: 128,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GroupsScreen()),
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: Colors.greenAccent.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.group,
                        size: 26,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Profile Picture - Top Middle
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(targetUid: uid),
                        ),
                      );
                    }
                  },
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      String? photoUrl;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>?;
                        photoUrl = data?['photoUrl'] as String?;
                      }

                      return Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: photoUrl != null
                              ? Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.person,
                                        color: Colors.white54,
                                        size: 35,
                                      ),
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        );
                                      },
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white54,
                                  size: 35,
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PathCircle extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget destination;

  const PathCircle({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.destination,
  });

  @override
  State<PathCircle> createState() => _PathCircleState();
}

class _PathCircleState extends State<PathCircle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => widget.destination),
            ),
            child: AnimatedScale(
              scale: _isHovered ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(
                            alpha: _isHovered ? 0.3 : 0.0,
                          ),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(
                            alpha: _isHovered ? 0.12 : 0.05,
                          ),
                          border: Border.all(
                            color: widget.color.withValues(
                              alpha: _isHovered ? 0.6 : 0.3,
                            ),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          widget.icon,
                          size: 50,
                          color: widget.color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _isHovered ? widget.color : Colors.white70,
            letterSpacing: 2,
          ),
          child: Text(widget.title),
        ),
      ],
    );
  }
}
