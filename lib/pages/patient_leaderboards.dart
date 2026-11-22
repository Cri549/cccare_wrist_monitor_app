import 'package:flutter/material.dart';
import 'patient_main_menu.dart';

class Leaderboard extends StatefulWidget {
  const Leaderboard({super.key});

  @override
  State<Leaderboard> createState() => _Leaderboard();
}

class _Leaderboard extends State<Leaderboard> {

  final List<Map<String, dynamic>> players = [
    {'name': 'John Doe', 'streak': 21, 'isMe': false},
    {'name': 'Jane Doe', 'streak': 17, 'isMe': false},
    {'name': 'Ellen Joe', 'streak': 16, 'isMe': false},
    {'name': 'Lucy', 'streak': 15, 'isMe': false},
    {'name': 'Vivian', 'streak': 14, 'isMe': false},
    {'name': 'Evelyn', 'streak': 13, 'isMe': false},
    {'name': 'Charlotte', 'streak': 12, 'isMe': false},
    {'name': 'Jean', 'streak': 11, 'isMe': false},
    {'name': 'Ben', 'streak': 10, 'isMe': false},
    {'name': 'Kafka', 'streak': 9, 'isMe': false},
    {'name': 'Robin', 'streak': 8, 'isMe': false},
    {'name': 'Alice', 'streak': 8, 'isMe': false},
    {'name': 'Billy', 'streak': 8, 'isMe': false},
    {'name': 'Nicole', 'streak': 5, 'isMe': false},
    {'name': 'Seth', 'streak': 3, 'isMe': false},
    {'name': 'Bernice', 'streak': 1, 'isMe': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('Leaderboard'),

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
                  '#${i + 1} ${players[i]['name']}',
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