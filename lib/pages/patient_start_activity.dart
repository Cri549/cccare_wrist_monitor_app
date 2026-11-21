import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cccare_wrist_monitor_app/ble_helper.dart';
import 'package:cccare_wrist_monitor_app/session_usage.dart'; // contains SessionController


class PatientStartActivity extends StatefulWidget {
  const PatientStartActivity({super.key});

  @override
  State<PatientStartActivity> createState() => _PatientStartActivity();
}

class _PatientStartActivity extends State<PatientStartActivity> {
  // One controller for the lifetime of this screen.
  final controller = SessionController();

  String? lastError;

  Future<void> _connect() async {
    setState(() => lastError = null);
    try {
      await controller.init(); // listeners are set up once; safe to repeat
    } catch (e, st) {
      debugPrint('CONNECT FAILED: $e\n$st');
      if (!mounted) return;
      setState(() => lastError = 'Connect failed: $e');
    }
  }

  Future<void> _toggleSession() async {
    try {
      if (controller.sessionRunning.value) {
        await controller.stop(); // summary is logged automatically
      } else {
        await controller.start();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String _statusText(BleStatus s) {
    switch (s) {
      case BleStatus.connected:
        return 'Sensor connected';
      case BleStatus.connecting:
        return 'Connecting...';
      case BleStatus.reconnecting:
        return 'Connection lost - reconnecting...';
      case BleStatus.disconnected:
        return 'Not connected';
    }
  }

  @override
  void dispose() {
    controller.dispose();
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
            StreamBuilder<BleStatus>(
              stream: controller.ble.statusStream,
              initialData: controller.ble.status,
              builder: (context, snap) {
                final status = snap.data ?? BleStatus.disconnected;
                final connected = status == BleStatus.connected;
                final canConnect = status == BleStatus.disconnected;
                final canDisconnect = connected || status == BleStatus.reconnecting;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusText(status)),
                    if (lastError != null && canConnect)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(lastError!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 12, children: [
                      ElevatedButton(
                        onPressed: canConnect ? _connect : null,
                        child: const Text('Connect'),
                      ),
                      ElevatedButton(
                        onPressed: canDisconnect ? controller.disconnect : null,
                        child: const Text('Disconnect'),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: controller.sessionRunning,
                        builder: (context, running, _) => ElevatedButton(
                          onPressed: connected ? _toggleSession : null,
                          child: Text(running ? 'Stop' : 'Start'),
                        ),
                      ),
                    ]),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            ListenableBuilder(
              listenable:
              Listenable.merge([controller.heartRate, controller.spo2]),
              builder: (context, _) {
                final hr = controller.heartRate.value;
                final sp = controller.spo2.value;
                return Text(
                  'Heart rate: ${hr == null ? '--' : '${hr.toStringAsFixed(0)} bpm'}   '
                      'SpO2: ${sp == null ? '--' : '${sp.toStringAsFixed(0)} %'}',
                );
              },
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: controller.reps,
              builder: (context, reps, _) => Text('Reps: $reps'),
            ),
          ],
        ),
      ),
    );
  }
}