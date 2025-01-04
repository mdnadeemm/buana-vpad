FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Copy requirements first 
COPY remote_server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY remote_server/ .

EXPOSE 8080

# Langsung pakai uvicorn
CMD ["python", "main.py"]