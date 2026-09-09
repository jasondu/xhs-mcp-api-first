FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/data \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

WORKDIR /app

COPY pyproject.toml README.md LICENSE ./
COPY src ./src

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && pip install --no-cache-dir '.[qrcode]' \
    && python -m playwright install --with-deps chromium \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 10001 xhsmcp \
    && useradd --uid 10001 --gid 10001 --create-home --home-dir /data xhsmcp \
    && mkdir -p /data/.xhs-mcp /data/publish-input \
    && chown -R xhsmcp:xhsmcp /data

USER xhsmcp

EXPOSE 18061

CMD ["xhs-mcp", "--transport", "http", "--port", "18061"]
