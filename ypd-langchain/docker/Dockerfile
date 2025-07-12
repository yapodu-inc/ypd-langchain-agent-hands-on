FROM python:3.13.3-slim

# Install Node.js for MCP server
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR /app

COPY ../app/pyproject.toml ../app/uv.lock ./

RUN uv export --no-dev --no-hashes > requirements.txt && \
    pip install --no-cache-dir --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org -r requirements.txt

# Copy app
COPY ../app/ .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]