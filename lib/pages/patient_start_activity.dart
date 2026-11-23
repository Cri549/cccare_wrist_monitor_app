import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // pubspec.yaml: share_plus: ^11.0.0 (or newer)

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

  // True between the user pressing Stop and the session being logged.
  bool _stopRequested = false;

  @override
  void initState() {
    super.initState();
    controller.sessionRunning.addListener(_onRunningChanged);
  }

  // The controller sets sessionRunning to false only AFTER the summary has been
  // written to the log, so the CSV is guaranteed to include the new session.
  void _onRunningChanged() {
    if (controller.sessionRunning.value || !_stopRequested) return;
    _stopRequested = false;

    // sessionRunning also goes false when the link drops; nothing was logged then.
    if (controller.ble.status == BleStatus.disconnected) return;
    if (!mounted) return;
    _showExportDialog();
  }

  Future<void> _showExportDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Session complete'),
        content: const Text(
            'Your session has been saved. What would you like to do with the data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _downloadData();
            },
            child: const Text('Download'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _sendToPhysician();
            },
            child: const Text('Send to physician'),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Phones: open the share sheet so the CSV can be saved to Files / Downloads.
  // Desktop: copy the CSV straight into the Downloads folder.
  Future<void> _downloadData() async {
    try {
      final csv = await controller.logger.exportCsvFile();

      if (Platform.isAndroid || Platform.isIOS) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(csv.path)],
            subject: 'Exercise session data',
          ),
        );
        return;
      }

      final dir = await getDownloadsDirectory();
      if (dir == null) throw Exception('Downloads folder not available');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final saved = await csv.copy('${dir.path}/sessions_export_$stamp.csv');
      _snack('Saved to ${saved.path}');
    } catch (e) {
      debugPrint('DOWNLOAD FAILED: $e');
      _snack('Could not save the data: $e');
    }
  }

  // Opens the share sheet (email, messaging, etc.) with the CSV attached.
  Future<void> _sendToPhysician() async {
    try {
      final csv = await controller.logger.exportCsvFile();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(csv.path)],
          subject: 'Exercise session report',
          text: 'Exercise session data from my wrist monitor app.',
        ),
      );
    } catch (e) {
      debugPrint('SEND FAILED: $e');
      _snack('Could not send the data: $e');
    }
  }

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
        _stopRequested = true; // dialog opens once the summary is logged
        await controller.stop();
      } else {
        await controller.start();
      }
    } catch (e) {
      _stopRequested = false;
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
    controller.sessionRunning.removeListener(_onRunningChanged);
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
                    Text(
                      'Rows', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87,)
                    ),

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