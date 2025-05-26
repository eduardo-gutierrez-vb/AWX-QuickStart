#!/bin/bash
# lib/core/resource_calculator.sh - Cálculo inteligente de recursos do sistema

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

readonly SAFETY_FACTOR_PROD=70
readonly SAFETY_FACTOR_DEV=80
readonly MIN_CPU_MILLICORES=500
readonly MIN_MEMORY_MB=512

declare -A SYSTEM_RESOURCES
declare -A AVAILABLE_RESOURCES  
declare -A AWX_RESOURCES

detect_system_resources() {
    log_debug "Iniciando detecção de recursos do sistema"
    
    if [[ -n "$FORCE_CPU" ]]; then
        SYSTEM_RESOURCES[CPU_CORES]="$FORCE_CPU"
        log_debug "CPU forçada: $FORCE_CPU cores"
    else
        SYSTEM_RESOURCES[CPU_CORES]=$(nproc --all)
        log_debug "CPU detectada: ${SYSTEM_RESOURCES[CPU_CORES]} cores"
    fi
    
    if [[ -n "$FORCE_MEM_MB" ]]; then
        SYSTEM_RESOURCES[MEMORY_MB]="$FORCE_MEM_MB"
        log_debug "Memória forçada: ${FORCE_MEM_MB}MB"
    else
        SYSTEM_RESOURCES[MEMORY_MB]=$(awk '/MemTotal/ { print int($2/1024) }' /proc/meminfo)
        log_debug "Memória detectada: ${SYSTEM_RESOURCES[MEMORY_MB]}MB"
    fi
    
    determine_system_profile
    
    log_info "Recursos do sistema detectados:"
    log_info "CPUs: ${SYSTEM_RESOURCES[CPU_CORES]} cores"
    log_info "Memória: ${SYSTEM_RESOURCES[MEMORY_MB]}MB"
    log_info "Perfil: ${SYSTEM_RESOURCES[PROFILE]}"
}

determine_system_profile() {
    local cores="${SYSTEM_RESOURCES[CPU_CORES]}"
    local memory_mb="${SYSTEM_RESOURCES[MEMORY_MB]}"
    
    if [[ "$cores" -ge 4 ]] && [[ "$memory_mb" -ge 8192 ]]; then
        SYSTEM_RESOURCES[PROFILE]="prod"
    else
        SYSTEM_RESOURCES[PROFILE]="dev"
    fi
    
    log_debug "Perfil determinado: ${SYSTEM_RESOURCES[PROFILE]}"
}

calculate_cpu_reserved() {
    local total_cores="$1"
    local reserved_millicores=0
    local remaining_cores="$total_cores"
    
    # Baseado em padrões GKE/EKS
    if [[ "$total_cores" -ge 1 ]]; then
        reserved_millicores=$((reserved_millicores + 60))
        remaining_cores=$((remaining_cores - 1))
    fi
    
    if [[ "$remaining_cores" -ge 1 ]]; then
        reserved_millicores=$((reserved_millicores + 10))
        remaining_cores=$((remaining_cores - 1))
    fi
    
    if [[ "$remaining_cores" -ge 2 ]]; then
        reserved_millicores=$((reserved_millicores + 10))
        remaining_cores=$((remaining_cores - 2))
    fi
    
    if [[ "$remaining_cores" -gt 0 ]]; then
        reserved_millicores=$((reserved_millicores + (remaining_cores * 25 / 10)))
    fi
    
    echo "$reserved_millicores"
}

calculate_memory_reserved() {
    local total_mem_mb="$1"
    local reserved_mb=0
    
    if [[ "$total_mem_mb" -lt 1024 ]]; then
        reserved_mb=255
    else
        # Primeiro 4GB - 25%
        local first_4gb=$((total_mem_mb > 4096 ? 4096 : total_mem_mb))
        reserved_mb=$((first_4gb * 25 / 100))
        local remaining_mb=$((total_mem_mb - first_4gb))
        
        # Próximos 4GB - 20%
        if [[ "$remaining_mb" -gt 0 ]]; then
            local next_4gb=$((remaining_mb > 4096 ? 4096 : remaining_mb))
            reserved_mb=$((reserved_mb + next_4gb * 20 / 100))
            remaining_mb=$((remaining_mb - next_4gb))
        fi
        
        # Próximos 8GB - 10%
        if [[ "$remaining_mb" -gt 0 ]]; then
            local next_8gb=$((remaining_mb > 8192 ? 8192 : remaining_mb))
            reserved_mb=$((reserved_mb + next_8gb * 10 / 100))
            remaining_mb=$((remaining_mb - next_8gb))
        fi
        
        # Próximos 112GB - 6%
        if [[ "$remaining_mb" -gt 0 ]]; then
            local next_112gb=$((remaining_mb > 114688 ? 114688 : remaining_mb))
            reserved_mb=$((reserved_mb + next_112gb * 6 / 100))
            remaining_mb=$((remaining_mb - next_112gb))
        fi
        
        # Restante - 2%
        if [[ "$remaining_mb" -gt 0 ]]; then
            reserved_mb=$((reserved_mb + remaining_mb * 2 / 100))
        fi
    fi
    
    # Buffer adicional de segurança
    reserved_mb=$((reserved_mb + 100))
    echo "$reserved_mb"
}

calculate_available_resources() {
    log_subheader "Calculando recursos disponíveis para AWX"
    
    local total_cores="${SYSTEM_RESOURCES[CPU_CORES]}"
    local total_memory_mb="${SYSTEM_RESOURCES[MEMORY_MB]}"
    local profile="${SYSTEM_RESOURCES[PROFILE]}"
    
    local cpu_reserved_millicores=$(calculate_cpu_reserved "$total_cores")
    local memory_reserved_mb=$(calculate_memory_reserved "$total_memory_mb")
    
    log_info "Reservas do sistema (baseado em padrões GKE/EKS):"
    log_info "CPU Reservada: ${cpu_reserved_millicores}m"
    log_info "Memória Reservada: ${memory_reserved_mb}MB"
    
    local safety_factor="$SAFETY_FACTOR_PROD"
    [[ "$profile" == "dev" ]] && safety_factor="$SAFETY_FACTOR_DEV"
    log_info "Fator de segurança aplicado: $safety_factor% (perfil $profile)"
    
    local available_cpu=$((total_cores * 1000 - cpu_reserved_millicores))
    local available_memory=$((total_memory_mb - memory_reserved_mb))
    
    available_cpu=$((available_cpu * safety_factor / 100))
    available_memory=$((available_memory * safety_factor / 100))
    
    [[ "$available_cpu" -lt "$MIN_CPU_MILLICORES" ]] && available_cpu="$MIN_CPU_MILLICORES"
    [[ "$available_memory" -lt "$MIN_MEMORY_MB" ]] && available_memory="$MIN_MEMORY_MB"
    
    AVAILABLE_RESOURCES[CPU_MILLICORES]="$available_cpu"
    AVAILABLE_RESOURCES[MEMORY_MB]="$available_memory"
    
    log_success "Recursos disponíveis calculados:"
    log_success "CPU: ${available_cpu}m"
    log_success "Memória: ${available_memory}MB"
}

calculate_replicas() {
    local profile="$1"
    local available_cpu_millicores="$2"
    local workload_type="$3"
    local replicas=1
    
    if [[ "$profile" == "prod" ]]; then
        local base_replicas=$((available_cpu_millicores / 1000))
        
        case "$workload_type" in
            web) replicas=$((base_replicas > 2 ? base_replicas : 2)) ;;
            task) replicas=$((base_replicas > 2 ? base_replicas : 2)) ;;
            *) replicas="$base_replicas" ;;
        esac
        
        [[ "$replicas" -lt 2 ]] && replicas=2
        [[ "$replicas" -gt 10 ]] && replicas=10
    else
        replicas=1
        [[ "$available_cpu_millicores" -ge 2000 ]] && replicas=2
    fi
    
    echo "$replicas"
}

calculate_awx_resources() {
    log_subheader "Calculando recursos específicos para AWX"
    
    local available_cpu="${AVAILABLE_RESOURCES[CPU_MILLICORES]}"
    local available_memory="${AVAILABLE_RESOURCES[MEMORY_MB]}"
    local profile="${SYSTEM_RESOURCES[PROFILE]}"
    
    local web_replicas=$(calculate_replicas "$profile" "$available_cpu" "web")
    local task_replicas=$(calculate_replicas "$profile" "$available_cpu" "task")
    
    # Calcular recursos por componente
    local web_cpu_req="${available_cpu}*15/100m"
    local web_cpu_lim="${available_cpu}*30/100m"
    local web_mem_req="${available_memory}*30/100Mi"
    local web_mem_lim="${available_memory}*50/100Mi"
    
    local task_cpu_req="${available_cpu}*15/100m"
    local task_cpu_lim="${available_cpu}*60/100m"
    local task_mem_req="${available_memory}*30/100Mi"
    local task_mem_lim="${available_memory}*50/100Mi"
    
    # Garantir valores mínimos
    [[ "${web_cpu_req%m}" -lt 1000 ]] && web_cpu_req="1000m"
    [[ "${web_mem_req%Mi}" -lt 1024 ]] && web_mem_req="1024Mi"
    [[ "${task_cpu_req%m}" -lt 1000 ]] && task_cpu_req="1000m"
    [[ "${task_mem_req%Mi}" -lt 1024 ]] && task_mem_req="1024Mi"
    
    AWX_RESOURCES[WEB_REPLICAS]="$web_replicas"
    AWX_RESOURCES[TASK_REPLICAS]="$task_replicas"
    AWX_RESOURCES[WEB_CPU_REQ]="$web_cpu_req"
    AWX_RESOURCES[WEB_CPU_LIM]="$web_cpu_lim"
    AWX_RESOURCES[WEB_MEM_REQ]="$web_mem_req"
    AWX_RESOURCES[WEB_MEM_LIM]="$web_mem_lim"
    AWX_RESOURCES[TASK_CPU_REQ]="$task_cpu_req"
    AWX_RESOURCES[TASK_CPU_LIM]="$task_cpu_lim"
    AWX_RESOURCES[TASK_MEM_REQ]="$task_mem_req"
    AWX_RESOURCES[TASK_MEM_LIM]="$task_mem_lim"
    
    log_success "Configuração final calculada:"
    log_success "Web Réplicas: $web_replicas"
    log_success "Task Réplicas: $task_replicas"
    log_success "Web CPU: $web_cpu_req - $web_cpu_lim"
}