/*
 * flutter_esc_pos_blue
 * Created by Onur Bulut
 * 
 * Copyright (c) 2022. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue/flutter_blue.dart';
// ignore: depend_on_referenced_packages
import 'package:rxdart/rxdart.dart' as rx;
import './enums.dart';

/// Bluetooth printer
class PrinterBluetooth {
  PrinterBluetooth(this._device);
  final BluetoothDevice _device;

  String get name => _device.name;
  String get address => _device.id.id;
  int get type => _device.type.index;
}

/// Printer Bluetooth Manager
class PrinterBluetoothManager {
  final FlutterBlue _flutterBlue = FlutterBlue.instance;
  bool _isPrinting = false;
  bool _isConnected = false;

  late StreamSubscription _scanResultsSubscription;
  late StreamSubscription _isScanningSubscription;
  PrinterBluetooth? _selectedPrinter;

  final rx.BehaviorSubject<bool> _isScanning = rx.BehaviorSubject.seeded(false);
  Stream<bool> get isScanningStream => _isScanning.stream;

  final rx.BehaviorSubject<List<PrinterBluetooth>> _scanResults =
      rx.BehaviorSubject.seeded([]);
  Stream<List<PrinterBluetooth>> get scanResults => _scanResults.stream;

  void startScan(Duration timeout) async {
    _scanResults.add(<PrinterBluetooth>[]);

    _flutterBlue.startScan(timeout: timeout);

    _scanResultsSubscription = _flutterBlue.scanResults.listen((devices) {
      _scanResults.add(devices.map((d) => PrinterBluetooth(d.device)).toList());
    });

    _isScanningSubscription =
        _flutterBlue.isScanning.listen((isScanningCurrent) async {
      // If isScanning value changed (scan just stopped)
      if (_isScanning.value! && !isScanningCurrent) {
        _scanResultsSubscription.cancel();
        _isScanningSubscription.cancel();
      }
      _isScanning.add(isScanningCurrent);
    });
  }

  void stopScan() async {
    await _flutterBlue.stopScan();
  }

  void selectPrinter(PrinterBluetooth printer) {
    _selectedPrinter = printer;
  }

  Future<void> disconnect() async {
    await _selectedPrinter!._device.disconnect();
    _isPrinting = false;
  }

  Future<PosPrintResult> writeBytes(
    List<int> bytes, {
    int chunkSizeBytes = 20,
    int queueSleepTimeMs = 20,
  }) async {
    final Completer<PosPrintResult> completer = Completer();

    if (_selectedPrinter == null) {
      debugPrint(1.toString());
      return Future<PosPrintResult>.value(PosPrintResult.printerNotSelected);
    } else if (_isScanning.value!) {
      debugPrint(2.toString());
      return Future<PosPrintResult>.value(PosPrintResult.scanInProgress);
    } else if (_isPrinting) {
      debugPrint(3.toString());
      return Future<PosPrintResult>.value(PosPrintResult.printInProgress);
    } else {
      completer.complete(PosPrintResult.print);
    }

    _isPrinting = true;
    bool isFirst = true;
    bool isFinish = false;
    // We have to rescan before connecting, otherwise we can connect only once

    // Connect
    if (!_isConnected) {
      await _selectedPrinter!._device.connect();
      _isConnected = true;
    }
    final len = bytes.length;
    List<List<int>> chunks = [];
    for (var i = 0; i < len; i += chunkSizeBytes) {
      var end = (i + chunkSizeBytes < len) ? i + chunkSizeBytes : len;
      chunks.add(bytes.sublist(i, end));
    }

    if (_isConnected) {
      List<BluetoothService> services =
          await _selectedPrinter!._device.discoverServices();
      for (BluetoothService service in services) {
        List<BluetoothCharacteristic> characteristics = service.characteristics;
        for (BluetoothCharacteristic characteristic in characteristics) {
          if (isFirst) {
            for (var i = 0; i < chunks.length; i += 1) {
              try {
                await characteristic.write(chunks[i], withoutResponse: true);
                await characteristic.read();
                isFirst = false;
                isFinish = true;
              } catch (e) {
                break;
              }
            }
            if (isFinish) {
              _isPrinting = false;
              _isConnected = false;
              await _selectedPrinter!._device.disconnect();
            }
          }
        }
      }
    }

    return completer.future;
  }

  Future<PosPrintResult> printTicket(
    List<int>? bytes, {
    int chunkSizeBytes = 20,
    int queueSleepTimeMs = 20,
  }) async {
    if (bytes == null || bytes.isEmpty) {
      return Future<PosPrintResult>.value(PosPrintResult.ticketEmpty);
    }
    return writeBytes(
      bytes,
      chunkSizeBytes: chunkSizeBytes,
      queueSleepTimeMs: queueSleepTimeMs,
    );
  }
}


















  /*
    _selectedPrinter._device.state.listen((state)async {
      switch(state){
        case BluetoothDeviceState.connected :
          final len = bytes.length;
          List<List<int>> chunks = [];
          for (var i = 0; i < len; i += chunkSizeBytes) {
            var end = (i + chunkSizeBytes < len) ? i + chunkSizeBytes : len;
            chunks.add(bytes.sublist(i, end));
          }

          if (_isConnected) {
            List<BluetoothService> services = await _selectedPrinter._device.discoverServices();
            for(BluetoothService service in services){
              List<BluetoothCharacteristic> characteristics = service.characteristics;
              for(BluetoothCharacteristic characteristic in characteristics){
                if(isFirst){
                  for (var i = 0; i < chunks.length; i += 1) {
                    try {
                      await characteristic.write(chunks[i], withoutResponse: true);
                      await characteristic.read();
                      isFirst = false;
                      _isFinish = true;
                    } catch (e) {
                      break;
                    }
                  }
                  if(_isFinish){
                    _isPrinting = false;
                    _isConnected = false;
                    await _selectedPrinter._device.disconnect();
                  }
                }
              }

            }

            /*
            _selectedPrinter._device.services.listen((event) async {
              _bluetoothServices = event;
              for (BluetoothService bluetoothService in _bluetoothServices) {

                List<BluetoothCharacteristic> characteristics = bluetoothService
                    .characteristics;
                for (BluetoothCharacteristic characteristic in characteristics) {
                  if(isFirst){
                    for (var i = 0; i < chunks.length; i += 1) {
                      try {
                        await characteristic.write(chunks[i], withoutResponse: true);
                        await characteristic.read();
                        isFirst = false;
                        _isFinish = true;
                      } catch (e) {
                        break;
                      }
                    }
                    if(_isFinish){
                      _isPrinting = false;
                      _isConnected = false;
                      await _selectedPrinter._device.disconnect();
                    }
                  }
                }
              }
            });

             */
          }

          break;
        case BluetoothDeviceState.disconnected :
          _isConnected = false;
          break;
        default:
          break;

      }
    });

     */