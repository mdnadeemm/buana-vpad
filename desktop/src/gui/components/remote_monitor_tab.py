from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QGridLayout,
    QScrollArea
)
from PyQt6.QtCore import Qt
from src.utils.remote_server_events import remote_server_events
from src.gui.components.monitor_tab import ControllerCard  # Reuse ControllerCard

class RemoteConnectionsMonitorTab(QWidget):
    def __init__(self):
        super().__init__()
        self.controller_cards = []
        self.active_cards = {}
        self.init_ui()
        self.connect_events()

    def connect_events(self):
        # Connect to remote server events
        remote_server_events.remote_update_controller_card.connect(self.handle_controller_update)
        remote_server_events.remote_server_stopped.connect(self.handle_server_stopped)
        remote_server_events.remote_controller_input.connect(self.handle_controller_input)

    def handle_controller_input(self, device_id: str, input_data: dict):
        """Handle input dari controller specific device"""
        if device_id not in self.active_cards:
            return
            
        card = self.controller_cards[self.active_cards[device_id]]
        
        # Update buttons
        button_states = input_data.get("buttonStates", {})
        for button_id, state in button_states.items():
            card.update_button(
                button_id, 
                state.get("isPressed", False),
                state.get("value", 1.0)
            )
        
        # Update sticks
        left_joy = input_data.get("leftJoystickState", {})
        if left_joy:
            card.update_stick(
                "left",
                left_joy.get("dx", 0),
                left_joy.get("dy", 0)
            )
            
        right_joy = input_data.get("rightJoystickState", {})
        if right_joy:
            card.update_stick(
                "right",
                right_joy.get("dx", 0),
                right_joy.get("dy", 0)
            )
        
        # Update DPAD
        dpad = input_data.get("dpadState", {})
        if dpad:
            card.update_dpad(
                dpad.get("upPressed", False),
                dpad.get("rightPressed", False),
                dpad.get("downPressed", False),
                dpad.get("leftPressed", False)
            )

    def handle_server_stopped(self):
        """Reset all controller cards when server stops"""
        # Reset semua card ke status disconnected
        for card in self.controller_cards:
            card.update_status(False)
        
        # Clear tracking active cards
        self.active_cards.clear()

    def handle_controller_update(self, controller_info: dict):
        """Handle controller card updates"""
        device_id = controller_info.get("device_id", "")
        connected = controller_info.get("connected", False)
        
        if connected:
            # Jika belum ada di active_cards, cari index yang available
            if device_id not in self.active_cards:
                used_indices = set(self.active_cards.values())
                available_indices = [i for i in range(len(self.controller_cards)) if i not in used_indices]
                
                if available_indices:
                    index = available_indices[0]
                    self.active_cards[device_id] = index
                else:
                    return  # Tidak ada slot tersedia
            
            index = self.active_cards[device_id]
        else:
            # Jika disconnect, ambil indexnya lalu hapus dari tracking
            if device_id not in self.active_cards:
                return
            index = self.active_cards[device_id]
            del self.active_cards[device_id]
        
        # Update card di index tersebut
        self.controller_cards[index].update_status(
            connected,
            controller_info.get("device_name", ""),
            device_id
        )
        
    def init_ui(self):
        # Dark theme for main widget
        self.setStyleSheet("""
            QWidget {
                background: #121212;
            }
            QScrollBar:vertical {
                background: #2a2a2a;
                width: 12px;
                margin: 0px;
            }
            QScrollBar::handle:vertical {
                background: #404040;
                border-radius: 6px;
                min-height: 20px;
                margin: 2px;
            }
            QScrollBar::handle:vertical:hover {
                background: #4a4a4a;
            }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                height: 0px;
            }
            QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {
                background: none;
            }
        """)

        # Create scroll area untuk vertical scrolling
        scroll = QScrollArea(self)
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        scroll.setStyleSheet("QScrollArea { border: none; }")

        # Container untuk grid
        container = QWidget()
        scroll.setWidget(container)

        # Main layout untuk scroll area
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.addWidget(scroll)
        
        # Grid layout untuk cards
        self.grid = QGridLayout(container)
        self.grid.setSpacing(15)
        self.grid.setContentsMargins(15, 15, 15, 15)
        
        # Create 4 controller cards
        for i in range(4):
            card = ControllerCard(i + 1)
            self.controller_cards.append(card)
            # Initial placement will be updated in resizeEvent
            self.grid.addWidget(card, i, 0)
    
    def resizeEvent(self, event):
        super().resizeEvent(event)
        width = event.size().width()
        
        # Reorganize grid based on width
        # Jika width cukup besar (>1000px), gunakan 2 kolom
        # Jika tidak, gunakan 1 kolom
        use_two_columns = width > 1000
        
        # Remove semua widget dari grid
        for card in self.controller_cards:
            self.grid.removeWidget(card)
        
        # Reassign widgets ke grid dengan layout baru
        for i, card in enumerate(self.controller_cards):
            if use_two_columns:
                row, col = divmod(i, 2)
                self.grid.addWidget(card, row, col)
            else:
                self.grid.addWidget(card, i, 0)
        
        # Update stretching
        if use_two_columns:
            for i in range(2):
                self.grid.setColumnStretch(i, 1)
        else:
            self.grid.setColumnStretch(0, 1)
            if self.grid.columnCount() > 1:
                self.grid.setColumnStretch(1, 0)