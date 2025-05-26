#!/bin/bash
# lib/core/resource_calculator.sh - Cálculo inteligente de recursos do sistema

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Constantes para cálculo de recursos
readonly SAFETY_FACTOR_PROD=70
readonly SAFETY_FACTOR_DEV=80
readonly MIN_CPU_MILLICORES=500
readonly MIN_MEMORY_MB=512

# Estrutura para armazenar resultados de cálculos
declare -A SYSTEM_RESOURCES
declare -A AVAILABLE_RESOURCES
declare -A AWX_RESOURCES

# Detecção de recursos do sistema
detect_system_resources() {
    log_debug "Iniciando detecção de recursos do sistema"
    
    # CPU Detection
    if [[ -n "$FORCE_CPU" ]]; then
        SYSTEM_RESOURCES[CPU_CORES]="$FORCE_CPU"
        log_debug "CPU forçada: ${FORCE_CPU} cores"
    else
        SYSTEM_RESOURCES[CPU_CORES]=$(nproc --all)
        log_debug "CPU detectada: ${SYSTEM_RESOURCES[CPU_CORES]} cores"
    fi
    
    # Memory Detection
    if [[ -n "$FORCE_MEM_MB" ]]; then
        SYSTEM_RESOURCES[MEMORY_MB]="$FORCE_MEM_MB"
        log_debug "Memória forçada: ${FORCE_MEM_MB}MB"
    else
        SYSTEM_RESOURCES[MEMORY_MB]=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
        log_debug "Memória detectada: ${SYSTEM_RESOURCES[MEMORY_MB]}MB"
    fi
    
    # Profile Determination
    determine_system_profile
    
    log_info "Recursos do sistema detectados:"
    log_info "   CPUs: ${SYSTEM_RESOURCES[CPU_CORES]} cores"
    log_info "   Memória: ${SYSTEM_RESOURCES[MEMORY_MB]}MB"
    log_info "   Perfil: ${SYSTEM_RESOURCES[PROFILE]}"
}

# Determinação do perfil do sistema
determine_system_profile() {
    local cores=${SYSTEM_RESOURCES[CPU_CORES]}
    local memory_mb=${SYSTEM_RESOURCES[MEMORY_MB]}
    
    if [[ $cores -ge 4 && $memory_mb -ge 8192 ]]; then
        SYSTEM_RESOURCES[PROFILE]="prod"
    else
        SYSTEM_RESOURCES[PROFILE]="dev"
    fi
    
    log_debug "Perfil determinado: ${SYSTEM_RESOURCES[PROFILE]}"
}

# Cálculo de CPU reservada baseado em padrões GKE/EKS
calculate_cpu_reserved() {
    local total_cores="$1"
    local reserved_millicores=0
    local remaining_cores=$total_cores

    # Algoritmo baseado em padrões de cloud providers
    if [[ $total_cores -ge 1 ]]; then
        reserved_millicores=$((reserved_millicores + 60))
        remaining_cores=$((remaining_cores - 1))
    fi

    if [[ $remaining_cores -ge 1 ]]; then
        reserved_millicores=$((reserved_millicores + 10))
        remaining_cores=$((remaining_cores - 1))
    fi

    if [[ $remaining_cores -ge 2 ]]; then
        reserved_millicores=$((reserved_millicores + 10))
        remaining_cores=$((remaining_cores - 2))
    fi

    if [[ $remaining_cores -gt 0 ]]; then
        reserved_millicores=$((reserved_millicores + (remaining_cores * 25 / 10)))
    fi

    echo $reserved_millicores
}

# Cálculo de memória reservada baseado em padrões GKE/EKS
calculate_memory_reserved() {
    local total_mem_mb="$1"
    local reserved_mb=0

    if [[ $total_mem_mb -lt 1024 ]]; then
        reserved_mb=255
    else
        # Primeiro 4GB - 25%
        local first_4gb=$((total_mem_mb > 4096 ? 4096 : total_mem_mb))
        reserved_mb=$((first_4gb * 25 / 100))
        local remaining_mb=$((total_mem_mb - first_4gb))

        # Próximos 4GB - 20%
        if [[ $remaining_mb -gt 0 ]]; then
            local next_4gb=$((remaining_mb > 4096 ? 4096 : remaining_mb))
            reserved_mb=$((reserved_mb + next_4gb * 20 / 100))
            remaining_mb=$((remaining_mb - next_4gb))
        fi

        # Próximos 8GB - 10%
        if [[ $remaining_mb -gt 0 ]]; then
            local next_8gb=$((remaining_mb > 8192 ? 8192 : remaining_mb))
            reserved_mb=$((reserved_mb + next_8gb * 10 / 100))
            remaining_mb=$((remaining_mb - next_8gb))
        fi

        # Próximos 112GB - 6%
        if [[ $remaining_mb -gt 0 ]]; then
            local next_112gb=$((remaining_mb > 114688 ? 114688 : remaining_mb))
            reserved_mb=$((reserved_mb + next_112gb * 6 / 100))
            remaining_mb=$((remaining_mb - next_112gb))
        fi

        # Restante - 2%
        if [[ $remaining_mb -gt 0 ]]; then
            reserved_mb=$((reserved_mb + remaining_mb * 2 / 100))
        fi
    fi

    # Buffer adicional de segurança
    reserved_mb=$((reserved_mb + 100))
    echo $reserved_mb
}

# Cálculo de recursos disponíveis para AWX
calculate_available_resources() {
    log_subheader "Calculando recursos disponíveis para AWX"
    
    local total_cores=${SYSTEM_RESOURCES[CPU_CORES]}
    local total_memory_mb=${SYSTEM_RESOURCES[MEMORY_MB]}
    local profile=${SYSTEM_RESOURCES[PROFILE]}
    
    # Calcular reservas do sistema
    local cpu_reserved_millicores=$(calculate_cpu_reserved "$total_cores")
    local memory_reserved_mb=$(calculate_memory_reserved "$total_memory_mb")
    
    log_info "Reservas do sistema (baseado em padrões GKE/EKS):"
    log_info "   CPU Reservada: ${cpu_reserved_millicores}m"
    log_info "   Memória Reservada: ${memory_reserved_mb}MB"
    
    # Aplicar fator de segurança
    local safety_factor=$SAFETY_FACTOR_PROD
    [[ "$profile" == "dev" ]] && safety_factor=$SAFETY_FACTOR_DEV
    
    log_info "Fator de segurança aplicado: ${safety_factor}% (perfil: $profile)"
    
    # Calcular recursos disponíveis
    local available_cpu=$((total_cores * 1000 - cpu_reserved_millicores))
    local available_memory=$((total_memory_mb - memory_reserved_mb))
    
    available_cpu=$((available_cpu * safety_factor / 100))
    available_memory=$((available_memory * safety_factor / 100))
    
    # Garantir valores mínimos
    [[ $available_cpu -lt $MIN_CPU_MILLICORES ]] && available_cpu=$MIN_CPU_MILLICORES
    [[ $available_memory -lt $MIN_MEMORY_MB ]] && available_memory=$MIN_MEMORY_MB
    
    # Armazenar resultados
    AVAILABLE_RESOURCES[CPU_MILLICORES]=$available_cpu
    AVAILABLE_RESOURCES[MEMORY_MB]=$available_memory
    
    log_success "Recursos disponíveis calculados:"
    log_success "   CPU: ${available_cpu}m"
    log_success "   Memória: ${available_memory}MB"
}

# Cálculo de réplicas baseado em recursos
calculate_replicas() {
    local profile="$1"
    local available_cpu_millicores="$2"
    local workload_type="$3"
    local replicas=1

    if [[ "$profile" == "prod" ]]; then
        local base_replicas=$((available_cpu_millicores / 1000))
        
        case "$workload_type" in
            "web")
                replicas=$((base_replicas * 2 / 3))
                ;;
            "task")
                replicas=$((base_replicas / 2))
                ;;
            *)
                replicas=$base_replicas
                ;;
        esac
        
        # Limites para produção
        [[ $replicas -lt 2 ]] && replicas=2
        [[ $replicas -gt 10 ]] && replicas=10
    else
        # Desenvolvimento: configuração simples
        replicas=1
        [[ $available_cpu_millicores -ge 2000 ]] && replicas=2
    fi

    echo $replicas
}

# Cálculo de recursos específicos para componentes AWX
calculate_awx_resources() {
    log_subheader "Calculando recursos específicos para AWX"
    
    local available_cpu=${AVAILABLE_RESOURCES[CPU_MILLICORES]}
    local available_memory=${AVAILABLE_RESOURCES[MEMORY_MB]}
    local profile=${SYSTEM_RESOURCES[PROFILE]}
    
    # Calcular réplicas
    local web_replicas=$(calculate_replicas "$profile" "$available_cpu" "web")
    local task_replicas=$(calculate_replicas "$profile" "$available_cpu" "task")
    
    # Calcular recursos por componente
    local web_cpu_req="$((available_cpu * 15 / 100))m"
    local web_cpu_lim="$((available_cpu * 30 / 100))m"
    local web_mem_req="$((available_memory * 30 / 100))Mi"
    local web_mem_lim="$((available_memory * 50 / 100))Mi"
    
    local task_cpu_req="$((available_cpu * 15 / 100))m"
    local task_cpu_lim="$((available_cpu * 60 / 100))m"
    local task_mem_req="$((available_memory * 30 / 100))Mi"
    local task_mem_lim="$((available_memory * 50 / 100))Mi"
    
    # Garantir valores mínimos
    [[ ${web_cpu_req%m} -lt 1000 ]] && web_cpu_req="1000m"
    [[ ${web_mem_req%Mi} -lt 1024 ]] && web_mem_req="1024Mi"
    [[ ${task_cpu_req%m} -lt 1000 ]] && task_cpu_req="1000m"
    [[ ${task_mem_req%Mi} -lt 1024 ]] && task_mem_req="1024Mi"
    
    # Armazenar resultados
    AWX_RESOURCES[WEB_REPLICAS]=$web_replicas
    AWX_RESOURCES[TASK_REPLICAS]=$task_replicas
    AWX_RESOURCES[WEB_CPU_REQ]="$web_cpu_req"
    AWX_RESOURCES[WEB_CPU_LIM]="$web_cpu_lim"
    AWX_RESOURCES[WEB_MEM_REQ]="$web_mem_req"
    AWX_RESOURCES[WEB_MEM_LIM]="$web_mem_lim"
    AWX_RESOURCES[TASK_CPU_REQ]="$task_cpu_req"
    AWX_RESOURCES[TASK_CPU_LIM]="$task_cpu_lim"
    AWX_RESOURCES[TASK_MEM_REQ]="$task_mem_req"
    AWX_RESOURCES[TASK_MEM_LIM]="$task_mem_lim"
    
    log_success "Configuração final calculada:"
    log_success "   Web Réplicas: $web_replicas"
    log_success "   Task Réplicas: $task_replicas"
    log_success "   Web CPU: $web_cpu_req - $web_cpu_lim"
    log_success "   Web Mem: $web_mem_req - $web_mem_lim"
    log_success "   Task CPU: $task_cpu_req - $task_cpu_lim"
    log_success "   Task Mem: $task_mem_req - $task_mem_lim"
}

# Função principal de inicialização
initialize_resource_calculations() {
    log_header "ANÁLISE E CÁLCULO DE RECURSOS"
    
    detect_system_resources
    calculate_available_resources
    calculate_awx_resources
    
    log_debug "Cálculos de recursos concluídos com sucesso"
}

# Função para exportar variáveis para compatibilidade
export_resource_variables() {
    export CORES=${SYSTEM_RESOURCES[CPU_CORES]}
    export MEM_MB=${SYSTEM_RESOURCES[MEMORY_MB]}
    export PERFIL=${SYSTEM_RESOURCES[PROFILE]}
    export AVAILABLE_CPU_MILLICORES=${AVAILABLE_RESOURCES[CPU_MILLICORES]}
    export AVAILABLE_MEMORY_MB=${AVAILABLE_RESOURCES[MEMORY_MB]}
    export WEB_REPLICAS=${AWX_RESOURCES[WEB_REPLICAS]}
    export TASK_REPLICAS=${AWX_RESOURCES[TASK_REPLICAS]}
    export AWX_WEB_CPU_REQ=${AWX_RESOURCES[WEB_CPU_REQ]}
    export AWX_WEB_CPU_LIM=${AWX_RESOURCES[WEB_CPU_LIM]}
    export AWX_WEB_MEM_REQ=${AWX_RESOURCES[WEB_MEM_REQ]}
    export AWX_WEB_MEM_LIM=${AWX_RESOURCES[WEB_MEM_LIM]}
    export AWX_TASK_CPU_REQ=${AWX_RESOURCES[TASK_CPU_REQ]}
    export AWX_TASK_CPU_LIM=${AWX_RESOURCES[TASK_CPU_LIM]}
    export AWX_TASK_MEM_REQ=${AWX_RESOURCES[TASK_MEM_REQ]}
    export AWX_TASK_MEM_LIM=${AWX_RESOURCES[TASK_MEM_LIM]}
}
