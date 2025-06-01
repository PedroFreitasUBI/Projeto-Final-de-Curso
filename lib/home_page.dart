import 'package:flutter/material.dart';
import 'package:iot_app/profile_page.dart';
import 'login_page.dart';
import 'graphs_page.dart';
import 'qr_code_page.dart';
import 'settings_page.dart';
import 'auth_service.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _logout() async {
    await AuthService.logout(); // Clear all auth data
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Container(
          width: double.infinity,
          child: Text(
            'Home',
            textAlign: TextAlign.center,
          )
        ),
        backgroundColor: Color(0xFF7086C7),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: _buildDrawer(context),
      body: GridView.count(
        padding: EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        children: [
          _buildImageButton('assets/graph_button.png'),
          _buildImageButton('assets/qr_code_button.png'),
          _buildImageButton('assets/profile_button.png'),
          _buildImageButton('assets/settings_button.png'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF7086C7),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: AssetImage('assets/default_profile.png'),
                ),
                SizedBox(height: 10),
                Text(
                  'Welcome!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: Color(0xFF7086C7)),
            title: Text('Home', style: TextStyle(color: Colors.black)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // Already on home page
            },
          ),
          ListTile(
            leading: Icon(Icons.show_chart, color: Color(0xFF7086C7)),
            title: Text('Graphs', style: TextStyle(color: Colors.black)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GraphsPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.qr_code, color: Color(0xFF7086C7)),
            title: Text('QR Codes', style: TextStyle(color: Colors.black)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => QrCodePage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.person, color: Color(0xFF7086C7)),
            title: Text('Profile', style: TextStyle(color: Colors.black)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: Color(0xFF7086C7)),
            title: Text('Settings', style: TextStyle(color: Colors.black)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context); // Close drawer first
              await _logout(); // Use the new logout function
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImageButton(String imagePath) {
    return InkWell(
      onTap: () {
        if (imagePath.contains('graph_button')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GraphsPage()),
          );
        }
        if (imagePath.contains('qr_code_button')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => QrCodePage()),
          );
        }
        if (imagePath.contains('profile_button')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfilePage()),
          );
        }
        if (imagePath.contains('settings_button')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsPage()),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}