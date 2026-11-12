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


    );


  }
}
