#!/bin/bash
# lib/core/validator.sh - Sistema de validação robusta

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Validações numéricas
is_number() {
    [[ $1 =~ ^[0-9]+$ ]]
}

validate_port() {
    local port="$1"
    local context="${2:-porta}"
    
    if ! is_number "$port" || [[ $port -lt 1 || $port -gt 65535 ]]; then
        log_error "Valor inválido para $context: $port. Use um valor entre 1 e 65535."
        return 1
    fi
    
    log_debug "Porta validada: $port"
    return 0
}

validate_cpu() {
    local cpu="$1"
    local context="${2:-CPU}"
    
    if ! is_number "$cpu" || [[ $cpu -lt 1 || $cpu -gt 64 ]]; then
        log_error "Valor inválido para $context: $cpu. Use um valor entre 1 e 64."
        return 1
    fi
    
    log_debug "CPU validada: $cpu cores"
    return 0
}

validate_memory() {
    local memory="$1"
    local context="${2:-memória}"
    
    if ! is_number "$memory" || [[ $memory -lt 512 || $memory -gt 131072 ]]; then
        log_error "Valor inválido para $context: $memory MB. Use um valor entre 512 MB e 131072 MB (128 GB)."
        return 1
    fi
    
    log_debug "Memória validada: $memory MB"
    return 0
}

# Validação de dependências de sistema
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

user_in_docker_group() {
    groups | grep -q docker
}

# Validação de disponibilidade de porta
check_port_availability() {
    local port="$1"
    local service_name="${2:-serviço}"
    
    log_debug "Verificando disponibilidade da porta $port para $service_name"
    
    # Verificar processos usando a porta
    local pid=$(lsof -t -i :"$port" 2>/dev/null || true)
    if [[ -n "$pid" ]]; then
        log_error "Conflito de porta detectado para $service_name (porta $port):"
        lsof -i :"$port"
        log_info "Execute para liberar: kill -9 $pid"
        return 1
    fi
    
    # Verificar containers Docker usando a porta
    local container=$(docker ps --format '{{.Names}}' 2>/dev/null | while read name; do
        if docker port "$name" 2>/dev/null | grep -q ":$port->"; then
            echo "$name"
            break
        fi
    done)
    
    if [[ -n "$container" ]]; then
        log_error "Container Docker '$container' está usando a porta $port para $service_name:"
        docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep "$port"
        log_info "Execute para liberar: docker rm -f $container"
        return 1
    fi
    
    log_debug "Porta $port disponível para $service_name"
    return 0
}

# Validação de ambiente Docker
validate_docker_environment() {
    log_debug "Validando ambiente Docker"
    
    if ! command_exists docker; then
        log_error "Docker não está instalado"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker não está acessível. Verifique se o serviço está rodando."
        if ! user_in_docker_group; then
            log_error "Usuário não está no grupo docker. Execute: sudo usermod -aG docker \$USER"
            log_error "Depois faça logout/login ou execute: newgrp docker"
        fi
        return 1
    fi
    
    log_debug "Ambiente Docker validado com sucesso"
    return 0
}

# Validação de ambiente Kubernetes
validate_kubernetes_environment() {
    log_debug "Validando ambiente Kubernetes"
    
    if ! command_exists kubectl; then
        log_error "kubectl não está instalado"
        return 1
    fi
    
    if ! command_exists kind; then
        log_error "Kind não está instalado"
        return 1
    fi
    
    log_debug "Ambiente Kubernetes validado com sucesso"
    return 0
}

# Validação de sistema operacional
validate_operating_system() {
    log_debug "Validando sistema operacional"
    
    if [[ ! -f /etc/os-release ]]; then
        log_warning "Não foi possível detectar o sistema operacional"
        return 0
    fi
    
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_warning "Este script foi testado apenas no Ubuntu. Prosseguindo mesmo assim..."
    else
        log_debug "Sistema operacional Ubuntu detectado"
    fi
    
    return 0
}

# Validação de espaço em disco
validate_disk_space() {
    local required_space_gb="${1:-10}"  # 10GB por padrão
    local mount_point="${2:-/}"
    
    log_debug "Verificando espaço em disco disponível em $mount_point"
    
    local available_space_kb=$(df "$mount_point" | tail -1 | awk '{print $4}')
    local available_space_gb=$((available_space_kb / 1024 / 1024))
    
    if [[ $available_space_gb -lt $required_space_gb ]]; then
        log_error "Espaço em disco insuficiente em $mount_point"
        log_error "Necessário: ${required_space_gb}GB, Disponível: ${available_space_gb}GB"
        return 1
    fi
    
    log_debug "Espaço em disco suficiente: ${available_space_gb}GB disponível"
    return 0
}

# Validação completa de pré-requisitos
validate_prerequisites() {
    log_header "VALIDAÇÃO DE PRÉ-REQUISITOS"
    
    local validation_failed=false
    
    # Validações individuais
    if ! validate_operating_system; then
        validation_failed=true
    fi
    
    if ! validate_disk_space 10; then
        validation_failed=true
    fi
    
    if ! validate_docker_environment; then
        validation_failed=true
    fi
    
    if ! validate_kubernetes_environment; then
        validation_failed=true
    fi
    
    # Verificar se alguma validação falhou
    if [[ "$validation_failed" == "true" ]]; then
        log_error "Falha na validação de pré-requisitos. Corrija os problemas acima antes de continuar."
        return 1
    fi
    
    log_success "Todos os pré-requisitos foram validados com sucesso"
    return 0
}

# Validação de parâmetros de entrada
validate_input_parameters() {
    local cluster_name="$1"
    local host_port="$2"
    local force_cpu="$3"
    local force_memory="$4"
    
    log_debug "Validando parâmetros de entrada"
    
    # Validar nome do cluster
    if [[ -n "$cluster_name" && ! "$cluster_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]]; then
        log_error "Nome do cluster inválido: $cluster_name"
        log_error "Use apenas letras, números e hífens. Deve começar e terminar com alfanumérico."
        return 1
    fi
    
    # Validar porta
    if [[ -n "$host_port" ]] && ! validate_port "$host_port" "porta do host"; then
        return 1
    fi
    
    # Validar CPU forçada
    if [[ -n "$force_cpu" ]] && ! validate_cpu "$force_cpu" "CPU forçada"; then
        return 1
    fi
    
    # Validar memória forçada
    if [[ -n "$force_memory" ]] && ! validate_memory "$force_memory" "memória forçada"; then
        return 1
    fi
    
    log_debug "Parâmetros de entrada validados com sucesso"
    return 0
}
