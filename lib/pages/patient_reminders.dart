import 'package:flutter/material.dart';
import 'main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PatientReminders extends StatefulWidget {
  const PatientReminders({super.key});

  @override
  State<PatientReminders> createState() => _PatientReminders();
}

class _PatientReminders extends State<PatientReminders> {
  final notifications = FlutterLocalNotificationsPlugin();
  int minHour = 0;
  int maxHour = 23;
  int minMin = 0;
  int maxMin = 59;
  int notifHour = 0;
  int notifMin = 0;

  @override
  void initState() {
    super.initState();
    notifications.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _sendNotification() {
    notifications.show(
      id: 0,
      title: 'Time to do your daily exercise',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('reminders', 'Reminders',
            importance: Importance.high, priority: Priority.high),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('Adjust Notifications'),

        leading: BackButton(
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        elevation: 10.0,
        shadowColor: Colors.black.withAlpha(255),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter notification hour (0 - 23)',
              ),
              onSubmitted: (text) {
                final hour = int.tryParse(text);
                if (hour != null) {
                  setState(() {
                    notifHour = hour.clamp(minHour, maxHour);
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter notification minute (0 - 59)',
              ),
              onSubmitted: (text) {
                final minute = int.tryParse(text);
                if (minute != null) {
                  setState(() {
                    notifMin = minute.clamp(minMin, maxMin);
                  });
                }
              },
            ),
            const SizedBox(height: 20),


            Text(
              'Reminder set for ${notifHour.toString().padLeft(2, '0')}:${notifMin.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 100,
              child: SelectionButton(
                label: 'Send notification',
                onPressed: () {
                  _sendNotification();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
