# ghcr.io/latentsp-hiring/tidewater-base
#
# Every Tidewater submission's final build stage must start FROM this image. It
# provides what the grader needs next to your service: Python 3.12, sqlite3 and curl.
# It also ships the default /app/migrate, which applies /app/migrations/*.sql in order.
#
# Your own Dockerfile can use any stack in earlier stages. Only the final stage
# must be FROM this image, with your executables at /app/start and /app/migrate.
FROM python:3.12-slim-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends sqlite3 curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY migrate /app/migrate
RUN chmod 0755 /app/migrate && mkdir -p /app/migrations
