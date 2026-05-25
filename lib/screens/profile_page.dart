import 'package:flutter/material.dart';
import 'edit_profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Which SAT section we’re looking at in the stats area.
enum SatSection { math, reading, writing }

extension SatSectionX on SatSection {
  String get label {
    switch (this) {
      case SatSection.math:
        return 'Math';
      case SatSection.reading:
        return 'Reading';
      case SatSection.writing:
        return 'Writing';
    }
  }

  /// How it appears in Firestore `section`/`sectionMode` fields.
  String get firestoreKey {
    switch (this) {
      case SatSection.math:
        return 'Math';
      case SatSection.reading:
        return 'Reading';
      case SatSection.writing:
        return 'Writing';
    }
  }
}

/// Internal aggregate holder for a section.
class _SectionAgg {
  int total = 0;
  int correct = 0;
  int totalTimeMs = 0;

  int weekTotal = 0;
  int weekCorrect = 0;
  int prevWeekTotal = 0;
  int prevWeekCorrect = 0;

  int monthTotal = 0;
  int monthCorrect = 0;
  int prevMonthTotal = 0;
  int prevMonthCorrect = 0;

  final Map<String, _SubcatAgg> subcats = {};
}

/// Internal aggregate holder for a subcategory.
class _SubcatAgg {
  int total = 0;
  int correct = 0;
  int totalTimeMs = 0;

  int weekTotal = 0;
  int weekCorrect = 0;

  int monthTotal = 0;
  int monthCorrect = 0;
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>> _userFuture;
  SatSection _selectedSection = SatSection.math;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUserData();
  }

  Future<Map<String, dynamic>> _loadUserData() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw Exception("Not logged in");
    }

    final uid = authUser.uid;

    // ------------ Load User Document ------------
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final user = userDoc.data() ?? {};

    // ------------ Load Attempt Stats ------------
    final attemptsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('attempts')
        .get();

    final attempts =
        attemptsSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    // Global stats (all sections combined)
    final total = attempts.length;
    final correct =
        attempts.where((a) => (a['correct'] as bool?) == true).length;
    final accuracy = total == 0 ? 0 : (correct / total * 100).round();

    final avgTimeMs = total == 0
        ? 0
        : attempts
                .map((a) => (a['timeMs'] as int? ?? 0))
                .fold<int>(0, (s, v) => s + v) ~/
            total;

    // ------------ Section & Subcategory Aggregation ------------
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final prevWeekAgo = now.subtract(const Duration(days: 14));
    final monthAgo = now.subtract(const Duration(days: 30));
    final prevMonthAgo = now.subtract(const Duration(days: 60));

    final Map<String, _SectionAgg> sectionAgg = {
      'Math': _SectionAgg(),
      'Reading': _SectionAgg(),
      'Writing': _SectionAgg(),
    };

    String _normalizeSection(String? raw) {
      final v = (raw ?? '').toLowerCase();
      if (v.startsWith('math')) return 'Math';
      if (v.startsWith('read')) return 'Reading';
      if (v.startsWith('writ')) return 'Writing';
      return 'Math'; // default fallback
    }

    for (final a in attempts) {
      final sec = _normalizeSection(
          (a['section'] as String?) ?? (a['sectionMode'] as String?));
      final secAgg = sectionAgg[sec] ??= _SectionAgg();

      final isCorrect = (a['correct'] as bool?) == true;
      final timeMs = a['timeMs'] as int? ?? 0;
      final subName = (a['subcategory'] as String?) ?? 'General';

      secAgg.total++;
      if (isCorrect) secAgg.correct++;
      secAgg.totalTimeMs += timeMs;

      final subAgg = secAgg.subcats[subName] ??= _SubcatAgg();
      subAgg.total++;
      if (isCorrect) subAgg.correct++;
      subAgg.totalTimeMs += timeMs;

      DateTime? tsDate;
      final ts = a['timestamp'];
      if (ts is Timestamp) {
        tsDate = ts.toDate();
      }

      if (tsDate != null) {
        // Weekly / previous weekly
        if (tsDate.isAfter(weekAgo)) {
          secAgg.weekTotal++;
          if (isCorrect) secAgg.weekCorrect++;
          subAgg.weekTotal++;
          if (isCorrect) subAgg.weekCorrect++;
        } else if (tsDate.isAfter(prevWeekAgo)) {
          secAgg.prevWeekTotal++;
          if (isCorrect) secAgg.prevWeekCorrect++;
        }

        // Monthly / previous monthly
        if (tsDate.isAfter(monthAgo)) {
          secAgg.monthTotal++;
          if (isCorrect) secAgg.monthCorrect++;
          subAgg.monthTotal++;
          if (isCorrect) subAgg.monthCorrect++;
        } else if (tsDate.isAfter(prevMonthAgo)) {
          secAgg.prevMonthTotal++;
          if (isCorrect) secAgg.prevMonthCorrect++;
        }
      }
    }

    double _ratio(int good, int total) =>
        total == 0 ? 0.0 : (good / total * 100);

    final Map<String, dynamic> sectionStats = {};
    sectionAgg.forEach((secName, agg) {
      final avgTimeSec =
          agg.total == 0 ? 0.0 : agg.totalTimeMs / agg.total / 1000.0;

      final weekAcc = _ratio(agg.weekCorrect, agg.weekTotal);
      final prevWeekAcc = agg.prevWeekTotal == 0
          ? 0.0
          : _ratio(agg.prevWeekCorrect, agg.prevWeekTotal);
      final weekChange = weekAcc - prevWeekAcc;

      final monthAcc = _ratio(agg.monthCorrect, agg.monthTotal);
      final prevMonthAcc = agg.prevMonthTotal == 0
          ? 0.0
          : _ratio(agg.prevMonthCorrect, agg.prevMonthTotal);
      final monthChange = monthAcc - prevMonthAcc;

      final Map<String, dynamic> subcatMap = {};
      agg.subcats.forEach((name, sAgg) {
        final acc = _ratio(sAgg.correct, sAgg.total);
        final weekAcc = _ratio(sAgg.weekCorrect, sAgg.weekTotal);
        final monthAcc = _ratio(sAgg.monthCorrect, sAgg.monthTotal);

        subcatMap[name] = {
          'total': sAgg.total,
          'correct': sAgg.correct,
          'accuracy': acc,
          'avgTimeSec': sAgg.total == 0
              ? 0.0
              : sAgg.totalTimeMs / sAgg.total / 1000.0,
          'weeklyAccuracy': weekAcc,
          'monthlyAccuracy': monthAcc,
        };
      });

      sectionStats[secName] = {
        'total': agg.total,
        'correct': agg.correct,
        'accuracy': _ratio(agg.correct, agg.total),
        'avgTimeSec': avgTimeSec,
        'weeklyChange': weekChange,
        'monthlyChange': monthChange,
        'subcategories': subcatMap,
      };
    });

    // ------------ SAT-style score estimates ------------
    double _frac(int good, int total) =>
        total == 0 ? 0.0 : good / total;

    final mathAgg = sectionAgg['Math']!;
    final readingAgg = sectionAgg['Reading']!;
    final writingAgg = sectionAgg['Writing']!;

    final double mathAccFrac = _frac(mathAgg.correct, mathAgg.total);
    final int mathScore = (mathAccFrac * 800).round();

    final int rwCorrect = readingAgg.correct + writingAgg.correct;
    final int rwTotal = readingAgg.total + writingAgg.total;
    final double rwAccFrac = _frac(rwCorrect, rwTotal);
    final int rwScore = (rwAccFrac * 800).round();

    final int estimatedSatScore = mathScore + rwScore;

    // ------------ Load Friends ------------
    final friendIds = List<String>.from(user["friends"] ?? []);
    List<Map<String, dynamic>> friends = [];

    for (final fid in friendIds) {
      final fDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(fid)
          .get();

      if (fDoc.exists) {
        final data = fDoc.data() as Map<String, dynamic>?;
        friends.add({
          "uid": fid,
          "displayName": data?["displayName"] ?? "",
          "username": data?["username"] ?? "",
        });
      }
    }

    // ------------ Return ALL Combined Data ------------
    return {
      "username": user["username"] ?? "",
      "displayName": user["displayName"] ?? "",
      "email": user["email"] ?? "",
      "number": user["number"] ?? "",
      "location": user["location"] ?? {},

      // Global stats
      "totalQuestions": total,
      "totalCorrect": correct,
      "accuracy": accuracy,
      "avgTime": (avgTimeMs / 1000).toStringAsFixed(1),

      // Section stats (Math / Reading / Writing)
      "sectionStats": sectionStats,

      // SAT-style scores
      "mathScore": mathScore,
      "rwScore": rwScore,
      "estimatedSatScore": estimatedSatScore,

      // Friends
      "friends": friends,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _userFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data!;
        final displayName = user["displayName"] as String? ?? "";
        final username = user["username"] as String? ?? "";
        final totalQuestions = user["totalQuestions"] ?? 0;
        final totalCorrect = user["totalCorrect"] ?? 0;

        final mathScore = user["mathScore"] as int? ?? 0;
        final rwScore = user["rwScore"] as int? ?? 0;
        final estimatedSatScore =
            user["estimatedSatScore"] as int? ?? 0;

        final initials = displayName.isNotEmpty
            ? displayName.substring(0, 1).toUpperCase()
            : "?";

        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------------------------- HEADER -------------------------
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color.fromARGB(255, 196, 18, 18),
                        const Color.fromARGB(255, 196, 18, 18)
                            .withOpacity(0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --------- PROFILE PHOTO ---------
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        backgroundImage: (user["photoUrl"] != null &&
                                (user["photoUrl"] as String).isNotEmpty)
                            ? NetworkImage(user["photoUrl"])
                            : null,
                        child: (user["photoUrl"] == null ||
                                (user["photoUrl"] as String).isEmpty)
                            ? Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              )
                            : null,
                      ),

                      const SizedBox(width: 18),

                      // --------- NAME + USERNAME  ---------
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 45,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    username,
                                    style: TextStyle(
                                      fontSize: 25,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      // --------- HEADER STATS  ---------
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _statColumn("Math", mathScore.toString()),
                              const SizedBox(width: 60),
                              _statColumn("Reading & Writing", rwScore.toString()),
                              const SizedBox(width: 60),
                              _statColumn("Estimated Score", estimatedSatScore.toString()),
                            ],
                          ),
                        ),
                      ),

                      // --------- EDIT + LOGOUT BUTTONS (Right) ---------
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const EditProfilePage()),
                              );

                              if (updated == true) {
                                setState(() {
                                  _userFuture = _loadUserData();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 60, vertical: 20),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text("Edit Profile"),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                Navigator.pushReplacementNamed(
                                    context, "/login");
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 60, vertical: 20 ),
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text("Log Out"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ------------------------- FRIENDS -------------------------
                _sectionTitle("Friends"),
                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: "Search friends...",
                          filled: true,
                          fillColor:
                              const Color.fromARGB(255, 219, 213, 213),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Horizontal carousel of real friends
                      SizedBox(
                        height:
                            (user["friends"] as List).isEmpty ? 0 : 90,
                        child: (user["friends"] as List).isEmpty
                            ? const SizedBox.shrink()
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount:
                                    (user["friends"] as List).length,
                                itemBuilder: (context, i) {
                                  final f = (user["friends"] as List)[i]
                                      as Map<String, dynamic>;
                                  final name = f["displayName"]
                                          as String? ??
                                      "";
                                  final initial = name.isNotEmpty
                                      ? name.substring(0, 1).toUpperCase()
                                      : "?";
                                  return _friendBubble(name, initial);
                                },
                              ),
                      ),

                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showFriendsPopup(
                              context,
                              (user["friends"] as List)
                                  .cast<Map<String, dynamic>>()),
                          child: const Text("View All"),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ------------------------- STATS SECTION -------------------------
                _buildStatsSection(user, totalQuestions, totalCorrect),

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  // ======================= SMALL HELPERS =======================

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 30,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _friendBubble(String name, String initial) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey.shade300,
            child: Text(
              initial,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  void _showFriendsPopup(
      BuildContext context, List<Map<String, dynamic>> friends) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Your Friends"),
        content: SizedBox(
          width: 300,
          height: 350,
          child: friends.isEmpty
              ? const Center(
                  child: Text(
                    "You have no friends added yet.",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, i) {
                    final f = friends[i];
                    final name =
                        f["displayName"] as String? ?? "";
                    final username =
                        f["username"] as String? ?? "";
                    final initial = name.isNotEmpty
                        ? name.substring(0, 1).toUpperCase()
                        : "?";

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        child: Text(initial),
                      ),
                      title: Text(name),
                      subtitle: Text(username),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // ======================= STATS SECTION =======================

  Widget _buildStatsSection(
      Map<String, dynamic> user, int totalQuestions, int totalCorrect) {
    final sectionStats =
        (user["sectionStats"] as Map<String, dynamic>? ?? {});
    final currentLabel = _selectedSection.label;
    final current =
        (sectionStats[currentLabel] as Map<String, dynamic>? ?? {});
    final subcats =
        (current['subcategories'] as Map<String, dynamic>? ?? {});

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Performance Overview",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Subject tabs
          _buildSubjectTabs(),

          const SizedBox(height: 20),

          // Row of quick metrics
          _buildTopRowMetrics(current, totalQuestions, totalCorrect),

          const SizedBox(height: 20),

          // Weekly & monthly improvement for this section
          _buildSubjectSummaryCards(current),

          const SizedBox(height: 30),

          // Best / worst subcategory
          _buildBestAndWorstSection(subcats),

          const SizedBox(height: 24),

          // Full subcategory table
          _buildSubcategoryTable(subcats),
        ],
      ),
    );
  }

  Widget _buildSubjectTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: SatSection.values.map((sec) {
          final selected = _selectedSection == sec;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _selectedSection = sec;
                });
              },
              child: _SubjectTab(
                label: sec.label,
                selected: selected,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopRowMetrics(
      Map<String, dynamic> current, int totalQ, int totalC) {
    final sectionTotal = current['total'] as int? ?? 0;
    final sectionCorrect = current['correct'] as int? ?? 0;
    final sectionAcc = current['accuracy'] as double? ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _miniMetricCard(
            "Average Score",
            "${sectionAcc.toStringAsFixed(0)}%",
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniMetricCard(
            "Total Qs (this section)",
            "$sectionTotal",
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniMetricCard(
            "Correct (this section)",
            "$sectionCorrect",
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectSummaryCards(Map<String, dynamic> current) {
    final weeklyChange = current['weeklyChange'] as double? ?? 0.0;
    final monthlyChange = current['monthlyChange'] as double? ?? 0.0;

    String _fmtChange(double v) =>
        v == 0 ? "+0%" : "${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}%";

    return Column(
      children: [
        _wideStatCard(
          "Weekly Improvement",
          _fmtChange(weeklyChange),
          Icons.trending_up,
        ),
        const SizedBox(height: 14),
        _wideStatCard(
          "Monthly Improvement",
          _fmtChange(monthlyChange),
          Icons.calendar_month,
        ),
      ],
    );
  }

  Widget _buildBestAndWorstSection(Map<String, dynamic> subcats) {
    if (subcats.isEmpty) {
      return const Text("No data available yet.");
    }

    MapEntry<String, dynamic>? best;
    MapEntry<String, dynamic>? worst;

    for (final entry in subcats.entries) {
      final acc = (entry.value['accuracy'] as double?) ?? 0.0;
      if (best == null ||
          acc >
              ((best!.value['accuracy'] as double?) ??
                  0.0)) best = entry;
      if (worst == null ||
          acc <
              ((worst!.value['accuracy'] as double?) ??
                  0.0)) worst = entry;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Subcategory Performance",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        if (best != null)
          _subcategoryHighlightCard(
            title: "Strongest Area",
            name: best!.key,
            accuracy: (best!.value['accuracy'] as double?) ?? 0.0,
            color: Colors.green.shade600,
            icon: Icons.check_circle,
          ),

        const SizedBox(height: 12),

        if (worst != null)
          _subcategoryHighlightCard(
            title: "Needs Most Improvement",
            name: worst!.key,
            accuracy: (worst!.value['accuracy'] as double?) ?? 0.0,
            color: Colors.red.shade600,
            icon: Icons.flag,
          ),
      ],
    );
  }

  Widget _buildSubcategoryTable(Map<String, dynamic> subcats) {
    final entries = subcats.entries.toList()
      ..sort((a, b) =>
          ((b.value['accuracy'] as double?) ?? 0)
              .compareTo((a.value['accuracy'] as double?) ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Text(
          "All Subcategories",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),

        ...entries.map((e) {
          final name = e.key;
          final data = e.value;

          final acc = (data['accuracy'] as double?) ?? 0.0;
          final weekly = (data['weeklyAccuracy'] as double?) ?? 0.0;
          final monthly = (data['monthlyAccuracy'] as double?) ?? 0.0;
          final total = data['total'] ?? 0;
          final correct = data['correct'] ?? 0;

          final color = _subcategoryColor(acc);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER ROW
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text("${acc.toStringAsFixed(0)}%",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ],
                ),

                const SizedBox(height: 12),

                // PROGRESS BAR
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: acc / 100,
                    color: color,
                    backgroundColor: color.withOpacity(0.15),
                  ),
                ),

                const SizedBox(height: 12),

                // FOOTER: total stats + trends
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Correct: $correct / $total",
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700)),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(children: [
                          const Text("Weekly: ",
                              style: TextStyle(fontSize: 12)),
                          _trendIcon(weekly - acc),
                        ]),
                        Row(children: [
                          const Text("Monthly: ",
                              style: TextStyle(fontSize: 12)),
                          _trendIcon(monthly - acc),
                        ]),
                      ],
                    )
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _subcategoryBar(
      String label, String name, double value, Color color) {
    final pct = value.clamp(0.0, 100.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: pct / 100,
            minHeight: 10,
            color: color,
            backgroundColor: color.withOpacity(0.15),
          ),
          const SizedBox(height: 6),
          Text("${pct.toStringAsFixed(0)}%"),
        ],
      ),
    );
  }

  Widget _wideStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Colors.redAccent),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetricCard(String title, String value) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// Simple visual chip for Math / Reading / Writing tabs
class _SubjectTab extends StatelessWidget {
  final String label;
  final bool selected;

  const _SubjectTab({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Colors.redAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

Widget _bigCategoryCard({
  required String title,
  required String subcat,
  required double accuracy,
  required Color color,
  required IconData icon,
}) {
  final pct = accuracy.clamp(0.0, 100.0);

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black12.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          subcat,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: pct / 100,
            color: color,
            backgroundColor: color.withOpacity(0.18),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "${pct.toStringAsFixed(0)}%",
          style: const TextStyle(fontSize: 14),
        ),
      ],
    ),
  );
}

Color _subcategoryColor(double accuracy) {
  if (accuracy >= 80) return Colors.green.shade600;
  if (accuracy >= 50) return Colors.amber.shade700;
  return Colors.red.shade600;
}

Widget _trendIcon(double change) {
  if (change > 0) {
    return Row(
      children: [
        const Icon(Icons.arrow_upward,
            size: 14, color: Colors.green),
        Text("+${change.toStringAsFixed(1)}%",
            style: const TextStyle(
                color: Colors.green, fontSize: 12)),
      ],
    );
  } else if (change < 0) {
    return Row(
      children: [
        const Icon(Icons.arrow_downward,
            size: 14, color: Colors.red),
        Text(change.toStringAsFixed(1) + "%",
            style: const TextStyle(
                color: Colors.red, fontSize: 12)),
      ],
    );
  } else {
    return const Text("0%",
        style: TextStyle(fontSize: 12, color: Colors.grey));
  }
}

Widget _subcategoryHighlightCard({
  required String title,
  required String name,
  required double accuracy,
  required Color color,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      border:
          Border.all(color: color.withOpacity(0.3), width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ]),
        const SizedBox(height: 12),
        Text(name,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: accuracy / 100,
          color: color,
          backgroundColor: color.withOpacity(0.2),
          minHeight: 10,
        ),
        const SizedBox(height: 6),
        Text("${accuracy.toStringAsFixed(0)}%"),
      ],
    ),
  );
}
