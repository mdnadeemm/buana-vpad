# mainwindow.py
from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QTabWidget,
    QVBoxLayout, QMessageBox, QApplication, QLabel
)
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QIcon 
from src.gui.components.author_tab import AuthorTab
from src.gui.components.server_tab import ServerControlTab
from src.gui.components.monitor_tab import ConnectionsMonitorTab
from src.gui.components.remote_server_tab import RemoteServerTab
from src.gui.components.remote_monitor_tab import RemoteConnectionsMonitorTab
from src.utils.server_events import server_events
from src.utils.remote_server_events import remote_server_events
import asyncio
import os
import sys

def get_resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    
    return os.path.join(base_path, relative_path)

class DarkTabWidget(QTabWidget):
    def __init__(self):
        super().__init__()
        self.setDocumentMode(True)
        self.setStyleSheet("""
            QTabWidget::pane {
                border: none;
                background: #121212;
            }
            QTabWidget::tab-bar {
                alignment: left;
            }
            QTabBar::tab {
                background: #1a1a1a;
                color: #808080;
                border: none;
                padding: 8px 16px;
                margin-right: 2px;
                font-family: 'Segoe UI', Arial;
                font-weight: bold;
            }
            QTabBar::tab:hover {
                background: #252525;
                color: #ffffff;
            }
            QTabBar::tab:selected {
                background: #2d2d2d;
                color: #ffffff;
            }
        """)

class MainWindow(QMainWindow):
    def __init__(self, local_server, remote_server):
        super().__init__()
        self.local_server = local_server
        self.remote_server = remote_server
        self.is_closing = False
        self.init_ui()
        self.setup_styles()
        self.connect_events()

    def init_ui(self):
        self.setWindowTitle("BuanaVPad")
        self.setMinimumSize(900, 700)
        
        # Set icon with proper path handling
        try:
            icon_path = get_resource_path(os.path.join('src', 'gui', 'logo', 'logo.ico'))
            if os.path.exists(icon_path):
                self.setWindowIcon(QIcon(icon_path))
                print(f"Icon loaded successfully from: {icon_path}")
            else:
                print(f"Icon not found at: {icon_path}")
        except Exception as e:
            print(f"Error loading icon: {e}")
        
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        # Initialize tabs container
        tabs = DarkTabWidget()
        layout.addWidget(tabs)
        
        # Initialize all tabs
        self.server_tab = ServerControlTab(self)
        self.monitor_tab = ConnectionsMonitorTab()
        self.remote_tab = RemoteServerTab(self)
        self.remote_monitor_tab = RemoteConnectionsMonitorTab()
        self.author_tab = AuthorTab()
        
        # Add all tabs
        tabs.addTab(self.server_tab, "Local Server Control")
        tabs.addTab(self.monitor_tab, "Local Gamepad Monitor")
        tabs.addTab(self.remote_tab, "Remote Server Control")
        tabs.addTab(self.remote_monitor_tab, "Remote Gamepad Monitor")
        tabs.addTab(self.author_tab, "Author")

    def setup_styles(self):
        self.setStyleSheet("""
            QMainWindow {
                background: #121212;
            }
            QWidget {
                background: #121212;
                color: #ffffff;
                font-family: 'Segoe UI', Arial;
            }
            QMessageBox {
                background-color: #1a1a1a;
            }
            QMessageBox QLabel {
                color: #ffffff;
            }
            QMessageBox QPushButton {
                background-color: #2d2d2d;
                border: none;
                padding: 8px 16px;
                border-radius: 5px;
                color: white;
                font-weight: bold;
                min-width: 80px;
            }
            QMessageBox QPushButton:hover {
                background-color: #3d3d3d;
            }
            QScrollBar:vertical {
                background-color: #1a1a1a;
                width: 12px;
                margin: 0px;
            }
            QScrollBar::handle:vertical {
                background-color: #404040;
                border-radius: 6px;
                min-height: 20px;
                margin: 2px;
            }
            QScrollBar::handle:vertical:hover {
                background-color: #4d4d4d;
            }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                height: 0px;
            }
            QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {
                background: none;
            }
        """)

    def connect_events(self):
        # Local server events
        server_events.server_error.connect(self.handle_server_error)
        # Remote server events
        remote_server_events.remote_server_error.connect(self.handle_remote_server_error)

    async def cleanup(self):
        """Cleanup resources before closing"""
        if self.server_tab.server_running:
            await self.stop_server()
        if hasattr(self.remote_tab, 'server_running') and self.remote_tab.server_running:
            await self.stop_remote_server()
        await asyncio.sleep(1)

    def closeEvent(self, event):
        """Handle application closing"""
        if self.is_closing:
            event.accept()
            return

        if (hasattr(self.server_tab, 'server_running') and self.server_tab.server_running) or \
           (hasattr(self.remote_tab, 'server_running') and self.remote_tab.server_running):
            reply = QMessageBox()
            reply.setWindowTitle("Confirm Exit")
            reply.setText("One or more servers are still running. Are you sure you want to exit?")
            reply.setStandardButtons(
                QMessageBox.StandardButton.Yes | 
                QMessageBox.StandardButton.No
            )
            reply.setDefaultButton(QMessageBox.StandardButton.No)
            
            if reply.exec() == QMessageBox.StandardButton.Yes:
                self.is_closing = True
                loop = asyncio.get_event_loop()
                loop.create_task(self._handle_close())
                event.ignore()
            else:
                event.ignore()
        else:
            self.is_closing = True
            self._final_close()
            event.accept()

    async def _handle_close(self):
        try:
            await self.cleanup()
        except Exception as e:
            print(f"Error during cleanup: {e}")
        finally:
            await asyncio.sleep(0.5)
            QTimer.singleShot(100, self._final_close)

    def _final_close(self):
        try:
            # Cleanup local server
            if hasattr(self, 'local_server') and self.local_server:
                self.local_server.server = None
                self.local_server._serve_task = None
                self.local_server = None
            
            # Cleanup remote server
            if hasattr(self, 'remote_server') and self.remote_server:
                self.remote_server.server = None
                self.remote_server._serve_task = None
                self.remote_server = None
            
            self.close()
            
            app = QApplication.instance()
            if app:
                QTimer.singleShot(100, app.quit)
            
            QTimer.singleShot(200, lambda: sys.exit(0))
        except Exception as e:
            print(f"Error during final close: {e}")
            sys.exit(1)

    # Error handlers
    def handle_server_error(self, error: str):
        msg = QMessageBox(self)
        msg.setIcon(QMessageBox.Icon.Critical)
        msg.setWindowTitle("Server Error")
        msg.setText("Server error occurred:")
        msg.setInformativeText(error)
        msg.setStandardButtons(QMessageBox.StandardButton.Ok)
        msg.setStyleSheet("""
            QMessageBox {
                background-color: #1a1a1a;
            }
            QLabel {
                color: #ffffff;
                padding: 10px;
                font-size: 14px;
            }
            QPushButton {
                background-color: #802020;
                border: none;
                padding: 8px 16px;
                border-radius: 5px;
                color: white;
                font-weight: bold;
                min-width: 80px;
            }
            QPushButton:hover {
                background-color: #993333;
            }
        """)
        msg.exec()

    def handle_remote_server_error(self, error: str):
        msg = QMessageBox(self)
        msg.setIcon(QMessageBox.Icon.Critical)
        msg.setWindowTitle("Remote Server Error")
        msg.setText("Remote server error occurred:")
        msg.setInformativeText(error)
        msg.setStandardButtons(QMessageBox.StandardButton.Ok)
        msg.setStyleSheet("""
            QMessageBox {
                background-color: #1a1a1a;
            }
            QLabel {
                color: #ffffff;
                padding: 10px;
                font-size: 14px;
            }
            QPushButton {
                background-color: #802020;
                border: none;
                padding: 8px 16px;
                border-radius: 5px;
                color: white;
                font-weight: bold;
                min-width: 80px;
            }
            QPushButton:hover {
                background-color: #993333;
            }
        """)
        msg.exec()

    # Server control methods
    async def start_server(self):
        try:
            await self.local_server.start()
        except Exception as e:
            server_events.emit_server_error(str(e))

    async def stop_server(self):
        try:
            await self.local_server.stop()
        except Exception as e:
            server_events.emit_server_error(str(e))

    async def start_remote_server(self):
        try:
            print("here")
            await self.remote_server.start()
        except Exception as e:
            remote_server_events.emit_remote_server_error(str(e))

    async def stop_remote_server(self):
        try:
            await self.remote_server.stop()
        except Exception as e:
            remote_server_events.emit_remote_server_error(str(e))