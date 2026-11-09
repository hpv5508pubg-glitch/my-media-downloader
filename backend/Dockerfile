FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=7860

# Install system dependencies: ffmpeg, curl, ca-certificates
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set up user for Hugging Face Spaces compatibility (UID 1000)
RUN useradd -m -u 1000 user
WORKDIR /app

# Ensure /tmp has full permissions for ephemeral file operations
RUN chmod 777 /tmp

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code and assign ownership to user
COPY --chown=user:user . /app

# Switch to non-root user
USER user

EXPOSE 7860

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7860"]
