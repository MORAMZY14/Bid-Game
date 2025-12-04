import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import shared models
import 'game_setup_page.dart';

class Question {
  final String id;
  final String text;
  final String category;
  final String difficulty;
  final int points;
  final Timestamp timestamp;
  final String status;
  final int questionNumber;

  Question({
    required this.id,
    required this.text,
    required this.category,
    required this.difficulty,
    required this.points,
    required this.timestamp,
    required this.status,
    required this.questionNumber,
  });

  factory Question.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Question(
      id: doc.id,
      text: data['text'] ?? '',
      category: data['category'] ?? 'General',
      difficulty: data['difficulty'] ?? 'Medium',
      points: 1, // Always 1 point per question
      timestamp: data['timestamp'] ?? Timestamp.now(),
      status: data['status'] ?? 'pending',
      questionNumber: (data['questionNumber'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'category': category,
      'difficulty': difficulty,
      'points': points,
      'timestamp': timestamp,
      'status': status,
      'questionNumber': questionNumber,
    };
  }
}

class GameplayPage extends StatefulWidget {
  final GameConfig gameConfig;

  const GameplayPage({super.key, required this.gameConfig});

  @override
  State<GameplayPage> createState() => _GameplayPageState();
}

class _GameplayPageState extends State<GameplayPage> {
  int _currentQuestionNumber = 1;
  Map<String, int> _teamScores = {};
  bool _isGameStarted = false;
  bool _isQuestionVisible = false;
  int _timeLeft = 0;
  Timer? _timer;
  bool _isTimerRunning = false;

  List<Question> _questions = [];
  List<Question> _usedQuestions = [];
  Question? _currentQuestion;
  bool _isLoadingQuestions = true;

  // Wildcards state - track usage per round
  Map<String, Map<String, bool>> _teamWildcards = {};
  Map<String, Map<String, bool>> _wildcardsUsedThisRound = {};
  int _currentRoundWildcardUses = 0;

  // Timer control state
  int _baseTime = 0;
  bool _isTimeExtended = false;

  // Modern score awarding
  String? _selectedTeamForPoints;
  bool _showAwardPanel = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeGame() {
    for (var team in widget.gameConfig.teams) {
      _teamScores[team.name] = 0;
      _teamWildcards[team.name] = {...team.wildcards};
      _wildcardsUsedThisRound[team.name] = {};
    }
    _timeLeft = widget.gameConfig.timePerQuestion;
    _baseTime = widget.gameConfig.timePerQuestion;
    _isQuestionVisible = false;
  }

  Future<void> _loadQuestions() async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      Query query = firestore.collection('questions')
          .where('status', isEqualTo: 'approved');

      if (widget.gameConfig.difficultyFilter != null &&
          widget.gameConfig.difficultyFilter != 'All') {
        query = query.where('difficulty', isEqualTo: widget.gameConfig.difficultyFilter);
      }

      final querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        _questions = _getSampleQuestions();
        _showWarning('No questions found. Using sample questions.');
      } else {
        _questions = querySnapshot.docs
            .map((doc) => Question.fromFirestore(doc))
            .toList();

        if (widget.gameConfig.difficultyFilter != null) {
          _showSuccess('Loaded ${_questions.length} ${widget.gameConfig.difficultyFilter!.toLowerCase()} questions');
        } else {
          _showSuccess('Loaded ${_questions.length} questions');
        }
      }

      _questions.shuffle();

      if (_questions.length > widget.gameConfig.numberOfRounds) {
        _questions = _questions.take(widget.gameConfig.numberOfRounds).toList();
      }

      if (_questions.isNotEmpty) {
        _currentQuestion = _questions.first;
      } else {
        _showError('No questions available.');
      }

      setState(() {
        _isLoadingQuestions = false;
      });
    } catch (e) {
      print('Error loading questions: $e');
      _showError('Error: $e');

      _questions = _getSampleQuestions();
      _questions.shuffle();

      if (_questions.isNotEmpty) {
        _currentQuestion = _questions.first;
      }

      setState(() {
        _isLoadingQuestions = false;
      });
    }
  }

  List<Question> _getSampleQuestions() {
    return [
      Question(
        id: '1',
        text: 'What is the capital of France?',
        category: 'Geography',
        difficulty: 'Easy',
        points: 1, // Always 1 point
        timestamp: Timestamp.now(),
        status: 'approved',
        questionNumber: 1,
      ),
      Question(
        id: '2',
        text: 'Who painted the Mona Lisa?',
        category: 'Art',
        difficulty: 'Medium',
        points: 1, // Always 1 point
        timestamp: Timestamp.now(),
        status: 'approved',
        questionNumber: 2,
      ),
      Question(
        id: '3',
        text: 'What is the chemical symbol for gold?',
        category: 'Science',
        difficulty: 'Easy',
        points: 1, // Always 1 point
        timestamp: Timestamp.now(),
        status: 'approved',
        questionNumber: 3,
      ),
    ];
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _getNextRandomQuestion() {
    if (_questions.isEmpty || _currentQuestionNumber >= widget.gameConfig.numberOfRounds) {
      _endGame();
      return;
    }

    _timer?.cancel();
    _isTimerRunning = false;
    _isTimeExtended = false;

    // Reset wildcard usage for new round
    _currentRoundWildcardUses = 0;
    for (var team in widget.gameConfig.teams) {
      _wildcardsUsedThisRound[team.name]?.clear();
    }

    if (_currentQuestion != null) {
      _usedQuestions.add(_currentQuestion!);
      _questions.removeWhere((q) => q.id == _currentQuestion!.id);
    }

    if (_questions.isNotEmpty) {
      setState(() {
        _currentQuestion = _questions.first;
        _currentQuestionNumber++;
        _isQuestionVisible = false;
        _timeLeft = widget.gameConfig.timePerQuestion;
        _baseTime = widget.gameConfig.timePerQuestion;
        _showAwardPanel = false;
        _selectedTeamForPoints = null;

        // Reset wildcard states for new round
        for (var team in widget.gameConfig.teams) {
          _teamWildcards[team.name] = {...team.wildcards};
        }
      });
    } else {
      _endGame();
    }
  }

  void _startTimer() {
    if (_isTimerRunning) return;

    _timer?.cancel();
    _isTimerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
        _isTimerRunning = false;
        if (!_isQuestionVisible) {
          _toggleQuestionVisibility();
        }
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
    setState(() {
      _timeLeft = _baseTime;
    });
  }

  void _addExtraTime(int seconds) {
    setState(() {
      _timeLeft += seconds;
      _isTimeExtended = true;
    });
  }

  void _useUnlimitedTime(String teamName) {
    if (_teamWildcards[teamName]?['Unlimited Time'] == true &&
        !(_wildcardsUsedThisRound[teamName]?['Unlimited Time'] ?? false)) {
      setState(() {
        _stopTimer();
        _teamWildcards[teamName]?['Unlimited Time'] = false;
        _wildcardsUsedThisRound[teamName]?['Unlimited Time'] = true;
        _currentRoundWildcardUses++;
      });
      _showSuccess('$teamName used Unlimited Time! Timer stopped.');
    }
  }

  void _useExtraTime(String teamName) {
    if (_teamWildcards[teamName]?['Extra Time'] == true &&
        !(_wildcardsUsedThisRound[teamName]?['Extra Time'] ?? false)) {
      setState(() {
        _addExtraTime(20);
        _teamWildcards[teamName]?['Extra Time'] = false;
        _wildcardsUsedThisRound[teamName]?['Extra Time'] = true;
        _currentRoundWildcardUses++;
      });
      _showSuccess('$teamName used Extra Time! +20 seconds added.');
    }
  }

  void _useTheif(String teamName) {
    if (_teamWildcards[teamName]?['Theif'] == true &&
        !(_wildcardsUsedThisRound[teamName]?['Theif'] ?? false)) {
      _showTheifDialog(teamName);
    }
  }

  void _usePlusMinus(String teamName) {
    if (_teamWildcards[teamName]?['Plus Minus'] == true &&
        !(_wildcardsUsedThisRound[teamName]?['Plus Minus'] ?? false)) {
      _showPlusMinusDialog(teamName);
    }
  }

  void _useTables(String teamName) {
    if (_teamWildcards[teamName]?['Tables'] == true &&
        !(_wildcardsUsedThisRound[teamName]?['Tables'] ?? false)) {
      _showTablesDialog(teamName);
    }
  }

  void _showTheifDialog(String teamName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF5A009D),
        title: const Text('Theif Wildcard', style: TextStyle(color: Colors.yellow)),
        content: Text('$teamName can steal minimum 20 points from another team',
            style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _teamWildcards[teamName]?['Theif'] = false;
                _wildcardsUsedThisRound[teamName]?['Theif'] = true;
                _currentRoundWildcardUses++;
              });
              _showStealPointsDialog(teamName);
            },
            child: const Text('Use', style: TextStyle(color: Colors.black)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
          ),
        ],
      ),
    );
  }

  void _showStealPointsDialog(String stealingTeam) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF5A009D),
        title: const Text('Steal Points', style: TextStyle(color: Colors.yellow)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select team to steal from:', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            ...widget.gameConfig.teams
                .where((team) => team.name != stealingTeam)
                .map((team) => ListTile(
              title: Text(team.name, style: const TextStyle(color: Colors.white)),
              trailing: Text('${_teamScores[team.name] ?? 0}',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _stealPoints(stealingTeam, team.name);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _stealPoints(String stealingTeam, String targetTeam) {
    final int targetScore = _teamScores[targetTeam] ?? 0;
    if (targetScore >= 20) {
      setState(() {
        _teamScores[stealingTeam] = (_teamScores[stealingTeam] ?? 0) + 20;
        _teamScores[targetTeam] = targetScore - 20;
      });
      _showSuccess('$stealingTeam stole 20 points from $targetTeam');
    } else {
      _showError('$targetTeam has less than 20 points to steal');
    }
  }

  void _showPlusMinusDialog(String teamName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF5A009D),
        title: const Text('Plus/Minus Wildcard', style: TextStyle(color: Colors.yellow)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add or subtract points from any team:',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            ...widget.gameConfig.teams.map((team) => Row(
              children: [
                Expanded(
                  child: Text(team.name, style: const TextStyle(color: Colors.white)),
                ),
                IconButton(
                  onPressed: () => _adjustPoints(team.name, 1),
                  icon: const Icon(Icons.add, color: Colors.green),
                ),
                IconButton(
                  onPressed: () => _adjustPoints(team.name, -1),
                  icon: const Icon(Icons.remove, color: Colors.red),
                ),
              ],
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _teamWildcards[teamName]?['Plus Minus'] = false;
                _wildcardsUsedThisRound[teamName]?['Plus Minus'] = true;
                _currentRoundWildcardUses++;
              });
            },
            child: const Text('Done', style: TextStyle(color: Colors.yellow)),
          ),
        ],
      ),
    );
  }

  void _adjustPoints(String teamName, int points) {
    setState(() {
      _teamScores[teamName] = (_teamScores[teamName] ?? 0) + points;
    });
  }

  void _showTablesDialog(String teamName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF5A009D),
        title: const Text('Tables Wildcard', style: TextStyle(color: Colors.yellow)),
        content: const Text('Special table-based questions activated!',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _teamWildcards[teamName]?['Tables'] = false;
                _wildcardsUsedThisRound[teamName]?['Tables'] = true;
                _currentRoundWildcardUses++;
              });
              _showSuccess('$teamName activated Tables wildcard!');
            },
            child: const Text('OK', style: TextStyle(color: Colors.yellow)),
          ),
        ],
      ),
    );
  }

  void _toggleQuestionVisibility() {
    setState(() {
      _isQuestionVisible = !_isQuestionVisible;
      if (_isQuestionVisible) {
        _stopTimer();
      }
    });
  }

  void _awardPoints(String teamName, bool isCorrect) {
    final currentQuestion = _currentQuestion;
    if (currentQuestion == null) return;

    // Always award 1 point for correct answer
    int points = 1;

    setState(() {
      if (isCorrect) {
        _teamScores[teamName] = (_teamScores[teamName] ?? 0) + points;
        _showSuccess('$teamName earned $points point!');
      } else if (widget.gameConfig.enableTimePenalty) {
        _teamScores[teamName] = (_teamScores[teamName] ?? 0) - (points ~/ 2);
        _showError('$teamName lost ${points ~/ 2} points!');
      }
    });
  }

  void _startGame() {
    if (_questions.isEmpty) {
      _showError('No questions available');
      return;
    }

    setState(() {
      _isGameStarted = true;
      // Don't auto-start timer
    });
  }

  void _endGame() {
    _timer?.cancel();
    _isTimerRunning = false;

    String? winningTeam;
    int highestScore = -999999;

    _teamScores.forEach((teamName, score) {
      if (score > highestScore) {
        highestScore = score;
        winningTeam = teamName;
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF5A009D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        title: const Text(
          'Game Over!',
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏆 Winning Team: ${winningTeam ?? "No winner"}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Final Scores:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ..._teamScores.entries.map(
                  (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      '${entry.value} points',
                      style: TextStyle(
                        color: entry.value >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Back to Setup',
              style: TextStyle(color: Colors.yellow),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildWildcardButton(String teamName, String wildcardName, IconData icon, Function() onPressed) {
    final hasWildcard = _teamWildcards[teamName]?[wildcardName] == true;
    final isUsed = _wildcardsUsedThisRound[teamName]?[wildcardName] ?? false;
    final canUse = hasWildcard && !isUsed;

    return Tooltip(
      message: '$wildcardName${isUsed ? ' (Used this round)' : canUse ? ' (Available)' : ' (Unavailable)'}',
      child: GestureDetector(
        onTap: canUse ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: canUse
                ? Colors.yellow.withOpacity(0.3)
                : isUsed
                ? Colors.green.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: canUse
                  ? Colors.yellow
                  : isUsed
                  ? Colors.green
                  : Colors.grey.withOpacity(0.3),
              width: isUsed ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: canUse ? Colors.yellow : isUsed ? Colors.green : Colors.grey,
                  size: 16),
              const SizedBox(height: 2),
              Text(
                wildcardName.split(' ').first,
                style: TextStyle(
                  color: canUse ? Colors.yellow : isUsed ? Colors.green : Colors.grey,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modern point awarding method
  void _toggleAwardPanel(String teamName) {
    setState(() {
      if (_selectedTeamForPoints == teamName) {
        _selectedTeamForPoints = null;
        _showAwardPanel = false;
      } else {
        _selectedTeamForPoints = teamName;
        _showAwardPanel = true;
      }
    });
  }

  void _awardPointsModern(String teamName, int points) {
    setState(() {
      _teamScores[teamName] = (_teamScores[teamName] ?? 0) + points;
      _showSuccess('$teamName earned $points point${points != 1 ? 's' : ''}!');
      _selectedTeamForPoints = null;
      _showAwardPanel = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamColors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Gameplay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        '$_currentQuestionNumber/${widget.gameConfig.numberOfRounds}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Timer and Game Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Referee: ${widget.gameConfig.refereeName}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (_currentQuestion != null)
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _currentQuestion!.category,
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getDifficultyColor(_currentQuestion!.difficulty).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _currentQuestion!.difficulty,
                                          style: TextStyle(
                                            color: _getDifficultyColor(_currentQuestion!.difficulty),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Timer Section
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _timeLeft > 10
                                        ? [Colors.green, Colors.lightGreen]
                                        : _timeLeft > 5
                                        ? [Colors.orange, Colors.yellow]
                                        : [Colors.red, Colors.orange],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_timeLeft',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Independent Timer Controls
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: _isTimerRunning ? _stopTimer : _startTimer,
                                    icon: Icon(
                                      _isTimerRunning ? Icons.stop : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.1),
                                      padding: const EdgeInsets.all(6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _resetTimer,
                                    icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.1),
                                      padding: const EdgeInsets.all(6),
                                    ),
                                  ),
                                  if (_isTimeExtended)
                                    const SizedBox(width: 8),
                                  if (_isTimeExtended)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '+20s',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Quick Stats
                      Row(
                        children: [
                          _buildStatItem(Icons.timer, 'Time', '${widget.gameConfig.timePerQuestion}s'),
                          const SizedBox(width: 12),
                          _buildStatItem(Icons.score, 'Points', '1'), // Always 1 point per question
                          const SizedBox(width: 12),
                          _buildStatItem(Icons.groups, 'Teams', '${widget.gameConfig.teams.length}'),
                          const SizedBox(width: 12),
                          _buildStatItem(Icons.card_giftcard, 'Wildcards', '$_currentRoundWildcardUses'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Question Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.question_answer, color: Colors.yellow, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Question $_currentQuestionNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (_currentQuestion != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.yellow.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '1 pt', // Always 1 point
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingQuestions)
                        const Center(
                          child: CircularProgressIndicator(color: Colors.yellow),
                        )
                      else if (_currentQuestion == null)
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 32),
                              const SizedBox(height: 12),
                              const Text(
                                'No questions available',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please add questions to the database',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                          GestureDetector(
                            onTap: _isGameStarted ? _toggleQuestionVisibility : null,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isQuestionVisible
                                      ? Colors.yellow.withOpacity(0.3)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  if (!_isQuestionVisible)
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.visibility_off, color: Colors.yellow, size: 24),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Question Hidden',
                                            style: TextStyle(
                                              color: Colors.yellow,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Text(
                                      _currentQuestion!.text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                    ),
                                  if (_isGameStarted)
                                    const SizedBox(height: 12),
                                  if (_isGameStarted)
                                    Text(
                                      _isQuestionVisible
                                          ? 'Tap to hide question'
                                          : 'Tap to reveal question',
                                      style: TextStyle(
                                        color: Colors.yellow,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      if (_isGameStarted && !_isQuestionVisible && _currentQuestion != null)
                        const SizedBox(height: 16),
                      if (_isGameStarted && !_isQuestionVisible && _currentQuestion != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Question is hidden. Tap the box above to reveal it.',
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Teams Scores Section with Modern Awarding
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.leaderboard, color: Colors.yellow, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Team Scores',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (widget.gameConfig.enableWildcards)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.yellow.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.card_giftcard, color: Colors.yellow, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    '$_currentRoundWildcardUses/${widget.gameConfig.teams.length * 5}',
                                    style: TextStyle(
                                      color: Colors.yellow,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Modern Award Points Panel
                      if (_showAwardPanel && _selectedTeamForPoints != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.yellow.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.yellow),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.yellow, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Award points to $_selectedTeamForPoints',
                                    style: const TextStyle(
                                      color: Colors.yellow,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedTeamForPoints = null;
                                        _showAwardPanel = false;
                                      });
                                    },
                                    icon: const Icon(Icons.close, color: Colors.yellow, size: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Award 1 point for correct answer
                                  ElevatedButton.icon(
                                    onPressed: () => _awardPointsModern(_selectedTeamForPoints!, 1),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Correct (+1)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                  // Penalty option
                                  ElevatedButton.icon(
                                    onPressed: () => _awardPointsModern(_selectedTeamForPoints!, -1),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Wrong (-1)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      ...widget.gameConfig.teams.map((team) {
                        final index = widget.gameConfig.teams.indexOf(team);
                        final score = _teamScores[team.name] ?? 0;
                        final color = teamColors[index % teamColors.length];
                        final wildcards = _teamWildcards[team.name] ?? {};
                        final isSelected = _selectedTeamForPoints == team.name;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withOpacity(0.3)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : color.withOpacity(0.2),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Team header with score
                              GestureDetector(
                                onTap: () => _toggleAwardPanel(team.name),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            team.name,
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${team.players.where((p) => p.isNotEmpty).length} players',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$score',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'points',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      isSelected ? Icons.expand_less : Icons.expand_more,
                                      color: color,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),

                              // Wildcards section
                              if (widget.gameConfig.enableWildcards)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Divider(color: Colors.white24),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildWildcardButton(team.name, 'Unlimited Time', Icons.timer_off,
                                                  () => _useUnlimitedTime(team.name)),
                                          _buildWildcardButton(team.name, 'Extra Time', Icons.timer,
                                                  () => _useExtraTime(team.name)),
                                          _buildWildcardButton(team.name, 'Theif', Icons.attach_money,
                                                  () => _useTheif(team.name)),
                                          _buildWildcardButton(team.name, 'Plus Minus', Icons.add_circle_outline,
                                                  () => _usePlusMinus(team.name)),
                                          _buildWildcardButton(team.name, 'Tables', Icons.table_chart,
                                                  () => _useTables(team.name)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Game Control Buttons
                if (!_isGameStarted)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _startGame,
                      icon: const Icon(Icons.play_arrow, size: 24),
                      label: const Text('START GAME', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                if (_isGameStarted) ...[
                  // Navigation Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _toggleQuestionVisibility,
                          icon: Icon(
                            _isQuestionVisible ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          label: Text(_isQuestionVisible ? 'Hide Question' : 'Show Question'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_currentQuestionNumber < widget.gameConfig.numberOfRounds) {
                              _getNextRandomQuestion();
                            } else {
                              _endGame();
                            }
                          },
                          icon: Icon(
                            _currentQuestionNumber < widget.gameConfig.numberOfRounds
                                ? Icons.skip_next
                                : Icons.flag,
                            size: 20,
                          ),
                          label: Text(
                            _currentQuestionNumber < widget.gameConfig.numberOfRounds
                                ? 'Next Question'
                                : 'Finish Game',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // End Game Button
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _endGame,
                      icon: const Icon(Icons.flag, size: 16),
                      label: const Text('End Game Now'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}