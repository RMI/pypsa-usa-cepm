# Dev Container User Guide: PyPSA-USA

## What is a dev container?

A dev container is a full Linux development environment that runs inside Docker on your machine. Instead of installing Python, packages, and tools directly on your Windows or Mac machine, everything lives inside a container — an isolated, reproducible environment that behaves identically for every developer on the team.

When you open this repository in VS Code and choose "Reopen in Container," VS Code connects to that Linux environment. Your terminal, Python interpreter, linter, and Jupyter notebooks all run inside the container. Your files stay on your host machine (Windows/Mac), but VS Code operates as if it's on Linux.

**Why bother?**

- **Reproducibility** — everyone runs the exact same Python version, the same packages at the same pinned versions, on the same Linux OS. "Works on my machine" stops being a problem.
- **Isolation** — the container doesn't interfere with other Python projects or system software on your machine.
- **Simplicity** — no manual `conda` or `pip` setup. You run one command and the environment is ready.

---

## How this container is built

This container uses three files working together:

### `Dockerfile`
Defines the Linux image. It starts from Astral's official UV image (Debian Linux with Python 3.11 and the UV package manager pre-installed), creates a non-root user called `dev`, and runs `uv sync --frozen` to install all Python dependencies from the lock file.

### `docker-compose.yml`
Configures how the container runs: which directories to mount, which ports to expose, which volumes to use for caching, and — most importantly — the `watch` service that monitors files for changes.

### `.devcontainer/devcontainer.json`
A minimal file that tells VS Code which Compose service to attach to and which extensions to install inside the container. All the real configuration lives in the Compose file.

---

## How the virtual environment works

This project uses **UV** as its package manager. UV is a fast, modern replacement for pip that reads `uv.lock` — a file that records the exact version of every package in the project — and installs them precisely as specified. You do not need to run `pip install` or activate an environment manually.

When the container starts, UV installs all packages into a virtual environment at `/workspace/.venv`. This virtual environment lives in a **named Docker volume** (not inside your Windows filesystem), which keeps it fast and isolated.

The virtual environment persists between container restarts. If you stop and restart the container, UV checks what's already installed and only downloads what's missing — usually nothing. This makes restarts fast after the first setup.

---

## How the watch service works

Docker Compose `watch` is a feature that monitors files on your host machine and reacts when they change. This container configures two types of reactions:

### `sync` — instant file updates
When you edit any file inside `workflow/`, the change is immediately copied into the running container. There is no delay, no restart, no rebuild. This is how you work day-to-day: edit a script on your host, and the container sees it instantly.

### `rebuild` — full container rebuild
When `uv.lock` or `pyproject.toml` changes, the watch service stops the container, rebuilds the image from scratch (re-running `uv sync`), and restarts it. This happens automatically whenever a developer adds or removes a Python dependency. It is slower (a few minutes), but it ensures that every developer's environment stays in sync with the lock file.

**To start the watch service:**
```bash
docker compose watch
```

Run this in a terminal on your host machine (not inside the container). Leave it running in the background while you work. You will see log output whenever a sync or rebuild is triggered.

---

## First-time setup

### 1. Install prerequisites

- **Docker Desktop** — download from [docker.com](https://www.docker.com/products/docker-desktop/). On Windows, accept the WSL2 backend option during installation.
- **VS Code** — download from [code.visualstudio.com](https://code.visualstudio.com/).
- **Dev Containers extension** — open VS Code, go to Extensions (Ctrl+Shift+X), search for "Dev Containers" (publisher: Microsoft), and install it.

### 2. Clone the repository

```bash
git clone https://github.com/PyPSA/pypsa-usa.git
cd pypsa-usa
```

### 3. Open in VS Code

```bash
code .
```

### 4. Reopen in container

VS Code will detect the `.devcontainer` folder and show a notification in the bottom-right corner: **"Folder contains a Dev Container configuration file. Reopen in container."** Click it.

Alternatively: **Ctrl+Shift+P → "Dev Containers: Reopen in Container"**

VS Code will:
1. Pull the base Linux image (first time only — ~500 MB download)
2. Build the container image (first time only — installs all Python packages)
3. Start the container
4. Install VS Code extensions inside the container
5. Connect your VS Code window to the container

The first time this runs, it may take 5–15 minutes depending on your internet connection. Subsequent opens take under a minute.

You'll know it's working when the bottom-left of VS Code shows **"Dev Container: PyPSA-USA"** in green.

### 5. Initialize config files

The first time you open the container, run this in the VS Code terminal (which is now a terminal inside the container):

```bash
bash init_pypsa_usa.sh
```

This copies configuration templates into `workflow/config/`. You only need to do this once.

---

## Day-to-day usage

### Opening the project

Open Docker Desktop (it needs to be running), then open VS Code and choose **"Dev Containers: Reopen in Container"**. The container starts in seconds — the environment is already built and cached.

### Running the terminal

The VS Code integrated terminal (**Ctrl+`**) automatically opens a shell inside the container. You are logged in as the `dev` user on Debian Linux.

### Running Python

```bash
# Run a Python script
uv run python workflow/scripts/my_script.py

# Open an interactive Python session
uv run python
```

You do not need to activate the virtual environment manually. `uv run` handles it.

### Running Snakemake

```bash
# Dry run — shows what would execute without running anything
uv run snakemake --dry-run -s workflow/Snakefile

# Run the workflow with 4 cores
uv run snakemake -s workflow/Snakefile --cores 4
```

### Running Jupyter

```bash
uv run jupyter lab --ip=0.0.0.0 --no-browser
```

Then open `http://localhost:8888` in your host browser. VS Code may also prompt you to open it automatically.

### Editing files

Edit files normally in VS Code. Your edits are on your host machine and are immediately visible inside the container — no sync step needed for editing.

---

## Adding or removing Python packages

If you need to add a new package to the project:

```bash
# Inside the container terminal
uv add package-name
```

This updates `pyproject.toml` and regenerates `uv.lock`. Commit both files. The next time any team member opens the container, the watch service will detect the changed lock file, rebuild automatically, and install the new package.

To remove a package:

```bash
uv remove package-name
```

---

## Ports available on your host machine

While the container is running, these ports are forwarded to your host:

| Port | Service | How to access |
|------|---------|---------------|
| 8888 | Jupyter Lab/Notebook | `http://localhost:8888` |
| 8787 | Dask dashboard | `http://localhost:8787` |
| 8000 | Sphinx docs preview | `http://localhost:8000` |

These ports do nothing when the corresponding service isn't running — you only need to open the URL when you've started the service in the terminal.

---

## VS Code extensions installed in the container

These extensions are automatically installed inside the container when you first open it. They run against the container's Python environment, not your host machine.

| Extension | What it does |
|-----------|-------------|
| **Python** (`ms-python.python`) | Core Python support: syntax highlighting, running and debugging scripts |
| **Pylance** (`ms-python.vscode-pylance`) | Autocomplete and type inference — hover over any function to see its signature and documentation |
| **Ruff** (`charliermarsh.ruff`) | Linting and formatting, shown inline as you type. Ruff is configured in `pyproject.toml` for this project (line length 120) |
| **Jupyter** (`ms-toolsai.jupyter`) | Run Jupyter notebooks directly inside VS Code without a separate browser window |
| **Snakemake** (`snakemake.snakemake-lang`) | Syntax highlighting for `.smk` Snakemake rule files in `workflow/rules/` |
| **Mypy** (`ms-python.mypy-type-checker`) | Type checking — shows type errors inline as you edit, using the mypy settings in this project |

---

## Solvers

This workflow requires an optimization solver to solve the energy system models. Two are available:

- **HiGHS** — open-source, installed automatically as a Python package. Works out of the box, no setup required. Sufficient for most development and testing.
- **Gurobi** — commercial solver, significantly faster on large problems. Requires a license file. If you have a `gurobi.lic` file in your home directory (`~/gurobi.lic`), it will be mounted into the container automatically. If not, HiGHS is used as the fallback.

---

## Troubleshooting

### Container won't start
- Make sure Docker Desktop is running (check the system tray).
- Try **Ctrl+Shift+P → "Dev Containers: Rebuild Container"** to force a clean rebuild.

### Python packages are missing
- Run `uv sync --frozen` in the container terminal. This re-syncs the venv against the lock file.

### `uv sync` is slow on restart
- This suggests the UV cache volume was deleted. Check that `docker compose down` was used (not `docker compose down --volumes`). The `--volumes` flag deletes the caches.

### Port already in use
- Another process on your host is using port 8888, 8787, or 8000. Stop that process, or edit `docker-compose.yml` to map to a different host port (e.g., `"8889:8888"`).

### File changes not appearing in container
- The watch service (`docker compose watch`) must be running for sync to work. Start it in a terminal on your host machine.
- For non-`workflow/` directories, changes are not automatically synced — they are on the bind-mounted project root, which means they're already shared.

### Gurobi license not found
- Confirm `~/gurobi.lic` exists on your host machine.
- Restart the container after adding the file — volume mounts are set at container start time.
