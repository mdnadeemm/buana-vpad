import asyncio
import qrcode
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, 
    QPushButton, QLabel, QTextEdit,
    QGroupBox, QSpinBox, QMessageBox,
    QScrollArea
)
from src.utils.config import settings
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QPixmap, QImage
from io import BytesIO
from src.gui.components.server_tab import DarkGroupBox
from src.utils.remote_server_events import remote_server_events

class RemoteServerTab(QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        self.server_running = False
        self.init_ui()
        self.connect_events()
        self.setup_styles()

    def setup_styles(self):
        # Main widget dark theme
        self.setStyleSheet("""
            QWidget {
                background-color: #121212;
                color: #ffffff;
                font-family: 'Segoe UI', Arial, sans-serif;
            }
            QLabel {
                color: #ffffff;
                padding: 2px;
            }
            QLabel[type="header"] {
                font-size: 16px;
                font-weight: bold;
                color: #ffffff;
            }
            QLabel[type="status"] {
                padding: 5px 10px;
                border-radius: 5px;
                font-weight: bold;
            }
            QLabel[status="running"] {
                background-color: rgba(77, 255, 77, 0.1);
                color: #4dff4d;
            }
            QLabel[status="stopped"] {
                background-color: rgba(255, 77, 77, 0.1);
                color: #ff4d4d;
            }
            QLabel[type="info"] {
                color: #999999;
            }
            QLabel[type="note"] {
                color: #666666;
                font-style: italic;
            }
            QPushButton {
                background-color: #2d2d2d;
                border: none;
                padding: 8px 16px;
                border-radius: 5px;
                color: white;
                font-weight: bold;
                min-width: 100px;
            }
            QPushButton:hover {
                background-color: #3d3d3d;
            }
            QPushButton:pressed {
                background-color: #404040;
            }
            QPushButton:disabled {
                background-color: #1a1a1a;
                color: #666666;
            }
            QPushButton#start {
                background-color: #2d5a27;
            }
            QPushButton#start:hover {
                background-color: #367032;
            }
            QPushButton#stop {
                background-color: #802020;
            }
            QPushButton#stop:hover {
                background-color: #993333;
            }
            QSpinBox {
                background-color: #2d2d2d;
                border: 1px solid #404040;
                border-radius: 4px;
                padding: 4px;
                color: white;
            }
            QSpinBox:disabled {
                background-color: #1a1a1a;
                color: #666666;
            }
            QTextEdit {
                background-color: #1a1a1a;
                border: 2px solid #333333;
                border-radius: 8px;
                padding: 8px;
                color: #cccccc;
                font-family: 'Consolas', 'Courier New', monospace;
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

    def init_ui(self):
        scroll = QScrollArea(self)
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setStyleSheet("QScrollArea { border: none; }")

        container = QWidget()
        scroll.setWidget(container)
        
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.addWidget(scroll)
        
        layout = QVBoxLayout(container)
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Status Group
        status_group = DarkGroupBox("Remote Server Status")
        status_layout = QHBoxLayout()
        
        status_header = QLabel("Current Status:")
        status_header.setProperty("type", "header")
        self.status_label = QLabel("Stopped")
        self.status_label.setProperty("type", "status")
        self.status_label.setProperty("status", "stopped")
        
        status_layout.addWidget(status_header)
        status_layout.addWidget(self.status_label)
        status_layout.addStretch()
        status_group.setLayout(status_layout)

        # Port configuration section
        port_group = DarkGroupBox("Port Configuration")
        port_layout = QHBoxLayout()
        
        port_label = QLabel("Remote Local Port:")
        port_label.setProperty("type", "info")
        self.port_spinbox = QSpinBox()
        self.port_spinbox.setRange(1024, 65535)
        self.port_spinbox.setValue(settings.REMOTE_LOCAL_PORT)
        self.port_spinbox.valueChanged.connect(self.port_changed)
        
        # Display remote server address
        remote_server_label = QLabel("Remote Server:")
        remote_server_label.setProperty("type", "info")
        remote_server_value = QLabel(settings.REMOTE_SERVER)
        remote_server_value.setProperty("type", "info")
        
        port_layout.addWidget(port_label)
        port_layout.addWidget(self.port_spinbox)
        port_layout.addStretch()
        port_layout.addWidget(remote_server_label)
        port_layout.addWidget(remote_server_value)
        port_group.setLayout(port_layout)

        # QR Code Group
        self.qr_group = DarkGroupBox("Connection QR Code")
        qr_layout = QVBoxLayout()
        
        self.qr_label = QLabel()
        self.qr_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.qr_info = QLabel("Scan this QR code with the mobile app to connect")
        self.qr_info.setProperty("type", "info")
        self.qr_info.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        self.unique_id_label = QLabel()
        self.unique_id_label.setProperty("type", "info")
        self.unique_id_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        qr_layout.addWidget(self.qr_label)
        qr_layout.addWidget(self.qr_info)
        qr_layout.addWidget(self.unique_id_label)
        self.qr_group.setLayout(qr_layout)
        self.qr_group.setVisible(False)

        # Control buttons
        button_group = DarkGroupBox("Remote Server Control")
        button_layout = QHBoxLayout()
        
        self.start_button = QPushButton("Start Remote Server")
        self.start_button.setObjectName("start")
        self.stop_button = QPushButton("Stop Remote Server")
        self.stop_button.setObjectName("stop")
        self.stop_button.setEnabled(False)
        
        button_layout.addWidget(self.start_button)
        button_layout.addWidget(self.stop_button)
        button_layout.addStretch()
        button_group.setLayout(button_layout)
        
        # Log viewer
        log_group = DarkGroupBox("Remote Server Log")
        log_layout = QVBoxLayout()
        
        self.log_viewer = QTextEdit()
        self.log_viewer.setReadOnly(True)
        self.log_viewer.setMinimumHeight(150)
        
        log_layout.addWidget(self.log_viewer)
        log_group.setLayout(log_layout)
        
        # Add all sections to main layout
        layout.addWidget(status_group)
        layout.addWidget(port_group)
        layout.addWidget(self.qr_group)
        layout.addWidget(button_group)
        layout.addWidget(log_group)
        layout.addStretch()
        
        # Connect button signals
        self.start_button.clicked.connect(self.start_server)
        self.stop_button.clicked.connect(self.stop_server)

    def connect_events(self):
        remote_server_events.remote_server_started.connect(self.handle_server_started)
        remote_server_events.remote_server_stopped.connect(self.handle_server_stopped)
        remote_server_events.remote_server_error.connect(self.handle_server_error)
        remote_server_events.remote_log_received.connect(self.log_message)

    def port_changed(self, new_port: int):
        if self.server_running:
            return
            
        if new_port < 1024:
            QMessageBox.warning(self, "Invalid Port", "Port number must be above 1024!")
            self.port_spinbox.setValue(settings.REMOTE_LOCAL_PORT)
            return
            
        settings.REMOTE_LOCAL_PORT = new_port
        self.log_message(f"Remote local port changed to: {new_port}")

    def generate_qr_code(self, unique_id: str):
        try:
            # Generate connection string
            conn_string = f"{settings.REMOTE_SERVER}/ws/{unique_id}"
            
            # Create QR code
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(conn_string)
            qr.make(fit=True)

            # Create image
            img = qr.make_image(fill_color="white", back_color="transparent")
            
            # Convert to QPixmap
            buffer = BytesIO()
            img.save(buffer, format='PNG')
            qimage = QImage.fromData(buffer.getvalue())
            pixmap = QPixmap.fromImage(qimage)
            
            # Scale to reasonable size
            pixmap = pixmap.scaledToWidth(200, Qt.TransformationMode.SmoothTransformation)
            
            # Update GUI
            self.qr_label.setPixmap(pixmap)
            self.unique_id_label.setText(f"Unique ID: {unique_id}")
            self.qr_group.setVisible(True)
            
        except Exception as e:
            self.log_message(f"Error generating QR code: {e}")

    def handle_server_started(self, unique_id: str):
        self.server_running = True
        self.status_label.setText("Running")
        self.status_label.setProperty("status", "running")
        self.start_button.setEnabled(False)
        self.stop_button.setEnabled(True)
        self.port_spinbox.setEnabled(False)
        self.generate_qr_code(unique_id)
        self.log_message("Remote server started successfully")
        self.status_label.style().unpolish(self.status_label)
        self.status_label.style().polish(self.status_label)

    def handle_server_stopped(self):
        self.server_running = False
        self.status_label.setText("Stopped")
        self.status_label.setProperty("status", "stopped")
        self.start_button.setEnabled(True)
        self.stop_button.setEnabled(False)
        self.port_spinbox.setEnabled(True)
        self.qr_group.setVisible(False)
        self.log_message("Remote server stopped")
        self.status_label.style().unpolish(self.status_label)
        self.status_label.style().polish(self.status_label)

    def handle_server_error(self, error: str):
        self.log_message(f"Remote Server Error: {error}")
        self.handle_server_stopped()

    def start_server(self):
        if not self.server_running:
            self.log_message("Starting remote server...")
            asyncio.create_task(self.main_window.start_remote_server())

    def stop_server(self):
        if self.server_running:
            self.log_message("Stopping remote server...")
            asyncio.create_task(self.main_window.stop_remote_server())

    def log_message(self, message: str):
        self.log_viewer.append(message)
        scrollbar = self.log_viewer.verticalScrollBar()
        scrollbar.setValue(scrollbar.maximum())