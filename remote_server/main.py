import uvicorn
from src.core.app import app
from src.utils.config import settings

if __name__ == "__main__":
    uvicorn.run(
        app,
        host=settings.HOST,
        port=settings.PORT,
        reload=False  # or just remove this line
    )