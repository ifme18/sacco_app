import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart'; // Ensure this import path is correct for your project

const String BASE_URL = 'https://stageapp.livecodesolutions.co.ke';
const String URL_LOGIN = '$BASE_URL/Token';
const String URL_SACCO_DETAILS = '$BASE_URL/api/Company/'; // Updated URL for Sacco details

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoggedIn();
  }

  void _checkLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      final String? token = prefs.getString('token');
      final String? saccoId = prefs.getString('companyId');
      if (token != null && saccoId != null) {
        await _getSaccoDetails(token, saccoId);
      } else {
        _showError("Token or Sacco ID is missing");
      }
    }
  }

  void _login() async {
    String phoneno = _phoneController.text.trim();
    String pass = _passwordController.text.trim();

    if (phoneno.isEmpty) {
      _showError("Enter Phone no.");
      return;
    }

    if (phoneno.length < 9) {
      _showError("Invalid Phone no.");
      return;
    }

    if (!phoneno.startsWith("7") && !phoneno.startsWith("1")) {
      _showError("Phone no. must start with 7 or 1");
      return;
    }

    if (pass.isEmpty) {
      _showError("Enter password");
      return;
    }

    if (pass.length < 4) {
      _showError("Invalid Password");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool isNetworkAvailable = await _isNetworkAvailable();
    if (isNetworkAvailable) {
      await _loginUser(phoneno, pass);
    } else {
      _showError("No network connection");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginUser(String phoneno, String pass) async {
    try {
      final response = await http.post(
        Uri.parse(URL_LOGIN),
        body: {
          'username': '254$phoneno',
          'password': pass,
          'grant_type': 'password',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData.containsKey('access_token') &&
            responseData.containsKey('CompanyID') &&
            responseData.containsKey('UserName') &&
            responseData.containsKey('Names')) {
          // Capture and store user details
          await _saveUserDetails(
              responseData['access_token'],
              responseData['CompanyID'],
              responseData['UserName'],
              responseData['Phone'],
              responseData['Site'],
              responseData['Names']
          );
          await _getSaccoDetails(responseData['access_token'], responseData['CompanyID']);
        } else {
          _showError(responseData['error_description'] ?? "Login failed");
        }
      } else {
        _showError("Invalid credentials or server issue");
      }
    } catch (e) {
      _showError("An error occurred during login: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getSaccoDetails(String token, String saccoId) async {
    try {
      final url = '$URL_SACCO_DETAILS$saccoId'; // Append Sacco ID to the URL
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('Sacco details response status: ${response.statusCode}');
      print('Sacco details response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData is Map<String, dynamic> && responseData.containsKey('CompanyCode')) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          final String? userName = prefs.getString('userName');
          final String? userFullName = prefs.getString('names');
          final String? site = prefs.getString('site');
          final String? phone = prefs.getString('phone');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                userId: saccoId,
                userName: userName ?? '',
                saccoDetails: responseData,
                userFullName: userFullName ?? '',
                site: site ?? '', // Pass site to HomeScreen
                phone: phone ?? '', // Pass phone to HomeScreen
              ),
            ),
          );
        } else {
          _showError("Could not fetch Sacco details");
        }
      } else {
        _showError("Failed to fetch Sacco details. Please try again.");
      }
    } catch (e) {
      _showError("An error occurred while fetching Sacco details: $e");
    }
  }


  Future<void> _saveUserDetails(String token, String companyId, String userName, String phone, String site, String names) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('token', token);
    await prefs.setString('companyId', companyId);
    await prefs.setString('userName', userName);
    await prefs.setString('phone', phone);
    await prefs.setString('site', site);
    await prefs.setString('names', names);
  }

  Future<bool> _isNetworkAvailable() async {
    // This method should include a real network check.
    // For simplicity, it returns true, assuming the network is available.
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.cyan.shade400, Colors.green.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 30),
                _buildTextField(
                  controller: _phoneController,
                  labelText: 'Phone no.',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 20),
                _buildTextField(
                  controller: _passwordController,
                  labelText: 'Password',
                  icon: Icons.lock,
                  obscureText: true,
                ),
                SizedBox(height: 30),
                _isLoading
                    ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
                    : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 80, vertical: 15),
                    backgroundColor: Colors.yellow.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Login',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    // Handle forgot password
                  },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius:  BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
    );
  }
}
