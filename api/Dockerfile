FROM python:3.11-slim

WORKDIR /app

# System deps (optional but common for ML/fastapi stacks)
RUN apt-get update && apt-get install -y \
    build-essential \
    bash \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

CMD ["/bin/bash", "/app/entrypoint.sh"]