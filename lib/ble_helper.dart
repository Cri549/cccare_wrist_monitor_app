// ble_helper.dart
//
// Thin wrapper around flutter_blue_plus for the ESP32 exercise sensor.
// pubspec.yaml:
//   flutter_blue_plus: ^1.35.0   (check pub.dev for the latest)

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// UUIDs must match the firmware.
class SensorUuids {
  static final service = Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');
  static final liveR = Guid('beb5483e-36e1-4688-b7f5-ea07361b26a8');
  static final liveH = Guid('beb5483e-36e1-4688-b7f5-ea07361b26a9');
  static final control = Guid('beb5483e-36e1-4688-b7f5-ea07361b26aa');
  static final summary = Guid('beb5483e-36e1-4688-b7f5-ea07361b26ab');
}

// One live reading (10 Hz by default).
class LiveRSample {
  final int msSinceStart;
  final int value;
  LiveRSample(this.msSinceStart, this.value);
}

class LiveHSample {
  final int msSinceStart;
  final double hValue, spValue;
  LiveHSample(this.msSinceStart, this.hValue, this.spValue);
}

// Stats the ESP32 sends once when a session stops.
class SessionSummary {
  final int durationMs;
  final int heartCount;
  final double havg;
  final double hmin;
  final double hmax;
  final int spCount;
  final double spavg;
  final double spmin;
  final double spmax;
  final int repCount;


  SessionSummary({
    required this.durationMs,
    required this.heartCount,
    required this.havg,
    required this.hmin,
    required this.hmax, 
    required this.spCount, 
    required this.spavg, 
    required this.spmin, 
    required this.spmax, 
    required this.repCount,
  });
}

class ExerciseBle {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _control;
  final List<StreamSubscription> _subs = [];

  final _liveHCtrl = StreamController<LiveHSample>.broadcast();
  final _liveRCtrl = StreamController<LiveRSample>.broadcast();
  final _summaryCtrl = StreamController<SessionSummary>.broadcast();
  final _connCtrl =
      StreamController<BluetoothConnectionState>.broadcast();

  Stream<LiveHSample> get liveHStream => _liveHCtrl.stream;
  Stream<LiveRSample> get liveRStream => _liveRCtrl.stream;
  Stream<SessionSummary> get summaryStream => _summaryCtrl.stream;
  Stream<BluetoothConnectionState> get connectionStream => _connCtrl.stream;

  bool get isConnected => _device?.isConnected ?? false;

  // Scan for the sensor (filtered by service UUID) and return the first hit.
  Future<BluetoothDevice> scanForSensor(
      {Duration timeout = const Duration(seconds: 10)}) async {
    final completer = Completer<BluetoothDevice>();

    // final sub = FlutterBluePlus.onScanResults.listen((results) {
    //   if (results.isNotEmpty && !completer.isCompleted) {
    //     completer.complete(results.last.device);
    //   }
    // });

    final sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        debugPrint('scan: "${r.advertisementData.advName}" '
            '${r.device.remoteId} svcs=${r.advertisementData.serviceUuids}');
        final match = r.advertisementData.serviceUuids.contains(SensorUuids.service) ||
            r.advertisementData.advName == 'ECE190ExerciseSensor';
        if (match && !completer.isCompleted) completer.complete(r.device);
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
      } else if (c.uuid == SensorUuids.liveR) {
        await c.setNotifyValue(true);
        _subs.add(c.onValueReceived.listen(_onRLive));
      } else if (c.uuid == SensorUuids.liveH) {
        await c.setNotifyValue(true);
        _subs.add(c.onValueReceived.listen(_onHLive));
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
    await _liveHCtrl.close();
    await _liveRCtrl.close();
    await _summaryCtrl.close();
    await _connCtrl.close();
  }

  // ---- Packet parsing (little-endian) ----
  // TODO: Update to add other sensor values

  void _onHLive(List<int> data) {
    if (data.length < 8) return;
    final b = ByteData.sublistView(Uint8List.fromList(data));
    _liveHCtrl.add(LiveHSample(
      b.getUint32(0, Endian.little),
      b.getFloat32(4, Endian.little),
      b.getFloat32(8, Endian.little),
    ));
  }

  void _onRLive(List<int> data) {
    if (data.length < 8) return;
    final b = ByteData.sublistView(Uint8List.fromList(data));
    _liveRCtrl.add(LiveRSample(
      b.getUint32(0, Endian.little),
      b.getUint32(4, Endian.little),
    ));
  }

  void _onSummary(List<int> data) {
    if (data.length < 20) return;
    final b = ByteData.sublistView(Uint8List.fromList(data));
    _summaryCtrl.add(SessionSummary(
      durationMs: b.getUint32(0, Endian.little),
      heartCount: b.getUint32(4, Endian.little),
      havg: b.getFloat32(8, Endian.little),
      hmin: b.getFloat32(12, Endian.little),
      hmax: b.getFloat32(16, Endian.little),
      spCount: b.getUint32(20, Endian.little),
      spavg: b.getFloat32(24, Endian.little),
      spmin: b.getFloat32(28, Endian.little),
      spmax: b.getFloat32(32, Endian.little),
      repCount: b.getUint32(36, Endian.little),
    ));
  }
}
