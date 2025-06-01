import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'qr_code_page.dart';
import 'auth_service.dart'; // Changed from session_service.dart

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _userData = {
    'username': 'Loading...',
    'email': 'Loading...',
    'points': 0
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  Future<void> _loadProfileData() async {
    try {
      // First try to fetch data directly
      await _fetchUserData();
    } catch (e) {
      // If fetch fails, check session
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loading profile...')),
        );
        await _checkSessionAndRetry();
      }
    }
  }

  Future<void> _checkSessionAndRetry() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    
    // Only force validation if remember me is off
    if (!rememberMe) {
      final isValid = await AuthService.validateSession();
      if (!isValid && mounted) {
        await AuthService.clearSession();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
        return;
      }
    }
    
    // Try fetching again if we passed validation
    if (mounted) {
      await _fetchUserData();
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) throw Exception('No token available');

      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/user-profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _userData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // Only redirect if remember me is off
        final rememberMe = await AuthService.getRememberMeStatus();
        if (!rememberMe && mounted) {
          await AuthService.clearSession();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', textAlign: TextAlign.center),
        backgroundColor: Color(0xFF7086C7),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: AssetImage('assets/default_profile.png'),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF7086C7),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.camera_alt, color: Colors.white),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text(
                    _userData['username'],
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 30),
                  Card(
                    color: Color(0xFF465172),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoRow('Email', _userData['email']),
                          Divider(color: Colors.grey),
                          _buildInfoRow('Points', '${_userData['points']}'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => QrCodePage()),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: Color(0xFF7086C7),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('Use Points'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.white70)),
          Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}