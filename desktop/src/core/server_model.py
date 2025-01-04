import asyncio

import uvicorn
from src.api import app
from src.utils.server_events import server_events
from src.utils.config import settings


class UvicornServer:
    def __init__(self):
        self.config = None
        self.server = None
        self._serve_task = None
        
    def _create_config(self):
        return uvicorn.Config(
            app=app,
            host=settings.HOST,
            port=settings.PORT,
            reload=False,
            loop="asyncio"
        )
        
    async def start(self):
        if not self._serve_task:
            try:
                self.config = self._create_config()
                self.server = uvicorn.Server(self.config)
                self._serve_task = asyncio.create_task(self.server.serve())
                server_events.emit_server_start()
            except Exception as e:
                server_events.emit_server_error(str(e))
    
    async def stop(self):
        if self._serve_task:
            try:
                if self.server:
                    self.server.should_exit = True
                    try:
                        await self.server.shutdown()
                        await asyncio.sleep(0.5)
                    except Exception:
                        pass

                if not self._serve_task.done():
                    self._serve_task.cancel()
                    try:
                        await asyncio.wait_for(self._serve_task, timeout=2.0)
                    except (asyncio.CancelledError, asyncio.TimeoutError):
                        pass

            except Exception as e:
                server_events.emit_server_error(str(e))
            finally:
                self._serve_task = None
                if hasattr(self, 'server'):
                    self.server = None
                if hasattr(self, 'config'):
                    self.config = None
                server_events.emit_server_stop()