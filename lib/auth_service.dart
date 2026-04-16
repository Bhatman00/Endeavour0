import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. SIGN IN ---
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  // --- 2. SIGN UP & SAVE INITIAL DATA ---
  // We pass the lifting stats here so they are saved immediately upon account creation
  Future<User?> signUp(String email, String password, int bench, int squat, int deadlift, int initialElo) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      User? user = result.user;
      
      if (user != null) {
        // Create a new document for the user in Firestore using their unique UID
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'bench': bench,
          'squat': squat,
          'deadlift': deadlift,
          'skillElo': initialElo,
          'effortElo': 0, // Everyone starts with 0 effort points
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } catch (e) {
      print("Sign Up Error: $e");
      return null;
    }
  }

  // --- 3. RETRIEVE USER DATA ---
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
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