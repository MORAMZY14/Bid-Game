import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionBankEntryPage extends StatefulWidget {
  const QuestionBankEntryPage({super.key});

  @override
  State<QuestionBankEntryPage> createState() => _QuestionBankEntryPageState();
}

class _QuestionBankEntryPageState extends State<QuestionBankEntryPage> {
  final TextEditingController _questionController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSubmitting = false;
  bool _showSuccessMessage = false;
  String? _errorMessage;

  // Variables for new fields
  String _selectedCategory = 'General';
  String _selectedDifficulty = 'Medium';
  final TextEditingController _pointsController = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _pointsController.text = '10'; // Default points
  }

  @override
  void dispose() {
    _questionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<int> _getNextQuestionNumber() async {
    try {
      final counterDoc = await _firestore
          .collection('metadata')
          .doc('questionCounter')
          .get();

      if (!counterDoc.exists) {
        await _firestore
            .collection('metadata')
            .doc('questionCounter')
            .set({'count': 0});
        return 1;
      }

      final currentCount = counterDoc.data()?['count'] as int? ?? 0;
      return currentCount + 1;
    } catch (e) {
      print('Error getting question number: $e');
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  Future<void> _updateQuestionCounter(int newCount) async {
    try {
      await _firestore
          .collection('metadata')
          .doc('questionCounter')
          .set({'count': newCount}, SetOptions(merge: true));
    } catch (e) {
      print('Error updating counter: $e');
    }
  }

  Future<void> _submitQuestion() async {
    // Validate question text
    if (_questionController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a question';
      });
      return;
    }

    // Validate points
    final points = int.tryParse(_pointsController.text);
    if (points == null || points <= 0) {
      setState(() {
        _errorMessage = 'Please enter valid points (positive number)';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _showSuccessMessage = false;
    });

    try {
      // Get the next question number
      final nextQuestionNumber = await _getNextQuestionNumber();

      // Use custom document ID "Question X"
      final docId = 'Question $nextQuestionNumber';

      // Prepare question data matching the factory structure
      final questionData = {
        'text': _questionController.text.trim(),
        'category': _selectedCategory,
        'difficulty': _selectedDifficulty,
        'points': points,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'approved',
        'questionNumber': nextQuestionNumber,
      };

      // Add question to Firestore with custom document ID
      await _firestore.collection('questions').doc(docId).set(questionData);

      // Update the counter for next time
      await _updateQuestionCounter(nextQuestionNumber);

      // Show success message
      setState(() {
        _showSuccessMessage = true;
      });

      // Clear all fields
      _questionController.clear();
      _pointsController.text = '10';
      _selectedCategory = 'General';
      _selectedDifficulty = 'Medium';

      // Hide success message after 3 seconds
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _showSuccessMessage = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit question: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = constraints.maxWidth > 1000;
              final isMediumScreen = constraints.maxWidth > 600;
              final isSmallScreen = constraints.maxWidth < 400;

              // Calculate responsive values
              final double horizontalPadding = isLargeScreen
                  ? constraints.maxWidth * 0.15
                  : isMediumScreen
                  ? 32.0
                  : isSmallScreen
                  ? 12.0
                  : 20.0;

              final double titleFontSize = isLargeScreen
                  ? 32
                  : isMediumScreen
                  ? 28
                  : isSmallScreen
                  ? 22
                  : 24;

              return Stack(
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Back Button and Title
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                    size: isSmallScreen ? 20 : 24,
                                  ),
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 12 : 20),
                              Expanded(
                                child: Text(
                                  'Question Bank Entry',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: isSmallScreen ? 20 : 40),

                          /// Description
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.yellow,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                    SizedBox(width: isSmallScreen ? 8 : 12),
                                    Text(
                                      'Submission Guidelines',
                                      style: TextStyle(
                                        color: Colors.yellow,
                                        fontSize: isSmallScreen ? 16 : 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 12 : 16),
                                _buildGuideline(
                                  '1. Enter clear and concise questions',
                                  isSmallScreen: isSmallScreen,
                                ),
                                _buildGuideline(
                                  '2. Questions should be related to bidding/gaming',
                                  isSmallScreen: isSmallScreen,
                                ),
                                _buildGuideline(
                                  '3. Avoid offensive or inappropriate content',
                                  isSmallScreen: isSmallScreen,
                                ),
                                _buildGuideline(
                                  '4. Submitted questions will be reviewed before use',
                                  isSmallScreen: isSmallScreen,
                                ),
                                _buildGuideline(
                                  '5. Blash As2la T3gzna Ya Shbab ♥',
                                  isSmallScreen: isSmallScreen,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 24 : 40),

                          /// Question Input Section
                          Text(
                            'Enter Your Question',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 18 : (isLargeScreen ? 24 : 20),
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 12 : 16),

                          /// Question Text Field
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: TextField(
                              controller: _questionController,
                              maxLines: isSmallScreen ? 4 : 6,
                              minLines: isSmallScreen ? 3 : 4,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type your question here...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                              ),
                              cursorColor: Colors.yellow,
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 16 : 24),

                          /// Category, Difficulty, and Points - RESPONSIVE LAYOUT
                          if (constraints.maxWidth > 700)
                            _buildDesktopSettingsRow(isSmallScreen)
                          else
                            _buildMobileSettingsColumn(isSmallScreen),

                          if (_errorMessage != null) ...[
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red[300],
                                    size: isSmallScreen ? 18 : 24,
                                  ),
                                  SizedBox(width: isSmallScreen ? 8 : 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red[300],
                                        fontSize: isSmallScreen ? 12 : 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          SizedBox(height: isSmallScreen ? 24 : 40),

                          /// Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: isSmallScreen ? 50 : (isLargeScreen ? 70 : 60),
                            child: GestureDetector(
                              onTap: _isSubmitting ? null : _submitQuestion,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _isSubmitting
                                        ? [Colors.grey, Colors.grey[700]!]
                                        : [
                                      const Color(0xFFFFC300),
                                      const Color(0xFFFF8A00)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(0, 4),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _isSubmitting
                                      ? SizedBox(
                                    height: isSmallScreen ? 20 : 24,
                                    width: isSmallScreen ? 20 : 24,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                      : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload,
                                        color: Colors.white,
                                        size: isSmallScreen ? 22 : 28,
                                      ),
                                      SizedBox(width: isSmallScreen ? 8 : 12),
                                      Text(
                                        'SUBMIT QUESTION',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen ? 14 : (isLargeScreen ? 20 : 18),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 40 : 60),

                          /// Recent Submissions Preview
                          StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('questions')
                                .orderBy('questionNumber', descending: true)
                                .limit(5)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recent Submissions',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 16 : (isLargeScreen ? 22 : 18),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: isSmallScreen ? 12 : 16),
                                    Container(
                                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'No submissions yet',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: isSmallScreen ? 12 : 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              final questions = snapshot.data!.docs;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recent Submissions',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 16 : (isLargeScreen ? 22 : 18),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  SizedBox(height: isSmallScreen ? 12 : 16),

                                  ...questions.map((doc) {
                                    final data =
                                    doc.data() as Map<String, dynamic>;
                                    return _buildRecentSubmissionItem(
                                      questionNumber: data['questionNumber'] ??
                                          int.tryParse(doc.id
                                              .replaceAll('Question ', '')) ??
                                          0,
                                      category: data['category'] ?? 'General',
                                      difficulty: data['difficulty'] ?? 'Medium',
                                      points: data['points'] ?? 10,
                                      timestamp: data['timestamp'] != null
                                          ? (data['timestamp'] as Timestamp)
                                          .toDate()
                                          : DateTime.now(),
                                      isSmallScreen: isSmallScreen,
                                    );
                                  }).toList(),
                                ],
                              );
                            },
                          ),

                          SizedBox(height: isSmallScreen ? 20 : 40),
                        ],
                      ),
                    ),
                  ),

                  /// Success Notification
                  if (_showSuccessMessage)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 24,
                            ),
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00C853),
                                  Color(0xFF64DD17),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(0, 4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: isSmallScreen ? 20 : 24,
                                ),
                                SizedBox(width: isSmallScreen ? 8 : 12),
                                Flexible(
                                  child: Text(
                                    'Question added successfully!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.w600,
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSettingsRow(bool isSmallScreen) {
    return Row(
      children: [
        /// Category Dropdown
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue!;
                      });
                    },
                    dropdownColor: const Color(0xFF7D00C8),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                      size: isSmallScreen ? 20 : 24,
                    ),
                    underline: const SizedBox(),
                    isExpanded: true,
                    items: <String>[
                      'General',
                      'Sports',
                      'Entertainment',
                      'History',
                      'Science',
                      'Geography',
                      'Math',
                      'Art',
                      'Music',
                      'Movies',
                      'TV Shows',
                      'Video Games',
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: isSmallScreen ? 8 : 16),

        /// Difficulty Dropdown
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Difficulty',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                  child: DropdownButton<String>(
                    value: _selectedDifficulty,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedDifficulty = newValue!;
                      });
                    },
                    dropdownColor: const Color(0xFF7D00C8),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                      size: isSmallScreen ? 20 : 24,
                    ),
                    underline: const SizedBox(),
                    isExpanded: true,
                    items: <String>[
                      'Easy',
                      'Medium',
                      'Hard',
                      'Expert',
                    ].map<DropdownMenuItem<String>>((String value) {
                      Color textColor;
                      switch (value) {
                        case 'Easy':
                          textColor = Colors.green;
                          break;
                        case 'Medium':
                          textColor = Colors.yellow;
                          break;
                        case 'Hard':
                          textColor = Colors.orange;
                          break;
                        case 'Expert':
                          textColor = Colors.red;
                          break;
                        default:
                          textColor = Colors.white;
                      }
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: textColor,
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: isSmallScreen ? 8 : 16),

        /// Points Field
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Points',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: TextField(
                  controller: _pointsController,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Points',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 12 : 16,
                    ),
                  ),
                  cursorColor: Colors.yellow,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileSettingsColumn(bool isSmallScreen) {
    return Column(
      children: [
        /// Category Dropdown
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue!;
                    });
                  },
                  dropdownColor: const Color(0xFF7D00C8),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: <String>[
                    'General',
                    'Sports',
                    'Entertainment',
                    'History',
                    'Science',
                    'Geography',
                    'Math',
                    'Art',
                    'Music',
                    'Movies',
                    'TV Shows',
                    'Video Games',
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: isSmallScreen ? 12 : 16),

        /// Difficulty Dropdown
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Difficulty',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                child: DropdownButton<String>(
                  value: _selectedDifficulty,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDifficulty = newValue!;
                    });
                  },
                  dropdownColor: const Color(0xFF7D00C8),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: <String>[
                    'Easy',
                    'Medium',
                    'Hard',
                    'Expert',
                  ].map<DropdownMenuItem<String>>((String value) {
                    Color textColor;
                    switch (value) {
                      case 'Easy':
                        textColor = Colors.green;
                        break;
                      case 'Medium':
                        textColor = Colors.yellow;
                        break;
                      case 'Hard':
                        textColor = Colors.orange;
                        break;
                      case 'Expert':
                        textColor = Colors.red;
                        break;
                      default:
                        textColor = Colors.white;
                    }
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(
                          color: textColor,
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: isSmallScreen ? 12 : 16),

        /// Points Field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Points',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              child: TextField(
                controller: _pointsController,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Points',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 12 : 16,
                  ),
                ),
                cursorColor: Colors.yellow,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGuideline(String text, {required bool isSmallScreen}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 4, right: isSmallScreen ? 8 : 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.yellow,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSubmissionItem({
    required int questionNumber,
    required String category,
    required String difficulty,
    required int points,
    required DateTime timestamp,
    required bool isSmallScreen,
  }) {
    Color difficultyColor;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        difficultyColor = Colors.green;
        break;
      case 'medium':
        difficultyColor = Colors.yellow;
        break;
      case 'hard':
        difficultyColor = Colors.orange;
        break;
      case 'expert':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = Colors.white;
    }

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // Submission icon
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.cloud_done,
              color: Colors.white.withOpacity(0.8),
              size: isSmallScreen ? 18 : 22,
            ),
          ),

          SizedBox(width: isSmallScreen ? 12 : 16),

          // Submission details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question #$questionNumber',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isSmallScreen ? 4 : 6),
                Wrap(
                  spacing: isSmallScreen ? 6 : 12,
                  runSpacing: isSmallScreen ? 4 : 6,
                  children: [
                    _buildInfoChip(
                      icon: Icons.category,
                      text: category,
                      color: Colors.blue,
                      isSmallScreen: isSmallScreen,
                    ),
                    _buildInfoChip(
                      icon: Icons.speed,
                      text: difficulty,
                      color: difficultyColor,
                      isSmallScreen: isSmallScreen,
                    ),
                    _buildInfoChip(
                      icon: Icons.star,
                      text: '$points pts',
                      color: Colors.yellow,
                      isSmallScreen: isSmallScreen,
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 4 : 6),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.white.withOpacity(0.6),
                      size: isSmallScreen ? 12 : 14,
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    Expanded(
                      child: Text(
                        'Submitted ${_formatDate(timestamp)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: isSmallScreen ? 11 : 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status indicator
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 12,
              vertical: isSmallScreen ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
              ),
            ),
            child: Text(
              'Submitted',
              style: TextStyle(
                color: Colors.green[300],
                fontSize: isSmallScreen ? 10 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 8,
        vertical: isSmallScreen ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: isSmallScreen ? 10 : 12,
          ),
          SizedBox(width: isSmallScreen ? 3 : 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: isSmallScreen ? 9 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} minutes ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}