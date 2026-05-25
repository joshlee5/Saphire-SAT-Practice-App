import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  static final UserModel instance = UserModel._();
  UserModel._();

  // Pull UID directly from Firebase
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? "";

  // Profile fields
  String name = "Student";
  String username = "Student0";

  // Fake stats (unchanged)
  int accuracy = 78;
  int avgTime = 52;
  int scoreEstimate = 1320;
  double trend = 3.4;
  int totalPracticed = 84;
  int totalCorrect = 73;
  int overallAvgTime = 99;

  String get displayInitials {
    if (name.isEmpty) return "?";
    final parts = name.split(" ");
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
