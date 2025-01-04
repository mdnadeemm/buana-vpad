import vgamepad as vg
from typing import Dict, Optional
from src.utils.remote_server_events import remote_server_events  # Import remote events

class RemoteControllerManager:
    def __init__(self):
        self.controllers: Dict[str, dict] = {}  # {device_id: {gamepad, name}}
        self.max_clients = 4

    async def add_client(self, device_id: str, device_name: str) -> Optional[dict]:
        if len(self.controllers) >= self.max_clients:
            raise Exception("Maximum controllers reached")
            
        if device_id in self.controllers:
            raise Exception("Device already connected")
            
        gamepad = vg.VX360Gamepad()
        client = {
            "gamepad": gamepad,
            "name": device_name
        }

        controller_info = {
            "device_name": device_name,
            "device_id": device_id,
            "connected": True,
        }
        self.controllers[device_id] = client
        print(f"Remote client connected: {device_name} ({device_id})")
        remote_server_events.emit_remote_client_connected(device_id, device_name)
        remote_server_events.emit_remote_controller_update(controller_info=controller_info)
        return client

    async def remove_client(self, device_id: str):
        if device_id in self.controllers:
            client = self.controllers[device_id]
            print(f"Remote client disconnected: {client['name']} ({device_id})")
            controller_info = {
                "device_name": client['name'],
                "device_id": device_id,
                "connected": False,
            }
            remote_server_events.emit_remote_controller_update(controller_info=controller_info)
            remote_server_events.emit_remote_client_disconnected(device_id, client['name'])
            del self.controllers[device_id]

    async def handle_input(self, device_id: str, data: dict):
        if device_id not in self.controllers:
            return
            
        gamepad = self.controllers[device_id]["gamepad"]
        client_name = self.controllers[device_id]["name"]
        
        try:
            remote_server_events.emit_remote_controller_input(device_id, data)
            # Handle button states
            button_states = data.get("buttonStates", {})
            for button_id, state in button_states.items():
                self._handle_button(gamepad, button_id, state)

            # Handle joysticks
            left_joy = data.get("leftJoystickState")
            right_joy = data.get("rightJoystickState")
            if left_joy and (left_joy.get("dx") != 0 or left_joy.get("dy") != 0):
                gamepad.left_joystick_float(
                    x_value_float=left_joy.get("dx", 0.0),
                    y_value_float=-left_joy.get("dy", 0.0)  # Invert Y axis
                )
            if right_joy and (right_joy.get("dx") != 0 or right_joy.get("dy") != 0):
                gamepad.right_joystick_float(
                    x_value_float=right_joy.get("dx", 0.0),
                    y_value_float=-right_joy.get("dy", 0.0)  # Invert Y axis
                )

            # Handle DPAD
            dpad = data.get("dpadState", {})
            self._handle_dpad(gamepad, dpad)

            # Apply changes
            gamepad.update()

        except Exception as e:
            print(f"Error processing remote input: {e}")
            raise

    def _handle_button(self, gamepad, button_id: str, state: dict):
        actual_button_id = button_id.split('_')[-1]
        
        button_mapping = {
            'A': vg.XUSB_BUTTON.XUSB_GAMEPAD_A,
            'B': vg.XUSB_BUTTON.XUSB_GAMEPAD_B,
            'X': vg.XUSB_BUTTON.XUSB_GAMEPAD_X,
            'Y': vg.XUSB_BUTTON.XUSB_GAMEPAD_Y,
            'LB': vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER,
            'RB': vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER,
            'Start': vg.XUSB_BUTTON.XUSB_GAMEPAD_START,
            'Select': vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK,
        }

        if actual_button_id in button_mapping:
            if state.get("isPressed"):
                gamepad.press_button(button=button_mapping[actual_button_id])
            else:
                gamepad.release_button(button=button_mapping[actual_button_id])

        elif actual_button_id == 'LT':
            gamepad.left_trigger_float(value_float=state.get("value", 0.0))
        elif actual_button_id == 'RT':
            gamepad.right_trigger_float(value_float=state.get("value", 0.0))

    def _handle_dpad(self, gamepad, dpad_state: dict):
        if dpad_state.get("upPressed"):
            gamepad.press_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP)
        else:
            gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP)
            
        if dpad_state.get("downPressed"):
            gamepad.press_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN)
        else:
            gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN)
            
        if dpad_state.get("leftPressed"):
            gamepad.press_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT)
        else:
            gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT)
            
        if dpad_state.get("rightPressed"):
            gamepad.press_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT)
        else:
            gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT)