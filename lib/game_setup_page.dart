import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_play_page.dart';

class Team {
  String name;
  List<String> players;
  Map<String, bool> wildcards; // Changed from powerUpUsed to wildcards

  Team({
    required this.name,
    required this.players,
    Map<String, bool>? wildcards,
  }) : wildcards = wildcards ?? {
    'Unlimited Time': false,
    'Extra Time': false,
    'Theif': false,
    'Plus Minus': false,
    'Tables': false,
  };

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'players': players,
      'wildcards': wildcards,
    };
  }

  static Team fromMap(Map<String, dynamic> map) {
    return Team(
      name: map['name'] ?? '',
      players: List<String>.from(map['players'] ?? []),
      wildcards: Map<String, bool>.from(map['wildcards'] ?? {
        'Unlimited Time': false,
        'Extra Time': false,
        'Theif': false,
        'Plus Minus': false,
        'Tables': false,
      }),
    );
  }
}

class GameConfig {
  final String refereeName;
  final int timePerQuestion;
  final int numberOfRounds;
  final int pointsPerCorrectAnswer;
  final bool enableTimePenalty;
  final bool enableWildcards; // Changed from enablePowerUps to enableWildcards
  final List<Team> teams;
  final String? difficultyFilter;

  GameConfig({
    required this.refereeName,
    required this.timePerQuestion,
    required this.numberOfRounds,
    required this.pointsPerCorrectAnswer,
    required this.enableTimePenalty,
    required this.enableWildcards,
    required this.teams,
    this.difficultyFilter,
  });

  Map<String, dynamic> toMap() {
    return {
      'refereeName': refereeName,
      'timePerQuestion': timePerQuestion,
      'numberOfRounds': numberOfRounds,
      'pointsPerCorrectAnswer': pointsPerCorrectAnswer,
      'enableTimePenalty': enableTimePenalty,
      'enableWildcards': enableWildcards,
      'teams': teams.map((team) => team.toMap()).toList(),
      'difficultyFilter': difficultyFilter,
    };
  }

  static GameConfig fromMap(Map<String, dynamic> map) {
    return GameConfig(
      refereeName: map['refereeName'] ?? '',
      timePerQuestion: map['timePerQuestion'] ?? 30,
      numberOfRounds: map['numberOfRounds'] ?? 1,
      pointsPerCorrectAnswer: map['pointsPerCorrectAnswer'] ?? 1,
      enableTimePenalty: map['enableTimePenalty'] ?? true,
      enableWildcards: map['enableWildcards'] ?? false,
      teams: List<Team>.from((map['teams'] ?? []).map((x) => Team.fromMap(x))),
      difficultyFilter: map['difficultyFilter'],
    );
  }
}

class GameSetupPage extends StatefulWidget {
  const GameSetupPage({super.key});

  @override
  State<GameSetupPage> createState() => _GameSetupPageState();
}

class _GameSetupPageState extends State<GameSetupPage> {
  String _refereeName = '';
  int _timePerQuestion = 30;
  int _numberOfRounds = 1;
  int _pointsPerCorrectAnswer = 1;
  bool _enableTimePenalty = true;
  bool _enableWildcards = false; // Changed from enablePowerUps to enableWildcards
  String? _selectedDifficultyFilter;

  List<Team> _teams = [
    Team(name: '', players: ['', '', '']),
    Team(name: '', players: ['', '', '']),
  ];

  final TextEditingController _newTeamController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final String _correctPassword = 'KPPS';

  // Wildcard descriptions - Fixed initialization
  final List<Map<String, dynamic>> _wildcards = [
    {
      'name': 'Unlimited Time',
      'description': 'Team gets unlimited time to answer',
      'icon': Icons.timer_off,
    },
    {
      'name': 'Extra Time',
      'description': 'Team gets extra 20 seconds to answer',
      'icon': Icons.timer,
    },
    {
      'name': 'Theif',
      'description': 'Steal points from another team (min 20 points)',
      'icon': Icons.attach_money,
    },
    {
      'name': 'Plus Minus',
      'description': 'Add or subtract points from any team',
      'icon': Icons.add_circle_outline,
    },
    {
      'name': 'Tables',
      'description': 'Special table-based challenge questions',
      'icon': Icons.table_chart,
    },
  ];

  @override
  void dispose() {
    _newTeamController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showPasswordDialogBox() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF5A009D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          title: const Text(
            'Enter Password',
            style: TextStyle(
              color: Colors.yellow,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter the password to start the game:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: TextField(
                  controller: _passwordController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter password...',
                    hintStyle: TextStyle(
                      color: Colors.white54,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  cursorColor: Colors.yellow,
                  onSubmitted: (value) {
                    _verifyPasswordAndStartGame();
                  },
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Hint: Password is "tfkar kteer w tafker 3ameq "',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _passwordController.clear();
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _verifyPasswordAndStartGame,
              child: const Text(
                'Start Game',
                style: TextStyle(color: Colors.yellow),
              ),
            ),
          ],
        );
      },
    );
  }

  void _verifyPasswordAndStartGame() {
    final enteredPassword = _passwordController.text.trim();

    if (enteredPassword.isEmpty) {
      _showError('Please enter the password');
      return;
    }

    if (enteredPassword != _correctPassword) {
      _showError('Incorrect password. Please try again.');
      _passwordController.clear();
      return;
    }

    Navigator.pop(context);
    _passwordController.clear();
    _validateAndStartGame();
  }

  void _addTeam() {
    if (_newTeamController.text.trim().isNotEmpty) {
      setState(() {
        _teams.add(Team(
          name: _newTeamController.text.trim(),
          players: ['', '', ''],
        ));
        _newTeamController.clear();
      });
    }
  }

  void _removeTeam(int index) {
    if (_teams.length > 2) {
      setState(() {
        _teams.removeAt(index);
      });
    }
  }

  void _addPlayer(int teamIndex) {
    if (_teams[teamIndex].players.length < 8) {
      setState(() {
        _teams[teamIndex].players.add('');
      });
    }
  }

  void _removePlayer(int teamIndex, int playerIndex) {
    if (_teams[teamIndex].players.length > 3) {
      setState(() {
        _teams[teamIndex].players.removeAt(playerIndex);
      });
    }
  }

  void _startGame() {
    _showPasswordDialogBox();
  }

  void _validateAndStartGame() {
    if (_refereeName.isEmpty) {
      _showError('Please enter referee name');
      return;
    }

    List<Team> cleanedTeams = [];
    for (int i = 0; i < _teams.length; i++) {
      if (_teams[i].name.trim().isEmpty) {
        _showError('Please enter name for Team ${i + 1}');
        return;
      }

      List<String> validPlayers = _teams[i]
          .players
          .where((player) => player.trim().isNotEmpty)
          .toList();

      if (validPlayers.isEmpty) {
        _showError('Team ${_teams[i].name} needs at least 1 player');
        return;
      }

      cleanedTeams.add(
        Team(
          name: _teams[i].name.trim(),
          players: validPlayers,
          wildcards: _teams[i].wildcards,
        ),
      );
    }

    final gameConfig = GameConfig(
      refereeName: _refereeName.trim(),
      timePerQuestion: _timePerQuestion,
      numberOfRounds: _numberOfRounds,
      pointsPerCorrectAnswer: _pointsPerCorrectAnswer,
      enableTimePenalty: _enableTimePenalty,
      enableWildcards: _enableWildcards,
      teams: cleanedTeams,
      difficultyFilter: _selectedDifficultyFilter,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameplayPage(gameConfig: gameConfig),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resetToDefaults() {
    setState(() {
      _refereeName = '';
      _timePerQuestion = 30;
      _numberOfRounds = 1;
      _pointsPerCorrectAnswer = 1;
      _enableTimePenalty = true;
      _enableWildcards = false;
      _selectedDifficultyFilter = null;
      _teams = [
        Team(name: '', players: ['', '', '']),
        Team(name: '', players: ['', '', '']),
      ];
      _newTeamController.clear();
    });
  }

  Widget _buildDifficultyChip(String label, String? value) {
    final bool isSelected = _selectedDifficultyFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDifficultyFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellow.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.yellow : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.yellow : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildWildcardToggle(int index, bool value) {
    final wildcard = _wildcards[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(wildcard['icon'] as IconData, color: Colors.yellow, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wildcard['name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  wildcard['description'] as String,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              setState(() {
                // Enable/disable this wildcard for all teams
                for (var team in _teams) {
                  team.wildcards[wildcard['name'] as String] = newValue;
                }
              });
            },
            activeColor: Colors.yellow,
            activeTrackColor: Colors.yellow.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'Game Setup',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _resetToDefaults,
                        icon: const Icon(Icons.restart_alt, color: Colors.white70),
                        tooltip: 'Reset to defaults',
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Referee Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.gavel, color: Colors.yellow, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Referee Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Referee Name',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: TextField(
                            onChanged: (value) => _refereeName = value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter referee name...',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                              prefixIcon: Icon(
                                Icons.person,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Difficulty Filter Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt, color: Colors.yellow, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Question Difficulty Filter',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select difficulty (optional)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildDifficultyChip('All', null),
                            _buildDifficultyChip('Easy', 'Easy'),
                            _buildDifficultyChip('Medium', 'Medium'),
                            _buildDifficultyChip('Hard', 'Hard'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedDifficultyFilter == null
                              ? 'Questions of all difficulties will be used'
                              : 'Only ${_selectedDifficultyFilter!.toLowerCase()} questions will be shown',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Teams Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.groups, color: Colors.yellow, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Teams Setup (${_teams.length} teams)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _teams.length,
                    itemBuilder: (context, teamIndex) {
                      final team = _teams[teamIndex];
                      final colors = [
                        Colors.red,
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.teal,
                        Colors.pink,
                        Colors.amber,
                      ];
                      final color = colors[teamIndex % colors.length];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: color),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${teamIndex + 1}',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                    ),
                                    child: TextField(
                                      onChanged: (value) {
                                        setState(() {
                                          _teams[teamIndex].name = value;
                                        });
                                      },
                                      style: const TextStyle(color: Colors.white, fontSize: 16),
                                      decoration: InputDecoration(
                                        hintText: 'Enter team name...',
                                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(16),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_teams.length > 2) ...[
                                  const SizedBox(width: 16),
                                  GestureDetector(
                                    onTap: () => _removeTeam(teamIndex),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                                      ),
                                      child: Icon(Icons.delete, color: Colors.red[300], size: 20),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Players (${team.players.length}/8)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (team.players.length < 8)
                                  GestureDetector(
                                    onTap: () => _addPlayer(teamIndex),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_add, color: Colors.green[300], size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Add Player',
                                            style: TextStyle(
                                              color: Colors.green[300],
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: List.generate(team.players.length, (playerIndex) {
                                return Container(
                                  width: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: TextField(
                                            onChanged: (value) {
                                              setState(() {
                                                _teams[teamIndex].players[playerIndex] = value;
                                              });
                                            },
                                            style: const TextStyle(color: Colors.white, fontSize: 14),
                                            decoration: InputDecoration(
                                              hintText: 'Player ${playerIndex + 1}',
                                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (team.players.length > 3)
                                        GestureDetector(
                                          onTap: () => _removePlayer(teamIndex, playerIndex),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: const BorderRadius.only(
                                                topRight: Radius.circular(12),
                                                bottomRight: Radius.circular(12),
                                              ),
                                            ),
                                            child: Icon(Icons.close, color: Colors.red[300], size: 16),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: TextField(
                              controller: _newTeamController,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                hintText: 'Enter new team name...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: _addTeam,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Game Settings
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.settings, color: Colors.yellow, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Game Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        // Time per question
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer, color: Colors.white, size: 20),
                                const SizedBox(width: 12),
                                const Text(
                                  'Time per question',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$_timePerQuestion seconds',
                                  style: const TextStyle(
                                    color: Colors.yellow,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Slider(
                              value: _timePerQuestion.toDouble(),
                              min: 10,
                              max: 120,
                              divisions: 11,
                              label: '$_timePerQuestion seconds',
                              activeColor: Colors.yellow,
                              inactiveColor: Colors.white.withOpacity(0.3),
                              onChanged: (value) {
                                setState(() {
                                  _timePerQuestion = value.toInt();
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Number of rounds
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.question_answer, color: Colors.white, size: 20),
                                const SizedBox(width: 12),
                                const Text(
                                  'Number of rounds (questions)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$_numberOfRounds',
                                  style: const TextStyle(
                                    color: Colors.yellow,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Slider(
                              value: _numberOfRounds.toDouble(),
                              min: 1,
                              max: 50,
                              divisions: 50,
                              label: '$_numberOfRounds',
                              activeColor: Colors.yellow,
                              inactiveColor: Colors.white.withOpacity(0.3),
                              onChanged: (value) {
                                setState(() {
                                  _numberOfRounds = value.toInt();
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Points per correct answer
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.score, color: Colors.white, size: 20),
                                const SizedBox(width: 12),
                                const Text(
                                  'Points per correct answer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$_pointsPerCorrectAnswer',
                                  style: const TextStyle(
                                    color: Colors.yellow,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Slider(
                              value: _pointsPerCorrectAnswer.toDouble(),
                              min: 1,
                              max: 50,
                              divisions: 50,
                              label: '$_pointsPerCorrectAnswer',
                              activeColor: Colors.yellow,
                              inactiveColor: Colors.white.withOpacity(0.3),
                              onChanged: (value) {
                                setState(() {
                                  _pointsPerCorrectAnswer = value.toInt();
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Toggle switches
                        Column(
                          children: [
                            // Time Penalty
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Time Penalty',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Deduct points for slow answers',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Switch(
                                    value: _enableTimePenalty,
                                    onChanged: (value) {
                                      setState(() {
                                        _enableTimePenalty = value;
                                      });
                                    },
                                    activeColor: Colors.yellow,
                                    activeTrackColor: Colors.yellow.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Wildcards Toggle
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Wildcards',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Enable special wildcard abilities',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Switch(
                                    value: _enableWildcards,
                                    onChanged: (value) {
                                      setState(() {
                                        _enableWildcards = value;
                                      });
                                    },
                                    activeColor: Colors.yellow,
                                    activeTrackColor: Colors.yellow.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Wildcards Configuration (only show if enabled)
                        if (_enableWildcards) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.yellow.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.card_giftcard, color: Colors.yellow, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Wildcards Configuration',
                                      style: TextStyle(
                                        color: Colors.yellow,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...List.generate(_wildcards.length, (index) {
                                  final wildcardName = _wildcards[index]['name'] as String;
                                  final isEnabled = _teams.isNotEmpty &&
                                      _teams[0].wildcards.containsKey(wildcardName) &&
                                      _teams[0].wildcards[wildcardName] == true;

                                  return _buildWildcardToggle(index, isEnabled);
                                }),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _resetToDefaults,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.restart_alt, color: Colors.white.withOpacity(0.8)),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Reset to Defaults',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: GestureDetector(
                          onTap: _startGame,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFC300), Color(0xFFFF8A00)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                  const SizedBox(width: 12),
                                  Text(
                                    'START GAME',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Password Info
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock, color: Colors.yellow, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Password required to start game',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}