import 'package:cccare_wrist_monitor_app/tools/text_size_settings.dart';
import 'package:flutter/material.dart';

class PatientSettings extends StatefulWidget {
  const PatientSettings({super.key});

  @override
  State<PatientSettings> createState() => _PatientSettings();
}

class _PatientSettings extends State<PatientSettings> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: Text('Settings'),

        leading: BackButton(
            onPressed: () {
              Navigator.pop(context);
            }
        ),

        elevation: 10.0,
        shadowColor: Colors.black.withAlpha(255),
      ),

      body: Padding (

        padding: const EdgeInsets.all(16),

        child: TextField(

          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Text size multiplier (0.8 - 1.6)'),

          onSubmitted: (text) {

            final multiplier = double.tryParse(text);
            if (multiplier != null) {
              TextSizeSettings.setTextScale(multiplier);
            }

          }

        )

      )


    );
  }
}