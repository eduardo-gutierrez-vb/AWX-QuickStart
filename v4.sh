#!/bin/bash
set -e

# ============================
# CONFIGURAÇÕES PERSONALIZÁVEIS
# ============================

# Arquivo de configuração personalizada (opcional)
CONFIG_FILE="${HOME}/.awx-deploy.conf"

# Configurações padrão (facilmente editáveis)
DEFAULT_CONFIG() {
    # Cluster e Networking
    export DEFAULT_CLUSTER_NAME="awx-cluster"
    export DEFAULT_HOST_PORT=8080
    export DEFAULT_NAMESPACE="awx"
    
    # Recursos e Performance
    export MIN_CPU_CORES=2
    export MIN_MEMORY_MB=4096
    export PROD_CPU_THRESHOLD=4
    export PROD_MEMORY_THRESHOLD=8192
    
    # Nomes fixos para recursos (evita nomes aleatórios)
    export AWX_INSTANCE_NAME="awx-main"
    export OPERATOR_RELEASE_NAME="awx-operator"
    export EE_IMAGE_TAG="custom-ee"
    
    # Timeouts e Intervalos
    export POD_READY_TIMEOUT=600
    export OPERATOR_TIMEOUT=300
    export REGISTRY_STARTUP_WAIT=10
    
    # Recursos AWX por perfil
    export DEV_WEB_CPU_LIMIT="500m"
    export DEV_WEB_MEMORY_LIMIT="1Gi"
    export DEV_TASK_CPU_LIMIT="1000m"
    export DEV_TASK_MEMORY_LIMIT="2Gi"
    
    export PROD_WEB_CPU_LIMIT="2000m"
    export PROD_WEB_MEMORY_LIMIT="4Gi"
    export PROD_TASK_CPU_LIMIT="4000m"
    export PROD_TASK_MEMORY_LIMIT="8Gi"
}

# Carregar configurações
load_config() {
    DEFAULT_CONFIG
    
    if [ -f "$CONFIG_FILE" ]; then
        log_info "Carregando configuração personalizada de: $CONFIG_FILE"
        source "$CONFIG_FILE"
    fi
}

# ============================
# SISTEMA DE LOG MELHORADO
# ============================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Sistema de log com timestamp e níveis
log_with_level() {
    local level=$1
    local color=$2
    local message=$3
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${color}[${timestamp}] [${level}]${NC} $message"
}

log_info() {
    log_with_level "INFO" "$BLUE" "$1"
}

log_success() {
    log_with_level "SUCCESS" "$GREEN" "$1"
}

log_warning() {
    log_with_level "WARNING" "$YELLOW" "$1"
}

log_error() {
    log_with_level "ERROR" "$RED" "$1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        log_with_level "DEBUG" "$PURPLE" "$1"
    fi
}

log_header() {
    echo ""
    echo -e "${CYAN}=====================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${CYAN}=====================================${NC}"
    echo ""
}

# Progress bar melhorado
show_progress() {
    local current=$1
    local total=$2
    local desc="${3:-Processando}"
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[INFO]${NC} %s: [" "$desc"
    printf "%0.s█" $(seq 1 $filled)
    printf "%0.s░" $(seq 1 $empty)
    printf "] %d%% (%d/%d)" $percent $current $total
    
    if [ $current -eq $total ]; then
        echo ""
    fi
}

# ============================
# DETECÇÃO E CÁLCULO DE RECURSOS SIMPLIFICADO
# ============================

detect_system_resources() {
    if [ -n "$FORCE_CPU" ]; then 
        CORES="$FORCE_CPU"
    else
        CORES=$(nproc --all)
    fi
    
    if [ -n "$FORCE_MEM_MB" ]; then 
        MEM_MB="$FORCE_MEM_MB"
    else
        MEM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    fi
    
    log_debug "Recursos detectados: ${CORES} CPUs, ${MEM_MB}MB RAM"
}

# Cálculo simplificado e mais preciso para ambientes locais
calculate_profile_and_resources() {
    local cores=$1
    local mem_mb=$2
    
    # Verificar requisitos mínimos
    if [ "$cores" -lt "$MIN_CPU_CORES" ] || [ "$mem_mb" -lt "$MIN_MEMORY_MB" ]; then
        log_error "Recursos insuficientes! Mínimo: ${MIN_CPU_CORES} CPUs, ${MIN_MEMORY_MB}MB RAM"
        log_error "Detectado: ${cores} CPUs, ${mem_mb}MB RAM"
        exit 1
    fi
    
    # Determinar perfil
    if [ "$cores" -ge "$PROD_CPU_THRESHOLD" ] && [ "$mem_mb" -ge "$PROD_MEMORY_THRESHOLD" ]; then
        PROFILE="prod"
        WEB_REPLICAS=2
        TASK_REPLICAS=2
        WEB_CPU_LIMIT="$PROD_WEB_CPU_LIMIT"
        WEB_MEMORY_LIMIT="$PROD_WEB_MEMORY_LIMIT"
        TASK_CPU_LIMIT="$PROD_TASK_CPU_LIMIT"
        TASK_MEMORY_LIMIT="$PROD_TASK_MEMORY_LIMIT"
    else
        PROFILE="dev"
        WEB_REPLICAS=1
        TASK_REPLICAS=1
        WEB_CPU_LIMIT="$DEV_WEB_CPU_LIMIT"
        WEB_MEMORY_LIMIT="$DEV_WEB_MEMORY_LIMIT"
        TASK_CPU_LIMIT="$DEV_TASK_CPU_LIMIT"
        TASK_MEMORY_LIMIT="$DEV_TASK_MEMORY_LIMIT"
    fi
    
    log_info "Perfil determinado: ${PROFILE}"
    log_info "Configuração: Web=${WEB_REPLICAS}, Task=${TASK_REPLICAS}"
}

# ============================
# VALIDAÇÕES ROBUSTAS
# ============================

validate_environment() {
    log_info "Validando ambiente..."
    
    # Verificar sistema operacional
    if [[ ! -f /etc/os-release ]]; then
        log_error "Sistema operacional não identificado"
        exit 1
    fi
    
    # Verificar conectividade de rede
    if ! curl -s --connect-timeout 5 https://google.com > /dev/null; then
        log_warning "Conectividade de rede limitada - algumas funcionalidades podem falhar"
    fi
    
    # Verificar espaço em disco
    local available_space=$(df / | tail -1 | awk '{print $4}')
    local required_space=5242880  # 5GB em KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_error "Espaço em disco insuficiente. Requerido: 5GB, Disponível: $((available_space/1024/1024))GB"
        exit 1
    fi
    
    log_success "Ambiente validado com sucesso"
}

# ============================
# INSTALAÇÃO DE DEPENDÊNCIAS COM FEEDBACK
# ============================

install_dependencies() {
    log_header "INSTALAÇÃO DE DEPENDÊNCIAS"
    
    validate_environment
    
    local deps=("docker" "kind" "kubectl" "helm" "python3.9")
    local total=${#deps[@]}
    local current=0
    
    for dep in "${deps[@]}"; do
        current=$((current + 1))
        show_progress $current $total "Instalando $dep"
        
        case $dep in
            "docker") install_docker_improved ;;
            "kind") install_kind_improved ;;
            "kubectl") install_kubectl_improved ;;
            "helm") install_helm_improved ;;
            "python3.9") install_python_improved ;;
        esac
        
        sleep 1  # Pequena pausa para feedback visual
    done
    
    setup_local_registry_improved
    log_success "Todas as dependências instaladas com sucesso!"
}

install_docker_improved() {
    if command -v docker &> /dev/null && docker --version &> /dev/null; then
        log_debug "Docker já instalado: $(docker --version)"
        verify_docker_setup
        return 0
    fi
    
    log_info "Instalando Docker..."
    
    # Instalação mais robusta com tratamento de erros
    sudo apt-get update -qq
    sudo apt-get install -y ca-certificates curl
    
    # Adicionar repositório Docker
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Configurar usuário
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    
    verify_docker_setup
}

verify_docker_setup() {
    # Verificar se Docker está funcionando
    if ! docker info &> /dev/null; then
        if ! groups | grep -q docker; then
            log_warning "Usuário não está no grupo docker. Execute: newgrp docker"
            newgrp docker
        fi
        
        # Aguardar Docker inicializar
        local attempts=0
        while ! docker info &> /dev/null && [ $attempts -lt 30 ]; do
            sleep 2
            attempts=$((attempts + 1))
        done
        
        if ! docker info &> /dev/null; then
            log_error "Docker não está funcionando corretamente"
            exit 1
        fi
    fi
    log_debug "Docker funcionando corretamente"
}

# ============================
# CRIAÇÃO DO CLUSTER COM NOMES FIXOS
# ============================

create_cluster_with_fixed_names() {
    log_header "CRIAÇÃO DO CLUSTER KUBERNETES"
    
    # Deletar cluster existente se necessário
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_warning "Cluster '$CLUSTER_NAME' já existe. Deletando..."
        kind delete cluster --name "$CLUSTER_NAME"
    fi
    
    log_info "Criando cluster Kind '$CLUSTER_NAME'..."
    
    # Configuração do cluster com nomes previsíveis
    local config_file="/tmp/kind-config-${CLUSTER_NAME}.yaml"
    
    cat > "$config_file" << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: ${HOST_PORT}
    hostPort: ${HOST_PORT}
    protocol: TCP
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
        extraArgs:
          enable-aggregator-routing: "true"
    metadata:
      name: config
  - |
    kind: KubeletConfiguration
    maxPods: 110
    metadata:
      name: kubelet-config
EOF

    # Adicionar worker se necessário
    if [ "$PROFILE" = "prod" ] && [ "$CORES" -ge 4 ]; then
        cat >> "$config_file" << EOF
- role: worker
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    maxPods: 110
    metadata:
      name: worker-kubelet-config
EOF
    fi
    
    # Criar cluster
    kind create cluster --config "$config_file"
    rm "$config_file"
    
    # Aguardar cluster estar pronto com feedback
    wait_for_cluster_ready
    connect_registry_to_cluster
}

wait_for_cluster_ready() {
    log_info "Aguardando cluster estar pronto..."
    
    local timeout=300
    local elapsed=0
    local interval=5
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl get nodes &> /dev/null; then
            local ready_nodes=$(kubectl get nodes --no-headers | grep Ready | wc -l)
            local total_nodes=$(kubectl get nodes --no-headers | wc -l)
            
            if [ "$ready_nodes" -eq "$total_nodes" ] && [ "$total_nodes" -gt 0 ]; then
                log_success "Cluster pronto! Nós: $ready_nodes/$total_nodes"
                return 0
            fi
            
            show_progress $elapsed $timeout "Aguardando nós ficarem prontos ($ready_nodes/$total_nodes)"
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    log_error "Timeout aguardando cluster ficar pronto"
    exit 1
}

# ============================
# INSTALAÇÃO AWX COM NOMES CONTROLADOS
# ============================

install_awx_with_fixed_names() {
    log_header "INSTALAÇÃO DO AWX"
    
    # Criar namespace
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Instalar operator com nome fixo
    install_awx_operator_fixed
    
    # Criar instância AWX com nome fixo
    create_awx_instance_fixed
    
    # Aguardar instalação com feedback detalhado
    monitor_awx_installation
}

install_awx_operator_fixed() {
    log_info "Instalando AWX Operator..."
    
    helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ 2>/dev/null || true
    helm repo update
    
    # Instalar com nome fixo e configurações específicas
    helm upgrade --install "$OPERATOR_RELEASE_NAME" awx-operator/awx-operator \
        --namespace "$NAMESPACE" \
        --set nameOverride="$OPERATOR_RELEASE_NAME" \
        --set fullnameOverride="$OPERATOR_RELEASE_NAME" \
        --wait \
        --timeout="${OPERATOR_TIMEOUT}s"
    
    log_success "AWX Operator instalado com nome fixo: $OPERATOR_RELEASE_NAME"
}

create_awx_instance_fixed() {
    log_info "Criando instância AWX..."
    
    local awx_manifest="/tmp/awx-${AWX_INSTANCE_NAME}.yaml"
    
    cat > "$awx_manifest" << EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: ${AWX_INSTANCE_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: awx
    instance: ${AWX_INSTANCE_NAME}
spec:
  service_type: nodeport
  nodeport_port: ${HOST_PORT}
  admin_user: admin
  admin_email: admin@awx.local
  
  # Nomes fixos para evitar aleatoriedade
  deployment_type: awx
  
  # Configurações de réplicas
  replicas: ${WEB_REPLICAS}
  web_replicas: ${WEB_REPLICAS}
  task_replicas: ${TASK_REPLICAS}
  
  # Recursos calculados
  web_resource_requirements:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: ${WEB_CPU_LIMIT}
      memory: ${WEB_MEMORY_LIMIT}
  
  task_resource_requirements:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: ${TASK_CPU_LIMIT}
      memory: ${TASK_MEMORY_LIMIT}
  
  # Armazenamento
  projects_persistence: true
  projects_storage_size: 8Gi
  
  # Configurações do PostgreSQL
  postgres_storage_requirements:
    requests:
      storage: 8Gi
EOF

    kubectl apply -f "$awx_manifest"
    rm "$awx_manifest"
    
    log_success "Instância AWX criada: $AWX_INSTANCE_NAME"
}

# ============================
# MONITORAMENTO MELHORADO
# ============================

monitor_awx_installation() {
    log_header "MONITORANDO INSTALAÇÃO"
    
    local timeout="$POD_READY_TIMEOUT"
    local interval=10
    local elapsed=0
    
    log_info "Aguardando pods do AWX ficarem prontos..."
    
    while [ $elapsed -lt $timeout ]; do
        local pods_status=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
        
        if [ -n "$pods_status" ]; then
            local total_pods=$(echo "$pods_status" | wc -l)
            local ready_pods=$(echo "$pods_status" | grep -c "Running\|Completed" || echo "0")
            local pending_pods=$(echo "$pods_status" | grep -c "Pending\|ContainerCreating\|Init" || echo "0")
            local error_pods=$(echo "$pods_status" | grep -c "Error\|CrashLoopBackOff\|ImagePullBackOff" || echo "0")
            
            # Mostrar progresso detalhado
            printf "\r${BLUE}[INFO]${NC} Status: Ready: %d, Pending: %d, Error: %d, Total: %d (%ds)" \
                   $ready_pods $pending_pods $error_pods $total_pods $elapsed
            
            # Verificar se há erros
            if [ "$error_pods" -gt 0 ]; then
                echo ""
                log_error "Encontrados pods com erro. Exibindo detalhes:"
                kubectl get pods -n "$NAMESPACE" | grep -E "Error|CrashLoopBackOff|ImagePullBackOff"
                show_troubleshooting_tips
                exit 1
            fi
            
            # Verificar se instalação está completa
            if [ "$ready_pods" -gt 0 ] && [ "$pending_pods" -eq 0 ] && [ "$total_pods" -ge 3 ]; then
                echo ""
                log_success "Instalação concluída! Todos os pods estão prontos."
                return 0
            fi
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo ""
    log_error "Timeout na instalação do AWX"
    show_troubleshooting_tips
    exit 1
}

show_troubleshooting_tips() {
    log_warning "Dicas para solução de problemas:"
    echo "  1. Verificar logs: kubectl logs -n $NAMESPACE deployment/${OPERATOR_RELEASE_NAME}"
    echo "  2. Verificar eventos: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
    echo "  3. Verificar recursos: kubectl top nodes"
    echo "  4. Reiniciar: kind delete cluster --name $CLUSTER_NAME && $0"
}

# ============================
# RELATÓRIO FINAL MELHORADO
# ============================

generate_final_report() {
    log_header "RELATÓRIO DE INSTALAÇÃO"
    
    # Obter informações do cluster
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    local awx_password=$(kubectl get secret "${AWX_INSTANCE_NAME}-admin-password" -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 --decode 2>/dev/null || echo "Aguardando...")
    
    # Informações do sistema
    local cluster_info=$(kubectl cluster-info --context kind-${CLUSTER_NAME} | head -1)
    local pods_count=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    local services_count=$(kubectl get svc -n "$NAMESPACE" --no-headers | wc -l)
    
    cat << EOF

${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}
${GREEN}║                    INSTALAÇÃO CONCLUÍDA                     ║${NC}
${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}

${CYAN}📋 INFORMAÇÕES DE ACESSO:${NC}
   🌐 URL: ${GREEN}http://localhost:${HOST_PORT}${NC}
   👤 Usuário: ${GREEN}admin${NC}
   🔑 Senha: ${GREEN}${awx_password}${NC}

${CYAN}🔧 CONFIGURAÇÃO DO SISTEMA:${NC}
   💻 Perfil: ${GREEN}${PROFILE}${NC}
   🖥️  CPUs: ${GREEN}${CORES}${NC}
   💾 Memória: ${GREEN}${MEM_MB}MB${NC}
   📦 Cluster: ${GREEN}${CLUSTER_NAME}${NC}
   🏠 Namespace: ${GREEN}${NAMESPACE}${NC}

${CYAN}📊 RECURSOS IMPLANTADOS:${NC}
   🌐 Web Réplicas: ${GREEN}${WEB_REPLICAS}${NC} (Limite CPU: ${WEB_CPU_LIMIT}, RAM: ${WEB_MEMORY_LIMIT})
   ⚙️  Task Réplicas: ${GREEN}${TASK_REPLICAS}${NC} (Limite CPU: ${TASK_CPU_LIMIT}, RAM: ${TASK_MEMORY_LIMIT})
   📋 Pods Ativos: ${GREEN}${pods_count}${NC}
   🔌 Serviços: ${GREEN}${services_count}${NC}

${CYAN}🛠️  COMANDOS ÚTEIS:${NC}
   Ver status: ${YELLOW}kubectl get pods -n ${NAMESPACE}${NC}
   Ver logs web: ${YELLOW}kubectl logs -n ${NAMESPACE} deployment/${AWX_INSTANCE_NAME}-web${NC}
   Ver logs task: ${YELLOW}kubectl logs -n ${NAMESPACE} deployment/${AWX_INSTANCE_NAME}-task${NC}
   Acessar pod: ${YELLOW}kubectl exec -n ${NAMESPACE} -it deployment/${AWX_INSTANCE_NAME}-web -- bash${NC}
   Deletar tudo: ${YELLOW}kind delete cluster --name ${CLUSTER_NAME}${NC}

${CYAN}⚙️  CONFIGURAÇÃO PERSONALIZADA:${NC}
   Arquivo: ${GREEN}${CONFIG_FILE}${NC}
   Edite este arquivo para personalizar futuras instalações.

EOF

    # Criar arquivo de configuração exemplo se não existir
    if [ ! -f "$CONFIG_FILE" ]; then
        create_example_config
    fi
    
    # Mostrar status atual detalhado se verbose
    if [ "$VERBOSE" = true ]; then
        echo "${CYAN}🔍 STATUS DETALHADO:${NC}"
        kubectl get all -n "$NAMESPACE"
    fi
}

create_example_config() {
    log_info "Criando arquivo de configuração exemplo..."
    
    cat > "$CONFIG_FILE" << EOF
# Configuração personalizada para AWX Deploy
# Edite conforme necessário

# Cluster e Networking
DEFAULT_CLUSTER_NAME="meu-awx-cluster"
DEFAULT_HOST_PORT=8080
DEFAULT_NAMESPACE="awx"

# Limites de recursos personalizados
PROD_CPU_THRESHOLD=6
PROD_MEMORY_THRESHOLD=12288

# Recursos AWX personalizados
PROD_WEB_CPU_LIMIT="3000m"
PROD_WEB_MEMORY_LIMIT="6Gi"

# Timeouts personalizados
POD_READY_TIMEOUT=900

# Nomes personalizados
AWX_INSTANCE_NAME="meu-awx"
OPERATOR_RELEASE_NAME="meu-operator"
EOF

    log_success "Arquivo de configuração criado: $CONFIG_FILE"
}

# ============================
# FUNÇÃO PRINCIPAL MELHORADA
# ============================

main() {
    # Carregar configurações
    load_config
    
    
    # Inicializar sistema
    detect_system_resources
    calculate_profile_and_resources "$CORES" "$MEM_MB"
    
    # Aplicar valores padrão
    CLUSTER_NAME=${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}
    HOST_PORT=${HOST_PORT:-$DEFAULT_HOST_PORT}
    NAMESPACE=${NAMESPACE:-$DEFAULT_NAMESPACE}
    
    # Exibir configuração
    show_configuration_summary
    
    # Executar instalação
    if [ "$INSTALL_DEPS_ONLY" = true ]; then
        install_dependencies
        log_success "✅ Dependências instaladas! Execute sem -d para instalar o AWX."
        exit 0
    fi
    
    # Instalação completa
    install_dependencies
    create_cluster_with_fixed_names
    install_awx_with_fixed_names
    generate_final_report
    
    log_success "🎉 AWX instalado com sucesso!"
}

# Executar função principal
main
