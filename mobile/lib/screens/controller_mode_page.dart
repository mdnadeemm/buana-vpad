import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:buana_vpad/widgets/controller_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:buana_vpad/models/button_state.dart';
import 'package:buana_vpad/models/controller_layout.dart';
import 'package:buana_vpad/models/controller_state.dart';
import 'package:buana_vpad/models/dpad_state.dart';
import 'package:buana_vpad/models/joystick_state.dart';

class ControllerModePage extends StatefulWidget {
  final ControllerLayout layout;
  final WebSocket socket;
  final String deviceName;
  final String deviceId;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const ControllerModePage({
    super.key,
    required this.layout,
    required this.deviceId,
    required this.socket,
    required this.deviceName,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  State<ControllerModePage> createState() => _ControllerModePageState();
}

class _ControllerModePageState extends State<ControllerModePage> {
  late final ValueNotifier<JoystickState> leftJoystickNotifier;
  late final ValueNotifier<JoystickState> rightJoystickNotifier; 
  late final ValueNotifier<Map<String, ButtonState>> buttonStatesNotifier;
  late final ValueNotifier<DPadState> dpadNotifier;
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(true);
  
  StreamSubscription? _socketSubscription;
  Timer? _pingTimer;
  Timer? _sendDebouncer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize state notifiers
    leftJoystickNotifier = ValueNotifier(JoystickState(
      dx: 0, dy: 0, intensity: 0, angle: 0, isPressed: false
    ));
    
    rightJoystickNotifier = ValueNotifier(JoystickState(
      dx: 0, dy: 0, intensity: 0, angle: 0, isPressed: false
    ));

    buttonStatesNotifier = ValueNotifier({
      'A': ButtonState(isPressed: false, value: 0, id: 'A'),
      'B': ButtonState(isPressed: false, value: 0, id: 'B'),
      'X': ButtonState(isPressed: false, value: 0, id: 'X'),
      'Y': ButtonState(isPressed: false, value: 0, id: 'Y'),
      'LB': ButtonState(isPressed: false, value: 0, id: 'LB'),
      'RB': ButtonState(isPressed: false, value: 0, id: 'RB'),
      'LT': ButtonState(isPressed: false, value: 0, id: 'LT'),
      'RT': ButtonState(isPressed: false, value: 0, id: 'RT'),
      'Start': ButtonState(isPressed: false, value: 0, id: 'Start'),
      'Select': ButtonState(isPressed: false, value: 0, id: 'Select'),
    });

    dpadNotifier = ValueNotifier(DPadState());

    _setupSocketListener();
    _setupPingPong();
    _sendInitialConnect();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _pingTimer?.cancel();
    _sendDebouncer?.cancel();
    leftJoystickNotifier.dispose();
    rightJoystickNotifier.dispose();
    buttonStatesNotifier.dispose();
    dpadNotifier.dispose();
    isConnectedNotifier.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _sendInitialConnect() async {
    try {
      widget.socket.add(jsonEncode({
        "type": "connect",
        "device_id": widget.deviceId,
        "device_name": widget.deviceName
      }));
    } catch (e) {
      print('Failed to send initial connect: $e');
      _handleDisconnect();
    }
  }

  void _setupPingPong() {
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && isConnectedNotifier.value) {
        try {
          widget.socket
              .add(jsonEncode({"type": "ping", "device_id": widget.deviceId}));
        } catch (e) {
          print('Ping error: $e');
          timer.cancel();
          _handleDisconnect();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _setupSocketListener() {
    _socketSubscription = widget.socket.listen(
      (message) {
        final data = jsonDecode(message);
        if (data["type"] == "connect_success") {
          widget.onConnect();
        } else if (data["type"] == "pong") {
          isConnectedNotifier.value = true;
        }
      },
      onDone: _handleDisconnect,
      onError: (error) {
        print('Socket error: $error');
        _handleDisconnect();
      },
    );
  }

  void _handleDisconnect() {
    isConnectedNotifier.value = false;
    _pingTimer?.cancel();
    widget.onDisconnect();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection lost. Returning to connect page...'),
          backgroundColor: Colors.red,
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    }
  }

  void _handleLeftJoystickChange(double dx, double dy, double intensity, double angle) {
    leftJoystickNotifier.value = JoystickState(
      dx: dx,
      dy: dy,
      intensity: intensity,
      angle: angle,
      isPressed: intensity > 0
    );
    _sendControllerState();
  }

  void _handleRightJoystickChange(double dx, double dy, double intensity, double angle) {
    rightJoystickNotifier.value = JoystickState(
      dx: dx,
      dy: dy,
      intensity: intensity,
      angle: angle,
      isPressed: intensity > 0
    );
    _sendControllerState();
  }

  void _handleButtonChange(String buttonId, bool isPressed, double value) {
    final newButtonStates = Map<String, ButtonState>.from(buttonStatesNotifier.value);
    newButtonStates[buttonId] = ButtonState(
      id: buttonId,
      isPressed: isPressed,
      value: value,
    );
    buttonStatesNotifier.value = newButtonStates;
    _sendControllerState();
  }

  void _handleDPadChange(String direction, bool isPressed) {
  late final DPadState newDPadState;
  
  switch (direction) {
    case 'up':
      newDPadState = dpadNotifier.value.copyWith(newUpPressed: isPressed);
      break;
    case 'down':
      newDPadState = dpadNotifier.value.copyWith(newDownPressed: isPressed);
      break;
    case 'left':
      newDPadState = dpadNotifier.value.copyWith(newLeftPressed: isPressed);
      break;
    case 'right':
      newDPadState = dpadNotifier.value.copyWith(newRightPressed: isPressed);
      break;
    default:
      return;
  }
  
  dpadNotifier.value = newDPadState;
  _sendControllerState();
}

  void _sendControllerState() {
  if (!mounted || !isConnectedNotifier.value) return;
  
  try {
    final state = ControllerState(
      leftJoystickState: leftJoystickNotifier.value,
      rightJoystickState: rightJoystickNotifier.value,
      buttonStates: buttonStatesNotifier.value,
      dpadState: dpadNotifier.value,
    );

    widget.socket.add(jsonEncode({
      "type": "controller_input",
      "device_id": widget.deviceId,
      "device_name": widget.deviceName,
      "data": state.toJson()
    }));
  } catch (e) {
    print('Failed to send input: $e');
    _handleDisconnect();
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: Stack(
          children: [
            ControllerWidget(
              layout: widget.layout,
              leftJoystickNotifier: leftJoystickNotifier,
              rightJoystickNotifier: rightJoystickNotifier,
              buttonStatesNotifier: buttonStatesNotifier,
              dpadNotifier: dpadNotifier,
              onLeftJoystickMove: _handleLeftJoystickChange,
              onRightJoystickMove: _handleRightJoystickChange,
              onButtonStateChange: _handleButtonChange,
              onDPadChange: _handleDPadChange,
            ),

            // Connection status indicator
            ValueListenableBuilder<bool>(
              valueListenable: isConnectedNotifier,
              builder: (context, isConnected, _) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                    ),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}