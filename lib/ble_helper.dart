// ble_helper.dart
//
// Thin wrapper around flutter_blue_plus for the ESP32 exercise sensor.
// pubspec.yaml:
//   flutter_blue_plus: ^1.35.0   (check pub.dev for the latest)

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// UUIDs must match the firmware.
class SensorUuids {
  static final service = Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');
  static final live = Guid('beb5483e-36e1-4688-b7f5-ea07361b26a8');
  static final control = Guid('beb5483e-36e1-4688-b7f5-ea07361b26a9');
  static final summary = Guid('beb5483e-36e1-4688-b7f5-ea07361b26aa');
}

// One live reading (10 Hz by default).
class LiveSample {
  final int msSinceStart;
  final double value;
  LiveSample(this.msSinceStart, this.value);
}

// Stats the ESP32 sends once when a session stops.
class SessionSummary {
  final int sampleCount;
  final int durationMs;
  final double avg;
  final double min;
  final double max;
  SessionSummary({
    required this.sampleCount,
    required this.durationMs,
    required this.avg,
    required this.min,
    required this.max,
  });
}

class ExerciseBle {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _control;
  final List<StreamSubscription> _subs = [];

  final _liveCtrl = StreamController<LiveSample>.broadcast();
  final _summaryCtrl = StreamController<SessionSummary>.broadcast();
  final _connCtrl =
      StreamController<BluetoothConnectionState>.broadcast();

  Stream<LiveSample> get liveStream => _liveCtrl.stream;
  Stream<SessionSummary> get summaryStream => _summaryCtrl.stream;
  Stream<BluetoothConnectionState> get connectionStream => _connCtrl.stream;

  bool get isConnected => _device?.isConnected ?? false;

  // Scan for the sensor (filtered by service UUID) and return the first hit.
  Future<BluetoothDevice> scanForSensor(
      {Duration timeout = const Duration(seconds: 10)}) async {
    final completer = Completer<BluetoothDevice>();

    final sub = FlutterBluePlus.onScanResults.listen((results) {
      if (results.isNotEmpty && !completer.isCompleted) {
        completer.complete(results.last.device);
      }
    });

    await FlutterBluePlus.startScan(
      withServices: [SensorUuids.service],
      timeout: timeout,
    );

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      throw Exception('Sensor not found');
    } finally {
      await sub.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  // Connect to a device, discover characteristics, subscribe to notifications.
  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    _device = device;

    _subs.add(device.connectionState.listen(_connCtrl.add));

    await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 15));

    final services = await device.discoverServices();
    final service =
        services.firstWhere((s) => s.uuid == SensorUuids.service);

    for (final c in service.characteristics) {
      if (c.uuid == SensorUuids.control) {
        _control = c;
      } else if (c.uuid == SensorUuids.live) {
        await c.setNotifyValue(true);
        _subs.add(c.onValueReceived.listen(_onLive));
      } else if (c.uuid == SensorUuids.summary) {
        await c.setNotifyValue(true);
        _subs.add(c.onValueReceived.listen(_onSummary));
      }
    }

    if (_control == null) {
      throw Exception('Control characteristic not found');
    }
  }

  // Convenience: scan + connect.
  Future<void> scanAndConnect() async => connect(await scanForSensor());

  Future<void> startSession() => _sendCommand(0x01);

  // Stop the session; the result arrives on [summaryStream].
  Future<void> stopSession() => _sendCommand(0x02);

  Future<void> _sendCommand(int cmd) async {
    final c = _control;
    if (c == null || !isConnected) throw Exception('Not connected');
    await c.write([cmd], withoutResponse: false);
  }

  Future<void> disconnect() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _control = null;
    await _device?.disconnect();
    _device = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _liveCtrl.close();
    await _summaryCtrl.close();
    await _connCtrl.close();
  }

  // ---- Packet parsing (little-endian) ----

  void _onLive(List<int> data) {
    if (data.length < 8) return;
    final b = ByteData.sublistView(Uint8List.fromList(data));
    _liveCtrl.add(LiveSample(
      b.getUint32(0, Endian.little),
      b.getFloat32(4, Endian.little),
    ));
  }

  void _onSummary(List<int> data) {
    if (data.length < 20) return;
    final b = ByteData.sublistView(Uint8List.fromList(data));
    _summaryCtrl.add(SessionSummary(
      sampleCount: b.getUint32(0, Endian.little),
      durationMs: b.getUint32(4, Endian.little),
      avg: b.getFloat32(8, Endian.little),
      min: b.getFloat32(12, Endian.little),
      max: b.getFloat32(16, Endian.little),
    ));
  }
}
