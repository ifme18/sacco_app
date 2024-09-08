import 'dart:convert'; // For json decoding
import 'package:flutter/material.dart'; // Flutter Material package
import 'package:http/http.dart' as http; // For HTTP requests
import 'package:shared_preferences/shared_preferences.dart'; // For shared preferences

// Base URL for your API
const String BASE_URL = 'https://stageapp.livecodesolutions.co.ke';
const String URL_GET_PARCEL = '$BASE_URL/api/Parcel?site={site}&Company={CompanyID}';
const String URL_VEHICLES = '$BASE_URL/api/Vehicles?Company={Company}';

// Model for Parcel
class Parcel {
  final double amount; // Amount
  final String senderName; // Sender's Name
  final String receiverName; // Receiver's Name
  final String companyCode; // Company Code

  Parcel({
    required this.amount,
    required this.senderName,
    required this.receiverName,
    required this.companyCode,
  });

  factory Parcel.fromJson(Map<String, dynamic> json) {
    return Parcel(
      amount: (json['Amount'] ?? 0.0).toDouble(), // Default to 0.0 if null or missing
      senderName: json['SenderName'] ?? '', // Default to empty string if null
      receiverName: json['Receivername'] ?? '', // Default to empty string if null
      companyCode: json['CompanyCode'] ?? '', // Default to empty string if null
    );
  }
}

// Model for Vehicle
class Vehicle {
  final String vehicleID;
  final String vehicleNo;

  Vehicle({required this.vehicleID, required this.vehicleNo});

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      vehicleID: json['RegNo'], // Adjust according to your API response
      vehicleNo: json['Owner'],  // Adjust according to your API response
    );
  }
}

// Function to get the token from shared preferences
Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token');
}

// Function to fetch parcels
Future<List<Parcel>> fetchParcels(String companyID, String site) async {
  final String finalUrl = URL_GET_PARCEL
      .replaceAll('{site}', site)
      .replaceAll('{CompanyID}', companyID);

  print("Fetching parcels from URL: $finalUrl");

  try {
    final String? token = await getToken(); // Get the Bearer token

    final response = await http.get(
      Uri.parse(finalUrl),
      headers: {
        'Authorization': 'Bearer $token', // Include the Bearer token
      },
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((parcel) => Parcel.fromJson(parcel)).toList();
    } else {
      print("Failed to load parcels: ${response.statusCode}");
      print("Response body: ${response.body}");
      throw Exception('Failed to load parcels');
    }
  } catch (error) {
    print("Error occurred while fetching parcels: $error");
    throw Exception('Error occurred while fetching parcels: $error');
  }
}

// Function to fetch vehicles
Future<List<Vehicle>> fetchVehicles(String companyID) async {
  final String finalUrl = URL_VEHICLES.replaceAll('{Company}', companyID);

  print("Fetching vehicles from URL: $finalUrl");

  try {
    final String? token = await getToken(); // Get the Bearer token

    final response = await http.get(
      Uri.parse(finalUrl),
      headers: {
        'Authorization': 'Bearer $token', // Include the Bearer token
      },
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((vehicle) => Vehicle.fromJson(vehicle)).toList();
    } else {
      print("Failed to load vehicles: ${response.statusCode}");
      throw Exception('Failed to load vehicles');
    }
  } catch (error) {
    print("Error occurred while fetching vehicles: $error");
    throw Exception('Error occurred while fetching vehicles: $error');
  }
}

// Function to attach a parcel with additional details
Future<void> attachParcel(Map<String, dynamic> parcelData) async {
  final String url = '$BASE_URL/api/AttachParcel';

  try {
    final String? token = await getToken(); // Get the Bearer token

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Include the Bearer token
      },
      body: json.encode(parcelData), // Send the entire JSON data
    );

    if (response.statusCode == 200) {
      print('Parcel attached successfully');
    } else {
      print("Failed to attach parcel: ${response.statusCode}");
      print("Response body: ${response.body}");
      throw Exception('Failed to attach parcel');
    }
  } catch (error) {
    print("Error occurred while attaching parcel: $error");
    throw Exception('Error occurred while attaching parcel: $error');
  }
}

// Main application
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parcel Vehicle Attachment',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ParcelScreen(companyID: 'your_company_id', site: 'your_site'),
    );
  }
}

class ParcelScreen extends StatefulWidget {
  final String companyID;
  final String site;

  ParcelScreen({required this.companyID, required this.site});

  @override
  _ParcelScreenState createState() => _ParcelScreenState();
}

class _ParcelScreenState extends State<ParcelScreen> {
  late Future<List<Parcel>> parcels;
  late Future<List<Vehicle>> vehicles;
  Map<String, String> selectedVehicles = {};

  @override
  void initState() {
    super.initState();
    parcels = fetchParcels(widget.companyID, widget.site);
    vehicles = fetchVehicles(widget.companyID);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Parcels"),
      ),
      body: FutureBuilder<List<Parcel>>(
        future: parcels,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return FutureBuilder<List<Vehicle>>(
            future: vehicles,
            builder: (context, vehicleSnapshot) {
              if (vehicleSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (vehicleSnapshot.hasError) {
                return Center(child: Text('Error: ${vehicleSnapshot.error}'));
              }

              final parcels = snapshot.data!;
              final vehicles = vehicleSnapshot.data!;

              return ListView.builder(
                itemCount: parcels.length,
                itemBuilder: (context, index) {
                  final parcel = parcels[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Amount: ${parcel.amount}"),
                          Text("Sender: ${parcel.senderName}"),
                          Text("Receiver: ${parcel.receiverName}"),
                          DropdownButton<String>(
                            value: selectedVehicles[parcel.senderName],
                            hint: Text("Select Vehicle"),
                            items: vehicles.map((Vehicle vehicle) {
                              return DropdownMenuItem<String>(
                                value: vehicle.vehicleID,
                                child: Text(vehicle.vehicleNo),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedVehicles[parcel.senderName] = newValue!;
                              });
                            },
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (selectedVehicles[parcel.senderName] != null) {
                                final parcelData = {
                                  'recid': 1, // or use the actual parcel ID
                                  'Amount': parcel.amount,
                                  'Valued': 1.0,
                                  'PaymentMode': 'sample string 2',
                                  'VehicleNo': selectedVehicles[parcel.senderName],
                                  'SendingOffice': 'sample string 4',
                                  'ReceivingOffice': 'sample string 5',
                                  'SenderName': parcel.senderName,
                                  'SenderTel': 'sample string 7',
                                  'Receivername': parcel.receiverName,
                                  'ReceiverTel': 'sample string 9',
                                  'DriverTel': 'sample string 10',
                                  'Descr': 'sample string 11',
                                  'Qty': 1.0,
                                  'Date': DateTime.now().toIso8601String(),
                                  'DateCaptured': DateTime.now().toIso8601String(),
                                  'SystemAdminName': 'sample string 12',
                                  'SystemAdmin': 'sample string 13',
                                  'Town': 'sample string 14',
                                  'Site': widget.site,
                                  'Rlsed': 1,
                                  'Confirmed': 1,
                                  'Attached': 1,
                                  'Delivered': 1,
                                  'DateDelivered': DateTime.now().toIso8601String(),
                                  'Collected': 1,
                                  'CollectedDate': DateTime.now().toIso8601String(),
                                  'CollectedBy': 'sample string 16',
                                  'CompanyID': widget.companyID,
                                  'ParcelID': parcel.senderName, // or use actual parcel ID
                                  'DateAttached': DateTime.now().toIso8601String(),
                                  'commission': 1.0,
                                };
                                attachParcel(parcelData)
                                    .then((_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Attached vehicle to parcel!'))
                                  );
                                }).catchError((error) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $error'))
                                  );
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Please select a vehicle')),
                                );
                              }
                            },
                            child: Text("Attach"),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}