FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim

# UV configuration:
# - UV_CACHE_DIR: package download cache, maps to a named Docker volume at runtime
# - UV_LINK_MODE=copy: required when the cache and venv are on different filesystems
# - UV_PROJECT_ENVIRONMENT: where uv creates/syncs the venv
ENV UV_CACHE_DIR=/uv-cache \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/workspace/.venv

# Create non-root user with bash as the default shell
RUN groupadd --gid 1000 dev && \
    useradd --uid 1000 --gid 1000 --shell /bin/bash --create-home dev

# Install system packages required to build Python extensions from source
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create volume mount points and set ownership to dev.
# Docker initializes named volumes from the image directory at mount time —
# these must be dev-owned so uv can write to them when it runs at startup.
RUN mkdir -p /uv-cache /workspace/.venv && \
    chown -R dev:dev /uv-cache /workspace

USER dev

# Auto-activate the venv in every bash terminal (VS Code integrated terminal included)
RUN echo 'source /workspace/.venv/bin/activate' >> /home/dev/.bashrc

WORKDIR /workspace
