#!/bin/bash
# lib/utils/common.sh - Funções utilitárias compartilhadas

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"

# Função para verificar se um comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para aguardar com timeout
wait_for_condition() {
    local condition="$1"
    local timeout="${2:-300}"
    local interval="${3:-5}"
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$condition"; then
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    echo
    return 1
}

# Função para gerar nomes únicos
generate_unique_name() {
    local prefix="$1"
    local suffix="$(date +%s | tail -c 6)"
    echo "${prefix}-${suffix}"
}

# Função para verificar conectividade de rede
check_network_connectivity() {
    local host="${1:-8.8.8.8}"
    local port="${2:-53}"
    
    if command_exists nc; then
        nc -z "$host" "$port" >/dev/null 2>&1
    elif command_exists ping; then
        ping -c 1 -W 2 "$host" >/dev/null 2>&1
    else
        return 1
    fi
}

# Função para cleanup de recursos temporários
cleanup_temp_resources() {
    local temp_dir="$1"
    if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
        log_debug "Limpando diretório temporário: $temp_dir"
        rm -rf "$temp_dir"
    fi
}

# Função para verificar permissões de usuário
check_user_permissions() {
    local required_groups=("docker")
    local missing_groups=()
    
    for group in "${required_groups[@]}"; do
        if ! groups | grep -q "$group"; then
            missing_groups+=("$group")
        fi
    done
    
    if [ ${#missing_groups[@]} -gt 0 ]; then
        log_warning "Usuário não está nos grupos necessários: ${missing_groups[*]}"
        return 1
    fi
    return 0
}

# Função para backup de configurações
backup_config() {
    local config_file="$1"
    local backup_dir="${2:-/tmp/awx-backups}"
    
    if [[ -f "$config_file" ]]; then
        mkdir -p "$backup_dir"
        local backup_name="$(basename "$config_file").$(date +%Y%m%d_%H%M%S).bak"
        cp "$config_file" "$backup_dir/$backup_name"
        log_info "Backup criado: $backup_dir/$backup_name"
    fi
}
