#!/bin/bash
# lib/core/logger.sh - Sistema de logging centralizado

declare -A LOG_COLORS=(
    [INFO]='\033[0;34m'
    [SUCCESS]='\033[0;32m'
    [WARNING]='\033[1;33m'
    [ERROR]='\033[0;31m'
    [DEBUG]='\033[0;35m'
    [HEADER]='\033[0;36m'
    [NC]='\033[0m'
)

LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"
LOG_TIMESTAMP="${LOG_TIMESTAMP:-true}"

log_message() {
    local level="$1"
    local message="$2"
    local color="${LOG_COLORS[$level]}"
    local reset="${LOG_COLORS[NC]}"
    
    case "$LOG_LEVEL" in
        DEBUG) allowed_levels="DEBUG INFO SUCCESS WARNING ERROR" ;;
        INFO) allowed_levels="INFO SUCCESS WARNING ERROR" ;;
        WARNING) allowed_levels="WARNING ERROR" ;;
        ERROR) allowed_levels="ERROR" ;;
        *) allowed_levels="INFO SUCCESS WARNING ERROR" ;;
    esac
    
    if [[ ! $allowed_levels =~ $level ]]; then
        return 0
    fi
    
    local formatted_message=""
    if [[ "$LOG_TIMESTAMP" == "true" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        formatted_message="[$timestamp] "
    fi
    formatted_message+="${color}[$level]${reset} $message"
    
    echo -e "$formatted_message" >&2
    
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$formatted_message" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}

log_info() { log_message "INFO" "$1"; }
log_success() { log_message "SUCCESS" "$1"; }
log_warning() { log_message "WARNING" "$1"; }
log_error() { log_message "ERROR" "$1"; }
log_debug() { log_message "DEBUG" "$1"; }

log_header() {
    local separator="${LOG_COLORS[HEADER]}$(printf '=%.0s' {1..60})${LOG_COLORS[NC]}"
    echo -e "$separator"
    log_message "HEADER" "$1"
    echo -e "$separator"
}

log_subheader() {
    log_message "HEADER" "--- $1 ---"
}

configure_logging() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
    fi
    
    if [[ -n "$LOG_FILE" ]]; then
        local log_dir=$(dirname "$LOG_FILE")
        mkdir -p "$log_dir"
    fi
}
