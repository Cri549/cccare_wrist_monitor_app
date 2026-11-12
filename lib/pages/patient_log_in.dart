import 'package:flutter/material.dart';
import 'patient_main_menu.dart';

class PatientLogIn extends StatefulWidget {
  const PatientLogIn({super.key});

  @override
  State<PatientLogIn> createState() => _PatientLogIn();
}

class _PatientLogIn extends State<PatientLogIn> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('Log In'),

        leading: BackButton(
            onPressed: () {
              Navigator.pop(context);
            }
        ),

        elevation: 10.0,
        shadowColor: Colors.black.withAlpha(255),
      ),

      body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              children: [

              ]
            )

          )

      )


    );
  }
}