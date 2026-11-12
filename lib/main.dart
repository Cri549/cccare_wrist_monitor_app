import 'package:flutter/material.dart';
import 'patient_main_menu.dart';

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

        colorScheme: .fromSeed(seedColor: Colors.cyan),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text(widget.title),

        elevation: 10.0,
        shadowColor: Colors.black.withAlpha(255),
      ),

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(16),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              Text(
                  'Welcome! Please select who you are',

                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black87,)
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 100,
                child: SelectionButton(
                  label: 'I am a patient',
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const PatientHomePage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                height: 100,
                child: SelectionButton(
                  label: 'I am a CCCARE Physician',
                  onPressed: () {},
                ),
              ),
              const SizedBox(height: 8),
            ],


          ),

        ),

      ),


    );
  }
}

class SelectionButton extends StatelessWidget {
  const SelectionButton({
    super.key,
    this.label,
    this.iconSize = 0,
    this.fontSize = 25,
    required this.onPressed,
  });

  final String? label;
  final double iconSize;
  final double fontSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,

        elevation: 4,
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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