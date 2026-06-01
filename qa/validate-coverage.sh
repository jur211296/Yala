#!/bin/bash
# Wrapper del validador del coverage-index. Usado por git pre-push, CI y /qa-sync.
exec python3 "$(dirname "$0")/validate-coverage.py" "$@"
