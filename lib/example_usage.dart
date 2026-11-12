// example_usage.dart
// Shows how the BLE helper and logger fit together. Not a full UI.

import 'ble_helper.dart';
import 'session_logger.dart';

class SessionController {
  final ble = ExerciseBle();
  final logger = SessionLogger();

  DateTime? _startedAt;

  Future<void> init() async {
    // Every time the ESP32 reports a finished session, log it.
    ble.summaryStream.listen((s) async {
      await logger.add(SessionRecord(
        startedAt: _startedAt ?? DateTime.now(),
        durationMs: s.durationMs,
        sampleCount: s.sampleCount,
        avg: s.avg,
        min: s.min,
        max: s.max,
        extra: {'exercise': 'knee extension'}, // customize
      ));
    });

    // Optional: live values for a chart.
    ble.liveStream.listen((p) => print('${p.msSinceStart} ms -> ${p.value}'));

    await ble.scanAndConnect();
  }

  Future<void> start() async {
    _startedAt = DateTime.now();
    await ble.startSession();
  }

  Future<void> stop() => ble.stopSession(); // summary arrives on summaryStream

  Future<String> reportForPhysio() => logger.toCsv();
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
