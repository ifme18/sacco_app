import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Parcel.dart';
import 'bookings.dart';
import 'transaction.dart';
import 'AddTransaction.dart';

// Token Storage Helper Class
class TokenStorage {
  static const _tokenKey = 'auth_token';

  // Save the token to SharedPreferences
  static Future<void> saveToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Retrieve the token from SharedPreferences
  static Future<String?> getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Remove the token from SharedPreferences
  static Future<void> removeToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}

class HomeScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String site;
  final String phone;
  final Map<String, dynamic> saccoDetails;
  final String userFullName;

  HomeScreen({
    required this.userId,
    required this.userName,
    required this.site,
    required this.phone,
    required this.saccoDetails,
    required this.userFullName,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _widgetOptions = []; // Initialize with an empty list

  @override
  void initState() {
    super.initState();
    _initializeWidgets();
  }

  Future<void> _initializeWidgets() async {
    try {
      // Retrieve the token from TokenStorage
      final token = await TokenStorage.getToken() ?? ''; // Provide default value if token is null

      // Initialize the widgets with the token
      setState(() {
        _widgetOptions = <Widget>[
          PaymentScreen(
            userFullName: widget.userFullName,
            CompanyCode: widget.saccoDetails['CompanyCode'],
            CompanyName: widget.saccoDetails['CompanyName'],
            Site: widget.site,
            phone: widget.phone,
          ),
          ParcelEntryDialog(
            CompanyCode: widget.saccoDetails['CompanyCode'],
            systemAdminName: widget.userFullName,
            systemAdmin: widget.userName,
            Site: widget.site,
          ),

          BusTicketWidget(
            userFullName: widget.userFullName,
            CompanyCode: widget.saccoDetails['CompanyCode'],
            City: widget.saccoDetails['City'],
            Site: widget.site,
            phone: widget.phone,
          ),
          CashSummaryWidget(
            companyId: widget.saccoDetails['CompanyCode'],
            site: widget.site,
            companyName: widget.saccoDetails['CompanyName'],
            email: widget.saccoDetails['Email'],
            phoneNumber: widget.phone,
            userName: widget.userName,
          )
        ];
      });
    } catch (e) {
      print('Error initializing widgets: $e');
      // Optionally handle the error or show a message to the user
      setState(() {
        _widgetOptions = <Widget>[Center(child: Text('Failed to load widgets.'))];
      });
    }
  }

  void _onItemTapped(int index) {
    if (index >= 0 && index < _widgetOptions.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String saccoName = widget.saccoDetails['CompanyName'] ?? 'Company Name';
    String userName = widget.userFullName;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $userName',
              style: TextStyle(fontSize: 20),
            ),
            Text(
              saccoName,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.cyanAccent,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.cyanAccent,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(0);
              },
            ),
            ListTile(
              leading: Icon(Icons.local_activity),
              title: Text('Parcelss'),
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(1);
              },
            ),
            ListTile(
              leading: Icon(Icons.local_shipping),
              title: Text('Ticket Booking'),
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(2);
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet),
              title: Text('Transactions'),
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(3);
              },
            ),
          ],
        ),
      ),
      body: _widgetOptions.isEmpty
          ? Center(child: CircularProgressIndicator()) // Show a spinner while widgets are being initialized
          : _widgetOptions[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_activity),
            label: 'Parcels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Tickets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Transactions',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.black,
        onTap: _onItemTapped,
      ),
    );
  }
}