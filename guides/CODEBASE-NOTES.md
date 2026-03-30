# Codebase Notes: Non-Obvious Behaviors and Gotchas

This file documents behaviors, design decisions, and configuration quirks that are not obvious from reading the code or docs — the kind of thing that takes an hour to debug the first time and five seconds to fix the second time. Add entries here when you discover something that would have saved you time to know upfront.

**Format:** each entry has a location, a symptom, an explanation, and a fix.

---

## Snakemake

### `config.default.yaml` is not loaded by default

**Location:** `workflow/Snakefile`, line 92

**Symptom:** Running `snakemake --dry-run` from the `workflow/` directory fails immediately with:

```
KeyError in file /workspace/workflow/rules/retrieve.smk, line 204:
'enable'
```

**Explanation:** The Snakefile loads five config files at startup (`config.cluster.yaml`, `config.common.yaml`, `config.plotting.yaml`, `config.api.yaml`, `config.sector.yaml`). The line that loads `config.default.yaml` — which contains the `enable` block that many rules depend on — is **commented out**:

```python
# configfile: "config/config.default.yaml"
```

The `enable` key (e.g. `enable.build_cutout`) is only defined in `config.default.yaml`, so any rule that references `config["enable"]` will throw a `KeyError` when this file is not loaded.

**Fix:** Uncomment line 92 in `workflow/Snakefile`:

```python
configfile: "config/config.default.yaml"
```

**Note:** Check whether this is intentional on your branch before uncommenting. On `master`/`develop`, `config.default.yaml` may be loaded via a different mechanism or the commenting-out may be branch-specific.

---

### Snakemake must be run from the `workflow/` directory

**Location:** `workflow/Snakefile`, lines 85–92 (configfile directives)

**Symptom:** Running `snakemake --dry-run -s workflow/Snakefile` from the repo root fails with:

```
WorkflowError: Workflow defines configfile config/config.cluster.yaml but it is not
present or accessible (full checked path: /workspace/config/config.cluster.yaml).
```

**Explanation:** Snakemake resolves `configfile:` paths relative to the working directory, not relative to the Snakefile. Config files live in `workflow/config/`, so Snakemake must be invoked from `workflow/`.

**Fix:** Always `cd workflow/` before running Snakemake:

```bash
cd workflow && snakemake --dry-run
```

---

## Configuration

### `init_pypsa_usa.sh` must be run once before Snakemake

**Location:** `init_pypsa_usa.sh` (repo root), `workflow/config/` (destination)

**Symptom:** Snakemake fails on missing config files even after cloning the repo.

**Explanation:** Config files (`config.default.yaml`, `config.common.yaml`, etc.) are gitignored in `workflow/config/`. Templates live in `workflow/repo_data/config/` and must be copied into place manually.

**Fix:** Run once after cloning (idempotent — safe to re-run):

```bash
bash init_pypsa_usa.sh
```

---

## Dev Container

### Gurobi license warning on every Snakemake run

**Symptom:**
```
UserWarning: GUROBI error: License expired 2025-11-24.
```

**Explanation:** `gurobipy` is installed as a Python dependency and attempts to find a license on import. If a license file exists on the host at `~/gurobi.lic` but is expired, this warning appears. It is harmless — Snakemake will use HiGHS as the solver instead.

**Fix:** None needed unless you are trying to use Gurobi. To suppress the warning, remove or rename the expired `~/gurobi.lic` file on your host machine.

---

*Add new entries above this line. Include: file path + line number, symptom, explanation, fix.*
