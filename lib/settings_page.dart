import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Existing language setting
  String _selectedLanguage = 'English';
  bool _notificationsEnabled = false;

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return NotificationSettingsDialog(
          onSave: (type, value, unit, direction) {
            // Handle saving all notification preferences
            print('Notification set: $type < $value $unit ${direction ?? ''}');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', textAlign: TextAlign.center),
        backgroundColor: Color(0xFF7086C7),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language Setting (unchanged)
            _buildLanguageDropdown(),
            SizedBox(height: 30),
            
            // Enhanced Notifications Toggle
            _buildNotificationToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Language', style: TextStyle(fontSize: 18, color: Colors.white)),
        DropdownButton<String>(
          value: _selectedLanguage,
          dropdownColor: Color(0xFF465172),
          style: TextStyle(color: Colors.white),
          underline: Container(height: 1, color: Colors.white),
          items: ['English', 'Portuguese'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedLanguage = newValue!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildNotificationToggle() {
    return Row(
      children: [
        Text('Notifications', style: TextStyle(fontSize: 18, color: Colors.white)),
        Switch(
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
            });
            if (value) {
              _showNotificationSettings(context);
            }
          },
          activeColor: Color(0xFF7086C7),
        ),
      ],
    );
  }
}

class NotificationSettingsDialog extends StatefulWidget {
  final Function(String, double, String, String?) onSave;

  NotificationSettingsDialog({required this.onSave});

  @override
  _NotificationSettingsDialogState createState() => _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState extends State<NotificationSettingsDialog> {
  String _selectedType = 'temperature';
  String _selectedUnit = 'ºC';
  String? _selectedDirection;
  final TextEditingController _valueController = TextEditingController();

  final Map<String, List<String>> _unitOptions = {
    'temperature': ['ºC', 'ºF'],
    'humidity': ['%'],
    'wind_speed': ['km/h', 'm/s'],
    'max_wind': ['km/h', 'm/s'],
    'precipitation': ['mm'],
    'pressure': ['hPa'],
    'soil_moisture': ['%'],
    'wind_direction': ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'],
  };

  @override
  void initState() {
    super.initState();
    _selectedUnit = _unitOptions[_selectedType]!.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Color(0xFF465172),
      title: Text('Notification Settings', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Measurement Type Dropdown
            Text('Notify me when...', style: TextStyle(color: Colors.white)),
            DropdownButton<String>(
              value: _selectedType,
              dropdownColor: Color(0xFF465172),
              style: TextStyle(color: Colors.white),
              items: _unitOptions.keys.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type.replaceAll('_', ' ').capitalize()),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedType = newValue!;
                  _selectedUnit = _unitOptions[_selectedType]!.first;
                  _selectedDirection = null;
                });
              },
            ),
            SizedBox(height: 20),

            // Value Input (hidden for wind direction)
            if (_selectedType != 'wind_direction') ...[
              Text('...falls below:', style: TextStyle(color: Colors.white)),
              TextField(
                controller: _valueController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter value',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
              ),
              SizedBox(height: 10),
            ],

            // Unit Selection (or direction for wind)
            if (_selectedType != 'wind_direction')
              DropdownButton<String>(
                value: _selectedUnit,
                dropdownColor: Color(0xFF465172),
                style: TextStyle(color: Colors.white),
                items: _unitOptions[_selectedType]!.map((String unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedUnit = newValue!;
                  });
                },
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('...wind comes from:', style: TextStyle(color: Colors.white)),
                  Wrap(
                    spacing: 8,
                    children: _unitOptions['wind_direction']!.map((String dir) {
                      return ChoiceChip(
                        label: Text(dir),
                        selected: _selectedDirection == dir,
                        onSelected: (selected) {
                          setState(() {
                            _selectedDirection = selected ? dir : null;
                          });
                        },
                        selectedColor: Color(0xFF7086C7),
                      );
                    }).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text('Cancel', style: TextStyle(color: Colors.white)),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text('Save', style: TextStyle(color: Color(0xFF7086C7))),
          onPressed: () {
            if (_selectedType == 'wind_direction') {
              if (_selectedDirection != null) {
                widget.onSave(_selectedType, 0, '', _selectedDirection);
              }
            } else {
              final value = double.tryParse(_valueController.text) ?? 0.0;
              widget.onSave(_selectedType, value, _selectedUnit, null);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}