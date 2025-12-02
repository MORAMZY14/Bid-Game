import 'package:bidgame/question_bank_entry_page.dart';
import 'package:flutter/material.dart';

import 'game_setup_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF5A009D),
              Color(0xFF7D00C8),
              Color(0xFF9A00E6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = constraints.maxWidth > 1000;
              final isMediumScreen = constraints.maxWidth > 600;

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen
                      ? constraints.maxWidth * 0.15
                      : isMediumScreen
                      ? 48.0
                      : 24.0,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    /// Top Spacer
                    SizedBox(height: constraints.maxHeight * 0.05),

                    /// Title Section
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "BID",
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: isLargeScreen ? 64 : 52,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "MASTER",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isLargeScreen ? 42 : 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Place your bids and win big!",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: isLargeScreen ? 18.0 : 16.0,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: constraints.maxHeight * 0.08),

                    /// PLAY NOW Button
                    SizedBox(
                      width: isLargeScreen ? 500 : double.infinity,
                      height: isLargeScreen ? 80 : 70,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFC300),
                                Color(0xFFFF8A00)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 6),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const GameSetupPage(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              splashColor: Colors.white.withOpacity(0.3),
                              highlightColor: Colors.white.withOpacity(0.2),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: isLargeScreen ? 44 : 36,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "PLAY NOW",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isLargeScreen ? 28 : 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: constraints.maxHeight * 0.08),

                    /// Grid Menu - Now with 3 buttons (Multiplayer removed)
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: isLargeScreen ? 3 : 2,
                        crossAxisSpacing: isLargeScreen ? 30 : 20,
                        mainAxisSpacing: isLargeScreen ? 30 : 20,
                        childAspectRatio: isLargeScreen ? 1.3 : 1.1,
                        padding: EdgeInsets.zero,
                        children: [
                          _buildMenuButton(
                            title: "Leaderboard",
                            icon: Icons.emoji_events,
                            color1: const Color(0xFFFF8A00),
                            color2: const Color(0xFFFF6A00),
                            isLargeScreen: isLargeScreen,
                            onTap: () {
                              // TODO: Add Leaderboard page navigation
                            },
                          ),
                          _buildMenuButton(
                            title: "Question Bank Entry",
                            icon: Icons.menu_book,
                            color1: const Color(0xFFE91E63),
                            color2: const Color(0xFF9C27B0),
                            isLargeScreen: isLargeScreen,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const QuestionBankEntryPage(),
                                ),
                              );
                            },
                          ),
                          _buildMenuButton(
                            title: "Settings",
                            icon: Icons.settings,
                            color1: const Color(0xFF424242),
                            color2: const Color(0xFF212121),
                            isLargeScreen: isLargeScreen,
                            onTap: () {
                              // TODO: Add Settings page navigation
                            },
                          ),
                        ],
                      ),
                    ),

                    /// Bottom Spacer
                    SizedBox(height: constraints.maxHeight * 0.02),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required String title,
    required IconData icon,
    required Color color1,
    required Color color2,
    required bool isLargeScreen,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white.withOpacity(0.3),
            highlightColor: Colors.white.withOpacity(0.2),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: isLargeScreen ? 44 : 36,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: isLargeScreen ? 18 : 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}