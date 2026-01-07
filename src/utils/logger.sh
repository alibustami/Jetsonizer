#!/bin/bash

JETSONIZER_LOG_DIR_DEFAULT="/home/.cache/Jetsonizer"

jetsonizer_log_init() {
    local caller="${BASH_SOURCE[1]:-$0}"

    if [ -z "${JETSONIZER_LOG_SCRIPT:-}" ]; then
        JETSONIZER_LOG_SCRIPT="$caller"
    fi

    local target="${JETSONIZER_LOG_DIR:-$JETSONIZER_LOG_DIR_DEFAULT}"
    if ! mkdir -p "$target" 2>/dev/null; then
        local fallback="${HOME:-/root}/.cache/Jetsonizer"
        if mkdir -p "$fallback" 2>/dev/null; then
            target="$fallback"
            JETSONIZER_LOG_DIR_FALLBACK=1
        fi
    fi
    JETSONIZER_LOG_DIR="$target"

    if [ -z "${JETSONIZER_LOG_FILE:-}" ]; then
        local script_base
        script_base="$(basename "$JETSONIZER_LOG_SCRIPT")"
        script_base="${script_base%.*}"
        local timestamp
        timestamp="$(date +'%Y%m%d_%H%M%S')"
        JETSONIZER_LOG_FILE="$JETSONIZER_LOG_DIR/${script_base}_${timestamp}.log"
    fi
}

jetsonizer_get_trap() {
    local trap_name="$1"
    trap -p "$trap_name" | sed -E "s/^trap -- '(.*)' ${trap_name}$/\\1/"
}

jetsonizer_prepend_trap() {
    local trap_name="$1"
    shift
    local new_trap="$*"
    local existing
    existing="$(jetsonizer_get_trap "$trap_name")"
    if [ -n "$existing" ]; then
        trap -- "$new_trap"$'\n'"$existing" "$trap_name"
    else
        trap -- "$new_trap" "$trap_name"
    fi
}

jetsonizer_append_trap() {
    local trap_name="$1"
    shift
    local new_trap="$*"
    local existing
    existing="$(jetsonizer_get_trap "$trap_name")"
    if [ -n "$existing" ]; then
        trap -- "$existing"$'\n'"$new_trap" "$trap_name"
    else
        trap -- "$new_trap" "$trap_name"
    fi
}

jetsonizer_notify_failure() {
    local exit_code="$1"
    local target="${JETSONIZER_LOG_FILE:-${JETSONIZER_LOG_DIR:-$JETSONIZER_LOG_DIR_DEFAULT}}"
    local message="Error encountered. Full error and logs written to $target."

    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 196 --bold "$message"
    else
        echo "$message" >&2
    fi

    return "$exit_code"
}

jetsonizer_log_failure() {
    local exit_code="${1:-$?}"
    local line="${BASH_LINENO[0]:-?}"
    local command="${BASH_COMMAND:-unknown}"
    local timestamp
    timestamp="$(date +'%Y-%m-%dT%H:%M:%S%z')"

    if [ -z "${JETSONIZER_LOG_FILE:-}" ]; then
        jetsonizer_log_init || true
    fi

    if [ -n "${JETSONIZER_LOG_FILE:-}" ]; then
        {
            printf 'Timestamp: %s\n' "$timestamp"
            printf 'Script: %s\n' "${JETSONIZER_LOG_SCRIPT:-$0}"
            printf 'Line: %s\n' "$line"
            printf 'Command: %s\n' "$command"
            printf 'Exit code: %s\n' "$exit_code"
            printf '\n'
        } >> "$JETSONIZER_LOG_FILE" 2>/dev/null || true
    fi

    JETSONIZER_LOGGED_ERROR=1
    jetsonizer_notify_failure "$exit_code"
    return "$exit_code"
}

jetsonizer_log_on_exit() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ] && [ "${JETSONIZER_LOGGED_ERROR:-0}" -eq 0 ]; then
        jetsonizer_log_failure "$exit_code"
    fi
}

jetsonizer_enable_err_trap() {
    if [ "${JETSONIZER_LOG_ERR_TRAP_SET:-0}" -eq 1 ]; then
        return 0
    fi

    jetsonizer_log_init || return 1
    JETSONIZER_LOG_ERR_TRAP_SET=1
    set -o errtrace 2>/dev/null || true
    jetsonizer_prepend_trap ERR 'jetsonizer_log_failure $?'
}

jetsonizer_enable_exit_trap() {
    if [ "${JETSONIZER_LOG_EXIT_TRAP_SET:-0}" -eq 1 ]; then
        return 0
    fi

    jetsonizer_log_init || return 1
    JETSONIZER_LOG_EXIT_TRAP_SET=1
    jetsonizer_append_trap EXIT 'jetsonizer_log_on_exit'
}
