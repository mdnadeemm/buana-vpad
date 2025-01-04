from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict

app = FastAPI(title="Vpad Remote Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

connections: Dict[str, Dict] = {}

@app.get("/")
async def root():
    print("Hey bro")
    return {"status": "running"}

@app.websocket("/ws/{unique_id}")
async def websocket_endpoint(websocket: WebSocket, unique_id: str):
    await websocket.accept()
    device_id = None
    device_name = None
    
    try:
        # Initial connection data
        data = await websocket.receive_json()
        device_type = data.get("device_type")
        device_id = data.get("device_id")
        device_name = data.get("device_name", "Unknown Device")
        
        # Initialize connection structure if needed
        if unique_id not in connections:
            connections[unique_id] = {
                "pc": None,
                "mobile": {}
            }
            
        # Handle PC connection
        if device_type == "pc":
            print("PC CONNECTED...")
            connections[unique_id]["pc"] = websocket
            # Notify all mobile devices that PC is connected
            for mobile_ws in connections[unique_id]["mobile"].values():
                await mobile_ws.send_json({
                    "type": "pc_connected",
                    "unique_id": unique_id
                })
        # Handle mobile connection
        else:
            # Send connect message to PC
            if connections[unique_id]["pc"]:
                await connections[unique_id]["pc"].send_json({
                    "type": "connect",
                    "device_id": device_id,
                    "device_name": device_name
                })
                connections[unique_id]["mobile"][device_id] = websocket

        while True:
            data = await websocket.receive_json()
            
            # Handle ping/pong
            if data.get("type") == "ping":
                await websocket.send_json({"type": "pong"})
                continue
                
            # Handle messages from PC
            if device_type == "pc":
                # Broadcast to all mobile devices
                for mobile_ws in connections[unique_id]["mobile"].values():
                    await mobile_ws.send_json(data)
                    
            # Handle messages from mobile
            else:
                if connections[unique_id]["pc"]:
                    if data.get("type") == "controller_input":
                        # Forward controller input to PC
                        await connections[unique_id]["pc"].send_json({
                            "type": "controller_input",
                            "device_id": device_id,
                            "data": data.get("data", {})
                        })
                    else:
                        # Forward other messages as is
                        await connections[unique_id]["pc"].send_json(data)
                    
    except WebSocketDisconnect:
        if device_type == "pc":
            print("PC DISCONNECTED")
            # Notify all mobile devices about PC disconnect
            for mobile_ws in connections[unique_id]["mobile"].values():
                await mobile_ws.send_json({
                    "type": "pc_disconnected",
                    "message": "PC has disconnected"
                })
        else:
            # Notify PC about mobile device disconnect
            print("MOBILE DISCONNECTED")
            if connections[unique_id]["pc"]:
                await connections[unique_id]["pc"].send_json({
                    "type": "disconnect",
                    "device_id": device_id,
                    "device_name": device_name
                })
        
    finally:
        if unique_id in connections:
            # Clean up connections
            if device_type == "pc":
                print("REMOVE PC")
                connections[unique_id]["pc"] = None
            elif device_id and device_id in connections[unique_id]["mobile"]:
                print("REMOVE MOBILE")
                connections[unique_id]["mobile"].pop(device_id)
            
            # Remove unique_id if no connections left
            if not connections[unique_id]["pc"] and not connections[unique_id]["mobile"]:
                print("REMOVE ALL")
                connections.pop(unique_id)