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
  bool _isAnswerRevealed = false;
  int _timeLeft = 0;
  Timer? _timer;

  List<Question> _questions = [];
  List<Question> _usedQuestions = [];
  Question? _currentQuestion;
  bool _isLoadingQuestions = true;

  Map<String, bool> _teamPowerUpActive = {};
  Map<String, bool> _teamPowerUpUsed = {};

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
      _teamPowerUpActive[team.name] = false;
      _teamPowerUpUsed[team.name] = false;
    }
    _timeLeft = widget.gameConfig.timePerQuestion;
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

    if (_currentQuestion != null) {
      _usedQuestions.add(_currentQuestion!);
      _questions.removeWhere((q) => q.id == _currentQuestion!.id);
    }

    if (_questions.isNotEmpty) {
      setState(() {
        _currentQuestion = _questions.first;
        _currentQuestionNumber++;
        _isAnswerRevealed = false;
        _timeLeft = widget.gameConfig.timePerQuestion;
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
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
        if (!_isAnswerRevealed) {
          _revealAnswer();
        }
      }
    });
  }

  void _revealAnswer() {
    setState(() {
      _isAnswerRevealed = true;
      _timer?.cancel();
    });
  }

  void _awardPoints(String teamName, bool isCorrect) {
    final currentQuestion = _currentQuestion;
    if (currentQuestion == null) return;

    int points = currentQuestion.points;

    if (_teamPowerUpActive[teamName] == true) {
      points *= 2;
      _teamPowerUpActive[teamName] = false;
    }

    setState(() {
      if (isCorrect) {
        _teamScores[teamName] = (_teamScores[teamName] ?? 0) + points;
      } else if (widget.gameConfig.enableTimePenalty) {
        _teamScores[teamName] = (_teamScores[teamName] ?? 0) - (points ~/ 2);
      }
    });
  }

  void _usePowerUp(String teamName) {
    if (_teamPowerUpUsed[teamName] == false) {
      setState(() {
        _teamPowerUpActive[teamName] = true;
        _teamPowerUpUsed[teamName] = true;
      });
      _showSuccess('$teamName activated 2X power-up!');
    }
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = constraints.maxWidth > 1000;
              final isMediumScreen = constraints.maxWidth > 600;

              return SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen
                        ? constraints.maxWidth * 0.1
                        : isMediumScreen
                        ? 32.0
                        : 16.0,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            'Gameplay',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Question $_currentQuestionNumber/${widget.gameConfig.numberOfRounds}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Referee: ${widget.gameConfig.refereeName}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (_currentQuestion != null)
                                      Text(
                                        '${_currentQuestion!.category} • ${_currentQuestion!.difficulty} • ${_currentQuestion!.points} points',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _timeLeft > 10
                                          ? [Colors.green, Colors.lightGreen]
                                          : _timeLeft > 5
                                          ? [Colors.orange, Colors.yellow]
                                          : [Colors.red, Colors.orange],
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    '$_timeLeft',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(Icons.timer, color: Colors.yellow, size: 20),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Time per question',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${widget.gameConfig.timePerQuestion}s',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(Icons.score, color: Colors.yellow, size: 20),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Points per answer',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${widget.gameConfig.pointsPerCorrectAnswer}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(Icons.groups, color: Colors.yellow, size: 20),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Teams',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${widget.gameConfig.teams.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.question_answer, color: Colors.yellow, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  'Question $_currentQuestionNumber',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (_currentQuestion != null) ...[
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getDifficultyColor(_currentQuestion!.difficulty),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _currentQuestion!.difficulty,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.blue),
                                    ),
                                    child: Text(
                                      '${_currentQuestion!.points} pts',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_isLoadingQuestions)
                              const Center(
                                child: CircularProgressIndicator(color: Colors.yellow),
                              )
                            else if (_currentQuestion == null)
                              Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No questions available',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Please add questions to the database',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    _currentQuestion!.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.purple),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Referee Instructions:',
                                        style: TextStyle(
                                          color: Colors.yellow,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        '1. Read the question aloud\n'
                                            '2. Teams will provide answers verbally\n'
                                            '3. Select teams that answered correctly\n'
                                            '4. Award points accordingly',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.leaderboard, color: Colors.yellow, size: 24),
                                const SizedBox(width: 12),
                                const Text(
                                  'Team Scores',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                if (widget.gameConfig.enablePowerUps)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.purple),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.bolt, color: Colors.yellow, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          '2X POWER-UPS',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isLargeScreen ? 4 : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.5,
                              ),
                              itemCount: widget.gameConfig.teams.length,
                              itemBuilder: (context, index) {
                                final team = widget.gameConfig.teams[index];
                                final score = _teamScores[team.name] ?? 0;
                                final color = teamColors[index % teamColors.length];
                                final powerUpUsed = _teamPowerUpUsed[team.name] ?? false;
                                final powerUpActive = _teamPowerUpActive[team.name] ?? false;
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: color.withOpacity(0.3)),
                                  ),
                                  child: Column(
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
                                      const SizedBox(height: 8),
                                      Text(
                                        '$score',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'points',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (widget.gameConfig.enablePowerUps)
                                        GestureDetector(
                                          onTap: powerUpUsed ? null : () => _usePowerUp(team.name),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: powerUpActive
                                                  ? Colors.yellow.withOpacity(0.2)
                                                  : powerUpUsed
                                                  ? Colors.grey.withOpacity(0.2)
                                                  : color.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: powerUpActive
                                                    ? Colors.yellow
                                                    : powerUpUsed
                                                    ? Colors.grey
                                                    : color,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  powerUpActive ? Icons.bolt : powerUpUsed ? Icons.bolt_outlined : Icons.bolt,
                                                  color: powerUpActive ? Colors.yellow : powerUpUsed ? Colors.grey : color,
                                                  size: 12,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  powerUpActive ? 'ACTIVE' : powerUpUsed ? 'USED' : '2X',
                                                  style: TextStyle(
                                                    color: powerUpActive ? Colors.yellow : powerUpUsed ? Colors.grey : color,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      if (!_isGameStarted)
                        Center(
                          child: GestureDetector(
                            onTap: _startGame,
                            child: Container(
                              height: 60,
                              width: 250,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFC300), Color(0xFFFF8A00)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                    SizedBox(width: 12),
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

                      if (_isGameStarted) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (!_isAnswerRevealed) _revealAnswer();
                                },
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
                                        Icon(
                                          _isAnswerRevealed ? Icons.visibility : Icons.visibility_off,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _isAnswerRevealed ? 'Answer Revealed' : 'Reveal Answer',
                                          style: const TextStyle(
                                            color: Colors.white,
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
                                onTap: () {
                                  if (_currentQuestionNumber < widget.gameConfig.numberOfRounds) {
                                    _getNextRandomQuestion();
                                  } else {
                                    _endGame();
                                  }
                                },
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.green, Colors.lightGreen],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _currentQuestionNumber < widget.gameConfig.numberOfRounds
                                              ? Icons.skip_next
                                              : Icons.flag,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _currentQuestionNumber < widget.gameConfig.numberOfRounds
                                              ? 'Next Question'
                                              : 'Finish Game',
                                          style: const TextStyle(
                                            color: Colors.white,
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
                          ],
                        ),
                        const SizedBox(height: 20),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Award Points',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Select teams that answered correctly:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isLargeScreen ? 4 : 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 3,
                                ),
                                itemCount: widget.gameConfig.teams.length,
                                itemBuilder: (context, index) {
                                  final team = widget.gameConfig.teams[index];
                                  final color = teamColors[index % teamColors.length];
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            _awardPoints(team.name, true);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.green),
                                            ),
                                            child: Center(
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${team.name} ✓',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          _awardPoints(team.name, false);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.red),
                                          ),
                                          child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () {
                                  if (_currentQuestionNumber < widget.gameConfig.numberOfRounds) {
                                    _getNextRandomQuestion();
                                  } else {
                                    _endGame();
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue),
                                  ),
                                  child: const Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.arrow_forward, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text(
                                          'Continue to Next Question',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Center(
                          child: GestureDetector(
                            onTap: _endGame,
                            child: Container(
                              height: 50,
                              width: 200,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.red),
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.flag, color: Colors.red, size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                      'End Game Now',
                                      style: TextStyle(
                                        color: Colors.red,
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
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}