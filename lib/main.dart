import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CCCARE App',
      theme: ThemeData(

        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'CCCARE Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});


  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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

      drawer: const MenuDrawer(),


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
          Icon(icon, size: iconSize),
          const SizedBox(height: 8),
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