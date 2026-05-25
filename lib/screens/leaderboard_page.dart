import 'package:flutter/material.dart';

class Player {
  final String name;
  final String state;
  final String local;
  // Map<mode, Map<subject, score>>
  final Map<String, Map<String, int>> scores;

  Player({
    required this.name,
    required this.state,
    required this.local,
    required this.scores,
  });

  int getScore(String mode, String subject) {
    return scores[mode]?[subject] ?? 0;
  }
}

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  // --- Mock current user (replace with real login later) ---
  final Player currentUser = Player(
    name: "You",
    state: "CA",
    local: "San Jose",
    scores: {
      "Ranked": {"Math": 800, "Reading": 760, "Writing": 780},
      "Practice": {"Math": 750, "Reading": 740, "Writing": 730},
      "Speedrun": {"Math": 700, "Reading": 710, "Writing": 690},
    },
  );

  // --- Filter state variables (make sure these are defined) ---
  String selectedLocation = "Global"; // "Global", "State", "Local"
  String selectedMode = "Ranked"; // must match keys in Player.scores
  String selectedSubject = "Math"; // e.g. "Math", "Reading", "Writing"

  final List<String> locationOptions = ["Global", "State", "Local"];
  final List<String> modeOptions = ["Ranked", "Practice", "Speedrun"];
  final List<String> subjectOptions = ["Math", "Reading", "Writing"];

  // --- Mock players ---
  final List<Player> mockPlayers = [
    Player(
      name: "Jane",
      state: "CA",
      local: "San Jose",
      scores: {
        "Ranked": {"Math": 1900, "Reading": 1200, "Writing": 1100},
        "Practice": {"Math": 1500, "Reading": 1400, "Writing": 1300},
        "Speedrun": {"Math": 900, "Reading": 850, "Writing": 870},
      },
    ),
    Player(
      name: "Mia",
      state: "CA",
      local: "Los Angeles",
      scores: {
        "Ranked": {"Math": 1750, "Reading": 1700, "Writing": 1600},
        "Practice": {"Math": 1350, "Reading": 1300, "Writing": 1250},
        "Speedrun": {"Math": 950, "Reading": 920, "Writing": 900},
      },
    ),
    Player(
      name: "Ethan",
      state: "TX",
      local: "Houston",
      scores: {
        "Ranked": {"Math": 1600, "Reading": 1500, "Writing": 1450},
        "Practice": {"Math": 1200, "Reading": 1180, "Writing": 1190},
        "Speedrun": {"Math": 880, "Reading": 860, "Writing": 820},
      },
    ),
    Player(
      name: "Lucas",
      state: "NY",
      local: "Queens",
      scores: {
        "Ranked": {"Math": 1580, "Reading": 1550, "Writing": 1500},
        "Practice": {"Math": 1250, "Reading": 1220, "Writing": 1210},
        "Speedrun": {"Math": 870, "Reading": 840, "Writing": 830},
      },
    ),
    Player(
      name: "Sofia",
      state: "CA",
      local: "San Jose",
      scores: {
        "Ranked": {"Math": 1520, "Reading": 1490, "Writing": 1480},
        "Practice": {"Math": 1100, "Reading": 1080, "Writing": 1050},
        "Speedrun": {"Math": 800, "Reading": 780, "Writing": 770},
      },
    ),
  ];

  // Filtered list shown in UI
  List<Player> filteredPlayers = [];

  @override
  void initState() {
    super.initState();
    applyFilters(); // initial population
  }

  // ---------------------------
  // Full applyFilters implementation
  // ---------------------------
  void applyFilters() {
    List<Player> list = [...mockPlayers, currentUser];

    // 1) Location filter: Global = everyone, State = currentUser.state, Local = currentUser.local
    if (selectedLocation == "State") {
      list = list.where((p) => p.state == currentUser.state).toList();
    } else if (selectedLocation == "Local") {
      list = list.where((p) => p.local == currentUser.local).toList();
    }

    // 2) Sort by selectedMode and selectedSubject (highest first)
    list.sort((a, b) {
      final int aScore = a.getScore(selectedMode, selectedSubject);
      final int bScore = b.getScore(selectedMode, selectedSubject);
      return bScore.compareTo(aScore);
    });

    // 3) Save result to state
    setState(() {
      filteredPlayers = list;
    });
  }

  // Helper to build dropdowns
  Widget buildDropdown(
    String label,
    List<String> options,
    String selected,
    Function(String?) onChanged,
  ) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: selected,
          items: options.map((e) {
            return DropdownMenuItem(value: e, child: Text(e));
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Leaderboards"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Toggle mock user state (debug)',
            onPressed: () {
              setState(() {
                // example debug toggle to see State filtering effect
                // toggles current user's state & local for demonstration
                if (currentUser.state == 'CA') {
                  // NOTE: currentUser is final; this is just illustrative.
                  // In a real app you'd update the actual user source.
                }
                applyFilters();
              });
            },
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Filters row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildDropdown("Location", locationOptions, selectedLocation, (val) {
                if (val == null) return;
                selectedLocation = val;
                applyFilters();
              }),
              buildDropdown("Mode", modeOptions, selectedMode, (val) {
                if (val == null) return;
                selectedMode = val;
                applyFilters();
              }),
              buildDropdown("Subject", subjectOptions, selectedSubject, (val) {
                if (val == null) return;
                selectedSubject = val;
                applyFilters();
              }),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          // Leaderboard list
          Expanded(
            child: ListView.builder(
              itemCount: filteredPlayers.length,
              itemBuilder: (context, index) {
                final rank = index + 1;
                final p = filteredPlayers[index];
                final score = p.getScore(selectedMode, selectedSubject);

                return ListTile(
                  leading: CircleAvatar(child: Text(rank.toString())),
                  title: Text(p.name),
                  subtitle: Text('${p.state} • ${p.local} • $selectedMode / $selectedSubject'),
                  trailing: Text(score.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}