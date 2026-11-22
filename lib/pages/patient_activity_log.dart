import 'package:flutter/material.dart';

class PatientActivityLog extends StatefulWidget {
  const PatientActivityLog({super.key});

  @override
  State<PatientActivityLog> createState() => _PatientActivityLog();
}

class _PatientActivityLog extends State<PatientActivityLog> {

  final List<Map<String, dynamic>> days = [
    {'name': '22 Nov. 2026', 'isDone': false},
    {'name': '21 Nov. 2026', 'isDone': true},
    {'name': '20 Nov. 2026', 'isDone': true},
    {'name': '19 Nov. 2026', 'isDone': true},
    {'name': '18 Nov. 2026', 'isDone': true},
    {'name': '17 Nov. 2026', 'isDone': false},
    {'name': '16 Nov. 2026', 'isDone': false},
    {'name': '15 Nov. 2026', 'isDone': true},
    {'name': '14 Nov. 2026', 'isDone': true},
    {'name': '13 Nov. 2026', 'isDone': true},
    {'name': '12 Nov. 2026', 'isDone': true},
    {'name': '11 Nov. 2026', 'isDone': false},
    {'name': '10 Nov. 2026', 'isDone': false},
    {'name': '9 Nov. 2026', 'isDone': true},
    {'name': '8 Nov. 2026', 'isDone': true},
    {'name': '7 Nov. 2026', 'isDone': true},
    {'name': '6 Nov. 2026', 'isDone': true},
    {'name': '5 Nov. 2026', 'isDone': false},
  ];

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

        body: ListView(
          padding: const EdgeInsets.all(16),

          children: [
            for (int i = 0; i < days.length; i++)
              Card(
                  child: ListTile(
                      leading: Text(
                        '${days[i]['name']}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),

                      trailing: Text(
                        'Completed: ${days[i]['isDone']}',
                        style: TextStyle(fontSize: 18),
                      )

                  )
              )

          ],

        )


    );
  }
}