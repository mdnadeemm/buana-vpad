import uvicorn
from src.core.app import app

if __name__ == "__main__":
    uvicorn.run(
        app,
        host='0.0.0.0',
        port=8080,
        access_log=True
    )