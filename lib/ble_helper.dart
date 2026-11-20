// ble_helper.dart
//
// Wrapper around flutter_blue_plus for the ESP32 exercise sensor, with
// automatic reconnection after an unexpected disconnect.
//
// pubspec.yaml:
//   flutter_blue_plus: ^2.x   (License.nonprofit)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// UUIDs must match the firmware (don't change them unless changed in firmware)
class SensorUuids {
  static const deviceName = 'ECE190ExerciseSensor';
  static final service = Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');
  static final liveR = Guid('beb5483e-36e1-4688-b7f5-ea07361b26a8');
  static final liveH = Guid('beb5483e-36e1-4688-b7f5-ea07361b26a9');
  static final control = Guid('beb5483e-36e1-4688-b7f5-ea07361b26aa');
  static final summary = Guid('beb5483e-36e1-4688-b7f5-ea07361b26ab');
  static final status = Guid('beb5483e-36e1-4688-b7f5-ea07361b26ac');
}

// Connection status as the UI should see it.
enum BleStatus { disconnected, connecting, connected, reconnecting }

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
  // ---- Settings ----
  bool autoReconnect = true;
  int maxReconnectAttempts = 10;

  // ---- Link state ----
  BluetoothDevice? _device;
  BluetoothDevice? _lastDevice; // remembered so we can reconnect directly
  BluetoothCharacteristic? _control;
  BluetoothCharacteristic? _statusChar;
  StreamSubscription? _connSub;
  final List<StreamSubscription> _charSubs = [];

  bool _linkUp = false; // true only after setup finished successfully
  bool _userDisconnected = false; // true after disconnect() was called by the app
  bool _reconnecting = false;
  int _loopToken = 0; // bumping this cancels a running reconnect loop

  BleStatus _status = BleStatus.disconnected;
  bool? _deviceSessionActive;

  // ---- Streams ----
  final _liveHCtrl = StreamController<LiveHSample>.broadcast();
  final _liveRCtrl = StreamController<LiveRSample>.broadcast();
  final _summaryCtrl = StreamController<SessionSummary>.broadcast();
  final _connCtrl = StreamController<BluetoothConnectionState>.broadcast();
  final _statusCtrl = StreamController<BleStatus>.broadcast();
  final _deviceSessionCtrl = StreamController<bool>.broadcast();

  Stream<LiveHSample> get liveHStream => _liveHCtrl.stream;
  Stream<LiveRSample> get liveRStream => _liveRCtrl.stream;
  Stream<SessionSummary> get summaryStream => _summaryCtrl.stream;
  Stream<BluetoothConnectionState> get connectionStream => _connCtrl.stream;

  // Connected / connecting / reconnecting / disconnected.
  Stream<BleStatus> get statusStream => _statusCtrl.stream;
  BleStatus get status => _status;

  // Fires after every (re)connect with whether the ESP32 says a session is
  // currently running, so the UI can resync.
  Stream<bool> get deviceSessionStream => _deviceSessionCtrl.stream;
  bool? get deviceSessionActive => _deviceSessionActive;

  bool get isConnected => _linkUp && (_device?.isConnected ?? false);

  void _setStatus(BleStatus s) {
    if (_status == s) return;
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  // Scan for the sensor and return the first match.
  Future<BluetoothDevice> scanForSensor(
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();

    final completer = Completer<BluetoothDevice>();
    final sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final adv = r.advertisementData;
        final match = adv.serviceUuids.contains(SensorUuids.service) ||
            adv.advName == SensorUuids.deviceName;
        debugPrint('scan: "${adv.advName}" ${r.device.remoteId} '
            'match=$match');
        if (match && !completer.isCompleted) completer.complete(r.device);
      }
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [SensorUuids.service],
        timeout: timeout,
      );
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      throw Exception('Sensor not found');
    } finally {
      await sub.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  // Connect to a specific device (user-initiated).
  Future<void> connect(BluetoothDevice device) async {
    _userDisconnected = false;
    _loopToken++; // cancel any reconnect loop in progress
    _setStatus(BleStatus.connecting);
    try {
      await _teardownLink();
      await _connectAndSetup(device, timeout: const Duration(seconds: 15));
    } catch (e) {
      await _teardownLink();
      _setStatus(BleStatus.disconnected);
      rethrow;
    }
  }

  // Scan + connect (user-initiated).
  Future<void> scanAndConnect() async {
    _userDisconnected = false;
    _loopToken++;
    _setStatus(BleStatus.connecting);
    try {
      await _attempt(tryDirect: false);
    } catch (e) {
      await _teardownLink();
      _setStatus(BleStatus.disconnected);
      rethrow;
    }
  }

  Future<void> startSession() => _sendCommand(0x01);

  // Stop the session; the result arrives on [summaryStream].
  Future<void> stopSession() => _sendCommand(0x02);

  // Disconnect on purpose. This also cancels any automatic reconnecting.
  Future<void> disconnect() async {
    _userDisconnected = true;
    _loopToken++;
    _linkUp = false;
    await _teardownLink();
    _setStatus(BleStatus.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _liveHCtrl.close();
    await _liveRCtrl.close();
    await _summaryCtrl.close();
    await _connCtrl.close();
    await _statusCtrl.close();
    await _deviceSessionCtrl.close();
  }

  // ------------------------------------------------------------------
  // Connecting / reconnecting internals
  // ------------------------------------------------------------------

  Future<void> _sendCommand(int cmd) async {
    if (!isConnected || _control == null) {
      throw StateError(_status == BleStatus.reconnecting
          ? 'Reconnecting to the sensor...'
          : 'Not connected');
    }
    await _control!.write([cmd], withoutResponse: false);
  }

  // One full connection attempt: optionally try the last known device
  // directly, otherwise scan and connect.
  Future<void> _attempt({required bool tryDirect}) async {
    await _teardownLink();

    final last = _lastDevice;
    if (tryDirect && last != null) {
      try {
        await _connectAndSetup(last, timeout: const Duration(seconds: 8));
        return;
      } catch (e) {
        debugPrint('Direct reconnect failed ($e), falling back to scan');
        await _teardownLink();
      }
    }

    final device = await scanForSensor();
    await _connectAndSetup(device, timeout: const Duration(seconds: 15));
  }

  // Connect, discover, subscribe, and sync the device's session state.
  // Throws on any failure; callers are responsible for tearing down.
  Future<void> _connectAndSetup(BluetoothDevice device,
      {required Duration timeout}) async {
    _device = device;
    _lastDevice = device;

    debugPrint('BLE: connecting to ${device.remoteId}');
    await device.connect(license: License.nonprofit, timeout: timeout);
    _connSub = device.connectionState.listen(_onConnState);

    final services =
    await device.discoverServices().timeout(const Duration(seconds: 15));
    final service = services.firstWhere(
          (s) => s.uuid == SensorUuids.service,
      orElse: () => throw Exception('Sensor service not found'),
    );

    for (final c in service.characteristics) {
      if (c.uuid == SensorUuids.control) {
        _control = c;
      } else if (c.uuid == SensorUuids.status) {
        _statusChar = c;
      } else if (c.uuid == SensorUuids.liveR) {
        _charSubs.add(c.onValueReceived.listen(_onRLive));
        await c.setNotifyValue(true);
      } else if (c.uuid == SensorUuids.liveH) {
        _charSubs.add(c.onValueReceived.listen(_onHLive));
        await c.setNotifyValue(true);
      } else if (c.uuid == SensorUuids.summary) {
        _charSubs.add(c.onValueReceived.listen(_onSummary));
        await c.setNotifyValue(true);
      }
    }

    if (_control == null) throw Exception('Control characteristic not found');
    if (!device.isConnected) throw Exception('Connection dropped during setup');

    await _syncDeviceStatus();

    _linkUp = true;
    _setStatus(BleStatus.connected);
    debugPrint('BLE: connected and ready');
  }

  // Ask the ESP32 whether a session is running (it may have kept running
  // while we were disconnected).
  Future<void> _syncDeviceStatus() async {
    final c = _statusChar;
    if (c == null) return; // older firmware without the Status characteristic
    try {
      final v = await c.read().timeout(const Duration(seconds: 5));
      final active = v.isNotEmpty && v[0] == 1;
      _deviceSessionActive = active;
      if (!_deviceSessionCtrl.isClosed) _deviceSessionCtrl.add(active);
      debugPrint('BLE: device session active = $active');
    } catch (e) {
      debugPrint('BLE: could not read status ($e)');
    }
  }

  void _onConnState(BluetoothConnectionState s) {
    if (!_connCtrl.isClosed) _connCtrl.add(s);

    // Only treat it as "link lost" if setup had finished; the stream also
    // reports the initial state while we are still connecting.
    if (s == BluetoothConnectionState.disconnected && _linkUp) {
      _linkUp = false;
      debugPrint('BLE: link lost (${_device?.disconnectReason})');
      _onLinkLost();
    }
  }

  void _onLinkLost() {
    for (final s in _charSubs) {
      s.cancel();
    }
    _charSubs.clear();
    _control = null;
    _statusChar = null;

    if (autoReconnect && !_userDisconnected) {
      _setStatus(BleStatus.reconnecting);
      unawaited(_reconnectLoop());
    } else {
      _setStatus(BleStatus.disconnected);
    }
  }

  Future<void> _reconnectLoop() async {
    if (_reconnecting) return;
    _reconnecting = true;
    final token = ++_loopToken;

    try {
      for (var attempt = 1; attempt <= maxReconnectAttempts; attempt++) {
        // Back off: 1 s, 2 s, 3 s, 4 s, then 5 s between attempts.
        await Future.delayed(Duration(seconds: attempt < 5 ? attempt : 5));
        if (token != _loopToken || _userDisconnected) return;

        debugPrint('BLE: reconnect attempt $attempt/$maxReconnectAttempts');
        try {
          await _attempt(tryDirect: attempt == 1);
          if (token != _loopToken) {
            // The app took over (connect/disconnect) while we were working.
            await _teardownLink();
          }
          return;
        } catch (e) {
          debugPrint('BLE: reconnect attempt $attempt failed: $e');
        }
      }

      if (token == _loopToken) {
        debugPrint('BLE: giving up reconnecting');
        await _teardownLink();
        _setStatus(BleStatus.disconnected);
      }
    } finally {
      _reconnecting = false;
    }
  }

  // Drop everything tied to the current connection (but keep _lastDevice).
  Future<void> _teardownLink() async {
    _linkUp = false;
    await _connSub?.cancel();
    _connSub = null;
    for (final s in _charSubs) {
      await s.cancel();
    }
    _charSubs.clear();
    _control = null;
    _statusChar = null;

    final d = _device;
    _device = null;
    if (d != null) {
      try {
        await d.disconnect().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('BLE: disconnect during teardown: $e');
      }
    }
  }

  // ------------------------------------------------------------------
  // Packet parsing (little-endian)
  // ------------------------------------------------------------------

  void _onHLive(List<int> data) {
    if (data.length < 12) return;
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
    if (data.length < 40) {
      debugPrint('Summary truncated to ${data.length} bytes (MTU too small?)');
      return;
    }
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