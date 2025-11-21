# Singapore Streets

Find and clean street names from OpenStreetMap (OSM) data. The pipeline downloads a country extract, cuts to city bounds, extracts street names, and produces a cleaned, deduplicated list. Although the repo includes Singapore examples, you can run any Geofabrik country via `COUNTRY=...`.

## Quick Start (Native)

Requirements: Python 3.11, `osmconvert`, `osmosis`, `wget`.

```
# Setup once
make venv

# Choose a country (default: asia/thailand). See countries.txt
COUNTRY=asia/singapore make osm
COUNTRY=asia/singapore make city
COUNTRY=asia/singapore make streets
COUNTRY=asia/singapore make clean

# Optional: categorize with Ollama (requires local ollama)
COUNTRY=asia/singapore make categorize
```

## Quick Start (Docker)

Build a small multi-stage image and run the full pipeline:

```
make docker-build
COUNTRY=asia/singapore make docker-run
```

Interactive shell inside the image:

```
COUNTRY=asia/singapore make docker-shell
```

Compose alternative with bind mounts:

```
COUNTRY=asia/singapore docker compose up --build
```

Outputs are written to `output/`, with excluded lines in `filtered/` for review.

## Make Targets

- `make venv`: Create virtualenv and install Python deps.
- `make osm`: Download Geofabrik PBF + POLY for `COUNTRY`.
- `make city`: Convert to city `.osm` using `.poly`.
- `make streets`: Extract street CSV + text list.
- `make clean`: Format, filter, and dedupe into `output/`.
- `make categorize` (optional): Group names with Ollama.
- `make all`: Runs `osm city streets clean categorize`.

## Notes

- Valid `COUNTRY` values are listed in `countries.txt` (e.g., `asia/singapore`).
- `categorize` uses `ollama` and is not installed in the Docker image by default.

## Open Issues

- Typos in OSM data (e.g., `Woodland Drive 75` vs `Woodlands Drive 75`).
