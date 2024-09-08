import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

const String BASE_URL = 'https://stageapp.livecodesolutions.co.ke';
const String URL_PAYMENT_MODE = '$BASE_URL/api/PaymentMode';

class ParcelEntryDialog extends StatefulWidget {
  final String CompanyCode;
  final String systemAdminName;
  final String systemAdmin;
  final String Site;

  ParcelEntryDialog({
    required this.CompanyCode,
    required this.systemAdminName,
    required this.systemAdmin,
    required this.Site,
  });

  @override
  _ParcelEntryDialogState createState() => _ParcelEntryDialogState();
}

class _ParcelEntryDialogState extends State<ParcelEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _commissionController;
  late TextEditingController _valuedController;
  late TextEditingController _sendingOfficeController;
  late TextEditingController _receivingOfficeController;
  late TextEditingController _senderNameController;
  late TextEditingController _senderTelController;
  late TextEditingController _receiverNameController;
  late TextEditingController _receiverTelController;
  late TextEditingController _driverTelController;
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _dateController;
  late TextEditingController _dateCapturedController;
  late TextEditingController _townController;
  late TextEditingController _dateAttachedController;
  late TextEditingController _dateDeliveredController;
  late TextEditingController _collectedByController;

  DateTime _selectedDate = DateTime.now();
  String _parcelId = '';
  String _recId = '';
  List<String> _paymentOptions = [];
  List<String> _siteOptions = [];
  String? _selectedPayment;
  String? _selectedSite;
  String? _token;

  BlueThermalPrinter printer = BlueThermalPrinter.instance;
  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _fetchTokenAndData();
    _parcelId = _generateParcelId();
    _recId = _generateRecId();
    _initializePrinter();
  }

  void _initializeControllers() {
    _amountController = TextEditingController();
    _commissionController = TextEditingController();
    _valuedController = TextEditingController();
    _sendingOfficeController = TextEditingController();
    _receivingOfficeController = TextEditingController();
    _senderNameController = TextEditingController();
    _senderTelController = TextEditingController();
    _receiverNameController = TextEditingController();
    _receiverTelController = TextEditingController();
    _driverTelController = TextEditingController();
    _descriptionController = TextEditingController();
    _quantityController = TextEditingController();
    _dateController = TextEditingController(text: _formatDate(DateTime.now()));
    _dateCapturedController = TextEditingController(text: _formatDate(DateTime.now()));
    _townController = TextEditingController();
    _dateAttachedController = TextEditingController(text: _formatDate(DateTime.now()));
    _dateDeliveredController = TextEditingController(text: _formatDate(DateTime.now()));
    _collectedByController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commissionController.dispose();
    _valuedController.dispose();
    _sendingOfficeController.dispose();
    _receivingOfficeController.dispose();
    _senderNameController.dispose();
    _senderTelController.dispose();
    _receiverNameController.dispose();
    _receiverTelController.dispose();
    _driverTelController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _dateController.dispose();
    _dateCapturedController.dispose();
    _townController.dispose();
    _dateAttachedController.dispose();
    _dateDeliveredController.dispose();
    _collectedByController.dispose();
    super.dispose();
  }

  Future<void> _fetchTokenAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      await _fetchSites();
      await _fetchPaymentMode();
    } else {
      _showError("Token is not available.");
    }
  }

  Future<void> _fetchPaymentMode() async {
    if (_token == null) return;

    try {
      final response = await http.get(
        Uri.parse(URL_PAYMENT_MODE),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _paymentOptions = data.map<String>((item) => item['PaymentMode'].toString()).toList();
        });
      }
    } catch (e) {
      print('Error: $e');
      _showError("An error occurred while fetching payment modes.");
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

  String _formatDate(DateTime date) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    return formatter.format(date);
  }

  String _generateParcelId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  String _generateRecId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _submitParcel() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final double amount = double.parse(_amountController.text);
    final double commission = double.parse(_commissionController.text);
    final parcelData = {
      'recid': _recId,
      'Amount': amount + commission,
      'Commission': commission,
      'Valued': double.parse(_valuedController.text),
      'PaymentMode': _selectedPayment ?? 'Code',
      'SendingOffice': _sendingOfficeController.text,
      'ReceivingOffice': _receivingOfficeController.text,
      'SenderName': _senderNameController.text,
      'SenderTel': _senderTelController.text,
      'ReceiverName': _receiverNameController.text,
      'ReceiverTel': _receiverTelController.text,
      'DriverTel': _driverTelController.text,
      'Descr': _descriptionController.text,
      'Qty': double.parse(_quantityController.text),
      'Date': _dateController.text,
      'DateCaptured': _dateCapturedController.text,
      'Town': _townController.text,
      'Site': _selectedSite ?? '',
      'DateAttached': _dateAttachedController.text,
      'DateDelivered': _dateDeliveredController.text,
      'CollectedBy': _collectedByController.text,
      'CompanyID': widget.CompanyCode,
      'ParcelID': _parcelId,
      'SystemAdminName': widget.systemAdminName,
      'SystemAdmin': widget.systemAdmin,
    };

    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/api/Parcel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(parcelData),
      );
      if (response.statusCode == 200) {
        _showSuccess("Parcel submitted successfully.");
        _showPrintDialog(parcelData);
      } else {
        print('Failed to submit parcel. Status: ${response.statusCode}');
        _showError("Failed to submit parcel. Status: ${response.statusCode}.");
      }
    } catch (e) {
      print('Error: $e');
      _showError("An error occurred. Please try again.");
    }
  }

  void _showSuccess(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Success"),
        content: Text(message),
        actions: [
          TextButton(
            child: Text("OK"),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            child: Text("OK"),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _initializePrinter() async {
    devices = await printer.getBondedDevices();
    setState(() {});
  }

  Future<void> _scanForDevices() async {
    setState(() {
      isScanning = true;
    });
    devices = await printer.getBondedDevices();
    setState(() {
      isScanning = false;
    });
  }

  Future<void> _connectToPrinter(BluetoothDevice device) async {
    try {
      await printer.connect(device);
      setState(() {
        selectedDevice = device;
      });
      _showSuccess("Connected to ${device.name}");
    } catch (e) {
      _showError("Failed to connect: $e");
    }
  }

  void _showPrintDialog(Map<String, dynamic> parcelData) {
    int copies = 1;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('Print Parcel'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Select a printer:'),
                    DropdownButton<BluetoothDevice>(
                      value: selectedDevice,
                      items: devices.map((device) {
                        return DropdownMenuItem(
                          value: device,
                          child: Text(device.name ?? ""),
                        );
                      }).toList(),
                      onChanged: (BluetoothDevice? value) {
                        setState(() {
                          selectedDevice = value;
                        });
                      },
                    ),
                    ElevatedButton(
                      onPressed: isScanning ? null : () async {
                        await _scanForDevices();
                        setState(() {});
                      },
                      child: Text(isScanning ? 'Scanning...' : 'Scan for printers'),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Number of copies:'),
                        DropdownButton<int>(
                          value: copies,
                          items: List.generate(5, (index) => index + 1).map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value.toString()),
                            );
                          }).toList(),
                          onChanged: (int? value) {
                            setState(() {
                              copies = value ?? 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text('Print'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (selectedDevice != null) {
                        _printParcel(parcelData, copies);
                      } else {
                        _showError("Please select a printer");
                      }
                    },
                  ),
                ],
              );
            }
        );
      },
    );
  }

  Future<void> _printParcel(Map<String, dynamic> parcelData, int copies) async {
    if (selectedDevice == null) {
      _showError("No printer selected. Please select a printer.");
      return;
    }

    try {
      await printer.connect(selectedDevice!);

      for (int i = 0; i < copies; i++) {
        if (i > 0) await Future.delayed(Duration(seconds: 1)); // Small delay between prints

        await printer.printNewLine();
        await printer.printCustom("Parcel Receipt", 3, 1);
        await printer.printNewLine();
        await printer.printCustom("Parcel ID: ${parcelData['ParcelID']}", 2, 0);
        await printer.printCustom("Town: ${parcelData['Town']}", 2, 0);
        await printer.printCustom("Amount Paid: ${parcelData['Amount']}", 2, 0);
        await printer.printCustom("Commission: ${parcelData['Commission']}", 2, 0);
        await printer.printCustom("Served by: ${parcelData['SystemAdminName']}", 2, 0);
        await printer.printCustom("Date: ${parcelData['Date']}", 2, 0);
        await printer.printNewLine();
        await printer.printCustom("Thank you for your business!", 2, 1);
        await printer.printNewLine();
        await printer.printNewLine();
        await printer.paperCut();
      }

      await printer.disconnect();
      _showSuccess("Printed $copies cop${copies > 1 ? 'ies' : 'y'} successfully");
    } catch (e) {
      _showError("Failed to print: $e");
    }
  }

  @override

  Widget build(BuildContext context) {
  return Scaffold(
  body: DraggableScrollableSheet(
  initialChildSize: 0.8,
  maxChildSize: 1.0,
  minChildSize: 0.4,
  builder: (BuildContext context, ScrollController scrollController) {
  return SingleChildScrollView(
  controller: scrollController,
  child: Container(
  padding: EdgeInsets.all(16.0),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(
  "Parcel Entry",
  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
  ),
  SizedBox(height: 16),
  Form(
  key: _formKey,
  child: Column(
  children: [
  _buildTextField(_amountController, "Amount", TextInputType.number),
  _buildTextField(_commissionController, "Commission", TextInputType.number),
  _buildTextField(_valuedController, "Valued", TextInputType.number),
  _buildDropdownField(_paymentOptions, _selectedPayment, "Payment Mode", (newValue) {
  setState(() {
  _selectedPayment = newValue;
  });
  }),
  _buildTextField(_sendingOfficeController, "Sending Office", TextInputType.text),
  _buildTextField(_receivingOfficeController, "Receiving Office", TextInputType.text),
  _buildTextField(_senderNameController, "Sender Name", TextInputType.text),
  _buildTextField(_senderTelController, "Sender Tel", TextInputType.phone),
  _buildTextField(_receiverNameController, "Receiver Name", TextInputType.text),
  _buildTextField(_receiverTelController, "Receiver Tel", TextInputType.phone),
  _buildTextField(_driverTelController, "Driver Tel", TextInputType.phone),
  _buildTextField(_descriptionController, "Description", TextInputType.text),
  _buildTextField(_quantityController, "Quantity", TextInputType.number),
  _buildDateField(_dateController, "Date", (newValue) {
  setState(() {
  _selectedDate = newValue;
  _dateController.text = _formatDate(newValue);
  });
  }),
  _buildDateField(_dateCapturedController, "Date Captured", (newValue) {
  setState(() {
  _dateCapturedController.text = _formatDate(newValue);
  });
  }),
  _buildTextField(_townController, "Town", TextInputType.text),
  _buildDropdownField(_siteOptions, _selectedSite, "Site", (newValue) {
  setState(() {
  _selectedSite = newValue;
  });
  }),
  _buildDateField(_dateAttachedController, "Date Attached", (newValue) {
  setState(() {
  _dateAttachedController.text = _formatDate(newValue);
  });
  }),
  _buildDateField(_dateDeliveredController, "Date Delivered", (newValue) {
  setState(() {
  _dateDeliveredController.text = _formatDate(newValue);
  });
  }),
  _buildTextField(_collectedByController, "Collected By", TextInputType.text),
  SizedBox(height: 20),
  Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
  ElevatedButton(
  onPressed: _submitParcel,
  child: Text("Submit"),
  ),
  ElevatedButton(
  onPressed: () {
  if (_formKey.currentState!.validate()) {
  final double amount = double.parse(_amountController.text);
  final double commission = double.parse(_commissionController.text);
  final parcelData = {
  'ParcelID': _parcelId,
  'Amount': amount + commission,
  'Commission': commission,
  'SystemAdminName': widget.systemAdminName,
  'Date': _dateController.text,
  'Town': _townController.text,
  };
  _showPrintDialog(parcelData);
  }
  },
  child: Text("Print"),
  ),
  ],
  ),
  ],
  ),
  ),
  ],
  ),
  ),
  );
  },
  ),
  );
  }

  Widget _buildTextField(TextEditingController controller, String label, TextInputType keyboardType) {
  return Padding(
  padding: const EdgeInsets.symmetric(vertical: 8.0),
  child: TextFormField(
  controller: controller,
  keyboardType: keyboardType,
  decoration: InputDecoration(
  labelText: label,
  border: OutlineInputBorder(),
  ),
  validator: (value) {
  if (value == null || value.isEmpty) {
  return 'Please enter $label';
  }
  return null;
  },
  ),
  );
  }

  Widget _buildDropdownField(List<String> options, String? selectedOption, String label, ValueChanged<String?> onChanged) {
  return Padding(
  padding: const EdgeInsets.symmetric(vertical: 8.0),
  child: DropdownButtonFormField<String>(
  value: selectedOption,
  onChanged: onChanged,
  decoration: InputDecoration(
  labelText: label,
  border: OutlineInputBorder(),
  ),
  items: options.map<DropdownMenuItem<String>>((String value) {
  return DropdownMenuItem<String>(
  value: value,
  child: Text(value),
  );
  }).toList(),
  validator: (value) {
  if (value == null || value.isEmpty) {
  return 'Please select $label';
  }
  return null;
  },
  ),
  );
  }

  Widget _buildDateField(TextEditingController controller, String label, ValueChanged<DateTime> onChanged) {
  return Padding(
  padding: const EdgeInsets.symmetric(vertical: 8.0),
  child: TextFormField(
  controller: controller,
  decoration: InputDecoration(
  labelText: label,
  border: OutlineInputBorder(),
  ),
  readOnly: true,
  onTap: () async {
  DateTime? pickedDate = await showDatePicker(
  context: context,
  initialDate: _selectedDate,
  firstDate: DateTime(2000),
  lastDate: DateTime(2101),
  );
  if (pickedDate != null) {
  onChanged(pickedDate);
  }
  },
  ),
  );
  }
}