import 'dart:ui';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'social_service.dart';
import 'auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String targetUid;

  const ProfileScreen({super.key, required this.targetUid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  int _globalRank = 0;
  bool _isLoading = true;
  bool _isUploading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUid)
          .get();

      if (!doc.exists) {
        if (mounted) {
          setState(() {
            _errorMessage = "User not found.";
            _isLoading = false;
          });
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final int userElo = _calculateTotalElo(data);

      // Perform a much more efficient count query to find rank
      // This is O(Rank) instead of O(TotalUsers) and uses significantly less bandwidth
      final countQuery = FirebaseFirestore.instance
          .collection('users')
          .where('totalElo', isGreaterThan: userElo);
      
      final countSnapshot = await countQuery.count().get();
      final rank = (countSnapshot.count ?? 0) + 1;

      if (mounted) {
        setState(() {
          _userData = data;
          _globalRank = rank;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            bool isPrivate = _userData?['isPrivate'] ?? false;
            
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C21),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Profile Settings",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndUploadImage();
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.amber),
                      ),
                      title: const Text(
                        "Change Profile Picture",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        "Upload from gallery",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                    ),
                    
                    const SizedBox(height: 10),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.lock, color: Colors.blueAccent),
                      ),
                      title: const Text(
                        "Private Profile",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        "Hide from global/regional leaderboards",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: Switch(
                        value: isPrivate,
                        activeThumbColor: Colors.blueAccent,
                        activeTrackColor: Colors.blueAccent.withValues(alpha: 0.5),
                        onChanged: (val) async {
                          setSheetState(() => isPrivate = val);
                          await AuthService().updatePrivacy(val);
                          _loadProfile();
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        _showUsernameDialog();
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit, color: Colors.purpleAccent),
                      ),
                      title: const Text(
                        "Change Username",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        "Update your display name",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                    ),
                    
                    const SizedBox(height: 30),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 10),
                    ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation();
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      ),
                      title: const Text(
                        "Delete Account",
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUsernameDialog() {
    final controller = TextEditingController(text: _userData?['username']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C21),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Change Username", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "New username...",
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              try {
                await AuthService().updateUsername(controller.text);
                if (mounted) {
                  nav.pop();
                  _loadProfile();
                  messenger.showSnackBar(
                    const SnackBar(content: Text("Username updated!")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll("Exception: ", "")),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text("SAVE", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C21),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Account?", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This action is permanent and will delete all your data. To continue, please enter your password:",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Password",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password is required to delete account")),
                );
                return;
              }

              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              try {
                // 1. Re-authenticate
                await AuthService().reauthenticate(passwordController.text);
                
                // 2. Delete
                await AuthService().deleteUserAccount();
                
                if (mounted) {
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  String errorMsg = e.toString();
                  if (errorMsg.contains("reauth-required")) {
                    errorMsg = "Login timeout. Please logout and log back in before deleting.";
                  } else if (errorMsg.contains("invalid-credential") || errorMsg.contains("wrong-password")) {
                    errorMsg = "Incorrect password. Deletion cancelled.";
                  }
                  
                  messenger.showSnackBar(
                    SnackBar(content: Text("Delete failed: $errorMsg"), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text("DELETE PERMANENTLY", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUploading = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pics')
          .child('${widget.targetUid}.jpg');
      
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();
      
      await AuthService().updateProfilePicture(url);
      
      _loadProfile(); 
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Profile picture updated!")),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  int _calculateTotalElo(Map<String, dynamic> data) {

    return _toInt(data['skillElo']) +
        _toInt(data['effortElo']) +
        _toInt(data['academicSkillElo']) +
        _toInt(data['academicEffortElo']) +
        _toInt(data['artSkillElo']) +
        _toInt(data['artEffortElo']);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "Unknown";
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
    }
    return "Unknown";
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMe =
        FirebaseAuth.instance.currentUser?.uid == widget.targetUid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isMe)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70),
              onPressed: _showSettingsSheet,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage.isNotEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Image
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 2),
                            color: Colors.white.withValues(alpha: 0.1),
                            image: _userData?['photoUrl'] != null
                                ? DecorationImage(
                                    image: NetworkImage(_userData!['photoUrl']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _userData?['photoUrl'] == null
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white54,
                                )
                              : null,
                        ),
                        if (_isUploading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.amber),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Username & Region
                    Text(
                      _userData?['username'] ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _userData?['region'] ?? 'Unknown Region',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Rank Banner
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.withValues(alpha: 0.2),
                                Colors.amber.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  const Text(
                                    "Global Rank",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "#$_globalRank",
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white24,
                              ),
                              Column(
                                children: [
                                  const Text(
                                    "Member Since",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(_userData?['createdAt']),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Social Actions
                    if (!isMe)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await SocialService().sendFriendRequest(
                                    widget.targetUid,
                                  );
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text("Friend request sent!"),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text("Failed: ${e.toString()}"),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.person_add,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Add Friend",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final myUid =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  if (myUid == null) return;
                                  final userDoc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(myUid)
                                      .get();
                                  final paths = List<String>.from(
                                    userDoc.data()?['groupPaths'] ?? [],
                                  );
                                  if (paths.isEmpty) {
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "You aren't in any groups yet!",
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  final groupDoc = await FirebaseFirestore
                                      .instance
                                      .doc(paths.first)
                                      .get();
                                  final groupData = groupDoc.data();
                                  if (groupData != null) {
                                    await SocialService().sendGroupInvite(
                                      widget.targetUid,
                                      groupDoc.id,
                                      groupData['name'] ?? 'Group',
                                    );
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Invited to ${groupData['name']}!",
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text("Failed: ${e.toString()}"),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.group_add,
                                color: Colors.black,
                              ),
                              label: const Text(
                                "Invite",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!isMe) const SizedBox(height: 25),

                    // Skills Breakdown
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Skills Breakdown",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _SkillCard(
                          title: "Gym",
                          icon: Icons.fitness_center,
                          pts: _toInt(_userData?['skillElo']) +
                              _toInt(_userData?['effortElo']),
                          glowColor: Colors.redAccent,
                        ),
                        const SizedBox(width: 10),
                        _SkillCard(
                          title: "Academic",
                          icon: Icons.school,
                          pts: _toInt(_userData?['academicSkillElo']) +
                              _toInt(_userData?['academicEffortElo']),
                          glowColor: Colors.blueAccent,
                        ),
                        const SizedBox(width: 10),
                        _SkillCard(
                          title: "Art",
                          icon: Icons.palette,
                          pts: _toInt(_userData?['artSkillElo']) +
                              _toInt(_userData?['artEffortElo']),
                          glowColor: Colors.purpleAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int pts;
  final Color glowColor;

  const _SkillCard({
    required this.title,
    required this.icon,
    required this.pts,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.white70, size: 28),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  pts.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
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
