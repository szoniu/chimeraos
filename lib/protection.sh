#!/usr/bin/env bash
if [[ -z "${_CHIMERA_INSTALLER:-}" ]]; then
    echo "ERROR: This file must be sourced by install.sh, not executed directly." >&2
    exit 1
fi
