import 'package:flutter/material.dart';

class PatientReminders extends StatefulWidget {
  const PatientReminders({super.key});

  @override
  State<PatientReminders> createState() => _PatientReminders();
}

class _PatientReminders extends State<PatientReminders> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('Adjust Notifications'),

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