
class UserModel {
  final String uid;
  final String displayName;
  
  // Elo Points (The "Keep" part)
  double gymSkillPoints;      // Every kilo * 5
  double artSkillPoints;      // Rating * 10
  double academicSkillPoints; // Grade * Yr Lvl
  
  // Effort Points (The "Wipe" part)
  double effortPoints;        
  
  int rank; // 1-10 (or top %)

  UserModel({
    required this.uid,
    required this.displayName,
    this.gymSkillPoints = 0.0,
    this.artSkillPoints = 0.0,
    this.academicSkillPoints = 0.0,
    this.effortPoints = 0.0,
    this.rank = 1,
  });

  // Total Elo Calculation based on your rules: Effort + Skills
  double get gymElo => effortPoints + gymSkillPoints;
  double get artElo => effortPoints + artSkillPoints;
  double get academicElo => effortPoints + academicSkillPoints;

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'gymSkillPoints': gymSkillPoints,
      'artSkillPoints': artSkillPoints,
      'academicSkillPoints': academicSkillPoints,
      'effortPoints': effortPoints,
      'rank': rank,
    };
  }

  // Create UserModel from Firestore Document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? '',
      gymSkillPoints: (map['gymSkillPoints'] ?? 0).toDouble(),
      artSkillPoints: (map['artSkillPoints'] ?? 0).toDouble(),
      academicSkillPoints: (map['academicSkillPoints'] ?? 0).toDouble(),
      effortPoints: (map['effortPoints'] ?? 0).toDouble(),
      rank: map['rank'] ?? 1,
    );
  }
}