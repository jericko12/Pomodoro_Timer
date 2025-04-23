import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomodoro Timer',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      home: PomodoroTimer(toggleTheme: toggleTheme, isDarkMode: isDarkMode),
    );
  }
}

class PomodoroTimer extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkMode;
  
  const PomodoroTimer({
    super.key, 
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> with SingleTickerProviderStateMixin {
  static const workDuration = 25 * 60; // 25 minutes in seconds
  static const shortBreakDuration = 5 * 60; // 5 minutes in seconds
  static const longBreakDuration = 15 * 60; // 15 minutes in seconds
  static const pomodorosPerLongBreak = 4;

  late AnimationController _animationController;
  Timer? _timer;
  Settings settings = Settings(); // Initialize with default values
  List<Task> tasks = [];
  Task? currentTask;
  List<SessionRecord> sessionHistory = [];
  
  int _secondsRemaining = 25 * 60;
  int _totalSeconds = 25 * 60;
  bool _isRunning = false;
  int _completedPomodoros = 0;
  bool _isWorkMode = true;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  DateTime? _sessionStartTime;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final List<String> _motivationalQuotes = [
    "The best way to get started is to quit talking and begin doing.",
    "Don't watch the clock; do what it does. Keep going.",
    "The secret of getting ahead is getting started.",
    "It always seems impossible until it's done.",
    "Your focus determines your reality.",
    "Small progress is still progress.",
  ];
  
  String _currentQuote = "";
  int _lastQuoteChangeMinute = -1;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );
    
    // Initialize the first quote
    _updateQuoteIfNeeded();
  }
  
  Future<void> _loadSettings() async {
    final loadedSettings = await Settings.load();
    setState(() {
      settings = loadedSettings;
      _secondsRemaining = settings.workDuration;
      _totalSeconds = settings.workDuration;
    });
    _loadTasks();
    _loadSessionHistory();
  }
  
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getStringList('tasks') ?? [];
    tasks = tasksJson
        .map((taskJson) => Task.fromJson(Map<String, dynamic>.from(
            Map<String, dynamic>.from(
                Map<String, dynamic>.from(jsonDecode(taskJson))))))
        .toList();
    setState(() {});
  }
  
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = tasks.map((task) => jsonEncode(task.toJson())).toList();
    await prefs.setStringList('tasks', tasksJson);
  }
  
  Future<void> _loadSessionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('sessionHistory') ?? [];
    sessionHistory = historyJson
        .map((sessionJson) => SessionRecord.fromJson(
            Map<String, dynamic>.from(jsonDecode(sessionJson))))
        .toList();
  }
  
  Future<void> _saveSessionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = sessionHistory
        .map((session) => jsonEncode(session.toJson()))
        .toList();
    await prefs.setStringList('sessionHistory', historyJson);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _updateQuoteIfNeeded() {
    // Get current minute
    final now = DateTime.now();
    final currentMinute = now.minute;
    
    // Change quote if minute has changed or if it's the first time
    if (_lastQuoteChangeMinute != currentMinute) {
      setState(() {
        _currentQuote = _motivationalQuotes[math.Random().nextInt(_motivationalQuotes.length)];
        _lastQuoteChangeMinute = currentMinute;
      });
    }
  }

  void _startTimer() {
    _sessionStartTime = DateTime.now();
    setState(() {
      _isRunning = true;
    });

    _animationController.duration = Duration(seconds: _secondsRemaining);
    _animationController.reverse(from: _secondsRemaining / _totalSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
          
          // Check if we need to update the quote (every minute)
          if (_secondsRemaining % 60 == 0) {
            _updateQuoteIfNeeded();
          }
        });
      } else {
        _handleTimerComplete();
      }
    });
    
    // Update quote when timer starts
    _updateQuoteIfNeeded();
  }

  void _pauseTimer() {
    _timer?.cancel();
    _animationController.stop();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _animationController.reset();
    setState(() {
      _isRunning = false;
      _totalSeconds = _isWorkMode ? settings.workDuration : 
        (_completedPomodoros % settings.pomodorosPerLongBreak == 0 && _completedPomodoros > 0) ? 
          settings.longBreakDuration : settings.shortBreakDuration;
      _secondsRemaining = _totalSeconds;
    });

    // If we're resetting a session that was in progress, record it as incomplete
    if (_sessionStartTime != null) {
      _recordSession(false);
    }
    
    // Update quote when timer is reset
    _updateQuoteIfNeeded();
  }

  void _handleTimerComplete() {
    _timer?.cancel();
    _animationController.reset();
    
    // Record completed session
    _recordSession(true);
    
    // Play sound
    if (settings.playSounds) {
      _playSound();
    }
    
    setState(() {
      _isRunning = false;
      
      if (_isWorkMode) {
        // Completed a work session
        _completedPomodoros++;
        _isWorkMode = false;
        
        // Update current task's completed pomodoros
        if (currentTask != null) {
          currentTask!.completedPomodoros++;
          _saveTasks();
        }
        
        // Determine if it should be a long break
        if (_completedPomodoros > 0 && _completedPomodoros % settings.pomodorosPerLongBreak == 0) {
          _totalSeconds = settings.longBreakDuration;
          print("Starting LONG break after $_completedPomodoros pomodoros");
        } else {
          _totalSeconds = settings.shortBreakDuration;
          print("Starting short break");
        }
        
        // Auto-start break if enabled
        if (settings.autoStartBreaks) {
          _secondsRemaining = _totalSeconds;
          _startTimer();
          return;
        }
      } else {
        // Completed a break
        _isWorkMode = true;
        _totalSeconds = settings.workDuration;
        
        // Auto-start pomodoro if enabled
        if (settings.autoStartPomodoros) {
          _secondsRemaining = _totalSeconds;
          _startTimer();
          return;
        }
      }
      _secondsRemaining = _totalSeconds;
    });
    
    // Update quote when timer completes
    _updateQuoteIfNeeded();
  }
  
  void _recordSession(bool completed) {
    if (_sessionStartTime != null) {
      final session = SessionRecord(
        startTime: _sessionStartTime!,
        endTime: DateTime.now(),
        isWorkSession: _isWorkMode,
        completed: completed,
        taskTitle: currentTask?.title,
      );
      sessionHistory.add(session);
      _saveSessionHistory();
      _sessionStartTime = null;
    }
  }
  
  void _playSound() async {
    if (_isWorkMode) {
      await _audioPlayer.play(AssetSource('sounds/work_complete.mp3'));
    } else {
      await _audioPlayer.play(AssetSource('sounds/break_complete.mp3'));
    }
  }

  void _skipSession() {
    _timer?.cancel();
    _animationController.reset();
    
    // Record skipped session as incomplete
    _recordSession(false);
    
    _handleTimerComplete();
  }
  
  void _addTask() {
    showDialog(
      context: context,
      builder: (context) => NewTaskDialog(
        onTaskAdded: (Task task) {
          setState(() {
            tasks.add(task);
            _saveTasks();
          });
        },
      ),
    );
  }
  
  void _selectTask(Task task) {
    setState(() {
      currentTask = task;
    });
  }
  
  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        settings: settings,
        onSettingsSaved: (Settings newSettings) {
          setState(() {
            settings = newSettings;
            settings.save();
            
            // Update current timer if needed
            if (!_isRunning) {
              _totalSeconds = _isWorkMode ? settings.workDuration : 
                (_completedPomodoros % settings.pomodorosPerLongBreak == 0 && _completedPomodoros > 0) ? 
                  settings.longBreakDuration : settings.shortBreakDuration;
              _secondsRemaining = _totalSeconds;
            }
          });
        },
      ),
    );
  }
  
  void _showStats() {
    showDialog(
      context: context,
      builder: (context) => StatsDialog(
        sessionHistory: sessionHistory,
        completedPomodoros: _completedPomodoros,
      ),
    );
  }

  String get _timerDisplayText {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _sessionText {
    if (_isWorkMode) {
      return 'Work Session';
    } else {
      return (_completedPomodoros > 0 && _completedPomodoros % settings.pomodorosPerLongBreak == 0) 
          ? 'Long Break' 
          : 'Short Break';
    }
  }

  Color get _sessionColor {
    if (widget.isDarkMode) {
      return _isWorkMode ? Colors.indigo.shade400 : Colors.teal.shade400;
    } else {
      return _isWorkMode ? Colors.red.shade600 : Colors.green.shade600;
    }
  }

  Color get _sessionLightColor {
    if (widget.isDarkMode) {
      return _isWorkMode ? Colors.indigo.shade900.withOpacity(0.3) : Colors.teal.shade900.withOpacity(0.3);
    } else {
      return _isWorkMode ? Colors.red.shade100 : Colors.green.shade100;
    }
  }

  LinearGradient get _backgroundGradient {
    if (widget.isDarkMode) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _isWorkMode ? Colors.indigo.shade900.withOpacity(0.8) : Colors.teal.shade900.withOpacity(0.8),
          _isWorkMode ? Colors.indigo.shade800.withOpacity(0.9) : Colors.teal.shade800.withOpacity(0.9),
        ],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _isWorkMode ? Colors.red.shade50 : Colors.green.shade50,
          _isWorkMode ? Colors.red.shade100 : Colors.green.shade100,
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          _buildTimerPage(),
          _buildTasksPage(),
          _buildStatsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPage,
        backgroundColor: widget.isDarkMode ? Colors.grey.shade900 : Colors.white,
        selectedItemColor: _sessionColor,
        onTap: (index) {
          _pageController.animateToPage(
            index, 
            duration: const Duration(milliseconds: 300), 
            curve: Curves.easeInOut
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Timer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimerPage() {
    return Container(
      decoration: BoxDecoration(
        gradient: _backgroundGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/app_logo.png',
                        width: 28,
                        height: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pomodoro Timer',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _sessionColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          color: _sessionColor,
                        ),
                        onPressed: () => widget.toggleTheme(),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.settings,
                          color: _sessionColor,
                        ),
                        onPressed: _showSettings,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Current Task
            if (currentTask != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: _sessionLightColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.task_alt, color: _sessionColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentTask!.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _sessionColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${currentTask!.completedPomodoros}/${currentTask!.estimatedPomodoros}',
                      style: TextStyle(
                        color: _sessionColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Session Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: _sessionLightColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isWorkMode ? Icons.timer : Icons.free_breakfast,
                    color: _sessionColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sessionText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _sessionColor,
                    ),
                  ),
                ],
              ),
            ),
            
            // Pomodoro Count
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Completed: $_completedPomodoros',
                style: TextStyle(
                  fontSize: 16,
                  color: widget.isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
            ),
            
            // Motivational Quote
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Text(
                _currentQuote,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
            
            // Timer Circle
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Circle
                        Container(
                          decoration: BoxDecoration(
                            color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _sessionColor.withOpacity(0.2),
                                blurRadius: 15,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        // Progress Circle
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: TimerPainter(
                                animation: _animationController,
                                backgroundColor: _sessionLightColor,
                                color: _sessionColor,
                              ),
                            );
                          },
                        ),
                        // Timer text
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _timerDisplayText,
                                style: TextStyle(
                                  fontSize: 70,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Roboto',
                                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Button Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reset button
                  FilledButton.tonalIcon(
                    onPressed: _resetTimer,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                      foregroundColor: widget.isDarkMode ? Colors.white70 : Colors.grey.shade800,
                      minimumSize: const Size(60, 60),
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text(''),
                  ),
                  
                  // Start/Pause button
                  FilledButton(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    style: FilledButton.styleFrom(
                      backgroundColor: _sessionColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                        const SizedBox(width: 8),
                        Text(_isRunning ? 'Pause' : 'Start'),
                      ],
                    ),
                  ),
                  
                  // Skip button
                  FilledButton.tonalIcon(
                    onPressed: _skipSession,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                      foregroundColor: widget.isDarkMode ? Colors.white70 : Colors.grey.shade800,
                      minimumSize: const Size(60, 60),
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.skip_next),
                    label: const Text(''),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTasksPage() {
    return Container(
      color: widget.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tasks',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Task'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _sessionColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Task List
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 64,
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add a task to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: tasks.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final isSelected = currentTask?.title == task.title;
                        
                        return Card(
                          elevation: isSelected ? 4 : 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isSelected 
                              ? _sessionLightColor 
                              : widget.isDarkMode 
                                  ? Colors.grey.shade800 
                                  : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isSelected 
                                ? BorderSide(color: _sessionColor, width: 2)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () => _selectTask(task),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Checkbox
                                  Checkbox(
                                    value: task.completed,
                                    activeColor: _sessionColor,
                                    onChanged: (value) {
                                      setState(() {
                                        task.completed = value!;
                                        _saveTasks();
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  
                                  // Task details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            decoration: task.completed
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color: task.completed
                                                ? Colors.grey
                                                : null,
                                          ),
                                        ),
                                        if (task.notes != null && task.notes!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              task.notes!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Pomodoro counter
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _sessionColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.timer,
                                          size: 16,
                                          color: _sessionColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${task.completedPomodoros}/${task.estimatedPomodoros}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _sessionColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Menu
                                  PopupMenuButton(
                                    icon: const Icon(Icons.more_vert),
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: const Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        // Show edit dialog
                                      } else if (value == 'delete') {
                                        setState(() {
                                          tasks.removeAt(index);
                                          if (currentTask == task) {
                                            currentTask = null;
                                          }
                                          _saveTasks();
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatsPage() {
    // Calculate statistics
    final totalSessions = sessionHistory.length;
    final completedSessions = sessionHistory.where((s) => s.completed).length;
    final workSessions = sessionHistory.where((s) => s.isWorkSession).length;
    final workMinutes = sessionHistory
        .where((s) => s.isWorkSession && s.completed)
        .fold(0, (sum, session) => sum + session.duration.inMinutes);
    
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final startOfWeek = startOfToday.subtract(Duration(days: today.weekday - 1));
    
    final sessionsToday = sessionHistory
        .where((s) => s.startTime.isAfter(startOfToday) && s.isWorkSession && s.completed)
        .length;
    
    final sessionsThisWeek = sessionHistory
        .where((s) => s.startTime.isAfter(startOfWeek) && s.isWorkSession && s.completed)
        .length;
    
    // Group sessions by day for the chart
    final last7Days = List.generate(7, (i) => 
      startOfToday.subtract(Duration(days: 6 - i))
    );
    
    final dailyCounts = last7Days.map((day) {
      final count = sessionHistory
          .where((s) => 
              s.startTime.year == day.year && 
              s.startTime.month == day.month && 
              s.startTime.day == day.day && 
              s.isWorkSession && 
              s.completed)
          .length;
      return MapEntry(day, count);
    }).toList();
    
    return Container(
      color: widget.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statistics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Focus Time',
                      value: '$workMinutes min',
                      icon: Icons.timer,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Completed Pomodoros',
                      value: '$_completedPomodoros',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Today',
                      value: '$sessionsToday',
                      icon: Icons.today,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'This Week',
                      value: '$sessionsThisWeek',
                      icon: Icons.calendar_view_week,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              
              // Daily Activity Chart
              if (totalSessions > 0) ...[
                const SizedBox(height: 32),
                const Text(
                  'Last 7 Days Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: dailyCounts.map((entry) {
                      final day = entry.key;
                      final count = entry.value;
                      final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
                      final isToday = day.day == today.day && 
                                     day.month == today.month && 
                                     day.year == today.year;
                      
                      // Calculate bar height (max 150)
                      final maxHeight = 150.0;
                      final barHeight = count > 0 ? 20.0 + (count * 15.0).clamp(0.0, maxHeight - 20.0) : 0.0;
                      
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('$count', style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: count > 0 ? _sessionColor : Colors.grey,
                          )),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            width: 24,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: isToday 
                                  ? _sessionColor 
                                  : _sessionColor.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(dayName, style: TextStyle(
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
              
              // Recent Sessions
              if (sessionHistory.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text(
                  'Recent Sessions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...sessionHistory.reversed.take(5).map((session) => 
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: session.completed
                          ? Border.all(color: session.isWorkSession ? Colors.red.shade300 : Colors.green.shade300)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: session.isWorkSession 
                                ? Colors.red.shade100 
                                : Colors.green.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            session.isWorkSession 
                                ? Icons.work_outline 
                                : Icons.free_breakfast,
                            color: session.isWorkSession 
                                ? Colors.red 
                                : Colors.green,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.isWorkSession 
                                    ? 'Work Session' 
                                    : 'Break',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (session.taskTitle != null)
                                Text(
                                  session.taskTitle!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${session.duration.inMinutes} min',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_formatDate(session.startTime)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          session.completed 
                              ? Icons.check_circle_outline 
                              : Icons.cancel_outlined,
                          color: session.completed 
                              ? Colors.green 
                              : Colors.grey,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);
    
    if (dateToCheck == today) {
      return 'Today ${_formatTime(date)}';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month} ${_formatTime(date)}';
    }
  }
  
  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class TimerPainter extends CustomPainter {
  final Animation<double> animation;
  final Color backgroundColor;
  final Color color;

  TimerPainter({
    required this.animation,
    required this.backgroundColor,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width / 15;
    
    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    
    final progress = animation.value * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(TimerPainter oldDelegate) {
    return animation.value != oldDelegate.animation.value ||
        color != oldDelegate.color ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

class Settings {
  int workDuration;
  int shortBreakDuration;
  int longBreakDuration;
  int pomodorosPerLongBreak;
  bool playSounds;
  bool autoStartBreaks;
  bool autoStartPomodoros;

  Settings({
    this.workDuration = 25 * 60,
    this.shortBreakDuration = 5 * 60,
    this.longBreakDuration = 15 * 60,
    this.pomodorosPerLongBreak = 4,
    this.playSounds = true,
    this.autoStartBreaks = true,
    this.autoStartPomodoros = false,
  });

  static Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Settings(
      workDuration: prefs.getInt('workDuration') ?? 25 * 60,
      shortBreakDuration: prefs.getInt('shortBreakDuration') ?? 5 * 60,
      longBreakDuration: prefs.getInt('longBreakDuration') ?? 15 * 60,
      pomodorosPerLongBreak: prefs.getInt('pomodorosPerLongBreak') ?? 4,
      playSounds: prefs.getBool('playSounds') ?? true,
      autoStartBreaks: prefs.getBool('autoStartBreaks') ?? true,
      autoStartPomodoros: prefs.getBool('autoStartPomodoros') ?? false,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('workDuration', workDuration);
    await prefs.setInt('shortBreakDuration', shortBreakDuration);
    await prefs.setInt('longBreakDuration', longBreakDuration);
    await prefs.setInt('pomodorosPerLongBreak', pomodorosPerLongBreak);
    await prefs.setBool('playSounds', playSounds);
    await prefs.setBool('autoStartBreaks', autoStartBreaks);
    await prefs.setBool('autoStartPomodoros', autoStartPomodoros);
  }
}

class Task {
  String title;
  bool completed;
  int estimatedPomodoros;
  int completedPomodoros;
  DateTime createdAt;
  String? notes;

  Task({
    required this.title,
    this.completed = false,
    this.estimatedPomodoros = 1,
    this.completedPomodoros = 0,
    DateTime? createdAt,
    this.notes,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'completed': completed,
      'estimatedPomodoros': estimatedPomodoros,
      'completedPomodoros': completedPomodoros,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      title: json['title'],
      completed: json['completed'],
      estimatedPomodoros: json['estimatedPomodoros'],
      completedPomodoros: json['completedPomodoros'],
      createdAt: DateTime.parse(json['createdAt']),
      notes: json['notes'],
    );
  }
}

class SessionRecord {
  DateTime startTime;
  DateTime endTime;
  bool isWorkSession;
  bool completed;
  String? taskTitle;

  SessionRecord({
    required this.startTime,
    required this.endTime,
    required this.isWorkSession,
    required this.completed,
    this.taskTitle,
  });

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'isWorkSession': isWorkSession,
      'completed': completed,
      'taskTitle': taskTitle,
    };
  }

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      isWorkSession: json['isWorkSession'],
      completed: json['completed'],
      taskTitle: json['taskTitle'],
    );
  }

  Duration get duration => endTime.difference(startTime);
}

class NewTaskDialog extends StatefulWidget {
  final Function(Task) onTaskAdded;

  const NewTaskDialog({
    super.key,
    required this.onTaskAdded,
  });

  @override
  State<NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends State<NewTaskDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  int _estimatedPomodoros = 1;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task Title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Estimated Pomodoros:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (_estimatedPomodoros > 1) {
                      setState(() {
                        _estimatedPomodoros--;
                      });
                    }
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_estimatedPomodoros',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _estimatedPomodoros++;
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_titleController.text.trim().isNotEmpty) {
              final task = Task(
                title: _titleController.text.trim(),
                estimatedPomodoros: _estimatedPomodoros,
                notes: _notesController.text.trim().isNotEmpty
                    ? _notesController.text.trim()
                    : null,
              );
              widget.onTaskAdded(task);
              Navigator.pop(context);
            }
          },
          child: const Text('Add Task'),
        ),
      ],
    );
  }
}

class SettingsDialog extends StatefulWidget {
  final Settings settings;
  final Function(Settings) onSettingsSaved;

  const SettingsDialog({
    super.key,
    required this.settings,
    required this.onSettingsSaved,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int workMinutes;
  late int shortBreakMinutes;
  late int longBreakMinutes;
  late int pomodorosPerLongBreak;
  late bool playSounds;
  late bool autoStartBreaks;
  late bool autoStartPomodoros;

  @override
  void initState() {
    super.initState();
    workMinutes = widget.settings.workDuration ~/ 60;
    shortBreakMinutes = widget.settings.shortBreakDuration ~/ 60;
    longBreakMinutes = widget.settings.longBreakDuration ~/ 60;
    pomodorosPerLongBreak = widget.settings.pomodorosPerLongBreak;
    playSounds = widget.settings.playSounds;
    autoStartBreaks = widget.settings.autoStartBreaks;
    autoStartPomodoros = widget.settings.autoStartPomodoros;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return AlertDialog(
      title: const Text('Settings'),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      content: Container(
        width: screenWidth * 0.8,
        constraints: const BoxConstraints(maxWidth: 350),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Timer (minutes)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildTimeAdjuster(
                label: 'Work',
                value: workMinutes,
                onChanged: (value) {
                  setState(() {
                    workMinutes = value;
                  });
                },
              ),
              _buildTimeAdjuster(
                label: 'Short Break',
                value: shortBreakMinutes,
                onChanged: (value) {
                  setState(() {
                    shortBreakMinutes = value;
                  });
                },
              ),
              _buildTimeAdjuster(
                label: 'Long Break',
                value: longBreakMinutes,
                onChanged: (value) {
                  setState(() {
                    longBreakMinutes = value;
                  });
                },
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Long Break Interval',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: const Text('Pomodoros before long break:'),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    isDense: true,
                    value: pomodorosPerLongBreak,
                    items: [2, 3, 4, 5, 6].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          pomodorosPerLongBreak = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Auto Start',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SwitchListTile(
                title: const Text('Auto-start Breaks'),
                subtitle: const Text('Automatically start breaks when work session ends'),
                value: autoStartBreaks,
                onChanged: (value) {
                  setState(() {
                    autoStartBreaks = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Auto-start Pomodoros'),
                subtitle: const Text('Automatically start new work session when break ends'),
                value: autoStartPomodoros,
                onChanged: (value) {
                  setState(() {
                    autoStartPomodoros = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Sounds',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SwitchListTile(
                title: const Text('Play Sounds'),
                subtitle: const Text('Play a sound when timer ends'),
                value: playSounds,
                onChanged: (value) {
                  setState(() {
                    playSounds = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final newSettings = Settings(
              workDuration: workMinutes * 60,
              shortBreakDuration: shortBreakMinutes * 60,
              longBreakDuration: longBreakMinutes * 60,
              pomodorosPerLongBreak: pomodorosPerLongBreak,
              playSounds: playSounds,
              autoStartBreaks: autoStartBreaks,
              autoStartPomodoros: autoStartPomodoros,
            );
            widget.onSettingsSaved(newSettings);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTimeAdjuster({
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.remove_circle_outline, size: 22),
                onPressed: value > 1
                    ? () => onChanged(value - 1)
                    : null,
              ),
              Container(
                width: 30,
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.add_circle_outline, size: 22),
                onPressed: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatsDialog extends StatelessWidget {
  final List<SessionRecord> sessionHistory;
  final int completedPomodoros;

  const StatsDialog({
    super.key,
    required this.sessionHistory,
    required this.completedPomodoros,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    final totalWorkSessions = sessionHistory.where((s) => s.isWorkSession).length;
    final completedWorkSessions = sessionHistory.where((s) => s.isWorkSession && s.completed).length;
    final totalMinutes = sessionHistory
        .where((s) => s.isWorkSession && s.completed)
        .fold(0, (sum, session) => sum + session.duration.inMinutes);

    final completionRate = totalWorkSessions > 0
        ? (completedWorkSessions / totalWorkSessions * 100).toStringAsFixed(1)
        : '0';

    return AlertDialog(
      title: const Text('Statistics'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Focus Time', '$totalMinutes min'),
            _buildStatRow('Completed Pomodoros', '$completedPomodoros'),
            _buildStatRow('Completion Rate', '$completionRate%'),
            const SizedBox(height: 16),
            const Text(
              'Recent Sessions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (sessionHistory.isEmpty)
              const Text('No sessions recorded yet.'),
            ...sessionHistory.reversed.take(5).map((session) {
              final dateStr = _formatDate(session.startTime);
              final durationStr = '${session.duration.inMinutes} min';
              final title = session.isWorkSession ? 'Work' : 'Break';
              
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  session.isWorkSession
                      ? Icons.work_outline
                      : Icons.free_breakfast,
                  color: session.isWorkSession ? Colors.red : Colors.green,
                ),
                title: Text('$title - $durationStr'),
                subtitle: Text(dateStr),
                trailing: Icon(
                  session.completed
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  color: session.completed ? Colors.green : Colors.red,
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);
    
    if (dateToCheck == today) {
      return 'Today ${_formatTime(date)}';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month} ${_formatTime(date)}';
    }
  }
  
  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
