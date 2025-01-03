import 'dart:async';
import 'package:buana_vpad/widgets/controller_widget.dart';
import 'package:flutter/material.dart';
import 'package:buana_vpad/database/db_helper.dart';
import 'package:buana_vpad/models/button_state.dart';
import 'package:buana_vpad/models/controller_layout.dart';
import 'package:buana_vpad/models/dpad_layout.dart';
import 'package:buana_vpad/models/dpad_state.dart';
import 'package:buana_vpad/models/joystick_layout.dart';
import 'package:buana_vpad/models/button_layout.dart';
import 'package:buana_vpad/models/joystick_state.dart';
import 'package:buana_vpad/utils/layout_percentage.dart';
import 'package:buana_vpad/enums/button_shape.dart';
import 'package:uuid/uuid.dart';

class ControllerPreviewPage extends StatefulWidget {
  final String? layoutId;
  final bool isStatic;
  final double? maxWidth;
  final double? maxHeight;
  final ControllerLayout? initialLayout;

  const ControllerPreviewPage(
      {super.key,
      this.layoutId,
      this.isStatic = false,
      this.maxWidth,
      this.maxHeight,
      this.initialLayout});

  @override
  State<ControllerPreviewPage> createState() => _ControllerPreviewPageState();
}

class _ControllerPreviewPageState extends State<ControllerPreviewPage> {
  late final ValueNotifier<ControllerLayout> layoutNotifier;
  late final ValueNotifier<JoystickState> leftJoystickNotifier;
  late final ValueNotifier<JoystickState> rightJoystickNotifier;
  late final ValueNotifier<Map<String, ButtonState>> buttonStatesNotifier;
  late final ValueNotifier<DPadState> dpadNotifier;
  late final ValueNotifier<bool> showDebugNotifier;
  late final ValueNotifier<bool> isEditingNotifier;
  late final ValueNotifier<bool> isLoadingNotifier;
  late final ValueNotifier<bool> showSidebarNotifier;

  late TextEditingController nameController;
  final dbHelper = DatabaseHelper();
  final uuid = const Uuid();
  bool _initialized = false;

  @override
void initState() {
  super.initState();
  
  // Initialize notifiers
  leftJoystickNotifier = ValueNotifier(JoystickState(
    dx: 0, dy: 0, intensity: 0, angle: 0, isPressed: false
  ));
  rightJoystickNotifier = ValueNotifier(JoystickState(
    dx: 0, dy: 0, intensity: 0, angle: 0, isPressed: false
  ));
  buttonStatesNotifier = ValueNotifier(_createInitialButtonStates());
  dpadNotifier = ValueNotifier(DPadState());
  showDebugNotifier = ValueNotifier(true);
  isEditingNotifier = ValueNotifier(false);
  isLoadingNotifier = ValueNotifier(true);
  showSidebarNotifier = ValueNotifier(true);
  nameController = TextEditingController(text: 'New Controller Layout');
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  
  if (!_initialized) {
    layoutNotifier = ValueNotifier(_createDefaultLayout());
    _loadLayout();
    _initialized = true;
  }
}

  @override
  void dispose() {
    leftJoystickNotifier.dispose();
    rightJoystickNotifier.dispose();
    buttonStatesNotifier.dispose();
    dpadNotifier.dispose();
    showDebugNotifier.dispose();
    isEditingNotifier.dispose();
    isLoadingNotifier.dispose();
    showSidebarNotifier.dispose();
    layoutNotifier.dispose();
    nameController.dispose();
    super.dispose();
  }

  Map<String, ButtonState> _createInitialButtonStates() {
    return {
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
    };
  }

  void _handleLeftJoystickChange(double dx, double dy, double intensity, double angle) {
    leftJoystickNotifier.value = JoystickState(
      dx: dx,
      dy: dy,
      intensity: intensity,
      angle: angle,
      isPressed: intensity > 0
    );
  }

  void _handleRightJoystickChange(double dx, double dy, double intensity, double angle) {
    rightJoystickNotifier.value = JoystickState(
      dx: dx,
      dy: dy,
      intensity: intensity,
      angle: angle,
      isPressed: intensity > 0
    );
  }

  void _handleButtonChange(String buttonId, bool isPressed, double value) {
    final newButtonStates = Map<String, ButtonState>.from(buttonStatesNotifier.value);
    newButtonStates[buttonId] = ButtonState(
      id: buttonId,
      isPressed: isPressed,
      value: value,
    );
    buttonStatesNotifier.value = newButtonStates;
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
  }

  ControllerLayout _transformLayout(ControllerLayout sourceLayout) {
    final newSize = Size(widget.maxWidth!, widget.maxHeight!);
    // Perlu di-convert ke current size preview card
    return LayoutPercentage.convertLayoutToCurrentScreen(
      sourceLayout,
      newSize,
    );
  }

  void _handleLayoutChange(ControllerLayout newLayout) {
    layoutNotifier.value = newLayout;
  }

  Future<void> _loadLayout() async {
    isLoadingNotifier.value = true;
    try {
      if (widget.initialLayout != null) {
        layoutNotifier.value = _transformLayout(widget.initialLayout!);
        nameController.text = widget.initialLayout!.name;
      } else if (widget.layoutId != null) {
        final savedLayout = await dbHelper.getControllerLayout(widget.layoutId!);
        if (savedLayout != null) {
          final currentScreenSize = MediaQuery.of(context).size;
          final convertedLayout = LayoutPercentage.convertLayoutToCurrentScreen(
            savedLayout,
            currentScreenSize,
          );
          final rawButtons = savedLayout.buttons;
          final cleanButtons = rawButtons.map((key, button) {
          // Pastikan ID button selalu pure (A, B, X, Y dll)
          final cleanId = stripLayoutPrefix(button.id, savedLayout.id);
          return MapEntry(
            cleanId, // Gunakan clean ID sebagai key
            button.copyWith(newId: cleanId) // Update button dengan clean ID
            );
          });
          final finalLayout = convertedLayout.copyWith(newButtons: cleanButtons);
          layoutNotifier.value = finalLayout;
          nameController.text = savedLayout.name;
        }
      } else {
        layoutNotifier.value = _createDefaultLayout();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading layout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      layoutNotifier.value = _createDefaultLayout();
    } finally {
      isLoadingNotifier.value = false;
    }
  }


  Future<void> _handleSave() async {
    try {
      final layoutToSave = layoutNotifier.value.copyWith(
        newName: nameController.text.trim(),
        newIsEditable: false,
      );

      await dbHelper.insertControllerLayout(layoutToSave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Layout "${layoutToSave.name}" saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving layout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    if (widget.layoutId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Layout'),
        content: Text('Are you sure you want to delete "${layoutNotifier.value.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await dbHelper.deleteControllerLayout(widget.layoutId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Layout deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting layout: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showSaveDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(widget.layoutId == null ? 'Save Layout' : 'Update Layout'),
          content: Text(widget.layoutId == null
              ? 'Are you sure you want to save this layout?'
              : 'Are you sure you want to update this layout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleSave();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  ControllerLayout _createDefaultLayout() {
    final screenSize = widget.isStatic
        ? Size(widget.maxWidth!, widget.maxHeight!)
        : MediaQuery.of(context).size;
    final layoutId = uuid.v4();
    final layoutPercentage = LayoutPercentage(
      screenWidth: screenSize.width,
      screenHeight: screenSize.height,
    );
    final raw = {
      'zones': <String, double>{
        'centerX': 50.0,
        'leftSide': 15.0,
        'rightSide': 85.0,
        'topMargin': 12.0,
      },
      'verticalZones': <String, double>{
        'triggerY': 15.0,
        'menuY': 30.0,
        'mainButtonY': 45.0, // ABXY dan left joystick
        'secondaryY': 70.0, // dpad dan right joystick
      },
      'sizes': <String, dynamic>{
        'mainButtons': <String, double>{
          // ABXY
          'size': 12.0,
          'spacing': 8.0,
        },
        'menuButtons': <String, double>{
          // Start/Select
          'size': 12.0,
          'spacing': 8.0,
        },
        'triggers': <String, double>{
          'width': 15.0,
          'height': 8.0,
          'verticalGap': 10.0,
        },
        'joystick': <String, double>{
          'size': 25.0,
        },
        'dpad': <String, double>{
          'size': 25.0,
          'spacing': 25.0,
        },
      },
    };

    // Helper functions
    double getZone(String key) => (raw['zones'] as Map<String, double>)[key]!;
    double getVerticalZone(String key) =>
        (raw['verticalZones'] as Map<String, double>)[key]!;
    double getMainButtonSize(String key) =>
        ((raw['sizes'] as Map<String, dynamic>)['mainButtons']
            as Map<String, double>)[key]!;
    double getMenuButtonSize(String key) =>
        ((raw['sizes'] as Map<String, dynamic>)['menuButtons']
            as Map<String, double>)[key]!;
    double getTriggerSize(String key) =>
        ((raw['sizes'] as Map<String, dynamic>)['triggers']
            as Map<String, double>)[key]!;
    double getJoystickSize() =>
        ((raw['sizes'] as Map<String, dynamic>)['joystick']
            as Map<String, double>)['size']!;
    double getDpadSize(String key) =>
        ((raw['sizes'] as Map<String, dynamic>)['dpad']
            as Map<String, double>)[key]!;

    return ControllerLayout(
      id: layoutId,
      name: 'New Controller Layout',
      width: screenSize.width,
      height: screenSize.height,
      buttons: {
        // Face buttons (ABXY)
        'A': ButtonLayout(
          id: 'A',
          x: layoutPercentage.getAbsoluteX(getZone('rightSide')),
          y: layoutPercentage.getAbsoluteY(
              getVerticalZone('mainButtonY') + getMainButtonSize('spacing')),
          width: layoutPercentage.getAbsoluteSize(getMainButtonSize('size')),
          label: 'A',
          shape: ButtonShape.circle,
        ),
        'B': ButtonLayout(
          id: 'B',
          x: layoutPercentage.getAbsoluteX(
              getZone('rightSide') + getMainButtonSize('spacing')),
          y: layoutPercentage.getAbsoluteY(getVerticalZone('mainButtonY')),
          width: layoutPercentage.getAbsoluteSize(getMainButtonSize('size')),
          label: 'B',
          shape: ButtonShape.circle,
        ),
        'X': ButtonLayout(
          id: 'X',
          x: layoutPercentage.getAbsoluteX(
              getZone('rightSide') - getMainButtonSize('spacing')),
          y: layoutPercentage.getAbsoluteY(getVerticalZone('mainButtonY')),
          width: layoutPercentage.getAbsoluteSize(getMainButtonSize('size')),
          label: 'X',
          shape: ButtonShape.circle,
        ),
        'Y': ButtonLayout(
          id: 'Y',
          x: layoutPercentage.getAbsoluteX(getZone('rightSide')),
          y: layoutPercentage.getAbsoluteY(
              getVerticalZone('mainButtonY') - getMainButtonSize('spacing')),
          width: layoutPercentage.getAbsoluteSize(getMainButtonSize('size')),
          label: 'Y',
          shape: ButtonShape.circle,
        ),

        // Shoulder buttons
        'LB': ButtonLayout(
          id: 'LB',
          x: layoutPercentage.getAbsoluteX(getZone('leftSide')),
          y: layoutPercentage.getAbsoluteY(getVerticalZone('triggerY')),
          width: layoutPercentage.getAbsoluteWidth(getTriggerSize('width')),
          height: layoutPercentage.getAbsoluteHeight(getTriggerSize('height')),
          label: 'LB',
          shape: ButtonShape.rectangle,
          cornerRadius: 20,
        ),
        'RB': ButtonLayout(
          id: 'RB',
          x: layoutPercentage
              .getAbsoluteX(getZone('rightSide') - getTriggerSize('width')),
          y: layoutPercentage.getAbsoluteY(getVerticalZone('triggerY')),
          width: layoutPercentage.getAbsoluteWidth(getTriggerSize('width')),
          height: layoutPercentage.getAbsoluteHeight(getTriggerSize('height')),
          label: 'RB',
          shape: ButtonShape.rectangle,
          cornerRadius: 20,
        ),

        // Triggers
        'LT': ButtonLayout(
          id: 'LT',
          x: layoutPercentage.getAbsoluteX(getZone('leftSide')),
          y: layoutPercentage.getAbsoluteY(
              getVerticalZone('triggerY') - getTriggerSize('verticalGap')),
          width: layoutPercentage.getAbsoluteWidth(getTriggerSize('width')),
          height: layoutPercentage.getAbsoluteHeight(getTriggerSize('height')),
          label: 'LT',
          shape: ButtonShape.rectangle,
          cornerRadius: 20,
        ),
        'RT': ButtonLayout(
          id: 'RT',
          x: layoutPercentage
              .getAbsoluteX(getZone('rightSide') - getTriggerSize('width')),
          y: layoutPercentage.getAbsoluteY(
              getVerticalZone('triggerY') - getTriggerSize('verticalGap')),
          width: layoutPercentage.getAbsoluteWidth(getTriggerSize('width')),
          height: layoutPercentage.getAbsoluteHeight(getTriggerSize('height')),
          label: 'RT',
          shape: ButtonShape.rectangle,
          cornerRadius: 20,
        ),

        // Menu buttons
        'Start': ButtonLayout(
          id: 'Start',
          x: layoutPercentage
              .getAbsoluteX(getZone('centerX') + getMenuButtonSize('spacing')),
          y: layoutPercentage.getAbsoluteY(getVerticalZone('menuY')),
          width: layoutPercentage.getAbsoluteSize(getMenuButtonSize('size')),
          label: '≡',
          shape: ButtonShape.circle,
        ),
        'Select': ButtonLayout(
          id: 'Select',
          x: layoutPercentage.getAbsoluteX(getZone('centerX') -
              getMenuButtonSize('spacing') -
              getMenuButtonSize('size')),
          y: layoutPercentage.getAbsoluteY(getVerticalZone('menuY')),
          width: layoutPercentage.getAbsoluteSize(getMenuButtonSize('size')),
          label: '⋮',
          shape: ButtonShape.circle,
        ),
      },

      // DPad
      dpadLayout: DPadLayout(
        centerX: layoutPercentage
            .getAbsoluteX(getZone('leftSide') + getDpadSize('spacing')),
        centerY: layoutPercentage.getAbsoluteY(getVerticalZone('secondaryY')),
        size: layoutPercentage.getAbsoluteSize(getDpadSize('size')),
        hapticEnabled: true,
      ),

      // Analog sticks
      leftJoystick: JoystickLayout(
        x: layoutPercentage.getAbsoluteX(getZone('leftSide')),
        y: layoutPercentage.getAbsoluteY(getVerticalZone('mainButtonY')),
        outerSize: layoutPercentage.getAbsoluteSize(getJoystickSize()),
        innerSize: layoutPercentage.getAbsoluteSize(getJoystickSize() * 0.4),
        isDraggable: true,
        deadzone: 0.1,
      ),
      rightJoystick: JoystickLayout(
        x: layoutPercentage
            .getAbsoluteX(getZone('rightSide') - getJoystickSize()),
        y: layoutPercentage.getAbsoluteY(getVerticalZone('secondaryY')),
        outerSize: layoutPercentage.getAbsoluteSize(getJoystickSize()),
        innerSize: layoutPercentage.getAbsoluteSize(getJoystickSize() * 0.4),
        isDraggable: true,
        deadzone: 0.1,
      ),

      isEditable: false,
    );
  }

  String stripLayoutPrefix(String buttonId, String layoutId) {
  // Contoh: Dari '8ead4838_A' jadi 'A'
  return buttonId.replaceAll('${layoutId}_', '');
}

  Widget _buildBackButton() {
    return Positioned(
      left: 8,
      top: MediaQuery.of(context).padding.top + 8,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return ValueListenableBuilder<bool>(
      valueListenable: showSidebarNotifier,
      builder: (context, showSidebar, _) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          right: showSidebar ? 0 : -300,
          top: 0,
          bottom: 0,
          width: 300,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSidebarHeader(),
                _buildActionButtons(),
                _buildDebugPanel(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarHeader() {
    return ValueListenableBuilder<bool>(
      valueListenable: isEditingNotifier,
      builder: (context, isEditing, _) {
        return Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            bottom: 16,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: nameController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check, color: Colors.white),
                            onPressed: () => isEditingNotifier.value = false,
                          ),
                        ),
                        onSubmitted: (_) => isEditingNotifier.value = false,
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              nameController.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => isEditingNotifier.value = true,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildActionButtons() {
  
  return ValueListenableBuilder<ControllerLayout>(
    valueListenable: layoutNotifier,
    builder: (context, layout, _) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                print(layout.isEditable);
                layoutNotifier.value = layout.copyWith(
                  newIsEditable: !layout.isEditable,
                );
                if (!layout.isEditable) {
                  buttonStatesNotifier.value = _createInitialButtonStates();
                  leftJoystickNotifier.value = JoystickState(
                    dx: 0, dy: 0, intensity: 0, angle: 0, isPressed: false
                  );
                  rightJoystickNotifier.value = JoystickState(
                    dx: 0, dy: 0, intensity: 0, angle: 0, isPressed: false
                  );
                  dpadNotifier.value = DPadState();
                }
                showSidebarNotifier.value = false;
              },
              icon: Icon(layout.isEditable ? Icons.visibility : Icons.edit),
              label: Text(layout.isEditable ? 'Preview' : 'Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: layout.isEditable ? Colors.amber : Colors.blue[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _showSaveDialog,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            if (widget.layoutId != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _handleDelete,
                icon: const Icon(Icons.delete),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

  Widget _buildToggleButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: showSidebarNotifier,
      builder: (context, showSidebar, _) {
        return Positioned(
          right: showSidebar ? 308 : 8,
          top: MediaQuery.of(context).padding.top + 8,
          child: GestureDetector(
            onTap: () => showSidebarNotifier.value = !showSidebar,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                showSidebar ? Icons.chevron_right : Icons.chevron_left,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildPreviewWidget() {
  return ValueListenableBuilder<bool>(
    valueListenable: isLoadingNotifier,
    builder: (context, isLoading, _) {
      if (isLoading) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth ?? double.infinity,
            maxHeight: widget.maxHeight ?? double.infinity,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: 
                  widget.isStatic ? BorderRadius.circular(8) : BorderRadius.zero,
            ),
            child: const Center(
              child: CircularProgressIndicator(),  
            ),
          ),
        );
      }

      return ValueListenableBuilder<ControllerLayout>(
        valueListenable: layoutNotifier,
        builder: (context, layout, _) {
          final previewWidget = Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.isStatic
                    ? [
                        Colors.grey[900]!,
                        Colors.grey[800]!,
                      ]
                    : [
                        Colors.grey[100]!,
                        Colors.grey[200]!,
                      ],
              ),
            ),
            child: ClipRRect(
              borderRadius:
                  widget.isStatic ? BorderRadius.circular(8) : BorderRadius.zero,
              child: ControllerWidget(
                layout: layout,
                leftJoystickNotifier: leftJoystickNotifier,
                rightJoystickNotifier: rightJoystickNotifier,
                buttonStatesNotifier: buttonStatesNotifier,
                dpadNotifier: dpadNotifier,
                onLeftJoystickMove: widget.isStatic ? (_, __, ___, ____) {} : _handleLeftJoystickChange,
                onRightJoystickMove: widget.isStatic ? (_, __, ___, ____) {} : _handleRightJoystickChange,
                onButtonStateChange: widget.isStatic ? (_, __, ___) {} : _handleButtonChange,
                onDPadChange: widget.isStatic ? (_, __) {} : _handleDPadChange,
                onLayoutChanged: widget.isStatic ? (_) {} : _handleLayoutChange,
              ),
            ),
          );

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.maxWidth ?? double.infinity,
              maxHeight: widget.maxHeight ?? double.infinity,
            ),
            child: previewWidget,
          );
        },
      );
    },
  );
}

  Widget _buildDebugPanel() {
  return ValueListenableBuilder<bool>(
    valueListenable: showDebugNotifier,
    builder: (context, showDebug, _) {
      return Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debug Info',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<ControllerLayout>(
                valueListenable: layoutNotifier,
                builder: (context, layout, _) {
                  return Text(
                    'Layout ID: ${layout.id}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<JoystickState>(
                valueListenable: leftJoystickNotifier,
                builder: (context, leftJoystick, _) {
                  return Text(
                    'Left Joy: ${leftJoystick.dx.toStringAsFixed(2)}, ${leftJoystick.dy.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<JoystickState>(
                valueListenable: rightJoystickNotifier,
                builder: (context, rightJoystick, _) {
                  return Text(
                    'Right Joy: ${rightJoystick.dx.toStringAsFixed(2)}, ${rightJoystick.dy.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<Map<String, ButtonState>>(
                valueListenable: buttonStatesNotifier,
                builder: (context, buttonStates, _) {
                  return Text(
                    'Active Buttons: ${buttonStates.entries.where((e) => e.value.isPressed).map((e) => e.key).join(", ")}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<DPadState>(
                valueListenable: dpadNotifier,
                builder: (context, dpadState, _) {
                  return Text(
                    'DPad: ${dpadState.currentDirection ?? "none"}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
  }
  @override
  Widget build(BuildContext context) {
    if (widget.isStatic) {
      return _buildPreviewWidget();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: isLoadingNotifier,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              // Main Content
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.grey.shade900,
                      Colors.grey.shade800,
                    ],
                  ),
                ),
                child: ValueListenableBuilder<ControllerLayout>(
                  valueListenable: layoutNotifier,
                  builder: (context, layout, _) {
                    return ControllerWidget(
                      layout: layout,
                      leftJoystickNotifier: leftJoystickNotifier,
                      rightJoystickNotifier: rightJoystickNotifier,
                      buttonStatesNotifier: buttonStatesNotifier,
                      dpadNotifier: dpadNotifier,
                      onLeftJoystickMove: _handleLeftJoystickChange,
                      onRightJoystickMove: _handleRightJoystickChange,
                      onButtonStateChange: _handleButtonChange,
                      onDPadChange: _handleDPadChange,
                      onLayoutChanged: _handleLayoutChange,
                    );
                  },
                ),
              ),
              // Sidebar
              _buildSidebar(),
              // Toggle Button
              _buildToggleButton(),
              // Back Button
              _buildBackButton(),
            ],
          ),
        );
      },
    );
  }
}
