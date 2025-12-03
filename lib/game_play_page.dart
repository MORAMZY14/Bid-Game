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
      points: (data['points'] ?? 10).toInt(),
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
  bool _isQuestionVisible = false; // Changed from _isAnswerRevealed
  int _timeLeft = 0;
  Timer? _timer;
  bool _isTimerRunning = false;

  List<Question> _questions = [];
  List<Question> _usedQuestions = [];
  Question? _currentQuestion;
  bool _isLoadingQuestions = true;

  // Wildcards state for each team
  Map<String, Map<String, bool>> _teamWildcards = {};
  Map<String, int> _teamWildcardUses = {};

  // Timer control state
  int _baseTime = 0;
  bool _isTimeExtended = false;

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
      _teamWildcardUses[team.name] = 0;
    }
    _timeLeft = widget.gameConfig.timePerQuestion;
    _baseTime = widget.gameConfig.timePerQuestion;
    _isQuestionVisible = false; // Start with question hidden
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
        points: 10,
        timestamp: Timestamp.now(),
        status: 'approved',
        questionNumber: 1,
      ),
      Question(
        id: '2',
        text: 'Who painted the Mona Lisa?',
        category: 'Art',
        difficulty: 'Medium',
        points: 15,
        timestamp: Timestamp.now(),
        status: 'approved',
        questionNumber: 2,
      ),
      Question(
        id: '3',
        text: 'What is the chemical symbol for gold?',
        category: 'Science',
        difficulty: 'Easy',
        points: 10,
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

    if (_currentQuestion != null) {
      _usedQuestions.add(_currentQuestion!);
      _questions.removeWhere((q) => q.id == _currentQuestion!.id);
    }

    if (_questions.isNotEmpty) {
      setState(() {
        _currentQuestion = _questions.first;
        _currentQuestionNumber++;
        _isQuestionVisible = false; // Reset question visibility for new question
        _timeLeft = widget.gameConfig.timePerQuestion;
        _baseTime = widget.gameConfig.timePerQuestion;
        if (_isGameStarted) {
          _startTimer();
        }
      });
    } else {
      _endGame();
    }
  }

  void _startTimer() {
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
        // When time runs out, automatically show the question
        if (!_isQuestionVisible) {
          _toggleQuestionVisibility();
        }
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
  }

  void _resumeTimer() {
    if (!_isTimerRunning && _timeLeft > 0) {
      _startTimer();
    }
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
        (_teamWildcardUses[teamName] ?? 0) < 1) {
      setState(() {
        _timer?.cancel();
        _isTimerRunning = false;
        _teamWildcards[teamName]?['Unlimited Time'] = false;
        _teamWildcardUses[teamName] = (_teamWildcardUses[teamName] ?? 0) + 1;
      });
      _showSuccess('$teamName used Unlimited Time! Timer stopped.');
    }
  }

  void _useExtraTime(String teamName) {
    if (_teamWildcards[teamName]?['Extra Time'] == true &&
        (_teamWildcardUses[teamName] ?? 0) < 1) {
      setState(() {
        _addExtraTime(20);
        _teamWildcards[teamName]?['Extra Time'] = false;
        _teamWildcardUses[teamName] = (_teamWildcardUses[teamName] ?? 0) + 1;
      });
      _showSuccess('$teamName used Extra Time! +20 seconds added.');
    }
  }

  void _useTheif(String teamName) {
    if (_teamWildcards[teamName]?['Theif'] == true &&
        (_teamWildcardUses[teamName] ?? 0) < 1) {
      _showTheifDialog(teamName);
    }
  }

  void _usePlusMinus(String teamName) {
    if (_teamWildcards[teamName]?['Plus Minus'] == true &&
        (_teamWildcardUses[teamName] ?? 0) < 1) {
      _showPlusMinusDialog(teamName);
    }
  }

  void _useTables(String teamName) {
    if (_teamWildcards[teamName]?['Tables'] == true &&
        (_teamWildcardUses[teamName] ?? 0) < 1) {
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
              _teamWildcards[teamName]?['Theif'] = false;
              _teamWildcardUses[teamName] = (_teamWildcardUses[teamName] ?? 0) + 1;
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
                  onPressed: () => _adjustPoints(team.name, 10),
                  icon: const Icon(Icons.add, color: Colors.green),
                ),
                IconButton(
                  onPressed: () => _adjustPoints(team.name, -10),
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
              _teamWildcards[teamName]?['Plus Minus'] = false;
              _teamWildcardUses[teamName] = (_teamWildcardUses[teamName] ?? 0) + 1;
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
              _teamWildcards[teamName]?['Tables'] = false;
              _teamWildcardUses[teamName] = (_teamWildcardUses[teamName] ?? 0) + 1;
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
        _pauseTimer(); // Pause timer when question is revealed
      } else {
        _resumeTimer(); // Resume timer when question is hidden
      }
    });
  }

  void _awardPoints(String teamName, bool isCorrect) {
    final currentQuestion = _currentQuestion;
    if (currentQuestion == null) return;

    int points = currentQuestion.points;

    setState(() {
      if (isCorrect) {
        _teamScores[teamName] = (_teamScores[teamName] ?? 0) + points;
      } else if (widget.gameConfig.enableTimePenalty) {
        _teamScores[teamName] = (_teamScores[teamName] ?? 0) - (points ~/ 2);
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
      _startTimer();
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
    final usesLeft = 1 - (_teamWildcardUses[teamName] ?? 0);

    return Tooltip(
      message: '$wildcardName\nUses left: $usesLeft',
      child: GestureDetector(
        onTap: hasWildcard && usesLeft > 0 ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasWildcard && usesLeft > 0
                ? Colors.yellow.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasWildcard && usesLeft > 0
                  ? Colors.yellow
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: hasWildcard && usesLeft > 0 ? Colors.yellow : Colors.grey,
                  size: 16),
              const SizedBox(height: 2),
              Text(
                wildcardName.split(' ').first,
                style: TextStyle(
                  color: hasWildcard && usesLeft > 0 ? Colors.yellow : Colors.grey,
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
                              if (_isGameStarted)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: _isTimerRunning ? _pauseTimer : _resumeTimer,
                                      icon: Icon(
                                        _isTimerRunning ? Icons.pause : Icons.play_arrow,
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
                          _buildStatItem(Icons.score, 'Points', '${widget.gameConfig.pointsPerCorrectAnswer}'),
                          const SizedBox(width: 12),
                          _buildStatItem(Icons.groups, 'Teams', '${widget.gameConfig.teams.length}'),
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
                              child: Text(
                                '${_currentQuestion!.points} pts',
                                style: const TextStyle(
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
                          // Question Display with Reveal/Hide functionality
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

                // Teams Scores Section
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
                              child: const Row(
                                children: [
                                  Icon(Icons.card_giftcard, color: Colors.yellow, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'WILDCARDS',
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
                      ...widget.gameConfig.teams.map((team) {
                        final index = widget.gameConfig.teams.indexOf(team);
                        final score = _teamScores[team.name] ?? 0;
                        final color = teamColors[index % teamColors.length];
                        final wildcards = _teamWildcards[team.name] ?? {};
                        final usesLeft = 1 - (_teamWildcardUses[team.name] ?? 0);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                        style: const TextStyle(
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
                                ],
                              ),
                              if (widget.gameConfig.enableWildcards && usesLeft > 0)
                                const SizedBox(height: 12),
                              if (widget.gameConfig.enableWildcards && usesLeft > 0)
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
                  // Answer Control
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
                        const Text(
                          'Award Points',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...widget.gameConfig.teams.map((team) {
                          final index = widget.gameConfig.teams.indexOf(team);
                          final color = teamColors[index % teamColors.length];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    team.name,
                                    style: TextStyle(color: color, fontSize: 14),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => _awardPoints(team.name, true),
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.green.withOpacity(0.1),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _awardPoints(team.name, false),
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.red.withOpacity(0.1),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Navigation Buttons (Removed Reveal Answer button)
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