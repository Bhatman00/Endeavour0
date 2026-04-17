import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();
  String? lastSignUpError;

  // --- 1. SIGN IN ---
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  // --- 2. SIGN UP & SAVE INITIAL DATA ---
  // We pass the lifting stats here so they are saved immediately upon account creation
  Future<User?> signUp(
    String email,
    String password,
    String username,
    String region,
    int bench,
    int squat,
    int deadlift,
    int initialElo,
  ) async {
    try {
      lastSignUpError = null;
      final usernameValue = _sanitizeUsername(username);
      if (usernameValue.isEmpty) {
        lastSignUpError =
            'Invalid username. Use only letters, numbers, or underscores.';
        print('Sign Up Error: invalid username');
        return null;
      }

      if (region.trim().isEmpty) {
        lastSignUpError = 'Please select a region.';
        print('Sign Up Error: region missing');
        return null;
      }

      // Create the auth user FIRST so Firestore queries run authenticated
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user == null) {
        lastSignUpError = 'Failed to create account.';
        return null;
      }

      // Now check username uniqueness (user is authenticated)
      if (await _usernameExists(usernameValue)) {
        // Username taken — delete the auth user we just created
        await user.delete();
        lastSignUpError = 'Username is already taken.';
        print('Sign Up Error: username already taken');
        return null;
      }

      print('SignUp Debug: auth currentUser uid=${_auth.currentUser?.uid}');
      print('SignUp Debug: writing /users/${user.uid}');
      await user.updateDisplayName(usernameValue);
      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'uid': user.uid,
        'username': usernameValue,
        'usernameLower': usernameValue.toLowerCase(),
        'region': region.trim(),
        'bench': bench,
        'squat': squat,
        'deadlift': deadlift,
        'skillElo': initialElo,
        'effortElo': 0,
        'academicSkillElo': 0,
        'academicEffortElo': 0,
        'groupPaths': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      return user;
    } on FirebaseAuthException catch (e) {
      lastSignUpError = e.message ?? 'Sign Up failed. Please try again.';
      print("Sign Up Error [Auth]: ${e.code} - ${e.message}");
      return null;
    } on FirebaseException catch (e) {
      lastSignUpError = e.message ?? 'Sign Up failed during Firestore write.';
      print("Sign Up Error [Firestore]: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      lastSignUpError = e.toString();
      print("Sign Up Error: $e");
      return null;
    }
  }

  Future<bool> _usernameExists(String username) async {
    final query = await _firestore
        .collection('users')
        .where('usernameLower', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  String _sanitizeUsername(String username) {
    final sanitized = username.trim();
    if (sanitized.isEmpty) return '';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(sanitized)) return '';
    return sanitized;
  }

  Future<String> _buildUniqueUsername(String email) async {
    String base = email
        .split('@')
        .first
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
        .toLowerCase();
    if (base.isEmpty) {
      base = 'user${_random.nextInt(9999)}';
    }

    String candidate = base;
    int suffix = 0;

    while (true) {
      final existing = await _firestore
          .collection('users')
          .where('usernameLower', isEqualTo: candidate)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        return candidate;
      }
      suffix += 1;
      candidate = '$base$suffix';
    }
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('usernameLower', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
    } catch (e) {
      print('Username lookup failed: $e');
    }
    return null;
  }

  // --- 3. RETRIEVE USER DATA ---
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
    return null;
  }

  // --- 4. SIGN OUT ---
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
