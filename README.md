# Pomodoro Timer

A feature-rich Pomodoro Timer app built with Flutter to boost your productivity and focus.

![Pomodoro Timer](assets/images/app_logo.png)

## Features

- **Customizable Timers**: 
  - Work sessions (default: 25 minutes)
  - Short breaks (default: 5 minutes) 
  - Long breaks (default: 15 minutes)
  - Configurable long break intervals (after how many pomodoros)

- **Task Management**: 
  - Create and manage tasks
  - Track pomodoros per task
  - Mark tasks as completed

- **Statistics**:
  - Track your focus time
  - View completed pomodoros
  - Daily and weekly activity tracking
  - Session history

- **Preferences**:
  - Dark/Light mode
  - Auto-start breaks
  - Auto-start work sessions
  - Sound notifications

## How to Use

1. **Timer**: Click Start to begin a work session. The timer will automatically switch between work and break sessions.

2. **Tasks**: 
   - Add tasks you want to accomplish
   - Estimate pomodoros needed for each task
   - Select a task to work on during your pomodoro sessions
   
3. **Stats**: View your productivity statistics and history.

4. **Settings**: Customize timers, break intervals, auto-start preferences, and sounds.

## The Pomodoro Technique

The Pomodoro Technique is a time management method developed by Francesco Cirillo:

1. Decide on a task to complete
2. Work for 25 minutes (one "pomodoro")
3. Take a short 5-minute break
4. After 4 pomodoros, take a longer 15-30 minute break
5. Repeat the process

This technique helps maintain focus and avoid burnout by incorporating regular breaks into your work schedule.

## Development

This app is built with Flutter and uses several packages:
- shared_preferences for persistent settings
- audioplayers for sound notifications

To run the project locally:

```
flutter pub get
flutter run
```

## Credits

Created by: Jericko Garcia

Icons and design: Custom-created
