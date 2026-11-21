// session_usage.dart
// Glue between the BLE helper and the logger. Not a full UI.

import 'package:flutter/foundation.dart';

import 'ble_helper.dart';
import 'session_logger.dart';

class SessionController {
  final ble = ExerciseBle();
  final logger = SessionLogger();

  // The UI listens to this. It is kept in sync with the ESP32 even across
  // reconnects (the ESP32 keeps a session running for a while if the app drops).
  final sessionRunning = ValueNotifier<bool>(false);

  // Live values shown in the UI. They are cleared whenever a new session starts.
  final reps = ValueNotifier<int>(0);
  final heartRate = ValueNotifier<double?>(null); // null = no reading yet
  final spo2 = ValueNotifier<double?>(null);

  LiveHSample hSample = LiveHSample(0, 0, 0);
  LiveRSample rSample = LiveRSample(0, 0);

  DateTime? _startedAt;
  bool _listening = false;

  // Set up listeners once, no matter how many times the user taps Connect.
  void _listen() {
    if (_listening) return;
    _listening = true;

    // Every time the ESP32 reports a finished session, log it.
    ble.summaryStream.listen((s) async {
      await logger.add(SessionRecord(
        startedAt: _startedAt ?? DateTime.now(),
        durationMs: s.durationMs,
        heartCount: s.heartCount,
        havg: s.havg,
        hmin: s.hmin,
        hmax: s.hmax,
        spCount: s.spCount,
        spavg: s.spavg,
        spmin: s.spmin,
        spmax: s.spmax,
        repCount: s.repCount,
        extra: {'exercise': 'knee extension'}, // customize
      ));
      _startedAt = null;
      sessionRunning.value = false;
    });

    // Live values for the UI.
    ble.liveRStream.listen((p) {
      rSample = p;
      reps.value = p.value;
    });
    ble.liveHStream.listen((p) {
      hSample = p;
      heartRate.value = p.hValue;
      spo2.value = p.spValue;
    });

    // After every (re)connect the ESP32 tells us whether a session is running.
    ble.deviceSessionStream.listen((active) {
      sessionRunning.value = active;
      if (active) _startedAt ??= DateTime.now();
    });

    // If we give up on reconnecting (or the user disconnects), nothing is running
    // from the app's point of view. The ESP32 drops its own session after its grace period.
    ble.statusStream.listen((s) {
      if (s == BleStatus.disconnected) sessionRunning.value = false;
    });
  }

  // Scan and connect. Safe to call again after a failure or a disconnect.
  Future<void> init() async {
    _listen();
    await ble.scanAndConnect();
  }

  // Clear everything the UI shows from the previous session.
  void _resetLive() {
    hSample = LiveHSample(0, 0, 0);
    rSample = LiveRSample(0, 0);
    reps.value = 0;
    heartRate.value = null;
    spo2.value = null;
  }

  Future<void> start() async {
    _resetLive();
    _startedAt = DateTime.now();
    await ble.startSession();
    sessionRunning.value = true;
  }

  // The summary arrives on summaryStream and is logged there.
  Future<void> stop() => ble.stopSession();

  Future<void> disconnect() => ble.disconnect();

  Future<String> reportForPhysio() => logger.toCsv();

  Future<void> dispose() async {
    await ble.dispose();
    sessionRunning.dispose();
    reps.dispose();
    heartRate.dispose();
    spo2.dispose();
  }
}

/*
 Platform setup

 Android (android/app/src/main/AndroidManifest.xml):
   <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
       android:usesPermissionFlags="neverForLocation" />
   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
   <!-- Android 11 and below also need: -->
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
       android:maxSdkVersion="30" />
   Request the runtime permissions (e.g. with permission_handler) before scanning.

 iOS (ios/Runner/Info.plist):
   <key>NSBluetoothAlwaysUsageDescription</key>
   <string>Connects to your exercise sensor.</string>
*/