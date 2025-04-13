# CHANGELOG

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] - 2024-01-05
### Fixed
- Fixed duplicate WebSocket listener issues when navigating between connection and gamepad pages
- Improved socket connection management by centralizing broadcast stream handling
- Enhanced connection stability during gamepad navigation
- Optimized socket cleanup and reconnection logic

## [1.0.4] - 2024-01-05
### Added
- Automatic navigation to gamepad mode after successful network scan or QR code connection
- "Return to Gamepad" button accessibility while connection is active

## [1.0.3] - 2024-01-04
### Added
- Remote server functionality
- Remote connection status monitoring
- Automatic reconnection handling
- Multiple device support through remote server
- QR code connection support
- Remote server status panel

## [1.0.2] - 2024-01-03
### Fixed
- Fixed URL launching functionality for external links

## [1.0.1] - 2024-01-03
### Fixed
- Improved performance handling multiple button presses simultaneously 
- Fixed button state duplication when saving/updating layouts
- Enhanced touch response reliability for concurrent inputs

## [1.0.0] - 2024-01-03
### Added
- Initial release of BuanaVPad mobile application
- Multiple controller layout support with customizable configurations
- Real-time controller input preview
- Controller layout management system
  - Create new layouts
  - Edit existing layouts  
  - Delete layouts
  - Save and load layouts
- Network connectivity features
  - PC connection via WiFi
  - Network scanning capability
  - Connection status monitoring
- Debug information panel
  - Input state tracking
  - Connection status
  - Layout ID display
  - Joystick position values  
- User interface components
  - Main dashboard
  - Controller layout editor
  - Connection manager
  - Settings panel
- Support for various controller inputs
  - Shoulder buttons (LT, RT, LB, RB)
  - Face buttons (A, B, X, Y)
  - Dual analog sticks
  - Menu buttons
- Visual feedback for button presses
- Layout persistence across app sessions

### Technical Details
- Built with Flutter for Android
- Minimum SDK version: Android 6.0 (API level 23)
- Target SDK version: Android 13 (API level 33)  
- Network protocol: WebSocket
