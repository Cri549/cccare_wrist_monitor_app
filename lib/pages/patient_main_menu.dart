import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'patient_activity_log.dart';
import 'patient_prescription_viewer.dart';
import 'patient_settings.dart';
import 'patient_start_activity.dart';
import 'patient_messaging.dart';
import 'patient_reminders.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePage();
}

class _PatientHomePage extends State<PatientHomePage> {
  int _dailyStreak = 0;
  String _streakDisplay = "";

  void _incrementStreak(){
    setState(() {
      _dailyStreak++;
      _streakDisplay = _dailyStreak.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('CCCARE Home'),

        actions: [
          Text(_streakDisplay, style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Icon(Icons.local_fire_department_outlined),
          SizedBox(width: 12),
        ],

        elevation: 10.0,
        shadowColor: Colors.black.withAlpha(255),
      ),

      drawer: MenuDrawer(),

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Big "Start Daily Routine" button
              Expanded(
                flex: 3,
                child: HomePageButton(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Start Daily Routine',
                  iconSize: 64,
                  fontSize: 24,
                  onPressed: () {
                    _incrementStreak();
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Row 1:
              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    //Prescription Button
                    Expanded(
                      child: HomePageButton(
                        icon: Icons.description_outlined,
                        label: 'Prescription',
                        onPressed: () {

                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PatientPresriptionViewer()),
                          );

                        },

                      ),
                    ),
                    const SizedBox(width: 16),

                    //Exercise Logs Button
                    Expanded(
                      child: HomePageButton(
                        icon: Icons.calendar_month_outlined,
                        label: 'Exercise Logs',
                        onPressed: () {

                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PatientActivityLog()),
                          );

                        },

                      ),
                    ),


                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Row 2:

              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    //Reminder Button
                    Expanded(
                      child: HomePageButton(
                        icon: Icons.doorbell_rounded,
                        label: 'Reminders',
                        onPressed: () {

                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PatientReminders()),
                          );

                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    //Contact CCCARE Button
                    Expanded(
                      child: HomePageButton(
                        icon: Icons.person_outline,
                        label: 'Contact CCCARE',
                        onPressed: () {

                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PatientMessaging()),
                          );

                        },
                      ),
                    ),


                  ],
                ),
              ),


            ],
          ),

        ),

      ),


    );
  }
}

class MenuDrawer extends StatelessWidget {
  const MenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircleAvatar(
                radius: 40,
                child: Icon(Icons.person_outline, size: 48),
              ),
            ),
            ListTile(title: const Text('Account'), onTap: () {}),
            ListTile(title: const Text('Settings'), onTap: () {

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PatientSettings()),
                );

              }
            ),

            ListTile(title: const Text('Log Out'), onTap: () {
              Navigator.popUntil(context, (route) => route.isFirst);
              }
            ),

          ],

        ),

      ),

    );

  }
}


class HomePageButton extends StatelessWidget {
  const HomePageButton({
    super.key,
    this.icon,
    this.label,
    this.iconSize = 36,
    this.fontSize = 16,
    required this.onPressed,
  });

  final IconData? icon;
  final String? label;
  final double iconSize;
  final double fontSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 4,
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) Icon(icon, size: iconSize),
          if (icon != null && label != null) const SizedBox(height: 8),
          if (label != null)
            Text(
              label!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fontSize),
            ),
        ],
      ),
    );
  }
}