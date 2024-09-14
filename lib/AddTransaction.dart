import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sacco_app/paymentprint.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';



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
        title: const Text('Payment'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Handle info icon press
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3),
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
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Amount is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _commissionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Commission',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Commission is required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedPayment,
                    hint: const Text('Select Payment Mode'),
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null ? 'Payment mode is required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedTransactionType,
                    hint: const Text('Select Transaction Type'),
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null ? 'Transaction type is required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedVehicle,
                    hint: const Text('Select Vehicle'),
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null ? 'Vehicle is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ownerController,
                    decoration: const InputDecoration(
                      labelText: 'Owner ID',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _submitPayment,
                      child: const Text('Submit Payment'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final bookingDataToPrint = {
                        'RegNo': _selectedVehicle ?? 'RegNo',
                        'CollectionTypes': _selectedTransactionType ?? 'Code',
                        'Trandate': DateTime.now().toIso8601String(),
                        'TranType': _selectedTransactionType ?? 'Descr',
                        'Amount': double.tryParse(_amountController.text) ?? 0.0,
                        // Add any other parcel-specific details here
                      };

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrinterpaymentScreen(paymentData:bookingDataToPrint), // Pass the parcel data
                        ),
                      );
                    }, child: null,
                  ),

               ]
              ),
            ),
          ),
        ),
      ),
    );
  }
}