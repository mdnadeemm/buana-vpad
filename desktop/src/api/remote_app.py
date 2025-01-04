import uuid
import asyncio
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from src.core.remote_controller_manager import RemoteControllerManager
from src.utils.remote_server_events import remote_server_events
from src.utils.config import settings
import websockets
import json

remote_controller_manager = RemoteControllerManager()
DEVICE_ID = str(uuid.uuid4())
remote_ws = None

def create_app(unique_id: str):
    async def handle_remote_messages():
        global remote_ws
        while remote_ws:
            try:
                if remote_ws:
                    message = await remote_ws.recv()
                    data = json.loads(message)
                    
                    if data.get("type") == "connect":
                        device_id = data.get("device_id")
                        device_name = data.get("device_name", "Unknown Device")
                        
                        try:
                            await remote_controller_manager.add_client(device_id, device_name)
                            await remote_ws.send(json.dumps({
                                "type": "connect_success",
                                "device_type": "pc",
                                "device_id": device_id
                            }))
                            remote_server_events.emit_remote_log(f"Client connected: {device_name} ({device_id})")
                        except Exception:
                            await remote_ws.send(json.dumps({
                                "type": "connect_error",
                                "device_id": device_id,
                                "device_type": "pc",
                                "message": "Failed to connect"
                            }))
                    
                    elif data.get("type") == "disconnect":
                        device_id = data.get("device_id")
                        await remote_controller_manager.remove_client(device_id)
                        remote_server_events.emit_remote_log(f"Client disconnected: {device_id}")
                    
                    elif data.get("type") == "controller_input":
                        device_id = data.get("device_id")
                        if device_id in remote_controller_manager.controllers:
                            try:
                                await remote_controller_manager.handle_input(
                                    device_id,
                                    data.get("data", {})
                                )
                            except Exception as e:
                                remote_server_events.emit_remote_log(
                                    f"Error handling input from {device_id}: {e}",
                                    level="ERROR"
                                )
                    
            except websockets.exceptions.ConnectionClosed:
                break
            except Exception:
                await asyncio.sleep(1)
                continue

        remote_server_events.emit_remote_log("Remote message handler stopped")

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        global remote_ws
        try:
            remote_url = f"ws://{settings.REMOTE_SERVER}/ws/{unique_id}"
            remote_ws = await websockets.connect(remote_url)
            
            remote_server_events.emit_remote_log(f"Connected to remote server at {remote_url}")
            
            await remote_ws.send(json.dumps({
                "device_type": "pc",
                "device_id": DEVICE_ID
            }))
            
            message_handler = asyncio.create_task(handle_remote_messages())
            
            # Yang penting: yield harus tetap dieksekusi meski ada error
            yield
            
            # Cancel message handler saat shutdown
            if not message_handler.done():
                message_handler.cancel()
                
        except Exception as e:
            remote_server_events.emit_remote_server_error(str(e))
            # Tetap yield untuk handle error case
            yield
        finally:
            # Cleanup
            if remote_ws:
                await remote_ws.close()
            remote_ws = None
            # Clear manager state juga
            await remote_controller_manager.clear()
            remote_server_events.emit_remote_log("Remote connection closed")

    app = FastAPI(title=f"{settings.APP_NAME}-Remote", lifespan=lifespan)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/")
    async def root():
        return {
            "status": "running",
            "mode": "remote",
            "connected_to": f"ws://{settings.REMOTE_SERVER}/ws/{unique_id}",
            "unique_id": unique_id,
            "connected_clients": len(remote_controller_manager.controllers)
        }

    @app.websocket("/ws/status")
    async def status_endpoint(websocket: WebSocket):
        await websocket.accept()
        try:
            while True:
                try:
                    clients_info = [
                        {
                            "device_id": device_id,
                            "device_name": client["name"]
                        }
                        for device_id, client in remote_controller_manager.controllers.items()
                    ]
                    
                    await websocket.send_json({
                        "type": "status",
                        "connected": remote_ws is not None and not remote_ws.closed,
                        "server": settings.REMOTE_SERVER,
                        "unique_id": unique_id,
                        "connected_clients": clients_info
                    })
                    await asyncio.sleep(1)
                except Exception:
                    break
        except Exception:
            pass

    return app