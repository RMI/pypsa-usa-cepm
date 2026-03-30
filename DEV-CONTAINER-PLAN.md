# Dev Container Implementation Plan: PyPSA-USA with UV

## Overview

This document is the implementation plan for a Docker Compose–based dev container for PyPSA-USA. It records the decisions made, the rationale behind them, and the step-by-step procedure to build and validate the container.

---

## Decisions Made

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 1 | Base image | `ghcr.io/astral-sh/uv:python3.11-bookworm-slim` | Purpose-built for UV workflows; Python 3.11 and UV pre-installed at pinned versions |
| 2 | System libraries | Start minimal, iterate | Keeps image lean; documents exactly what's needed rather than guessing |
| 3 | `.venv` location | Named Docker volume | Avoids Windows↔Linux filesystem overhead on thousands of small venv files |
| 4 | Watch scope | `uv.lock` + `pyproject.toml` → rebuild; `workflow/` → sync | Catches dependency changes while keeping source edits fast |
| 5 | Cluster support | Local-only | HPC runs should be submitted directly from the cluster environment |
| 6 | Gurobi license | Optional volume mount | No license currently; HiGHS is the fallback solver |
| 7 | Ports | 8888 (Jupyter), 8787 (Dask), 8000 (Sphinx) | Low cost to expose; available when needed |
| 8 | User | Non-root `dev` at UID 1000 | Best practice; VS Code Dev Containers is designed around this pattern |
| 9 | VS Code extensions | python, pylance, ruff, jupyter, snakemake-lang, mypy | Covers linting, type checking, notebooks, and Snakemake syntax |

---

## Prerequisites (Machine Requirements)

Before anyone can use this dev container, their machine needs:

1. **Docker Desktop ≥ 4.24** (or Docker Engine + Docker Compose plugin ≥ 2.22 on Linux)
   - Required for Compose `watch` support (`develop.watch` key)
   - On Windows, Docker Desktop uses WSL2 as its backend — WSL2 must be installed and up to date

2. **VS Code** with the **Dev Containers extension** (`ms-vscode-remote.remote-containers`)

3. **Disk space** — the UV package cache and virtual environment for this project are large due to GIS and scientific Python dependencies. Budget at least 5 GB for Docker volumes.

4. **RAM** — Snakemake workflows can be memory-intensive. 16 GB minimum, 32 GB recommended for larger runs.

5. **Git** configured on the host — the container will inherit host Git credentials via a volume mount so commits work from inside the container.

6. **EIA API key** (optional, for dynamic fuel pricing) — stored in `workflow/config/config.api.yaml` after running `init_pypsa_usa.sh`. Not needed for basic workflow runs.

7. **Gurobi license** (optional) — if you have a `~/gurobi.lic` file on the host, the Compose file will mount it into the container automatically. If absent, HiGHS is used as the solver.

---

## Proposed File Structure

```
pypsa-usa-cepm/
├── .devcontainer/
│   └── devcontainer.json       # Minimal — delegates to docker-compose.yml
├── docker-compose.yml          # Main Compose file with watch config
├── Dockerfile                  # Image definition
├── .dockerignore               # Excludes .venv, __pycache__, large data dirs
├── DEV-CONTAINER-PLAN.md       # This file
└── DEV-CONTAINER-GUIDE.md      # User-facing guide
```

---

## Implementation Steps

### Step 1: Write `.dockerignore`

Before writing the Dockerfile, create `.dockerignore` to prevent large or irrelevant directories from being sent to the Docker build context. At minimum, exclude:

```
.venv/
__pycache__/
*.pyc
.git/
```

Check the `.gitignore` for other large data directories (e.g., downloaded input data) that should also be excluded.

---

### Step 2: Write the Dockerfile (minimal first pass)

Start with the Astral UV base image and the minimum needed to run `uv sync`:

```dockerfile
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim

# Create non-root user
RUN groupadd --gid 1000 dev && \
    useradd --uid 1000 --gid 1000 --create-home dev

WORKDIR /workspace

# Copy only dependency files first (layer cache: only re-runs uv sync when these change)
COPY pyproject.toml uv.lock ./

# Sync dependencies into the named volume mount point
RUN uv sync --frozen --no-install-project

USER dev
```

Key UV environment variables to set:
- `UV_CACHE_DIR=/uv-cache` — points UV's download cache to the named volume
- `UV_LINK_MODE=copy` — required when the cache and venv are on different filesystems (which they will be, since venv is a separate named volume)
- `UV_PROJECT_ENVIRONMENT=/workspace/.venv` — tells UV where to create/sync the venv

---

### Step 3: Attempt `uv sync` and iterate on system libraries

This is the core discovery step. The goal is to find the minimum set of `apt` packages needed for all dependencies in `uv.lock` to install successfully.

**Procedure:**

1. Build the minimal image:
   ```bash
   docker compose build
   ```

2. If the build fails during `uv sync`, read the error output. Errors will typically look like:
   - `cannot find -lgdal` or `gdal-config not found` → need `libgdal-dev`
   - `HDF5 not found` → need `libhdf5-dev`
   - `No such file: geos_c.h` → need `libgeos-dev`
   - `error: command 'gcc' failed` → need `build-essential`

3. Add the missing package to the Dockerfile's `apt-get install` block and rebuild.

4. Repeat until `uv sync --frozen` completes without errors.

5. Record the final set of required packages in this document.

**Known likely candidates** (from the dependency list and install docs warning):

| apt package | Why it's needed |
|-------------|----------------|
| `build-essential` | C/C++ compiler for packages without pre-built wheels |
| `libgdal-dev` / `gdal-bin` | `rasterio`, `geopandas` |
| `libgeos-dev` | `shapely`, `cartopy` |
| `libproj-dev` / `proj-bin` | `cartopy`, `pyproj` |
| `libhdf5-dev` | `PyTables` (HDF5 file format) |
| `libnetcdf-dev` | `netCDF4` |
| `graphviz` | Snakemake DAG visualization |

**Important:** Many of these packages ship pre-built Linux wheels on PyPI, which means `uv sync` may succeed without the corresponding system library. Only add a system package if the build actually fails without it. The iteration procedure above will reveal exactly what's needed.

---

### Step 4: Write `docker-compose.yml`

```yaml
services:
  dev:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      # Project source (bind mount)
      - .:/workspace
      # Virtual environment (named volume — fast, isolated from Windows FS)
      - pypsa-venv:/workspace/.venv
      # UV package download cache (named volume — persists across rebuilds)
      - uv-cache:/uv-cache
      # Git credentials from host
      - ~/.gitconfig:/home/dev/.gitconfig:ro
      # Gurobi license (optional — Docker silently ignores missing host paths)
      - ~/gurobi.lic:/home/dev/gurobi.lic:ro
    environment:
      UV_CACHE_DIR: /uv-cache
      UV_LINK_MODE: copy
      UV_PROJECT_ENVIRONMENT: /workspace/.venv
    ports:
      - "8888:8888"   # Jupyter
      - "8787:8787"   # Dask dashboard
      - "8000:8000"   # Sphinx autobuild
    command: sleep infinity   # Keeps container alive; VS Code attaches to it

    develop:
      watch:
        # Rebuild image + re-run uv sync when dependencies change
        - path: uv.lock
          action: rebuild
        - path: pyproject.toml
          action: rebuild
        # Sync source files into container without rebuilding
        - path: workflow
          action: sync
          target: /workspace/workflow

volumes:
  pypsa-venv:
  uv-cache:
```

---

### Step 5: Write `.devcontainer/devcontainer.json`

This file is minimal — it delegates all configuration to the Compose file:

```json
{
  "name": "PyPSA-USA",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "dev",
  "workspaceFolder": "/workspace",
  "remoteUser": "dev",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "charliermarsh.ruff",
        "ms-toolsai.jupyter",
        "snakemake.snakemake-lang",
        "ms-python.mypy-type-checker"
      ],
      "settings": {
        "python.defaultInterpreterPath": "/workspace/.venv/bin/python"
      }
    }
  }
}
```

---

### Step 6: Run `init_pypsa_usa.sh` inside the container

The first time the container starts, the `workflow/config/` directory will be empty (its contents are gitignored). Run the init script once:

```bash
bash init_pypsa_usa.sh
```

This copies config templates from `workflow/repo_data/config/` into `workflow/config/`. It is idempotent — safe to run again, it will just report that files already exist.

---

### Step 7: End-to-end validation

See the **Testing Procedure** section below.

---

## Testing Procedure

Use this procedure to verify the dev container is working correctly after any significant change to the Dockerfile or Compose configuration.

### 1. Clean-slate build

Start from a completely clean state to simulate a first-time user:

```bash
# Remove existing containers and named volumes
docker compose down --volumes

# Build the image with no cache
docker compose build --no-cache
```

A clean build should complete without errors. Note the build time — this is the worst-case startup time a new user will experience.

### 2. Start the container and attach VS Code

```bash
docker compose up -d
```

Then in VS Code: **Cmd/Ctrl+Shift+P → "Dev Containers: Reopen in Container"**

VS Code should connect without errors and show "Dev Container: PyPSA-USA" in the bottom-left status bar.

### 3. Verify the Python environment

Open a terminal inside VS Code (which will be a shell inside the container) and run:

```bash
# Confirm we're running the right Python version
python --version
# Expected: Python 3.11.x

# Confirm UV sees the correct venv
uv run python -c "import pypsa; print(pypsa.__version__)"
# Expected: 0.30.2

# Confirm a GIS package works (exercises compiled system libraries)
uv run python -c "import geopandas; print(geopandas.__version__)"
# Expected: 1.0.1

# Confirm the solver is available
uv run python -c "import highspy; print('HiGHS available')"
# Expected: HiGHS available
```

### 4. Verify Snakemake

```bash
# Dry run of the full workflow — shows the DAG without executing anything
uv run snakemake --dry-run -s workflow/Snakefile

# If config files aren't copied yet, run the init script first:
bash init_pypsa_usa.sh
```

### 5. Verify Jupyter

```bash
uv run jupyter lab --ip=0.0.0.0 --no-browser
```

Open `http://localhost:8888` in your host browser. You should see the JupyterLab interface with the `/workspace` directory visible.

### 6. Verify fast restart (cache effectiveness)

```bash
# Stop the container but keep the named volumes
docker compose down

# Start again (volumes preserved)
docker compose up -d
```

The second start should be significantly faster than the first — the image is already built, and `uv sync` should report that all packages are already installed (no new downloads). If `uv sync` re-downloads packages, the UV cache volume is not being mounted correctly.

### 7. Verify watch behavior

With the container running, modify `workflow/scripts/` — any Python file will do. Save the file and confirm it appears updated inside the container immediately (sync, no rebuild).

Then add a comment to `pyproject.toml` and save. The container should stop and rebuild automatically. Confirm the rebuild completes and the container restarts cleanly.

### 8. Verify Gurobi (if license available)

```bash
uv run python -c "import gurobipy; m = gurobipy.Model(); print('Gurobi license valid')"
```

If no license is present, Gurobi will print a size-limited trial warning — this is expected and not an error.

---

## Caching Behavior Reference

| What is cached | Where | Persists across |
|---------------|-------|----------------|
| Downloaded package files | `uv-cache` named volume | Container restarts, image rebuilds |
| Installed `.venv` | `pypsa-venv` named volume | Container restarts; **lost** on `docker compose down --volumes` |
| Built image layers | Docker image cache | Rebuilds (unless `--no-cache`); lost if image is pruned |

**Rule of thumb:** `docker compose down` (no flags) preserves volumes and is fast to restart. `docker compose down --volumes` is a full reset — use it when you want to verify a clean first-time experience.
