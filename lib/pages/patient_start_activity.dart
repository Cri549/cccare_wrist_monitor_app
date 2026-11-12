import 'package:flutter/material.dart';

class PatientStartActivity extends StatefulWidget {
  const PatientStartActivity({super.key});

  @override
  State<PatientStartActivity> createState() => _PatientStartActivity();
}

class _PatientStartActivity extends State<PatientStartActivity> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('Daily Routine'),

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