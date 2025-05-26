#!/bin/bash
# lib/utils/diagnostics.sh - Ferramentas de diagnóstico

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

diagnose_system_resources() {
    log_header "DIAGNÓSTICO DE RECURSOS DO SISTEMA"
    
    # CPU
    local cpu_count=$(nproc --all)
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    log_info "CPU: $cpu_count cores, Load Average: $cpu_load"
    
    # Memória
    local mem_info=$(free -h | grep Mem)
    log_info "Memória: $mem_info"
    
    # Disco
    local disk_info=$(df -h / | tail -1)
    log_info "Disco raiz: $disk_info"
    
    # Rede
    if check_network_connectivity; then
        log_success "Conectividade de rede: OK"
    else
        log_error "Conectividade de rede: FALHA"
    fi
}

diagnose_docker_environment() {
    log_header "DIAGNÓSTICO DO AMBIENTE DOCKER"
    
    if ! command_exists docker; then
        log_error "Docker não está instalado"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon não está acessível"
        return 1
    fi
    
    log_success "Docker: $(docker --version)"
    log_info "Docker Info:"
    docker info --format "{{.ServerVersion}}" | while read -r line; do
        log_info "  Versão do servidor: $line"
    done
    
    # Verificar containers em execução
    local running_containers=$(docker ps --format "table {{.Names}}\t{{.Status}}" | tail -n +2)
    if [[ -n "$running_containers" ]]; then
        log_info "Containers em execução:"
        echo "$running_containers" | while read -r line; do
            log_info "  $line"
        done
    fi
}

diagnose_kubernetes_cluster() {
    log_header "DIAGNÓSTICO DO CLUSTER KUBERNETES"
    
    if ! command_exists kubectl; then
        log_error "kubectl não está instalado"
        return 1
    fi
    
    # Verificar conexão com cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Não foi possível conectar ao cluster Kubernetes"
        return 1
    fi
    
    log_success "Cluster Kubernetes acessível"
    
    # Informações dos nós
    log_info "Nós do cluster:"
    kubectl get nodes --no-headers | while read -r line; do
        log_info "  $line"
    done
    
    # Recursos do cluster
    if kubectl top nodes >/dev/null 2>&1; then
        log_info "Uso de recursos dos nós:"
        kubectl top nodes | while read -r line; do
            log_info "  $line"
        done
    fi
}

diagnose_awx_pods() {
    log_header "DIAGNÓSTICO DOS PODS AWX"
    local namespace="${1:-awx}"
    
    # Status dos pods
    log_info "Status dos pods no namespace $namespace:"
    kubectl get pods -n "$namespace" -o wide 2>/dev/null | while read -r line; do
        log_info "  $line"
    done
    
    # Eventos recentes
    log_info "Eventos recentes:"
    kubectl get events -n "$namespace" --sort-by='.metadata.creationTimestamp' | tail -10 | while read -r line; do
        log_info "  $line"
    done
    
    # Logs de pods com problemas
    local failed_pods=$(kubectl get pods -n "$namespace" --field-selector=status.phase=Failed -o name 2>/dev/null)
    if [[ -n "$failed_pods" ]]; then
        log_warning "Pods com falha detectados:"
        echo "$failed_pods" | while read -r pod; do
            log_error "Logs do $pod:"
            kubectl logs -n "$namespace" "$pod" --previous --tail=20 2>/dev/null | while read -r line; do
                log_error "    $line"
            done
        done
    fi
}

run_full_diagnostics() {
    log_header "EXECUTANDO DIAGNÓSTICO COMPLETO"
    
    diagnose_system_resources
    echo
    diagnose_docker_environment
    echo
    diagnose_kubernetes_cluster
    echo
    diagnose_awx_pods "$1"
    
    log_success "Diagnóstico completo finalizado"
}
