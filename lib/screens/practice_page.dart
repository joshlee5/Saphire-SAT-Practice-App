import 'package:flutter/material.dart';
import '../modes/timed_mode.dart';  // uses showTimedSetup + TimedModePage + SectionMode

class PracticePage extends StatelessWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // ------------------ TITLE ------------------
            const Text(
              "Practice Modes",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 60, // big title
                fontWeight: FontWeight.w800,
                color: Color(0xFFC41212),
              ),
            ),

            const SizedBox(height: 50),

            // ------------------ TIMED MODE ------------------
            _modeButton(
              context,
              icon: Icons.timer,
              title: "Timed Mode",
              onTap: () async {
                // same behavior as your old page
                final cfg = await showTimedSetup(context);
                if (cfg == null) return; // user cancelled

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TimedModePage(
                      totalSeconds: cfg.totalSeconds,
                      sectionMode: cfg.sectionMode,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // ------------------ CLASSIC PRACTICE ------------------
            _modeButton(
              context,
              icon: Icons.menu_book_rounded,
              title: "Classic Practice",
              onTap: () async {
                // TODO: hook up when you build this mode
              },
            ),
            const SizedBox(height: 28),

            // ------------------ LIGHTNING MODE ------------------
            _modeButton(
              context,
              icon: Icons.flash_on,
              title: "Lightning Mode",
              onTap: () async {
                // TODO: hook up when you build this mode
              },
            ),
            const SizedBox(height: 28),

            // ------------------ STREAK MODE ------------------
            _modeButton(
              context,
              icon: Icons.local_fire_department,
              title: "Streak Mode",
              onTap: () async {
                // TODO: hook up when you build this mode
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  //                 REUSABLE CLEAN BUTTON
  // ---------------------------------------------------------
  Widget _modeButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Future<void> Function() onTap,
  }) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: SizedBox(
        width: screenWidth * 0.90, // wide but not full width
        height: 85,                // tall buttons
        child: ElevatedButton(
          onPressed: () {
            onTap();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF7F7F7),
            elevation: 3,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFC41212), width: 2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: const Color(0xFFC41212),
                size: 30,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
