import 'package:flutter/material.dart';

class PatientActivityLog extends StatefulWidget {
  const PatientActivityLog({super.key});

  @override
  State<PatientActivityLog> createState() => _PatientActivityLog();
}

class _PatientActivityLog extends State<PatientActivityLog> {

  final List<Map<String, dynamic>> players = [
    {'name': 'John Doe', 'streak': 21, 'isMe': false},
    {'name': 'John Doe', 'streak': 17, 'isMe': false},
    {'name': 'John Doe', 'streak': 16, 'isMe': false},
    {'name': 'John Doe', 'streak': 15, 'isMe': false},
    {'name': 'John Doe', 'streak': 14, 'isMe': false},
    {'name': 'John Doe', 'streak': 13, 'isMe': false},
    {'name': 'John Doe', 'streak': 12, 'isMe': false},
    {'name': 'John Doe', 'streak': 11, 'isMe': false},
    {'name': 'John Doe', 'streak': 10, 'isMe': false},
    {'name': 'John Doe', 'streak': 9, 'isMe': false},
    {'name': 'John Doe', 'streak': 8, 'isMe': false},
    {'name': 'John Doe', 'streak': 8, 'isMe': false},
    {'name': 'John Doe', 'streak': 8, 'isMe': false},
    {'name': 'John Doe', 'streak': 5, 'isMe': false},
    {'name': 'John Doe', 'streak': 3, 'isMe': false},
    {'name': 'John Doe', 'streak': 1, 'isMe': false},
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
            for (int i = 0; i < players.length; i++)
              Card(
                  child: ListTile(
                      leading: Text(
                        '#${i + 1}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),

                      trailing: Text(
                        '🔥 ${players[i]['streak']} days',
                        style: TextStyle(fontSize: 18),
                      )

                  )
              )

          ],

        )


    );
  }
}