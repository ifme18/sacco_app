

import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'dart:async';

class PrinterbookingScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData; // Accept parcel data to print

  PrinterbookingScreen({Key? key, required this.bookingData}) : super(key: key);

  @override
  _PrinterScreenState createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterbookingScreen> {
  PrinterManager printerManager = PrinterManager.instance;
  List<PrinterDevice> devices = [];
  PrinterDevice? selectedPrinter;
  bool isScanning = false;
  bool isConnected = false;
  StreamSubscription<PrinterDevice>? _subscription;

  @override
  void initState() {
    super.initState();
    _startScanDevices();
  }

  void _startScanDevices() {
    setState(() {
      isScanning = true;
      devices.clear();
    });

    _subscription?.cancel();
    _subscription = printerManager.discovery(type: PrinterType.bluetooth).listen((device) {
      setState(() {
        devices.add(device);
      });
    }, onDone: () {
      setState(() {
        isScanning = false;
      });
    });

    // Optionally stop scanning after a certain duration.
    Future.delayed(Duration(seconds: 10), () {
      _stopScanDevices();
    });
  }

  void _stopScanDevices() {
    _subscription?.cancel();
    setState(() {
      isScanning = false;
    });
  }

  Future<void> _connectToPrinter(PrinterDevice printer) async {
    if (isConnected) {
      await printerManager.disconnect(type: PrinterType.bluetooth);
    }
    try {
      BluetoothPrinterInput bluetoothInput = BluetoothPrinterInput(
        name: printer.name ?? '',
        address: printer.address ?? '',
      );

      await printerManager.connect(
        type: PrinterType.bluetooth,
        model: bluetoothInput,
      );

      setState(() {
        selectedPrinter = printer;
        isConnected = true;
      });

      print('Connected to printer: ${printer.name}');
      await printParcelDetails(); // Automatically print after connecting
    } catch (e) {
      print('Failed to connect to printer: $e');
      _showError("Failed to connect to printer: $e");
    }
  }

  Future<void> printParcelDetails() async {
    if (selectedPrinter == null) {
      showError("No printer selected. Please select a printer.");
      return;
    }

    // Prepare the content to print
    String printContent = '''
Parcel Receipt
------------------------------
Parcel ID: ${widget.bookingData['ParcelID']}
Amount Paid: ${widget.bookingData['Amount']}
Commission: ${widget.bookingData['Commission']}
Sender: ${widget.bookingData['SenderName']}
Receiver: ${widget.bookingData['ReceiverName']}
Date: ${widget.bookingData['Date']}
------------------------------
Thank you for using our service!
''';

    try {
      // Assuming your printerManager has a method to print raw text.
      // Example of sending raw text data to the printer:
      final bytes = printContent.codeUnits; // Convert to byte array
      await printerManager.send(type: PrinterType.bluetooth, bytes: bytes); // Send to printer

      _showSuccess("Printing Successful");
    } catch (e) {
      showError("Failed to print: $e");
    }
  }
  void showError(String message) {
    // Implement this method to show an error message to the user
    // For example:
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void showSuccess(String message) {
    // Implement this method to show a success message to the user
    // For example:
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }


  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            child: Text("OK"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Success"),
        content: Text(message),
        actions: [
          TextButton(
            child: Text("OK"),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Close the PrinterScreen after printing
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Printer Selection'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(devices[index].name ?? ''),
                  subtitle: Text(devices[index].address ?? ''),
                  onTap: () async {
                    await _connectToPrinter(devices[index]);
                  },
                );
              },
            ),
          ),
          if (isScanning)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          ElevatedButton(
            onPressed: isScanning ? _stopScanDevices : _startScanDevices,
            child: Text(isScanning ? "Stop Scanning" : "Scan for Printers"),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context); // Go back to the previous screen
        },
        child: Icon(Icons.close),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    printerManager.disconnect(type: PrinterType.bluetooth); // Disconnect from the printer
    super.dispose();
  }
}