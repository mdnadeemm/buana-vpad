from PyQt6.QtCore import QObject, pyqtSignal
import queue

class RemoteServerEvents(QObject):
    # Signals
    remote_server_started = pyqtSignal(str)
    remote_server_stopped = pyqtSignal()
    remote_server_error = pyqtSignal(str)
    remote_log_received = pyqtSignal(str)
    remote_client_connected = pyqtSignal(str, str)  # device_id, device_name
    remote_client_disconnected = pyqtSignal(str)  # device_id
    remote_update_controller_card = pyqtSignal(dict)
    remote_controller_input = pyqtSignal(str, dict)
    remote_connection_established = pyqtSignal(str)  # unique_id
    remote_connection_lost = pyqtSignal()
    
    def __init__(self):
        super().__init__()
        self.log_queue = queue.Queue()
        self.is_remote_server_running = False
        self.is_connected_to_remote = False
        self.remote_unique_id = None
        
    def emit_remote_server_start(self, unique_id: str):  # Menambahkan parameter unique_id
        self.is_remote_server_running = True
        self.remote_server_started.emit(unique_id)
        self.emit_remote_log("Remote server started")
        
    def emit_remote_server_stop(self):
        self.is_remote_server_running = False
        self.remote_server_stopped.emit()
        self.emit_remote_log("Remote server stopped")
        
    def emit_remote_server_error(self, error: str):
        self.remote_server_error.emit(error)
        self.emit_remote_log(f"Error: {error}", level="ERROR")
        
    def emit_remote_log(self, message: str, level: str = "INFO"):
        self.log_queue.put((level, message))
        self.remote_log_received.emit(f"[{level}] {message}")
        
    def emit_remote_client_connected(self, device_id: str, device_name: str):
        self.remote_client_connected.emit(device_id, device_name)
        self.emit_remote_log(f"Remote client connected: {device_name} ({device_id})")
        
    def emit_remote_client_disconnected(self, device_id: str, device_name: str):
        self.remote_client_disconnected.emit(device_id)
        self.emit_remote_log(f"Remote client disconnected: {device_name} ({device_id})")
        
    def emit_remote_controller_update(self, controller_info: dict):
        self.remote_update_controller_card.emit(controller_info)

    def emit_remote_controller_input(self, device_id: str, input_data: dict):
        formatted_data = {}
        
        # Handle button states
        button_states = input_data.get("buttonStates", {})
        formatted_buttons = {}
        for button_id, state in button_states.items():
            formatted_buttons[f"_{button_id.upper()}"] = {
                "isPressed": state.get("isPressed", False),
                "value": state.get("value", 0)
            }
        formatted_data["buttonStates"] = formatted_buttons
        
        # Handle dpad
        dpad = input_data.get("dpadState", {})
        formatted_data["dpadState"] = {
            "upPressed": dpad.get("upPressed", False),
            "rightPressed": dpad.get("rightPressed", False),
            "downPressed": dpad.get("downPressed", False),
            "leftPressed": dpad.get("leftPressed", False)
        }
        
        # Handle joysticks
        formatted_data["leftJoystickState"] = input_data.get("leftJoystickState", {})
        formatted_data["rightJoystickState"] = input_data.get("rightJoystickState", {})
        
        self.remote_controller_input.emit(device_id, formatted_data)

    def emit_remote_connection_established(self, unique_id: str):
        self.is_connected_to_remote = True
        self.remote_unique_id = unique_id
        self.remote_connection_established.emit(unique_id)
        self.emit_remote_log(f"Connected to remote server. Unique ID: {unique_id}")
        
    def emit_remote_connection_lost(self):
        self.is_connected_to_remote = False
        self.remote_unique_id = None
        self.remote_connection_lost.emit()
        self.emit_remote_log("Lost connection to remote server")

# Global instance
remote_server_events = RemoteServerEvents()