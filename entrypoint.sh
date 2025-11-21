#!/usr/bin/env bash
set -euo pipefail

COUNTRY_VAL="${COUNTRY:-}"
if [[ -z "$COUNTRY_VAL" ]]; then
  echo "COUNTRY is not set; using default from image if provided." >&2
fi

if [[ -f /app/countries.txt ]] && [[ -n "${COUNTRY_VAL}" ]]; then
  if ! grep -qx "${COUNTRY_VAL}" /app/countries.txt; then
    echo "Warning: COUNTRY='${COUNTRY_VAL}' not found in countries.txt. Showing a few examples:" >&2
    head -n 20 /app/countries.txt >&2 || true
  fi
fi

exec "$@"

