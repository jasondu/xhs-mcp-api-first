# Deployment and migration

## Prerequisites

- Linux amd64 host with Docker Engine and Docker Compose
- At least 3 GB of free disk space
- Persistent host directories for login state and publish inputs
- For public access: a DNS A/AAAA record, inbound TCP 80/443, nginx, and Certbot

## Start

```bash
cp .env.example .env
mkdir -p data/xhs-state data/publish-input
sudo chown -R 10001:10001 data/xhs-state
docker login ghcr.io
docker compose --env-file .env pull
docker compose --env-file .env up -d
docker compose ps
```

Copy an existing `cookies.json` into `data/xhs-state/` with mode `0600`, then
call `reload_cookies` and `check_login_status`.

## Public HTTPS

1. Generate a random token with `openssl rand -hex 32`.
2. Replace `__MCP_DOMAIN__`, `__MCP_BEARER_TOKEN__`, and `__MCP_PORT__` in
   `nginx.conf.template` and install it as a root-owned nginx config.
3. Obtain a Let's Encrypt certificate with the webroot
   `/var/www/letsencrypt`.
4. Validate that no token returns HTTP 401 and the correct token can run MCP
   `initialize`, `tools/list`, and `check_login_status`.

Never commit the rendered nginx file because it contains the Bearer token.

## Login-state migration

Stop the MCP container before copying `data/xhs-state`. Transfer it through an
encrypted channel, preserve restrictive permissions, start the container, and
verify login before publishing. Do not store Cookie or browser-profile backups
in Git or container images.

## Upgrade and rollback

Set `XHS_MCP_VERSION` in `.env` to an immutable release tag, then run:

```bash
docker compose --env-file .env pull
docker compose --env-file .env up -d
```

Rollback uses the same commands after restoring the previous version tag.
