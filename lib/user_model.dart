import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String usernameLower;
  final String email;
  final String region;
  final String? photoUrl;
  final bool isPrivate;
  
  // Gym Stats
  final int bench;
  final int squat;
  final int deadlift;
  final double bodyweight; // in kg
  final String gender; // 'male' or 'female'

  // Elo Points
  final int skillElo;
  final int effortElo;
  final int academicSkillElo;
  final int academicEffortElo;
  final int artSkillElo;
  final int artEffortElo;
  
  final List<String> groupPaths;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.username,
    required this.usernameLower,
    required this.email,
    required this.region,
    this.photoUrl,
    this.isPrivate = false,
    this.bench = 0,
    this.squat = 0,
    this.deadlift = 0,
    this.bodyweight = 0.0,
    this.gender = 'male',
    this.skillElo = 0,
    this.effortElo = 0,
    this.academicSkillElo = 0,
    this.academicEffortElo = 0,
    this.artSkillElo = 0,
    this.artEffortElo = 0,
    this.groupPaths = const [],
    this.createdAt,
  });

  // Total Elo Calculations
  int get gymElo => skillElo + effortElo;
  int get academicElo => academicSkillElo + academicEffortElo;
  int get artElo => artSkillElo + artEffortElo;
  int get totalElo => gymElo + academicElo + artElo;

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'usernameLower': usernameLower,
      'email': email,
      'region': region,
      'photoUrl': photoUrl,
      'isPrivate': isPrivate,
      'bench': bench,
      'squat': squat,
      'deadlift': deadlift,
      'bodyweight': bodyweight,
      'gender': gender,
      'skillElo': skillElo,
      'effortElo': effortElo,
      'academicSkillElo': academicSkillElo,
      'academicEffortElo': academicEffortElo,
      'artSkillElo': artSkillElo,
      'artEffortElo': artEffortElo,
      'groupPaths': groupPaths,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  // Create UserModel from Firestore Document
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      username: map['username'] ?? 'Unknown',
      usernameLower: map['usernameLower'] ?? '',
      email: map['email'] ?? '',
      region: map['region'] ?? 'Unknown',
      photoUrl: map['photoUrl'],
      isPrivate: map['isPrivate'] ?? false,
      bench: (map['bench'] ?? 0).toInt(),
      squat: (map['squat'] ?? 0).toInt(),
      deadlift: (map['deadlift'] ?? 0).toInt(),
      bodyweight: (map['bodyweight'] ?? 0.0).toDouble(),
      gender: map['gender'] ?? 'male',
      skillElo: (map['skillElo'] ?? 0).toInt(),
      effortElo: (map['effortElo'] ?? 0).toInt(),
      academicSkillElo: (map['academicSkillElo'] ?? 0).toInt(),
      academicEffortElo: (map['academicEffortElo'] ?? 0).toInt(),
      artSkillElo: (map['artSkillElo'] ?? 0).toInt(),
      artEffortElo: (map['artEffortElo'] ?? 0).toInt(),
      groupPaths: List<String>.from(map['groupPaths'] ?? []),
      createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }
}