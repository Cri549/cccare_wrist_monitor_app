import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';

class DeviceData {
    double heartrate;
    // TODO: define data that will be logged
    DeviceData(
        this.heartrate
    );

    void update(){
        
    }
}


class BluetoothService {
  final FlutterBluetoothClassic _bluetooth = FlutterBluetoothClassic();
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<BluetoothData>? _dataSubscription;
  StreamSubscription<BluetoothState>? _stateSubscription;

  // Check if Bluetooth is supported
  Future<bool> isBluetoothSupported() async {
    try {
      return await _bluetooth.isBluetoothSupported();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Bluetooth support: $e');
      }
      return false;
    }
  }

  // Check if Bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      return await _bluetooth.isBluetoothEnabled();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Bluetooth status: $e');
      }
      return false;
    }
  }

  // Get paired devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await _bluetooth.getPairedDevices();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting paired devices: $e');
      }
      return [];
    }
  }

  // Setup event listeners
  void setupListeners() {
    // Listen for Bluetooth state changes
    _stateSubscription = _bluetooth.onStateChanged.listen((state) {
      if (kDebugMode) {
        print('Bluetooth state: ${state.isEnabled ? "enabled" : "disabled"}');
      }
    });

    // Listen for connection state changes
    _connectionSubscription = _bluetooth.onConnectionChanged.listen((
      connectionState,
    ) {
      if (connectionState.isConnected) {
        if (kDebugMode) {
          print('Connected to ${connectionState.deviceAddress}');
        }
      } else {
        if (kDebugMode) {
          print('Disconnected: ${connectionState.status}');
        }
      }
    });

    // Listen for incoming data
    _dataSubscription = _bluetooth.onDataReceived.listen((data) {
      String received = data.asString();
      print('Received from ${data.deviceAddress}: $received');
    });
  }

  // Connect to a device
  Future<bool> connectToDevice(String deviceAddress) async {
    try {
      return await _bluetooth.connect(deviceAddress);
    } catch (e) {
      if (kDebugMode) {
        print('Connection failed: $e');
      }
      return false;
    }
  }

  // Send string data
  Future<bool> sendMessage(String message) async {
    try {
      return await _bluetooth.sendString(message);
    } catch (e) {
      if (kDebugMode) {
        print('Send failed: $e');
      }
      return false;
    }
  }

  // Send raw data
  Future<bool> sendData(List<int> data) async {
    try {
      return await _bluetooth.sendData(data);
    } catch (e) {
      if (kDebugMode) {
        print('Send failed: $e');
      }
      return false;
    }
  }

  // Disconnect
  Future<bool> disconnect() async {
    try {
      return await _bluetooth.disconnect();
    } catch (e) {
      if (kDebugMode) {
        print('Disconnect failed: $e');
      }
      return false;
    }
  }

  // Start device discovery
  Future<bool> startDiscovery() async {
    try {
      return await _bluetooth.startDiscovery();
    } catch (e) {
      if (kDebugMode) {
        print('Discovery failed: $e');
      }
      return false;
    }
  }

  // Stop device discovery
  Future<bool> stopDiscovery() async {
    try {
      return await _bluetooth.stopDiscovery();
    } catch (e) {
      if (kDebugMode) {
        print('Stop discovery failed: $e');
      }
      return false;
    }
  }

  // Clean up resources
  void dispose() {
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    _stateSubscription?.cancel();
  }
}
