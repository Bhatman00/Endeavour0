import 'package:flutter/material.dart';

class Rank {
  final String name;
  final Color color;
  final int threshold;

  const Rank({
    required this.name,
    required this.color,
    required this.threshold,
  });
}

class RankUtils {
  static const List<Rank> gymRanks = [
    Rank(name: "GRAVITY DEFIER", color: Colors.blueGrey, threshold: 0),
    Rank(name: "BRONZE GRINDER", color: Colors.brown, threshold: 500),
    Rank(name: "SILVER LIFTER", color: Colors.grey, threshold: 1500),
    Rank(name: "GOLD CRUSHER", color: Colors.orange, threshold: 3500),
    Rank(name: "PLATFORM VETERAN", color: Colors.cyan, threshold: 7000),
    Rank(name: "DIAMOND ELITE", color: Colors.blueAccent, threshold: 12000),
    Rank(name: "MASTER TITAN", color: Colors.purpleAccent, threshold: 20000),
    Rank(name: "GRANDMASTER LEGEND", color: Colors.redAccent, threshold: 35000),
    Rank(name: "MYTHIC VANGUARD", color: Colors.amberAccent, threshold: 55000),
    Rank(name: "CELESTIAL CHAMPION", color: Colors.tealAccent, threshold: 85000),
  ];

  static const List<Rank> academicRanks = [
    Rank(name: "NOVICE SCHOLAR", color: Colors.blueGrey, threshold: 0),
    Rank(name: "DEDICATED STUDENT", color: Colors.lightBlue, threshold: 500),
    Rank(name: "HONOURS RESEARCHER", color: Colors.blueAccent, threshold: 1500),
    Rank(name: "MASTER INNOVATOR", color: Colors.indigoAccent, threshold: 3500),
    Rank(name: "CHIEF ARCHITECT", color: Colors.deepPurpleAccent, threshold: 7000),
    Rank(name: "KNOWLEDGE ARCHON", color: Colors.cyanAccent, threshold: 12000),
    Rank(name: "UNIVERSAL MIND", color: Colors.white, threshold: 20000),
  ];

  static const List<Rank> artRanks = [
    Rank(name: "NOVICE ARTIST", color: Colors.blueGrey, threshold: 0),
    Rank(name: "DEDICATED CREATOR", color: Colors.pinkAccent, threshold: 500),
    Rank(name: "SKILLED ARTISAN", color: Colors.deepOrangeAccent, threshold: 1500),
    Rank(name: "MASTER VIRTUOSO", color: Colors.amberAccent, threshold: 3500),
    Rank(name: "CHIEF VISIONARY", color: Colors.tealAccent, threshold: 7000),
    Rank(name: "COSMIC CREATOR", color: Colors.purpleAccent, threshold: 12000),
  ];

  static Rank getRank(int elo, List<Rank> ranks) {
    return ranks.lastWhere((r) => elo >= r.threshold, orElse: () => ranks.first);
  }

  static String formatElo(int elo) {
    if (elo < 1000) return elo.toString();
    if (elo < 1000000) {
      return '${(elo / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
    }
    if (elo < 1000000000) {
      return '${(elo / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    }
    return '${(elo / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}B';
  }
}
