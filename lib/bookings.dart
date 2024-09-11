
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';


const String BASE_URL = 'https://stageapp.livecodesolutions.co.ke';
const String URL_VEHICLES = '$BASE_URL/api/Vehicles?Company={Company}';
const String URL_PAYMENT_MODE = '$BASE_URL/api/PaymentMode';
const String URL_BOOK_TICKET = '$BASE_URL/api/Tickets';
const String URL_TICKET = '$BASE_URL/api/Tickets?site={{site}}&Company={{CompanyID}}';

class BusTicketWidget extends StatefulWidget {
  final String userFullName;
  final String CompanyCode;
  final String City;
  final String Site;
  final String phone;

  BusTicketWidget({
    required this.userFullName,
    required this.CompanyCode,
    required this.City,
    required this.Site,
    required this.phone,
  });

  @override
  _BusTicketWidgetState createState() => _BusTicketWidgetState();
}

class _BusTicketWidgetState extends State<BusTicketWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _locationController;
  late TextEditingController _destinationController;
  late TextEditingController _amountController;
  late TextEditingController _commissionedAmountController;
  late TextEditingController _passangerNOController;
  late TextEditingController _passengerNameController;
  late TextEditingController _seatNoController;
  late TextEditingController _extrachargeController;
  late TextEditingController _phoneController;

  List<dynamic> _vehicles = [];
  List<dynamic> _Payment = [];
  List<dynamic> _siteOptions = [];
  String? _selectedVehicle;
  String? _selectedPayment;
  String? _selectedSite;
  String? _TicketNumber = '';
  String? _token;
  bool _hasFetchedVehicles = false;
  bool _isLoadingVehicles = false;
  bool _isLoadingPayment = false;

  PrinterBluetoothManager printerManager = PrinterBluetoothManager();
  List<PrinterBluetooth> devices = [];
  PrinterBluetooth? selectedPrinter;
  bool isScanning = false;


  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadToken();
    _initializePrinter();
  }

  void _initializeControllers() {
    _locationController = TextEditingController();
    _destinationController = TextEditingController();
    _amountController = TextEditingController();
    _commissionedAmountController = TextEditingController();
    _passangerNOController = TextEditingController();
    _passengerNameController = TextEditingController();
    _seatNoController = TextEditingController();
    _extrachargeController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _locationController.dispose();
    _destinationController.dispose();
    _amountController.dispose();
    _commissionedAmountController.dispose();
    _passangerNOController.dispose();
    _passengerNameController.dispose();
    _seatNoController.dispose();
    _extrachargeController.dispose();
    _phoneController.dispose();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    print('Loaded token: $_token');

    if (_token != null) {
      await _fetchVehicles();
      await _fetchPaymentMode();
      await _fetchTicketNumber();
      await _fetchSites();
    } else {
      _showError("Token is not available.");
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

  Future<void> _fetchSites() async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/api/Site?Company=${widget.CompanyCode}&Site=${widget.Site}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          _siteOptions = data
              .map<String>((item) => item['Site'].toString())
              .where((site) => site != widget.Site)
              .toList();

          if (_selectedSite != null && !_siteOptions.contains(_selectedSite)) {
            _selectedSite = null;
          }
        });
      } else {
        print('Failed to fetch sites. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      _showError("An error occurred while fetching sites.");
    }
  }

  Future<void> _fetchTicketNumber() async {
    if (_token == null) return;

    try {
      final url = URL_TICKET
          .replaceFirst('{{site}}', widget.Site)
          .replaceFirst('{{CompanyID}}', widget.CompanyCode);

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseBody = jsonDecode(response.body);

        if (responseBody.isNotEmpty && responseBody[0] is Map<String, dynamic>) {
          _TicketNumber = responseBody[0]['TicketNo'] ?? 'Not available';
        } else {
          _TicketNumber = 'No invoice number available';
        }
      } else {
        _handleHttpError(response.statusCode);
        _TicketNumber = 'Failed to fetch invoice number';
      }
    } catch (e) {
      _handleSpecificError(e);
      _TicketNumber = 'Error occurred while fetching invoice number';
    }
  }

  Future<void> _fetchVehicles() async {
    if (_token == null) {
      _showError("Token is not available.");
      return;
    }

    if (_hasFetchedVehicles) return;

    setState(() {
      _isLoadingVehicles = true;
    });

    try {
      final url = URL_VEHICLES.replaceFirst('{Company}', widget.CompanyCode);
      print('Fetching vehicles from: $url');
      print('Authorization Token: $_token');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      print('Fetching vehicles process complete with status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Fetched vehicles data: $data');

        if (data.isEmpty) {
          _showError("No vehicles found.");
        } else {
          setState(() {
            _vehicles = data;
            _hasFetchedVehicles = true;
          });
        }
      } else {
        _handleHttpError(response.statusCode);
      }
    } catch (e) {
      print('Error fetching vehicles: $e');
      _handleSpecificError(e);
    } finally {
      setState(() {
        _isLoadingVehicles = false;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_token == null || widget.CompanyCode.isEmpty) {
        _showError("Token or Company Code is not available.");
        return;
      }

      final body = {
        'recid': 0,
        'TicketID': _TicketNumber ?? 'sample string 2',
        'Amount': double.tryParse(_amountController.text) ?? 0.0,
        'commission': double.tryParse(_commissionedAmountController.text) ?? 0.0,
        'PaymentMode': _selectedPayment ?? 'sample string 3',
        'VehicleNo': _selectedVehicle ?? 'sample string 4',
        'SendingOffice': _locationController.text,
        'ReceivingOffice': _destinationController.text,
        'PassengerName': _passengerNameController.text,
        'PassengerTel': _passangerNOController.text,
        'sitNo': _seatNoController.text,
        'dateOfTravel': DateTime.now().toIso8601String(),
        'DateOfIssue': DateTime.now().toIso8601String(),
        'TimeOfTravel': DateTime.now().toIso8601String(),
        'Date': DateTime.now().toIso8601String(),
        'SystemAdminName': widget.userFullName,
        'SystemAdmin': _phoneController.text,
        'Town': widget.City,
        'Site': _selectedSite,
        'Rlsed': 1,
        'Confirmed': 1,
        'Attached': 1,
        'DateAttached': DateTime.now().toIso8601String(),
        'CompanyID': widget.CompanyCode,
      };

      print('Submitting ticket with body: $body');
      print('Using token: $_token');

      try {
        final response = await http.post(
          Uri.parse(URL_BOOK_TICKET),
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        print('Ticket submission process complete with status code: ${response.statusCode}');

        if (response.statusCode == 200) {
          _showSuccess("Ticket booked successfully.");
          print("Ticket booking was successful.");

          // Call the print function after successful booking
          await _printTicket();
        } else {
          _handleHttpError(response.statusCode);
        }
      } catch (e) {
        print('Error during ticket submission: $e');
        _handleSpecificError(e);
      }
    }
  }

  void _initializePrinter() {
    printerManager.scanResults.listen((devices) {
      setState(() {
        this.devices = devices;
      });
    });
  }
  Future<void> _scanBluetoothDevices() async {
    setState(() {
      isScanning = true;
    });
    printerManager.startScan(Duration(seconds: 4));
    await Future.delayed(Duration(seconds: 4));
    setState(() {
      isScanning = false;
    });
  }

  Future<void> _printTicket() async {
    // Show dialog to select Bluetooth printer
    selectedPrinter = await showDialog<PrinterBluetooth>(
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
                _scanBluetoothDevices();
              },
              child: Text('Scan'),
            ),
          ],
        );
      },
    );

    if (selectedPrinter == null) {
      _showError("No Bluetooth printer selected.");
      return;
    }

    try {
      // Generate ESC/POS commands
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);

      List<int> bytes = [];

      // Add ticket details to print
      bytes += generator.text("Company: ${widget.CompanyCode}", styles: PosStyles(align: PosAlign.center, height: PosTextSize.size2));
      bytes += generator.text("Vehicle: $_selectedVehicle", styles: PosStyles(align: PosAlign.center));
      bytes += generator.text("Amount Paid: ${_amountController.text}", styles: PosStyles(align: PosAlign.center));
      bytes += generator.text("Served By: ${widget.userFullName}", styles: PosStyles(align: PosAlign.center));
      bytes += generator.text("Customer Care: ${widget.phone}", styles: PosStyles(align: PosAlign.center));

      bytes += generator.feed(2);
      bytes += generator.cut();

      // Select printer and print ticket
      printerManager.selectPrinter(selectedPrinter!); // No need to await here
      final result = await printerManager.printTicket(bytes);
      print("Print result: $result");
      _showSuccess("Ticket printed successfully");
    } catch (e) {
      _showError("An error occurred while printing: $e");
    }
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleHttpError(int statusCode) {
    String errorMessage;
    switch (statusCode) {
      case 400:
        errorMessage = "Bad request. Please check your request parameters.";
        break;
      case 401:
        errorMessage = "Unauthorized. Please check your authentication token.";
        break;
      case 403:
        errorMessage = "Forbidden. You don't have permission to access this resource.";
        break;
      case 404:
        errorMessage = "Not found. The requested resource could not be found.";
        break;
      case 500:
        errorMessage = "Internal server error. Please try again later.";
        break;
      default:
        errorMessage = "Unexpected error occurred. Status Code: $statusCode";
    }
    _showError(errorMessage);
    print('HTTP Error: $errorMessage');
  }

  void _handleSpecificError(Object e) {
    String errorMessage;
    if (e is http.ClientException) {
      errorMessage = "Network error. Please check your internet connection.";
    } else if (e is FormatException) {
      errorMessage = "Data format error. Received invalid data.";
    } else if (e is Exception) {
      errorMessage = "An unexpected error occurred: $e";
    } else {
      errorMessage = "An unknown error occurred.";
    }
    _showError(errorMessage);
    print('Specific Error: $errorMessage');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book Bus Ticket'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_isLoadingVehicles)
                  CircularProgressIndicator()
                else
                  DropdownButtonFormField<String>(
                    value: _selectedVehicle,
                    hint: Text('Select Vehicle (Optional)'),
                    items: _vehicles
                        .map<DropdownMenuItem<String>>(
                          (vehicle) => DropdownMenuItem<String>(
                        value: vehicle['RegNo'],
                        child: Text(vehicle['RegNo']),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicle = value;
                      });
                    },
                  ),
                if (_isLoadingPayment)
                  CircularProgressIndicator()
                else
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
                DropdownButtonFormField<String>(
                  value: _selectedSite,
                  hint: Text('Select Site'),
                  items: _siteOptions.map((site) {
                    return DropdownMenuItem<String>(
                      value: site,
                      child: Text(site),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSite = value;
                    });
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null ? 'Site selection is required' : null,
                ),

                SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter the location' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _destinationController,
                  decoration: InputDecoration(
                    labelText: 'Destination',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter the destination' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    return amount == null ? 'Please enter a valid amount' : null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _commissionedAmountController,
                  decoration: InputDecoration(
                    labelText: 'Commissioned Amount',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    return amount == null ? 'Please enter a valid commissioned amount' : null;
                  },
                ),

                SizedBox(height: 16),
                TextFormField(
                  controller: _passengerNameController,
                  decoration: InputDecoration(
                    labelText: 'Passenger Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter the passenger name' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _seatNoController,
                  decoration: InputDecoration(
                    labelText: 'Seat No',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter the seat number' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter the phone number' : null,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitForm,
                  child: Text('Submit'),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _scanBluetoothDevices,
                  child: Text('Scan for Bluetooth Printers'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}