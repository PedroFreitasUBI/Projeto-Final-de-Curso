import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:clipboard/clipboard.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'http_client.dart';
import 'auth_service.dart';
import 'dart:io';

class QrCodePage extends StatefulWidget {
  @override
  _QrCodePageState createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final Session _httpClient = Session();
  QRViewController? qrController;
  bool isScanning = false;
  bool isLoading = false;
  bool hasCameraPermission = false;
  String? generatedCode;
  bool isGenerating = false;
  int? pointsAwarded;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  @override
  void dispose() {
    qrController?.dispose();
    super.dispose();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    setState(() {
      hasCameraPermission = status.isGranted;
    });
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      hasCameraPermission = status.isGranted;
    });
    
    if (!hasCameraPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera permission is required to scan QR codes')));
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.qrController = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code == null || isLoading) return;
      
      setState(() => isLoading = true);
      qrController?.pauseCamera();

      try {
        final token = await AuthService.getAccessToken();
        if (token == null) {
          _showScanResult('Please login to scan QR codes', isSuccess: false);
          return;
        }

        final response = await _httpClient.post(
          'http://10.0.2.2:5000/api/validate-qr',
          jsonEncode({'qr_content': scanData.code}),
          token: token,
        );

        final result = jsonDecode(response.body);
        
        if (response.statusCode == 200 && result['valid'] == true) {
          setState(() => pointsAwarded = result['points_awarded']);
          _showScanResult(
            '✅ Success! ${result['points_awarded']} points awarded',
            isSuccess: true,
          );
        } else {
          _showScanResult(
            '❌ ${result['error'] ?? 'Invalid QR code'}',
            isSuccess: false,
          );
        }
      } catch (e) {
        _showScanResult(
          '⚠️ Error: ${e.toString().replaceAll('Exception: ', '')}',
          isSuccess: false,
        );
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
          qrController?.resumeCamera();
        }
      }
    });
  }

  Future<void> _generateQRCode() async {
    setState(() => isGenerating = true);

    try {
      final token = await AuthService.getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await _httpClient.post(
        'http://10.0.2.2:5000/api/generate-qr',
        jsonEncode({'points': 10}),
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        setState(() {
          generatedCode = data['qr_code'];
          pointsAwarded = data['points'];
        });
      } else {
        throw Exception(data['details'] ??
            data['message'] ??
            'Server error ${response.statusCode}');
      }
    } on SocketException catch (e) {
      // Handle network-related errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: ${e.message}')),
      );
    } on FormatException catch (e) {
      // Handle JSON decoding errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid response format: ${e.message}')),
      );
    } catch (e) {
      // Handle other exceptions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: ${e.toString()}')),
      );
    } finally {
      setState(() => isGenerating = false);
    }
  }
  void _copyToClipboard() {
    if (generatedCode != null) {
      FlutterClipboard.copy(generatedCode!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied to clipboard')));
    }
  }

  Future<void> _shareQRCode() async {
    if (generatedCode != null) {
      await Share.share(
        'Scan this QR code to earn $pointsAwarded points: $generatedCode',
        subject: 'Share QR Code',
      );
    }
  }

  void _showScanResult(String message, {required bool isSuccess}) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isSuccess ? 'Success!' : 'Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => isScanning = false);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(generatedCode != null ? 'Your QR Code' : 'QR Codes'),
        backgroundColor: Color(0xFF7086C7),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (generatedCode != null) {
              setState(() => generatedCode = null);
            } else if (isScanning) {
              setState(() => isScanning = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _buildCurrentView(),
    );
  }

  Widget _buildCurrentView() {
    if (generatedCode != null) {
      return _buildGeneratedCodeView();
    }
    if (isScanning) {
      return _buildScannerView();
    }
    return _buildMainMenu();
  }

  Widget _buildGeneratedCodeView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  QrImageView(
                    data: generatedCode!,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '$pointsAwarded points',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.copy, size: 30),
                onPressed: _copyToClipboard,
                tooltip: 'Copy Code',
                color: Colors.white,
              ),
              SizedBox(width: 20),
              IconButton(
                icon: Icon(Icons.share, size: 30),
                onPressed: _shareQRCode,
                tooltip: 'Share Code',
                color: Colors.white,
              ),
            ],
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _generateQRCode,
            child: Text('Generate New Code'),
            style: ElevatedButton.styleFrom(
              primary: Color(0xFF465172),
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: QRView(
                key: qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: QrScannerOverlayShape(
                  borderColor: Colors.blue,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: MediaQuery.of(context).size.width * 0.7,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => setState(() => isScanning = false),
                child: Text('Cancel Scan'),
                style: ElevatedButton.styleFrom(
                  primary: Colors.red,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildMainMenu() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code, size: 80, color: Colors.white70),
          SizedBox(height: 30),
          Text(
            'QR Code Options',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 40),
          SizedBox(
            width: 250,
            height: 50,
            child: ElevatedButton(
              onPressed: hasCameraPermission
                  ? () => setState(() => isScanning = true)
                  : _requestCameraPermission,
              style: ElevatedButton.styleFrom(
                primary: Color(0xFF7086C7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Scan QR Code',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: 250,
            height: 50,
            child: ElevatedButton(
              onPressed: isGenerating ? null : _generateQRCode,
              style: ElevatedButton.styleFrom(
                primary: Color(0xFF7086C7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isGenerating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Text(
                      'Generate QR Code',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}