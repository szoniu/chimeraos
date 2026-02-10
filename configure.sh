#!/usr/bin/env bash
# configure.sh — Wrapper: runs only the TUI configuration wizard
exec "$(dirname "${BASH_SOURCE[0]}")/install.sh" --configure "$@"
