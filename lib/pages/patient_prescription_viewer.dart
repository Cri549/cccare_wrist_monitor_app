import 'package:flutter/material.dart';

class PatientPresriptionViewer extends StatefulWidget {
  const PatientPresriptionViewer({super.key});

  @override
  State<PatientPresriptionViewer> createState() => _PatientPresriptionViewer();
}

class _PatientPresriptionViewer extends State<PatientPresriptionViewer> {

  final List<String> items = [
    'Hamstring Stretch',
    'Calf Stretch',
    'Cat-Cow Stretch',
    'Upper-trap Stretch',
    '10 Pushups',
    '20 Stepups',
  ];

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



      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(
                  'For Today: '
                  , style: TextStyle(fontSize: 26, fontWeight:FontWeight.bold),
              ),

              for (final i in items)

                Text('- $i', style: TextStyle(fontSize: 20)),


            ],


          ),

        ),

      ),



    );
  }
}