import 'dart:convert'; // For JSON decoding
import 'package:flutter/material.dart'; // Flutter Material package
import 'package:http/http.dart' as http; // For HTTP requests
import 'package:shared_preferences/shared_preferences.dart'; // For storing and retrieving token

// Base URL for your API
const String BASE_URL = 'https://stageapp.livecodesolutions.co.ke';

// Endpoints
const String URL_COLLECTED_PARCELS = '$BASE_URL/api/ParcelCollected?Company={Company}&site={site}&User={}&Status=Incoming';
const String URL_COLLECTED = '$BASE_URL/api/ParcelCollected/{id}';
const String URL_DELIVERED = '$BASE_URL/api/ParcelDelivered/{id}';

// Model for Parcel
class Parcel {
  final String parcelID;
  final double amount;
  final String senderName;
  final String receiverName;
  final String companyCode;

  Parcel({
    required this.parcelID,
    required this.amount,
    required this.senderName,
    required this.receiverName,
    required this.companyCode,
  });

  factory Parcel.fromJson(Map<String, dynamic> json) {
    return Parcel(
      parcelID: json['ParcelID'] ?? '',
      amount: (json['Amount'] ?? 0.0).toDouble(),
      senderName: json['SenderName'] ?? 'Unknown',
      receiverName: json['ReceiverName'] ?? 'Unknown',
      companyCode: json['CompanyCode'] ?? '',
    );
  }
}

// Fetch the token from SharedPreferences
Future<String> _getToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    throw Exception('Token not found');
  }
  return token;
}

// Function to fetch collected parcels
Future<List<Parcel>> fetchCollectedParcels(String companyID, String site) async {
  final token = await _getToken();
  final response = await http.get(
    Uri.parse(URL_COLLECTED_PARCELS
        .replaceAll('{Company}', companyID)
        .replaceAll('{site}', site)),
    headers: {
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((parcel) => Parcel.fromJson(parcel)).toList();
  } else {
    print('Error fetching collected parcels: ${response.statusCode} ${response.body}');
    throw Exception('Failed to load collected parcels');
  }
}

// Function to mark a parcel as collected
Future<void> markAsCollected(String parcelID) async {
  final token = await _getToken();
  final response = await http.put(
    Uri.parse(URL_COLLECTED.replaceAll('{id}', parcelID)),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    // Successfully marked as collected
  } else {
    print('Error marking parcel as collected: ${response.statusCode} ${response.body}');
    throw Exception('Failed to mark parcel as collected');
  }
}

// Function to mark a parcel as delivered
Future<void> markAsDelivered(String parcelID) async {
  final token = await _getToken();
  final response = await http.put(
    Uri.parse(URL_DELIVERED.replaceAll('{id}', parcelID)),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    // Successfully marked as delivered
  } else {
    print('Error marking parcel as delivered: ${response.statusCode} ${response.body}');
    throw Exception('Failed to mark parcel as delivered');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parcel Collection and Delivery',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CollectedParcelsScreen(companyID: 'your_company_id', site: 'your_site'),
    );
  }
}

class CollectedParcelsScreen extends StatefulWidget {
  final String companyID;
  final String site;

  CollectedParcelsScreen({required this.companyID, required this.site});

  @override
  _CollectedParcelsScreenState createState() => _CollectedParcelsScreenState();
}

class _CollectedParcelsScreenState extends State<CollectedParcelsScreen> {
  late Future<List<Parcel>> collectedParcels;
  Map<String, bool> collectedStatus = {};
  Map<String, bool> deliveredStatus = {};

  @override
  void initState() {
    super.initState();
    collectedParcels = fetchCollectedParcels(widget.companyID, widget.site);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Collected Parcels"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: FutureBuilder<List<Parcel>>(
        future: collectedParcels,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No parcels found'));
          }

          final parcels = snapshot.data!;

          return ListView.builder(
            itemCount: parcels.length,
            itemBuilder: (context, index) {
              final parcel = parcels[index];

              return Container(
                margin: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? Colors.amber[100] : Colors.lightGreen[100],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Parcel ID: ${parcel.parcelID}"),
                    Text("Amount: ${parcel.amount}"),
                    Text("Sender: ${parcel.senderName}"),
                    Text("Receiver: ${parcel.receiverName}"),
                    Row(
                      children: [
                        Checkbox(
                          value: collectedStatus[parcel.parcelID] ?? false,
                          onChanged: (bool? value) {
                            setState(() {
                              collectedStatus[parcel.parcelID] = value!;
                            });
                            if (value!) {
                              markAsCollected(parcel.parcelID).then((_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Parcel marked as collected')),
                                );
                              }).catchError((error) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $error')),
                                );
                              });
                            }
                          },
                        ),
                        Text('Collected'),
                        Checkbox(
                          value: deliveredStatus[parcel.parcelID] ?? false,
                          onChanged: (bool? value) {
                            setState(() {
                              deliveredStatus[parcel.parcelID] = value!;
                            });
                            if (value!) {
                              markAsDelivered(parcel.parcelID).then((_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Parcel marked as delivered')),
                                );
                              }).catchError((error) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $error')),
                                );
                              });
                            }
                          },
                        ),
                        Text('Delivered'),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

void main() => runApp(MyApp());
