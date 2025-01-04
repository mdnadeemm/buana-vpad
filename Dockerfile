FROM python:3.11-slim
WORKDIR /app/remote_server
COPY remote_server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY remote_server/ .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]