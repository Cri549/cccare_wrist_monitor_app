import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    show BluetoothConnectionState;

import 'package:cccare_wrist_monitor_app/ble_helper.dart';
import 'package:cccare_wrist_monitor_app/session_usage.dart'; // contains SessionController

class PatientStartActivity extends StatefulWidget {
  const PatientStartActivity({super.key});

  @override
  State<PatientStartActivity> createState() => _PatientActivityLog();
}

class _PatientActivityLog extends State<PatientStartActivity> {
  // One controller for the lifetime of this screen.
  final controller = SessionController();

  String status = 'Not connected';
  bool busy = false;
  bool sessionRunning = false;

  Future<void> _connect() async {
    setState(() {
      busy = true;
      status = 'Scanning...';
    });
    try {
      await controller.init(); // sets up listeners + scanAndConnect()
      if (!mounted) return;
      setState(() => status = 'Connected');
    } catch (e, st) {
      debugPrint('CONNECT FAILED: $e\n$st');
      if (!mounted) return;
      setState(() => status = 'Connect failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggleSession() async {
    try {
      if (sessionRunning) {
        await controller.stop(); // summary is logged automatically
      } else {
        await controller.start();
      }
      if (!mounted) return;
      setState(() => sessionRunning = !sessionRunning);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    controller.ble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        title: const Text('Activity Log'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        elevation: 10.0,
        shadowColor: Colors.black.withAlpha(255),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<BluetoothConnectionState>(
              stream: controller.ble.connectionStream,
              initialData: BluetoothConnectionState.disconnected,
              builder: (context, snap) {
                final connected =
                    snap.data == BluetoothConnectionState.connected;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(connected ? 'Sensor connected' : status),
                    const SizedBox(height: 12),
                    Row(children: [
                      ElevatedButton(
                        onPressed: (busy || connected) ? null : _connect,
                        child: const Text('Connect'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: connected ? _toggleSession : null,
                        child: Text(sessionRunning ? 'Stop' : 'Start'),
                      ),
                    ]),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            StreamBuilder<LiveHSample>(
              stream: controller.ble.liveHStream,
              builder: (context, snap) {
                final s = snap.data;
                return Text(s == null
                    ? 'Heart rate / SpO2: --'
                    : 'Heart rate: ${s.hValue.toStringAsFixed(0)} bpm   '
                    'SpO2: ${s.spValue.toStringAsFixed(0)} %');
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<LiveRSample>(
              stream: controller.ble.liveRStream,
              builder: (context, snap) =>
                  Text('Reps: ${snap.data?.value ?? 0}'),
            ),
          ],
        ),
      ),
    );
  }
}