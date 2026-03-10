#!/bin/bash
# Runs once after the dev container is created.
# Handles project-specific setup that depends on the mounted repo contents.

set -e

echo ""
echo "========================================"
echo "  PyPSA-USA Dev Container Post-Setup"
echo "========================================"

# Step 1: Copy config templates into workflow/config/
# init_pypsa_usa.sh is idempotent — skips if configs already exist
echo ""
echo "[1/3] Initializing config files..."
bash init_pypsa_usa.sh

# Step 2: Install pre-commit hooks into the repo's .git/hooks/
# Must run at container-create time (not image-build time) because .git is
# only available once the workspace is bind-mounted.
echo ""
echo "[2/3] Installing pre-commit hooks..."
micromamba run -n pypsa-usa pre-commit install

echo ""
echo "[3/3] Setup complete!"
echo ""
echo "--------------------------------------------"
echo "  ACTION REQUIRED: EIA API Key"
echo "  The workflow requires an EIA API key."
echo "  Add it to workflow/config/config.yaml:"
echo "    api_key: YOUR_KEY_HERE"
echo "  Get a free key at: https://www.eia.gov/opendata/"
echo ""
echo "  SOLVERS AVAILABLE:"
echo "    HiGHS  — installed (free, default for PyPSA)"
echo "    CBC    — check: coinor-cbc"
echo "    Gurobi — requires GRB_LICENSE_FILE env var"
echo "--------------------------------------------"
echo ""
