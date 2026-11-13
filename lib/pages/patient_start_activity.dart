import 'package:flutter/material.dart';

class PatientStartActivity extends StatefulWidget {
  const PatientStartActivity({super.key});

  @override
  State<PatientStartActivity> createState() => _PatientStartActivity();
}

class _PatientStartActivity extends State<PatientStartActivity> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('Daily Routine'),

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
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [

                Expanded(

                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Routine',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 12),
                        const Text('- Rows'),
                        const Text('- Placeholder'),
                        const Text('- Placeholder'),
                        const Text('- Placeholder'),
                        const Text('- Placeholder'),
                        const Text('- Placeholder'),
                        const Text('- Placeholder'),
                        const Text('- Placeholder'),
                        const Text('- Placeholder'),
                        const Text('- Placeholder'),
                        const Text('- Hello!'),


                      ],
                    ),
                  ),

                ),

                const SizedBox(height: 12),

                // Static part: always at the bottom
                SizedBox(
                  height: 60,

                  child: ElevatedButton(
                    onPressed: () {
                      // start the activity
                    },
                    child: const Text('Start Activity', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ]

            )

          )

      )


    );
  }
}