#!/bin/bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

log_error() {
    echo "${SCRIPT_NAME}: $*" >&2
}

normalize_path() {
    local candidate="$1"
    local resolved=""

    # Preserve symlink paths so venv interpreters don't collapse to /usr/bin.
    if [[ "$candidate" != /* ]]; then
        resolved="$(type -P "$candidate" 2>/dev/null || true)"
        if [ -n "$resolved" ]; then
            candidate="$resolved"
        fi
    fi

    printf '%s\n' "$candidate"
}

is_executable_python() {
    local candidate="$1"
    [ -n "$candidate" ] && [ -x "$candidate" ]
}

try_candidate() {
    local candidate="$1"
    if is_executable_python "$candidate"; then
        normalize_path "$candidate"
        return 0
    fi
    return 1
}

resolve_from_owner_env() {
    local owner var value
    local skip_presets=0

    if [ -n "${JETSONIZER_FORCE_REDETECT:-}" ]; then
        skip_presets=1
    fi

    if [ "$skip_presets" -eq 0 ]; then
        for var in JETSONIZER_ACTIVE_PYTHON_BIN JETSONIZER_PREFERRED_PYTHON_BIN; do
            value="${!var:-}"
            if try_candidate "$value"; then
                return 0
            fi
        done
    fi

    if [ -n "${VIRTUAL_ENV:-}" ]; then
        if try_candidate "$VIRTUAL_ENV/bin/python"; then
            return 0
        fi
    fi

    if [ -n "${CONDA_PREFIX:-}" ]; then
        if try_candidate "$CONDA_PREFIX/bin/python"; then
            return 0
        fi
    fi

    if [ -n "${UV_PROJECT_ENVIRONMENT:-}" ]; then
        if try_candidate "$UV_PROJECT_ENVIRONMENT/bin/python"; then
            return 0
        fi
    fi

    if [ -n "${PYENV_ROOT:-}" ] && [ -n "${PYENV_VERSION:-}" ]; then
        if try_candidate "$PYENV_ROOT/versions/${PYENV_VERSION}/bin/python"; then
            return 0
        fi
    fi

    return 1
}

resolve_with_which() {
    local candidate=""
    if command -v which >/dev/null 2>&1; then
        candidate="$(which python 2>/dev/null || true)"
        if try_candidate "$candidate"; then
            return 0
        fi
    fi

    return 1
}

resolve_with_command_v() {
    local candidate=""
    local names=(python python3 python3.12 python3.11 python3.10 python3.9)
    for name in "${names[@]}"; do
        if candidate="$(command -v "$name" 2>/dev/null || true)"; then
            if try_candidate "$candidate"; then
                return 0
            fi
        fi
    done
    return 1
}

if resolve_from_owner_env; then
    exit 0
fi

if resolve_with_which; then
    exit 0
fi

if resolve_with_command_v; then
    exit 0
fi

log_error "Unable to determine an active Python interpreter. Please ensure python is on PATH."
exit 1
