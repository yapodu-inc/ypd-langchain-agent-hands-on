FROM python:3.13.3-slim

# Install Node.js for MCP server
RUN apt-get update && apt-get install -y \
    curl \
    && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ../app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ../app/ .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
