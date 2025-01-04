from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "Desktop Controller"
    BROADCAST_PORT: int = 8081
    DEBUG: bool = True
    HOST: str = "0.0.0.0"
    PORT: int = 8058
    REMOTE_SERVER: str = "localhost:8000"
    REMOTE_LOCAL_PORT: int = 8052

settings = Settings()
