import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:buana_vpad/database/db_helper.dart';
import 'package:buana_vpad/models/controller_layout.dart';
import 'package:buana_vpad/screens/controller_mode_page.dart';
import 'package:buana_vpad/utils/settings_manager.dart';
import 'package:buana_vpad/enums/link.dart';

class RemoteServerPage extends StatefulWidget {
  const RemoteServerPage({super.key});

  @override
  State<RemoteServerPage> createState() => _RemoteServerPageState();
}

class _RemoteServerPageState extends State<RemoteServerPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  
  bool _isLoading = true;
  bool _isConnecting = false;
  bool _isConnected = false;
  WebSocket? _socket;
  List<ControllerLayout> _layouts = [];
  ControllerLayout? _selectedLayout;
  String? _deviceId;
  String? _deviceName;
  final _remoteServerUrl = Link.remoteServer.path;

  @override
  void initState() {
    super.initState();
    _loadLayouts();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final deviceId = await SettingsManager.getDeviceId();
    final deviceName = await SettingsManager.getDeviceName();
    setState(() {
      _deviceId = deviceId;
      _deviceName = deviceName;
    });
  }

  Future<void> _loadLayouts() async {
    setState(() => _isLoading = true);
    try {
      final dbHelper = DatabaseHelper();
      final layouts = await dbHelper.getAllControllerLayouts();
      setState(() {
        _layouts = layouts;
        _selectedLayout = layouts.isNotEmpty ? layouts.first : null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading layouts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showQRScanner() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scan QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      setState(() {
                        _codeController.text = barcode.rawValue!;
                      });
                      Navigator.pop(context);
                      break;
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadQRCode() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        final MobileScannerController controller = MobileScannerController();
        final barcodeCapture = await controller.analyzeImage(image.path);
        
        if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
          final firstBarcode = barcodeCapture.barcodes.first;
          if (firstBarcode.rawValue != null) {
            setState(() {
              _codeController.text = firstBarcode.rawValue!;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No QR code found in the image'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        controller.dispose();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Connection code is required';
    }
    if (value.length < 6) {
      return 'Invalid connection code';
    }
    return null;
  }

  Future<void> _connect() async {
    if (_formKey.currentState!.validate()) {
      if (_deviceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device ID not found. Please restart the app.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedLayout == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a controller layout first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isConnecting = true);

      try {
        final wsUrl = '$_remoteServerUrl/ws/${_codeController.text}';
        print(wsUrl);
        _socket = await WebSocket.connect(wsUrl)
            .timeout(const Duration(seconds: 5), onTimeout: () {
          throw 'Connection timeout. Please check your internet connection.';
        });

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ControllerModePage(
                layout: _selectedLayout!,
                socket: _socket!,
                deviceId: _deviceId!,
                deviceName: _deviceName ?? 'Unknown Device',
                onConnect: () {
                  setState(() {
                    _isConnecting = false;
                    _isConnected = true;
                  });
                },
                onDisconnect: () {
                  _disconnect();
                },
              ),
            ),
          );
        }
      } catch (e) {
        _disconnect();

        String errorMessage = 'Connection failed';
        if (e.toString().contains('timeout')) {
          errorMessage = 'Connection timeout. Please check your internet connection.';
        } else if (e.toString().contains('refused')) {
          errorMessage = 'Connection refused. Please check the connection code.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _disconnect() {
    _socket?.close();
    setState(() {
      _isConnecting = false;
      _isConnected = false;
      _socket = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Remote Connection',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[900]!,
              Colors.grey[850]!,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Connection Status
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isConnected ? Colors.green : Colors.grey[800]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isConnected ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isConnected ? 'Connected' : 'Not Connected',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // QR Code Options
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  // Scan QR Button
                                  InkWell(
                                    onTap: _isConnected ? null : _showQRScanner,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.qr_code_scanner,
                                                color: Colors.blue,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Scan QR Code',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios,
                                            color: Colors.blue,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Divider(color: Colors.grey),
                                  // Upload QR Button
                                  InkWell(
                                    onTap: _isConnected ? null : _uploadQRCode,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.photo_library,
                                                color: Colors.blue,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Upload QR Code',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios,
                                            color: Colors.blue,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Manual Code Input
                            Text(
                              'Or enter code manually',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _codeController,
                              enabled: !_isConnected,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Connection Code',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                hintText: 'Enter the code shown on your PC',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.blue),
                                ),
                              ),
                              validator: _validateCode,
                            ),
                            const SizedBox(height: 24),

                            // Controller Layout Selection
                            if (_layouts.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning,
                                      color: Colors.red.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No controller layouts found. Please create one first.',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Controller Layout',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<ControllerLayout>(
                                        value: _selectedLayout,
                                        isExpanded: true,
                                        dropdownColor: Colors.grey[850],
                                        style: const TextStyle(color: Colors.white),
                                        items: _layouts.map((layout) {
                                          return DropdownMenuItem(
                                            value: layout,
                                            child: Text(layout.name),
                                          );
                                        }).toList(),
                                        onChanged: _isConnected
                                            ? null
                                            : (layout) {
                                                setState(() {
                                                  _selectedLayout = layout;
                                                });
                                              },
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            // Connection Info
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'How to connect:',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoPoint(
                                    '1. Open Buana VPad on your PC',
                                    Icons.computer,
                                  ),
                                  _buildInfoPoint(
                                    '2. Click "Remote Connection" and get the QR code',
                                    Icons.qr_code,
                                  ),
                                  _buildInfoPoint(
                                    '3. Scan/Upload QR code or enter the code manually on the mobile app',
                                    Icons.input,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Fixed Connect Button at bottom
                  Container(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: MediaQuery.of(context).padding.bottom + 24,
                      top: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_layouts.isEmpty || _isConnecting)
                            ? null
                            : () {
                                if (_isConnected) {
                                  _disconnect();
                                } else {
                                  _connect();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isConnected ? Colors.red : Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isConnecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _isConnected ? 'Disconnect' : 'Connect',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoPoint(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _socket?.close();
    super.dispose();
  }
}