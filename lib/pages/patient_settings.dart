import 'package:flutter/material.dart';

class PatientSettings extends StatefulWidget {
  const PatientSettings({super.key});

  @override
  State<PatientSettings> createState() => _PatientSettings();
}

class _PatientSettings extends State<PatientSettings> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('Settings'),

        leading: BackButton(
            onPressed: () {
              Navigator.pop(context);
            }
        ),

        elevation: 10.0,
        shadowColor: Colors.black.withAlpha(255),
      ),




    );
  }
}