import 'package:flutter/material.dart';

class PatientMessaging extends StatefulWidget {
  const PatientMessaging({super.key});

  @override
  State<PatientMessaging> createState() => _PatientMessaging();
}

class _PatientMessaging extends State<PatientMessaging> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('Message CCCARE'),

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