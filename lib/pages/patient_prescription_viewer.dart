import 'package:flutter/material.dart';

class PatientPresriptionViewer extends StatefulWidget {
  const PatientPresriptionViewer({super.key});

  @override
  State<PatientPresriptionViewer> createState() => _PatientPresriptionViewer();
}

class _PatientPresriptionViewer extends State<PatientPresriptionViewer> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('Your Prescription'),

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