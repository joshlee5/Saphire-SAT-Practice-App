// The new "Home" dashboard: settings icon, search bar, announcements,
// recents, progress, streak, and stats.

import 'package:flutter/material.dart';
import '../widgets/streak_header.dart';
import '../widgets/announcements_board.dart';
import '../widgets/recents_row.dart';
import '../widgets/progress_card.dart';
import '../widgets/stats_grid.dart';
import '../models/announcement.dart';

class DashboardHomePage extends StatefulWidget {
  const DashboardHomePage({super.key});

  @override
  State<DashboardHomePage> createState() => _DashboardHomePageState();
}

class _DashboardHomePageState extends State<DashboardHomePage> {
  String _selectedTimeOfDay = 'Morning';
  String _selectedSubject = 'Math';

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.settings, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            shape: const CircleBorder(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Time of Day Section
                    const Text(
                      'Preferred Study Time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Morning', 'Afternoon', 'Evening', 'Night']
                          .map((time) => ChoiceChip(
                                label: Text(time),
                                selected: _selectedTimeOfDay == time,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedTimeOfDay = time;
                                  });
                                  this.setState(() {});
                                },
                                selectedColor: Colors.blue.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 24),

                    // Subject Focus Section
                    const Text(
                      'Subject Focus',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Math', 'Reading', 'Writing', 'Science']
                          .map((subject) => ChoiceChip(
                                label: Text(subject),
                                selected: _selectedSubject == subject,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedSubject = subject;
                                  });
                                  this.setState(() {});
                                },
                                selectedColor: Colors.blue.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Settings saved!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ---------------- Declarations ----------------
    final announcements = <Announcement>[
      Announcement(
        Icons.new_releases_outlined,
        'New Writing Set',
        subtitle: 'Parallel structure & misplaced modifiers',
      ),
      Announcement(
        Icons.bolt_outlined,
        'Speed Tip',
        subtitle: 'Use estimation to eliminate wrong answers quickly.',
      ),
      Announcement(
        Icons.campaign_outlined,
        'Weekly Challenge',
        subtitle: 'Finish 3 drills by Sunday for +150 XP',
      ),
    ];

    final recentModes = <String>['Timed Mode', 'Practice Sets', 'Adaptive Drill'];

    //---------------- Widget -----------------------------------------------------
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 1, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------- HEADER ROW ----------------
              Row(
                children: [
                  // Search bar FIRST with flexible width
                  Expanded(
                    child: TextField(
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search practice, tips, or questions',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white.withOpacity(.92),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (query) {
                        // TODO search implementation
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Right-side settings button
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: _showSettingsDialog,
                    icon: const Icon(Icons.settings, color: Colors.black54),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(.85),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ---------------- STREAK ----------------
              const StreakHeader(streakDays: 4),

              const SizedBox(height: 16),

              // ---------------- RECENTS ----------------
              RecentsRow(
                items: recentModes,
                onTap: (label) {
                  // TODO: Route logic
                },
              ),

              const SizedBox(height: 16),

              // ---------------- PROGRESS ----------------
              const ProgressCard(
                title: 'Weekly Progress',
                subtitle: "You're on track for your goal",
                progress: 0.62,
                trailingLabel: '62%',
              ),

              const SizedBox(height: 16),

              // ---------------- ANNOUNCEMENTS ----------------
              AnnouncementsBoard(items: announcements),

              const SizedBox(height: 16),

              // ---------------- STATS GRID ----------------
              const StatsGrid(
                items: [
                  StatItem(
                      icon: Icons.check_circle_outline,
                      label: 'Accuracy',
                      value: '78%'),
                  StatItem(
                      icon: Icons.av_timer,
                      label: 'Avg Time',
                      value: '52s'),
                  StatItem(
                      icon: Icons.auto_graph,
                      label: 'Score Est.',
                      value: '1320'),
                  StatItem(
                      icon: Icons.stacked_line_chart,
                      label: 'Trend',
                      value: '+3.4%'),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}