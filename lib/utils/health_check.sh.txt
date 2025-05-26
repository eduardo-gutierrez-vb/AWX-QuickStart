#!/bin/bash
# lib/utils/health_check.sh - Verificações de saúde do sistema

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Verificação de saúde do sistema
health_check_system() {
    log_subheader "Verificação de Saúde do Sistema"
    
    local issues=()
    
    # Verificar espaço em disco
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        issues+=("Espaço em disco crítico: ${disk_usage}%")
    fi
    
    # Verificar memória disponível
    local mem_available=$(free | grep Mem | awk '{printf "%.0f", $7/$2 * 100}')
    if [[ $mem_available -lt 10 ]]; then
        issues+=("Memória disponível baixa: ${mem_available}%")
    fi
    
    # Verificar load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' | cut -d'.' -f1)
    local cpu_count=$(nproc --all)
    if [[ $load_avg -gt $((cpu_count * 2)) ]]; then
        issues+=("Load average alto: $load_avg (CPUs: $cpu_count)")
    fi
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        log_success "Sistema saudável"
        return 0
    else
        log_warning "Problemas detectados:"
        for issue in "${issues[@]}"; do
            log_warning "  - $issue"
        done
        return 1
    fi
}

# Verificação de saúde do Docker
health_check_docker() {
    log_subheader "Verificação de Saúde do Docker"
    
    if ! docker system df >/dev/null 2>&1; then
        log_error "Docker não está funcionando"
        return 1
    fi
    
    # Verificar uso de espaço do Docker
    local docker_usage=$(docker system df --format "table {{.Type}}\t{{.Size}}" | grep -v TYPE)
    log_info "Uso de espaço do Docker:"
    echo "$docker_usage" | while read -r line; do
        log_info "  $line"
    done
    
    # Verificar containers parados há muito tempo
    local old_containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}" --filter "since=24h")
    if [[ -n "$old_containers" ]]; then
        log_warning "Containers parados há mais de 24h:"
        echo "$old_containers" | while read -r container; do
            log_warning "  $container"
        done
    fi
    
    log_success "Docker funcionando normalmente"
    return 0
}

# Verificação de saúde do Kubernetes
health_check_kubernetes() {
    log_subheader "Verificação de Saúde do Kubernetes"
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cluster Kubernetes não está acessível"
        return 1
    fi
    
    # Verificar nós não prontos
    local not_ready_nodes=$(kubectl get nodes --no-headers | grep -v " Ready " | awk '{print $1}')
    if [[ -n "$not_ready_nodes" ]]; then
        log_warning "Nós não prontos:"
        echo "$not_ready_nodes" | while read -r node; do
            log_warning "  $node"
        done
    fi
    
    # Verificar pods em estado problemático
    local problem_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null)
    if [[ -n "$problem_pods" ]]; then
        log_warning "Pods em estado problemático:"
        echo "$problem_pods" | while read -r line; do
            log_warning "  $line"
        done
    fi
    
    log_success "Cluster Kubernetes funcionando normalmente"
    return 0
}

# Verificação de saúde do AWX
health_check_awx() {
    local namespace="${1:-awx}"
    local instance_name="${2:-awx-prod}"
    
    log_subheader "Verificação de Saúde do AWX"
    
    # Verificar se o AWX está instalado
    if ! kubectl get awx "$instance_name" -n "$namespace" >/dev/null 2>&1; then
        log_error "Instância AWX '$instance_name' não encontrada no namespace '$namespace'"
        return 1
    fi
    
    # Verificar status dos pods
    local awx_pods=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/managed-by=awx-operator --no-headers)
    local running_pods=$(echo "$awx_pods" | grep -c "Running" || echo "0")
    local total_pods=$(echo "$awx_pods" | wc -l)
    
    if [[ $running_pods -eq $total_pods && $total_pods -gt 0 ]]; then
        log_success "Todos os pods AWX estão funcionando ($running_pods/$total_pods)"
    else
        log_warning "Nem todos os pods AWX estão funcionando ($running_pods/$total_pods)"
        echo "$awx_pods" | while read -r line; do
            log_info "  $line"
        done
    fi
    
    # Verificar conectividade do serviço
    local service_ip=$(kubectl get service -n "$namespace" -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
    if [[ -n "$service_ip" ]]; then
        log_info "Serviço AWX disponível em: $service_ip"
    fi
    
    return 0
}

# Verificação completa de saúde
run_health_checks() {
    log_header "VERIFICAÇÃO COMPLETA DE SAÚDE"
    
    local all_healthy=true
    
    if ! health_check_system; then
        all_healthy=false
    fi
    echo
    
    if ! health_check_docker; then
        all_healthy=false
    fi
    echo
    
    if ! health_check_kubernetes; then
        all_healthy=false
    fi
    echo
    
    if ! health_check_awx "$1" "$2"; then
        all_healthy=false
    fi
    
    if $all_healthy; then
        log_success "Todas as verificações de saúde passaram"
        return 0
    else
        log_warning "Algumas verificações de saúde falharam"
        return 1
    fi
}
