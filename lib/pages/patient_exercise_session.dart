import 'package:flutter/material.dart';

class PatientActivityLog extends StatefulWidget {
  const PatientActivityLog({super.key});

  @override
  State<PatientActivityLog> createState() => _PatientActivityLog();
}

class _PatientActivityLog extends State<PatientActivityLog> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('Activity Log'),

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