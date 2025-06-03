import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:iot_app/profile_page.dart';
import 'package:iot_app/qr_code_page.dart';
import 'package:iot_app/settings_page.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'auth_service.dart';

class GraphsPage extends StatefulWidget {
  @override
  _GraphsPageState createState() => _GraphsPageState();
}

class _GraphsPageState extends State<GraphsPage> {
  String? _selectedDevice;
  String? _selectedMeasurement;
  String? _selectedUnit;
  bool _viewMultipleDevices = false;
  bool _isLoading = true;
  List<String> _selectedAdditionalDevices = [];
  List<String> _allDevices = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, List<String>> _measurementUnits = {};
  List<FlSpot> _graphData = [];
  bool _isGraphLoading = false;

  final Map<String, Map<String, double Function(double)>> _unitConverters = {
    'temperature': {
      '°C': (v) => v,
      '°F': (v) => (v * 9/5) + 32,
      'K': (v) => v + 273.15,
    },
    'humidity': {
      '%': (v) => v,
      'kg/m³': (v) => v * 0.001,
      'g/m³': (v) => v * 1.0,
    },
    'wind_speed': {
      'km/h': (v) => v,
      'm/s': (v) => v / 3.6,
      'M/h': (v) => v / 1.609,
    },
    'max_wind': {
      'km/h': (v) => v,
      'm/s': (v) => v / 3.6,
      'M/h': (v) => v / 1.609,
    },
    'precipitation': {
      'mm': (v) => v,
      'in': (v) => v / 25.4,
    },
    'pressure': {
      'hPa': (v) => v,
      'Pa': (v) => v * 100,
      'bar': (v) => v / 1000,
    },
    'wind_direction': {
      'N': (v) => v,
      'NE': (v) => v,
      'E': (v) => v,
      'SE': (v) => v,
      'S': (v) => v,
      'SW': (v) => v,
      'W': (v) => v,
      'NW': (v) => v,
    },
    'soil_moisture': {
      '%': (v) => v,
      'm³/m³': (v) => v / 100,
    },
  };

  Future<void> _fetchGraphData() async {
    if (_selectedDevice == null || _selectedMeasurement == null) return;

    setState(() => _isGraphLoading = true);

    try {
      final token = await AuthService.getAccessToken();
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/measurements?'
          'station_id=${_selectedDevice!}'
          '&type=${_selectedMeasurement!}'
          '&start=${DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch ~/ 1000}'
          '&end=${DateTime.now().millisecondsSinceEpoch ~/ 1000}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final defaultUnit = _measurementUnits[_selectedMeasurement]?.first ?? '';
        
        setState(() {
          _graphData = data.map((point) {
            double value = (point['y'] as num).toDouble();
            if (_selectedUnit != null && 
                _selectedUnit != defaultUnit &&
                _unitConverters[_selectedMeasurement]?[_selectedUnit] != null) {
              value = _unitConverters[_selectedMeasurement]![_selectedUnit]!(value);
            }
            return FlSpot(
              (point['x'] as num).toDouble(),
              value,
            );
          }).toList();
        });
      } else {
        throw Exception('Failed to fetch graph data: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load graph data: $e')),
      );
    } finally {
      setState(() => _isGraphLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData().then((_) => _fetchGraphData());
    });
  }

  Future<void> _loadData() async {
    try {
      final stations = await AuthService.getStationIds();
      final measurements = await AuthService.getMeasurementTypes();
      
      setState(() {
        _allDevices = stations;
        _selectedDevice = stations.isNotEmpty ? stations.first : null;
        _measurementUnits = measurements;
        _selectedMeasurement = measurements.keys.isNotEmpty ? measurements.keys.first : null;
        _selectedUnit = _selectedMeasurement != null && measurements[_selectedMeasurement]!.isNotEmpty 
            ? measurements[_selectedMeasurement]!.first 
            : null;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  double _calculateYInterval() {
    if (_graphData.isEmpty) return 10;
    final values = _graphData.map((e) => e.y).toList();
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    final range = maxValue - minValue;
    return range > 0 ? range / 5 : 1; // Ensure a non-zero interval
  }

  Future<void> _loadGraphData() async {
    if (_selectedDevice == null || _selectedMeasurement == null) return;

    setState(() => _isGraphLoading = true);

    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: 7));

      final token = await AuthService.getAccessToken();
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/measurements?'
          'station_id=$_selectedDevice'
          '&type=$_selectedMeasurement'
          '&start=${startDate.millisecondsSinceEpoch ~/ 1000}'
          '&end=${endDate.millisecondsSinceEpoch ~/ 1000}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _graphData = data.map((point) => FlSpot(
            (point['x'] as num).toDouble(),
            (point['y'] as num).toDouble(),
          )).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isGraphLoading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF465172),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF7086C7),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Container(
          width: double.infinity,
          child: Text(
            'Graphs',
            textAlign: TextAlign.center,
          ),
        ),
        backgroundColor: Color(0xFF7086C7),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Filters Title
            Text(
              'Filters',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            
            // Device Dropdown
            _buildFilterDropdown(
              label: 'Device',
              value: _selectedDevice,
              items: _allDevices,
              onChanged: (value) {
                setState(() {
                  _selectedDevice = value;
                  _loadGraphData();
                });
              },
            ),
            SizedBox(height: 15),
            
            // Measurement Dropdown
            _buildFilterDropdown(
              label: 'Measurement',
              value: _selectedMeasurement,
              items: _measurementUnits.keys.toList(),
              onChanged: (value) {
                setState(() {
                  _selectedMeasurement = value;
                  _selectedUnit = _measurementUnits[value]?.first;
                  _fetchGraphData(); // Fetch new data when measurement changes
                });
              },
            ),
            SizedBox(height: 15),
            
            // Unit Dropdown
            _buildFilterDropdown(
              label: 'Unit',
              value: _selectedUnit,
              items: _selectedMeasurement != null 
                  ? _measurementUnits[_selectedMeasurement] ?? []
                  : [],
              onChanged: (value) {
                setState(() {
                  _selectedUnit = value;
                  _fetchGraphData(); // Recalculate graph data when unit changes
                });
              },
            ),
            SizedBox(height: 20),
            
            // View Multiple Devices Checkbox
            Row(
              children: [
                Checkbox(
                  value: _viewMultipleDevices,
                  onChanged: (value) {
                    setState(() {
                      _viewMultipleDevices = value!;
                    });
                  },
                  fillColor: MaterialStateProperty.resolveWith<Color>(
                    (Set<MaterialState> states) {
                      return Color(0xFF7086C7);
                    },
                  ),
                ),
                Text(
                  'View multiple devices',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: 10),
            
            // Additional Devices Selection (conditional)
            if (_viewMultipleDevices)
              Column(
                children: [
                  Text(
                    'Select additional devices:',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _allDevices
                        .where((device) => device != _selectedDevice)
                        .map((device) => FilterChip(
                          label: Text(device, style: TextStyle(color: Colors.white)),
                          selected: _selectedAdditionalDevices.contains(device),
                          selectedColor: Color(0xFF7086C7),
                          backgroundColor: Color(0xFF465172),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAdditionalDevices.add(device);
                              } else {
                                _selectedAdditionalDevices.remove(device);
                              }
                            });
                          },
                        ))
                        .toList(),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            // graph widget
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: _isGraphLoading
                  ? Center(child: CircularProgressIndicator())
                  : _graphData.isEmpty
                      ? Center(child: Text("No data available"))
                      : Padding(
                          padding: EdgeInsets.all(16),
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                horizontalInterval: _calculateYInterval(),
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.grey[300]!,
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, _) => Text(
                                      DateFormat('MM/dd').format(
                                        DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000),
                                      ),
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 10,
                                      ),
                                    ),
                                    reservedSize: 22,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, _) => Text(
                                      '${value.toStringAsFixed(1)} ${_selectedUnit ?? ''}',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 10,
                                      ),
                                    ),
                                    reservedSize: 28,
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(color: Colors.grey),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _graphData,
                                  isCurved: true,
                                  color: Color(0xFF7086C7),
                                  barWidth: 3,
                                  dotData: FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF7086C7).withOpacity(0.3),
                                        Color(0xFF7086C7).withOpacity(0.1),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                              minX: _graphData.map((e) => e.x).reduce(min),
                              maxX: _graphData.map((e) => e.x).reduce(max),
                              minY: _graphData.map((e) => e.y).reduce(min) * 0.95,
                              maxY: _graphData.map((e) => e.y).reduce(max) * 1.05,
                            ),
                          ),
                        ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    // Ensure items are unique
    final uniqueItems = items.toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 5),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Color(0xFF465172),
            border: Border.all(color: Color(0xFF7086C7)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: uniqueItems.contains(value) ? value : null, // Ensure value exists in items
            isExpanded: true,
            underline: SizedBox(),
            dropdownColor: Color(0xFF465172),
            icon: Icon(Icons.arrow_drop_down, color: Color(0xFF7086C7)),
            style: TextStyle(color: Colors.white),
            items: uniqueItems.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
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
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.show_chart, color: Color(0xFF7086C7)),
            title: Text('Graphs', style: TextStyle(color: Colors.black)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.qr_code, color: Color(0xFF7086C7)),
            title: Text('QR Codes', style: TextStyle(color: Colors.black)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
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
              Navigator.pushReplacement(
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
              Navigator.pop(context);
              await _logout();
            },
          ),
        ],
      ),
    );
  }
}