import asyncio
import uuid
import uvicorn
from src.utils.remote_server_events import remote_server_events
from src.utils.config import settings

class RemoteUvicornServer:
    def __init__(self):
        self.config = None
        self.server = None
        self._serve_task = None
        self.unique_id = None
        
    @property
    def is_running(self):
        return self._serve_task is not None and not self._serve_task.done()
        
    def _create_config(self):
        from src.api.remote_app import create_app
        return uvicorn.Config(
            app=create_app(self.unique_id),
            host=settings.HOST,
            port=settings.REMOTE_LOCAL_PORT,
            reload=False,
            loop="asyncio"
        )
        
    async def start(self):
        if not self._serve_task:
            try:
                self.unique_id = str(uuid.uuid4())
                self.config = self._create_config()
                self.server = uvicorn.Server(self.config)
                self._serve_task = asyncio.create_task(self.server.serve())
                remote_server_events.emit_remote_server_start(self.unique_id)
            except Exception as e:
                remote_server_events.emit_remote_server_error(str(e))
    
    async def stop(self):
        if self._serve_task:
            try:
                if self.server:
                    self.server.should_exit = True
                    try:
                        await self.server.shutdown()
                        await asyncio.sleep(0.5)  # Tambahan delay kecil setelah shutdown
                    except Exception:
                        pass
                        
                if not self._serve_task.done():
                    self._serve_task.cancel()
                    try:
                        await asyncio.wait_for(self._serve_task, timeout=2.0)
                    except (asyncio.CancelledError, asyncio.TimeoutError):
                        pass
                        
            except Exception as e:
                remote_server_events.emit_remote_server_error(str(e))
            finally:
                self._serve_task = None
                if hasattr(self, 'server'):
                    self.server = None
                if hasattr(self, 'config'):
                    self.config = None
                if hasattr(self, 'unique_id'):
                    self.unique_id = None
                remote_server_events.emit_remote_server_stop()
                remote_server_events.emit_remote_log("Remote server stopped")