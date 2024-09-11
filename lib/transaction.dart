import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CashSummaryWidget extends StatefulWidget {
  final String companyId;
  final String site;
  final String companyName;
  final String email;
  final String phoneNumber;
  final String userName;

  CashSummaryWidget({
    required this.companyId,
    required this.site,
    required this.companyName,
    required this.email,
    required this.phoneNumber,
    required this.userName,
  });

  @override
  _CashSummaryWidgetState createState() => _CashSummaryWidgetState();
}

class _CashSummaryWidgetState extends State<CashSummaryWidget>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? cashSummary;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  bool isVisible = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0, 1),
    ).animate(_animationController);
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      fetchCashSummary();
    } else {
      _showError("Token is not available.");
    }
  }

  Future<void> fetchCashSummary() async {
    if (_token == null) {
      _showError("Token is not available.");
      return;
    }

    final now = DateTime.now();
    final String startDate = DateFormat('yyyy-MM-dd 00:00:00').format(now);
    final String endDate = DateFormat('yyyy-MM-dd 23:59:59').format(now);

    final url = Uri.parse(
        'https://stageapp.livecodesolutions.co.ke/api/CashSummary?Company=${widget.companyId}&site=${widget.site}&User=254723759494&Startdate=$startDate&Enddate=$endDate'
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          cashSummary = json.decode(response.body);
        });
        print('Fetched Cash Summary: $cashSummary');
      } else {
        _handleHttpError(response.statusCode);
      }
      if (response.body.isNotEmpty) {
        setState(() {
          cashSummary = json.decode(response.body);
        });
        print('Fetched Cash Summary: $cashSummary');
      } else {
        _showError("Empty response received.");
      }

    } catch (e) {
      _handleSpecificError(e);
    }
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
      errorMessage = "Data format error. Received invalid data: ${e.message}";
    } else if (e is Exception) {
      errorMessage = "An unexpected error occurred: $e";
    } else {
      errorMessage = "An unknown error occurred.";
    }
    _showError(errorMessage);
    print('Specific Error: $errorMessage');
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void toggleVisibility() {
    setState(() {
      if (isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
      isVisible = !isVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cash Summary'),
      ),
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0) {
            toggleVisibility(); // Dragging down hides
          } else {
            toggleVisibility(); // Dragging up shows
          }
        },
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.companyName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Email: ${widget.email}',
                        style: TextStyle(color: Colors.white),
                      ),
                      Text(
                        'Phone: ${widget.phoneNumber}',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: cashSummary == null || cashSummary!.isEmpty
                        ? Center(child: Text('No data available.'))
                        : ListView.builder(
                      itemCount: cashSummary?.length ?? 0,
                      itemBuilder: (context, index) {
                        String key = cashSummary!.keys.elementAt(index);
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(key),
                            subtitle: Text(cashSummary![key].toString()),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.grey[300],
                  child: Text(
                    cashSummary == null || cashSummary!.isEmpty
                        ? 'Amount total: 0.00'
                        : 'Amount total: ${calculateTotalAmount()}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double calculateTotalAmount() {
    if (cashSummary == null || cashSummary!.isEmpty) {
      return 0.00;
    }
    return cashSummary!.values.fold(0.00, (sum, item) {
      if (item is Map && item.containsKey('amount')) {
        return sum + (item['amount'] as num).toDouble();
      }
      return sum;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}