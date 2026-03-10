# Dev Container Startup Guide

## Prerequisites

Install the following before opening the project:

- **Docker Desktop** — [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop). Make sure it is running before you open VS Code. On Windows, use the WSL2 backend (Docker Desktop default).
- **VS Code Dev Containers extension** — search `ms-vscode-remote.remote-containers` in the Extensions panel.

---

## Opening the Container

In VS Code with this repo open:

`Ctrl+Shift+P` → **Dev Containers: Reopen in Container**

The first build takes **15–20 minutes** (micromamba solving and installing ~50 packages). Subsequent opens are instant — Docker caches the image layers. You can watch progress in the VS Code terminal popup.

---

## Set Your EIA API Key

Once inside the container, open `workflow/config/config.yaml` and find the `api_key` field. Get a free key at [eia.gov/opendata](https://www.eia.gov/opendata/).

---

## Verify the Environment

Open a terminal inside the container (`Ctrl+\``) and run:

```bash
python -c "import pypsa, linopy, atlite; print('OK')"
snakemake --version
highs --version
```

All three should return without errors.

---

## Windows / OneDrive Note

The dev container works from any location on the Windows filesystem, including OneDrive. However, there are two things to be aware of:

**Performance:** Docker bind mounts from the Windows filesystem cross a filesystem boundary (Windows → WSL2 → container), which adds overhead. For full Snakemake workflow runs that read/write thousands of intermediate files, cloning the repo directly into the WSL2 filesystem (e.g. `~/projects/pypsa-usa-cepm`) and opening VS Code from there with `code .` gives significantly better I/O performance. For code editing and small test runs, the Windows location is fine.

**OneDrive sync conflicts:** OneDrive will try to sync `results/`, `resources/`, and `data/` as Snakemake writes them, which can cause file locking conflicts mid-run. To avoid this:
- Right-click the repo folder in File Explorer → **OneDrive → Always keep on this device**
- Exclude `results/`, `resources/`, and `data/` from OneDrive sync in OneDrive settings

These directories are already gitignored, so excluding them from OneDrive does not affect version control.
