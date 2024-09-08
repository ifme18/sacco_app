import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

const String BASE_URL = 'https://stageapp.livecodesolutions.co.ke';
const String URL_PAYMENT = '$BASE_URL/api/lipafare';
const String URL_TRANSACTION_TYPES = '$BASE_URL/api/Trantype?Company={Company}';
const String URL_VEHICLES = '$BASE_URL/api/Vehicles?Company={Company}';
const String URL_PAYMENT_MODE = '$BASE_URL/api/PaymentMode';

class PaymentScreen extends StatefulWidget {
  final String userFullName;
  final String CompanyCode;
  final String CompanyName;
  final String Site;
  final String phone;

  PaymentScreen({
    required this.userFullName,
    required this.CompanyCode,
    required this.CompanyName,
    required this.Site,
    required this.phone,
  });

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _commissionController;
  late TextEditingController _ownerController;

  BlueThermalPrinter printer = BlueThermalPrinter.instance; // Instance of the Bluetooth printer
  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;

  String? _token;
  bool _isLoading = false;
  bool _isLoadingTransactionTypes = true;
  bool _isLoadingVehicles = true;
  bool _isLoadingPayment = true;
  List<dynamic> _Payment = [];
  List<dynamic> _transactionTypes = [];
  List<dynamic> _vehicles = [];
  String? _selectedPayment;
  String? _selectedTransactionType;
  String? _selectedVehicle;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadTokenAndCompanyDetails();
  }

  void _initializeControllers() {
    _amountController = TextEditingController();
    _commissionController = TextEditingController();
    _ownerController = TextEditingController();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _amountController.dispose();
    _commissionController.dispose();
    _ownerController.dispose();
  }

  Future<void> _loadTokenAndCompanyDetails() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');

    if (_token != null) {
      await Future.wait([
        _fetchVehicles(),
        _fetchTransactionTypes(),
        _fetchPaymentMode(),
      ]);
    } else {
      _showError("Token is not available.");
    }
  }

  Future<void> _fetchVehicles() async {
    if (_token == null) return;

    setState(() => _isLoadingVehicles = true);

    try {
      final url = URL_VEHICLES.replaceFirst('{Company}', widget.CompanyCode);
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _vehicles = data;
        });
      } else {
        _handleHttpError(response.statusCode);
      }
    } catch (e) {
      _handleSpecificError(e);
    } finally {
      setState(() => _isLoadingVehicles = false);
    }
  }

  Future<void> _fetchPaymentMode() async {
    if (_token == null) return;

    setState(() => _isLoadingPayment = true);

    try {
      final response = await http.get(
        Uri.parse(URL_PAYMENT_MODE),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() => _Payment = data);
      } else {
        _handleHttpError(response.statusCode);
      }
    } catch (e) {
      _handleSpecificError(e);
    } finally {
      setState(() => _isLoadingPayment = false);
    }
  }

  Future<void> _fetchTransactionTypes() async {
    if (_token == null) return;

    setState(() => _isLoadingTransactionTypes = true);

    try {
      final url = URL_TRANSACTION_TYPES.replaceFirst('{Company}', widget.CompanyCode);
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() => _transactionTypes = data);
      } else {
        _handleHttpError(response.statusCode);
      }
    } catch (e) {
      _handleSpecificError(e);
    } finally {
      setState(() => _isLoadingTransactionTypes = false);
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_token == null) {
      _showError("Token is not available.");
      return;
    }

    setState(() => _isLoading = true);

    final paymentData = {
      'recid': 1,
      'RegNo': _selectedVehicle ?? 'RegNo',
      'CollectionTypes': _selectedTransactionType ?? 'Code',
      'Trandate': DateTime.now().toIso8601String(),
      'TranType': _selectedTransactionType ?? 'Descr',
      'Amount': double.tryParse(_amountController.text) ?? 0.0,
      'Charges': double.tryParse(_commissionController.text) ?? 0.0,
      'CompanyID': widget.CompanyCode ?? 'sample string 6',
      'MemberID': _ownerController.text ?? 'sample string 8',
      'PaymentMode': _selectedPayment ?? 'PaymentMode',
      'rlsed': 0,
      'SystemAdmin': widget.phone ?? 'sample string 11',
      'SiteID': widget.Site ?? 'sample string 10',
    };

    try {
      final response = await http.post(
        Uri.parse(URL_PAYMENT),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(paymentData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccess("Payment submitted successfully!");
        await _printInvoice(); // Call print here if the response is 200 or 201
      } else {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final String errorMessage = responseBody['Message'] ?? 'Unknown error occurred';

        _handleHttpError(response.statusCode);
        print("Error: HTTP Status Code ${response.statusCode}");
        print("Error Message: $errorMessage");
        print("Response Body: ${response.body}");
      }
    } catch (e) {
      _handleSpecificError(e);
      print("Exception: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _printInvoice() async {
    if (selectedDevice == null) {
      _showError("No Bluetooth printer selected.");
      return;
    }

    try {
      // Attempt to connect to the selected Bluetooth printer
      await printer.connect(selectedDevice!);

      // Create a new ESC/POS printer profile
      final profile = await CapabilityProfile.load();
      final escPosPrinter = NetworkPrinter(PaperSize.mm80, profile);

      // Replace with your printer's IP address and port
      final String printerIp = "192.168.1.100"; // Replace with your printer's IP address
      final int port = 9100; // Default port for thermal printers

      final res = await escPosPrinter.connect(printerIp, port: port);

      if (res == PosPrintResult.success) {
        // Print the invoice content
        escPosPrinter.text('Company: ${widget.CompanyName}', styles: PosStyles(fontType: PosFontType.fontB, align: PosAlign.center));
        escPosPrinter.text('Vehicle: ${_selectedVehicle ?? 'N/A'}', styles: PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
        escPosPrinter.text('Amount Paid: ${_amountController.text}', styles: PosStyles(fontType: PosFontType.fontB, align: PosAlign.center));
        escPosPrinter.text('Commission: ${_commissionController.text}', styles: PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
        escPosPrinter.text('Served By: ${widget.userFullName}', styles: PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
        escPosPrinter.cut();
      } else {
        _showError("Could not connect to the printer. Please check the IP and port.");
      }
    } catch (e) {
      _showError("An error occurred while printing: $e");
    }
  }

  Future<void> _scanBluetoothDevices() async {
    try {
      devices = await printer.getBondedDevices();
      setState(() {});
    } catch (e) {
      _showError("Error scanning for Bluetooth devices: $e");
    }
  }

  Future<void> _selectPrinter(BuildContext context) async {
    selectedDevice = await showDialog<BluetoothDevice>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Bluetooth Printer'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(devices[index].name ?? ""),
                  onTap: () {
                    Navigator.of(context).pop(devices[index]);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _scanBluetoothDevices(); // Allow rescan
              },
              child: Text('Scan'),
            ),
          ],
        );
      },
    );

    if (selectedDevice != null) {
      _showSuccess("Selected printer: ${selectedDevice!.name}");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _handleHttpError(int statusCode) {
    String message = statusCode == 400
        ? "Bad request. Please check your input."
        : statusCode == 401 ? "Unauthorized. Please log in again."
        : "Something went wrong. Please try again.";
    _showError(message);
  }

  void _handleSpecificError(dynamic error) {
    String message = error is Exception ? error.toString() : "An error occurred.";
    _showError(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              // Handle info icon press
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            margin: EdgeInsets.all(16.0),
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Amount is required' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _commissionController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Commission',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Commission is required' : null,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedPayment,
                    hint: Text('Select Payment Mode'),
                    items: _Payment.map((payment) {
                      return DropdownMenuItem<String>(
                        value: payment['PaymentMode'],
                        child: Text(payment['PaymentMode']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPayment = value;
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null ? 'Payment mode is required' : null,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedTransactionType,
                    hint: Text('Select Transaction Type'),
                    items: _transactionTypes.map((transactionType) {
                      return DropdownMenuItem<String>(
                        value: transactionType['Code'],
                        child: Text(transactionType['Descr']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTransactionType = value;
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null ? 'Transaction type is required' : null,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedVehicle,
                    hint: Text('Select Vehicle'),
                    items: _vehicles.map((vehicle) {
                      return DropdownMenuItem<String>(
                        value: vehicle['RegNo'],
                        child: Text(vehicle['RegNo']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicle = value;

                        // Populate the owner ID field from the selected vehicle
                        final selectedVehicle = _vehicles.firstWhere((vehicle) => vehicle['RegNo'] == value);
                        _ownerController.text = selectedVehicle['Owner'] ?? 'N/A';
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null ? 'Vehicle is required' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _ownerController,
                    decoration: InputDecoration(
                      labelText: 'Owner ID',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    readOnly: true,
                  ),
                  SizedBox(height: 16),
                  if (_isLoading)
                    Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _submitPayment,
                      child: Text('Submit Payment'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _selectPrinter(context), // Opens the printer selection dialog
                    child: Text('Select Bluetooth Printer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}