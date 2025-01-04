import sys
import asyncio
from PyQt6.QtWidgets import QApplication
from src.gui.main_window import MainWindow
import qasync
from src.core.server_model import UvicornServer
from src.core.remote_server_model import RemoteUvicornServer

async def run_app():
    try:
        print("Starting application...")
        app = QApplication.instance() or QApplication(sys.argv)
        print("Created QApplication")
        
        loop = qasync.QEventLoop(app)
        asyncio.set_event_loop(loop)
        print("Created event loop")
        
        local_server = UvicornServer()
        remote_server = RemoteUvicornServer()
        print("Created servers")
        
        window = MainWindow(local_server, remote_server)
        print("Created main window")
        window.show()
        print("Window shown")
        
        print("Starting event loop")
        with loop:
            return await loop.run_forever()
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    try:
        asyncio.run(run_app())
    except KeyboardInterrupt:
        pass
    finally:
        sys.exit(0)