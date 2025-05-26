#!/bin/bash
# lib/services/awx_installer.sh - Instalação e configuração AWX

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/resource_calculator.sh"

install_awx() {
    log_header "INSTALAÇÃO DO AWX OPERATOR"
    
    log_info "Adicionando repositório Helm do AWX Operator..."
    helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ 2>/dev/null || true
    helm repo update
    
    log_info "Criando namespace..."
    kubectl create namespace "$AWX_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    log_info "Instalando AWX Operator usando Helm..."
    helm upgrade --install awx-operator awx-operator/awx-operator \
        -n "$AWX_NAMESPACE" --create-namespace --wait --timeout=10m
    
    log_success "AWX Operator instalado com sucesso!"
}

create_awx_instance() {
    log_info "Criando instância AWX..."
    calculate_awx_resources
    
    cat > /tmp/awx-instance.yaml << EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-$PERFIL
  namespace: $AWX_NAMESPACE
spec:
  service_type: nodeport
  nodeport_port: $HOST_PORT
  admin_user: admin
  admin_email: sno@cgrupvob.com.br
  
  control_plane_ee_image: localhost:${REGISTRY_PORT:-5001}/awx-enterprise-ee:latest
  
  replicas: $WEB_REPLICAS
  web_replicas: $WEB_REPLICAS
  task_replicas: $TASK_REPLICAS
  
  web_resource_requirements:
    requests:
      cpu: $AWX_WEB_CPU_REQ
      memory: $AWX_WEB_MEM_REQ
    limits:
      cpu: $AWX_WEB_CPU_LIM
      memory: $AWX_WEB_MEM_LIM
      
  task_resource_requirements:
    requests:
      cpu: $AWX_TASK_CPU_REQ
      memory: $AWX_TASK_MEM_REQ
    limits:
      cpu: $AWX_TASK_CPU_LIM
      memory: $AWX_TASK_MEM_LIM
      
  postgres_configuration_secret: awx-postgres-configuration
  postgres_storage_requirements:
    requests:
      storage: 8Gi
    limits:
      storage: 8Gi
      
  projects_persistence: true
  projects_storage_size: 8Gi
  projects_storage_access_mode: ReadWriteOnce
EOF
    
    kubectl apply -f /tmp/awx-instance.yaml -n "$AWX_NAMESPACE"
    
    log_success "Instância AWX criada com recursos calculados dinamicamente!"
}

wait_for_awx() {
    log_header "AGUARDANDO INSTALAÇÃO DO AWX"
    
    if ! kubectl get namespace "$AWX_NAMESPACE" &>/dev/null; then
        log_error "Namespace $AWX_NAMESPACE não existe!"
        return 1
    fi
    
    local phases=("Pending" "ContainerCreating" "Running")
    local timeout=120
    
    for phase in "${phases[@]}"; do
        log_info "Aguardando pods na fase $phase"
        local elapsed=0
        
        while [[ "$elapsed" -lt "$timeout" ]]; do
            local pod_count=$(kubectl get pods -n "$AWX_NAMESPACE" \
                --field-selector=status.phase="$phase" --no-headers 2>/dev/null | wc -l)
            
            if [[ "$pod_count" -gt 0 ]]; then
                log_success "Encontrados $pod_count pods na fase $phase"
                kubectl get pods -n "$AWX_NAMESPACE"
                break
            fi
            
            sleep 10
            elapsed=$((elapsed + 10))
            echo -n "."
        done
        echo
    done
    
    if ! kubectl wait --for=condition=Ready pods --all -n "$AWX_NAMESPACE" --timeout=600s; then
        log_error "Pods não ficaram prontos. Executando diagnóstico..."
        diagnose_awx_pods
        check_cluster_resources
        check_registry
        exit 1
    fi
}

get_awx_password() {
    log_info "Obtendo senha do administrador AWX..."
    
    local timeout=300
    local elapsed=0
    
    while ! kubectl get secret "awx-$PERFIL-admin-password" -n "$AWX_NAMESPACE" &>/dev/null; do
        if [[ "$elapsed" -ge "$timeout" ]]; then
            log_error "Timeout aguardando senha do AWX. Verifique os logs:"
            log_error "kubectl logs -n $AWX_NAMESPACE deployment/awx-operator-controller-manager"
            exit 1
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    echo
    
    AWX_PASSWORD=$(kubectl get secret "awx-$PERFIL-admin-password" -n "$AWX_NAMESPACE" \
        -o jsonpath="{.data.password}" | base64 --decode)
}

show_final_info() {
    log_header "INSTALAÇÃO CONCLUÍDA"
    
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    echo
    log_success "AWX IMPLANTADO COM SUCESSO"
    echo
    
    log_info "INFORMAÇÕES DE ACESSO:"
    log_info "URL: ${GREEN}http://$node_ip:$HOST_PORT${NC}"
    log_info "Usuário: ${GREEN}admin${NC}"
    log_info "Senha: ${GREEN}$AWX_PASSWORD${NC}"
    echo
    
    log_info "CONFIGURAÇÃO DO SISTEMA:"
    log_info "Perfil: ${GREEN}$PERFIL${NC}"
    log_info "CPUs Detectadas: ${GREEN}$CORES${NC}"
    log_info "Memória Detectada: ${GREEN}$MEM_MB MB${NC}"
    log_info "Web Réplicas: ${GREEN}$WEB_REPLICAS${NC}"
    log_info "Task Réplicas: ${GREEN}$TASK_REPLICAS${NC}"
    echo
    
    log_info "RECURSOS ALOCADOS:"
    log_info "Web CPU: ${GREEN}$AWX_WEB_CPU_REQ - $AWX_WEB_CPU_LIM${NC}"
    log_info "Web Mem: ${GREEN}$AWX_WEB_MEM_REQ - $AWX_WEB_MEM_LIM${NC}"
    log_info "Task CPU: ${GREEN}$AWX_TASK_CPU_REQ - $AWX_TASK_CPU_LIM${NC}"
    log_info "Task Mem: ${GREEN}$AWX_TASK_MEM_REQ - $AWX_TASK_MEM_LIM${NC}"
    echo
    
    log_info "COMANDOS ÚTEIS:"
    log_info "Ver pods: ${CYAN}kubectl get pods -n $AWX_NAMESPACE${NC}"
    log_info "Ver logs web: ${CYAN}kubectl logs -n $AWX_NAMESPACE deployment/awx-$PERFIL-web${NC}"
    log_info "Ver logs task: ${CYAN}kubectl logs -n $AWX_NAMESPACE deployment/awx-$PERFIL-task${NC}"
    log_info "Diagnosticar problemas: ${CYAN}diagnose_awx_pods${NC}"
    log_info "Deletar cluster: ${CYAN}kind delete cluster --name $CLUSTER_NAME${NC}"
    echo
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "STATUS ATUAL DOS PODS:"
        kubectl get pods -n "$AWX_NAMESPACE" -o wide
    fi
}
