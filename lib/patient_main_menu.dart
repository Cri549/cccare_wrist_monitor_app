import 'package:flutter/material.dart';

class PatientHomePage extends StatelessWidget {
  const PatientHomePage({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CCCARE App',
      theme: ThemeData(

        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(title: 'CCCARE Home'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});


  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _dailyStreak = 1;
  String _streakDisplay = "";

  void _incrementStreak(){
    setState(() {
      _dailyStreak++;
      _streakDisplay = _dailyStreak.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: Text(widget.title),

        actions: [
          Icon(Icons.local_fire_department_outlined),
          SizedBox(width: 4),
          Text(_streakDisplay, style: TextStyle(fontSize: 20)),
          SizedBox(width: 16),
        ],

        elevation: 10.0,
        shadowColor: Colors.black.withAlpha(255),
      ),

      drawer: MenuDrawer(),

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Big "Start Daily Routine" button
              Expanded(
                flex: 3,
                child: HomePageButton(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Start Daily Routine',
                  iconSize: 64,
                  fontSize: 24,
                  onPressed: () {
                    // TODO: navigate to the daily routine screen
                    _incrementStreak();
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Row 1: Prescription + Exercise Logs
              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: HomePageButton(
                        icon: Icons.description_outlined,
                        label: 'Prescription',
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: HomePageButton(
                        icon: Icons.calendar_month_outlined,
                        label: 'Exercise Logs',
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Row 2:

              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: HomePageButton(
                        // Empty for now, like the sketch. Add icon/label later.
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: HomePageButton(
                        icon: Icons.person_outline,
                        label: 'Contact CCCARE',
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

        ),

      ),


    );
  }
}

class MenuDrawer extends StatelessWidget {
  const MenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircleAvatar(
                radius: 40,
                child: Icon(Icons.person_outline, size: 48),
              ),
            ),
            ListTile(title: const Text('Account'), onTap: () {}),
            ListTile(title: const Text('Settings'), onTap: () {}),
            ListTile(title: const Text('Help'), onTap: () {}),
          ],

        ),

      ),

    );

  }
}


class HomePageButton extends StatelessWidget {
  const HomePageButton({
    super.key,
    this.icon,
    this.label,
    this.iconSize = 36,
    this.fontSize = 16,
    required this.onPressed,
  });

  final IconData? icon;
  final String? label;
  final double iconSize;
  final double fontSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 4,
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) Icon(icon, size: iconSize),
          if (icon != null && label != null) const SizedBox(height: 8),
          if (label != null)
            Text(
              label!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fontSize),
            ),
        ],
      ),
    );
  }
}