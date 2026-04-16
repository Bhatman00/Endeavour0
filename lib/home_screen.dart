import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'gym_dashboard.dart';
import 'academic_dashboard.dart';
import 'groups_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Backend logic untouched
  void _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // Reusable widget for creating new paths easily
  Widget _buildPathCircle(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget destination,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(icon, size: 50, color: color),
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            letterSpacing: 2,
          ),
        ),
      ],
    );
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

                    // Wrap automatically handles putting items on the next line when there are too many
                    Wrap(
                      spacing: 40,
                      runSpacing: 40,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildPathCircle(
                          context,
                          "GYM",
                          Icons.fitness_center,
                          Colors.orange,
                          const GymDashboard(),
                        ),
                        _buildPathCircle(
                          context,
                          "ACADEMICS",
                          Icons.school,
                          Colors.blueAccent,
                          const AcademicDashboard(),
                        ),
                        // Fix 3: Added the missing Leaderboard
                        _buildPathCircle(
                          context,
                          "LEADERBOARD",
                          Icons.emoji_events,
                          Colors.amber,
                          const LeaderboardScreen(),
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
          ],
        ),
      ),
    );
  }
}
