# Start from Microsoft's standard devcontainer base (Ubuntu 22.04 LTS).
# This gives us the vscode user, git, zsh, sudo, and all VS Code server tooling
# WITHOUT any Anaconda/Miniconda software (which requires a commercial license
# for organizations). Python comes exclusively from our micromamba environment.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# ── Micromamba ────────────────────────────────────────────────────────────────
# micromamba is a fast, standalone C++ re-implementation of conda/mamba.
# It is maintained by the conda-forge community (NOT Anaconda Inc.) and is
# free for any use. It uses the same environment.yaml format and resolves
# packages from the conda-forge channel declared in environment.yaml.
RUN curl -fsSL https://micro.mamba.pm/api/micromamba/linux-64/latest \
        | tar -xvj --strip-components=1 -C /usr/local/bin bin/micromamba

# Store all environments under /opt/conda (mirrors the conda convention so
# paths are predictable for VS Code and shell configuration).
ENV MAMBA_ROOT_PREFIX=/opt/conda

# ── Project environment ───────────────────────────────────────────────────────
# Create the pypsa-usa conda environment from the project's environment.yaml.
# This installs Python 3.11.9 and all native/GIS dependencies (GDAL, HDF5,
# cartopy, rasterio, graphviz, cyipopt) as pre-compiled conda-forge binaries.
# Build context is the repo root (see devcontainer.json), so this path works.
COPY workflow/envs/environment.yaml /tmp/environment.yaml
RUN micromamba env create -f /tmp/environment.yaml \
    && micromamba clean --all --yes

# ── HiGHS solver ─────────────────────────────────────────────────────────────
# highspy (the Python bindings) is already in environment.yaml and installs
# a bundled HiGHS shared library. Additionally install the system HiGHS binary
# so the solver is available on PATH for CLI use and Snakemake rule invocations.
RUN apt-get update \
    && apt-get install -y --no-install-recommends highs \
    && rm -rf /var/lib/apt/lists/*

# ── Dev tools ────────────────────────────────────────────────────────────────
# Install dev-only packages (mirrors workflow/envs/dev.yaml) into the same
# environment. Keeping these in the Dockerfile means they are cached in the
# image layer and don't need to be re-installed on every container start.
RUN micromamba run -n pypsa-usa pip install --no-cache-dir \
    bump2version \
    pudb \
    "mypy~=1.11.0" \
    pre-commit \
    "ruff~=0.5.2" \
    types-PyYAML \
    sphinx-autobuild \
    sphinx \
    sphinx-book-theme \
    myst-parser \
    pytest \
    "sphinxcontrib-bibtex>=2.6.5"

# ── Shell activation ──────────────────────────────────────────────────────────
# Wire up micromamba's shell hook and auto-activate the project environment
# for the vscode user's interactive bash and zsh sessions.
RUN echo 'export MAMBA_ROOT_PREFIX=/opt/conda' >> /home/vscode/.bashrc \
    && echo 'eval "$(micromamba shell hook --shell bash)"' >> /home/vscode/.bashrc \
    && echo 'micromamba activate pypsa-usa' >> /home/vscode/.bashrc \
    && echo 'export MAMBA_ROOT_PREFIX=/opt/conda' >> /home/vscode/.zshrc \
    && echo 'eval "$(micromamba shell hook --shell zsh)"' >> /home/vscode/.zshrc \
    && echo 'micromamba activate pypsa-usa' >> /home/vscode/.zshrc
