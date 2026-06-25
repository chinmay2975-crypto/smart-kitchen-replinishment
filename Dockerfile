# ============================================================
# Smart Kitchen Replenishment System — Dockerfile
# Deploy to Render, Railway, Fly.io, or any container platform
# ============================================================

FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Set working directory
WORKDIR /app

# Install system dependencies (for psycopg2 / asyncpg if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Expose the port the app runs on
EXPOSE 8000

# Run the application
# Render provides the PORT environment variable automatically
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --forwarded-allow-ips '*'