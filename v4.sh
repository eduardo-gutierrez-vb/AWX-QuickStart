#!/bin/bash
set -eo pipefail

# ============================ 
# CONFIGURAÇÕES GLOBAIS
# ============================
DEFAULT_PROFILE="dev"
AWX_NAMESPACE="awx"
OPERATOR_VERSION="24.6.1"
EE_BASE_IMAGE="quay.io/ansible/awx-ee:${OPERATOR_VERSION}"
KIND_VERSION="v0.20.0"
KUBECTL_VERSION="v1.29.0"
HELM_VERSION="v3.14.1"
CLUSTER_NAME="awx-cluster"
REGISTRY_PORT="5001"
HOST_PORT="8080"

# ============================
# DETECÇÃO DE RECURSOS DINÂMICOS
# ============================
detect_resources() {
    # CPU: considera cores físicos e lógicos
    CPU_CORES=$(lscpu | awk '/^CPU\(s\):/ {print $2}')
    SOCKETS=$(lscpu | awk '/^Socket\(s\):/ {print $2}')
    PHYSICAL_CORES=$((CPU_CORES / SOCKETS))
    
    # Memória: converte para MB considerando memória disponível
    TOTAL_MEM=$(free -m | awk '/Mem:/ {print $2}')
    AVAILABLE_MEM=$(free -m | awk '/Mem:/ {print $7}')
    
    # Ajusta valores para ambiente de desenvolvimento
    if [ $PHYSICAL_CORES -lt 4 ] || [ $AVAILABLE_MEM -lt 4096 ]; then
        PROFILE="dev"
        WEB_REPLICAS=1
        TASK_REPLICAS=1
        MEMORY_LIMIT=$((AVAILABLE_MEM / 2))"Mi"
    else
        PROFILE="prod"
        WEB_REPLICAS=2
        TASK_REPLICAS=2
        MEMORY_LIMIT=$((AVAILABLE_MEM * 70 / 100))"Mi"
    fi
}

# ============================
# FUNÇÕES DE LOG MELHORADAS
# ============================
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local color
    
    case $level in
        "INFO") color="\033[36m" ;;
        "SUCCESS") color="\033[32m" ;;
        "WARNING") color="\033[33m" ;;
        "ERROR") color="\033[31m" ;;
        *) color="\033[0m" ;;
    esac
    
    echo -e "${color}[${timestamp}][${level}]${NC} ${message}"
    logger -t "AWX-Installer" "${level}: ${message}"
}

# ============================
# VERIFICAÇÃO DE DEPENDÊNCIAS
# ============================
verify_dependencies() {
    local missing=()
    
    declare -A requirements=(
        ["docker"]="docker --version"
        ["kubectl"]="kubectl version --client"
        ["kind"]="kind version"
        ["helm"]="helm version"
        ["ansible"]="ansible --version"
        ["ansible-builder"]="ansible-builder --version"
    )
    
    for cmd in "${!requirements[@]}"; do
        if ! eval "${requirements[$cmd]}" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log "ERROR" "Dependências faltando: ${missing[*]}"
        exit 1
    fi
}

# ============================
# CONFIGURAÇÃO DO REGISTRY
# ============================
setup_registry() {
    log "INFO" "Configurando registry local..."
    
    # Criar registry persistente
    docker run -d \
        --name kind-registry \
        --restart=always \
        -p ${REGISTRY_PORT}:5000 \
        -v ${PWD}/registry:/var/lib/registry \
        registry:2
    
    # Conectar ao network do Kind
    docker network connect kind kind-registry 2>/dev/null || true
    
    # Configurar DNS local
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry
  namespace: kube-public
data:
  localRegistry: "kind-registry:5000"
EOF
}

# ============================
# CRIAÇÃO DO CLUSTER KIND
# ============================
create_kind_cluster() {
    log "INFO" "Criando cluster Kind..."
    
    cat <<EOF | kind create cluster --name ${CLUSTER_NAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:${KUBECTL_VERSION}
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        enable-admission-plugins: NodeRestriction
    controllerManager:
      extraArgs:
        bind-address: 0.0.0.0
    scheduler:
      extraArgs:
        bind-address: 0.0.0.0
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443
  - containerPort: ${HOST_PORT}
    hostPort: ${HOST_PORT}
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://kind-registry:5000"]
EOF

    log "SUCCESS" "Cluster Kind criado com sucesso!"
}

# ============================
# INSTALAÇÃO DO AWX OPERATOR
# ============================
install_awx_operator() {
    log "INFO" "Instalando AWX Operator..."
    
    helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
    helm upgrade --install awx-operator awx-operator/awx-operator \
        --namespace ${AWX_NAMESPACE} \
        --create-namespace \
        --version ${OPERATOR_VERSION} \
        --wait
    
    log "SUCCESS" "AWX Operator instalado com sucesso!"
}

# ============================
# CONSTRUÇÃO DA IMAGEM EE
# ============================
build_execution_environment() {
    log "INFO" "Construindo Execution Environment..."
    
    local ee_dir="/tmp/awx-ee"
    mkdir -p ${ee_dir}
    
    cat > ${ee_dir}/execution-environment.yml <<EOF
version: 3
images:
  base_image:
    name: ${EE_BASE_IMAGE}
dependencies:
  galaxy: requirements.yml
  python: requirements.txt
additional_build_steps:
  prepend:
    - RUN dnf install -y jq
  append:
    - RUN ansible-galaxy collection list
EOF

    cat > ${ee_dir}/requirements.yml <<EOF
collections:
  - name: community.general
    version: 7.0.0
  - name: kubernetes.core
    version: 2.4.0
EOF

    cat > ${ee_dir}/requirements.txt <<EOF
pywinrm>=0.4.3
requests>=2.28.0
kubernetes>=24.2.0
EOF

    ansible-builder build \
        --tag localhost:${REGISTRY_PORT}/awx-ee:custom \
        --context ${ee_dir} \
        --verbosity 3
    
    docker push localhost:${REGISTRY_PORT}/awx-ee:custom
    rm -rf ${ee_dir}
    
    log "SUCCESS" "Execution Environment construído com sucesso!"
}

# ============================
# IMPLANTAÇÃO DO AWX
# ============================
deploy_awx() {
    log "INFO" "Implantando instância AWX..."
    
    local web_replicas=${WEB_REPLICAS}
    local task_replicas=${TASK_REPLICAS}
    local memory_limit=${MEMORY_LIMIT}
    
    cat <<EOF | kubectl apply -f -
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-${PROFILE}
  namespace: ${AWX_NAMESPACE}
spec:
  service_type: nodeport
  nodeport_port: ${HOST_PORT}
  hostname: awx.local
  admin_user: admin
  admin_email: admin@awx.local
  control_plane_ee_image: localhost:${REGISTRY_PORT}/awx-ee:custom
  replicas: ${web_replicas}
  task_replicas: ${task_replicas}
  web_resource_requirements:
    requests:
      cpu: "100m"
      memory: "256Mi"
    limits:
      cpu: "1000m"
      memory: ${memory_limit}
  task_resource_requirements:
    requests:
      cpu: "200m"
      memory: "512Mi"
    limits:
      cpu: "2000m"
      memory: ${memory_limit}
  projects_persistence: true
  projects_storage_size: 10Gi
  postgres_configuration_secret: awx-postgres-config
EOF

    log "SUCCESS" "Instância AWX implantada com sucesso!"
}

# ============================
# CONFIGURAÇÃO PÓS-INSTALAÇÃO
# ============================
post_installation() {
    log "INFO" "Configurando recursos pós-instalação..."
    
    # Criar secret para PostgreSQL
    kubectl create secret generic awx-postgres-config \
        --namespace ${AWX_NAMESPACE} \
        --from-literal=host=awx-postgres \
        --from-literal=port=5432 \
        --from-literal=database=awx \
        --from-literal=username=awx \
        --from-literal=password=$(openssl rand -base64 32)
    
    # Configurar Network Policies
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: awx-network-policy
  namespace: ${AWX_NAMESPACE}
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: awx
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
  egress:
  - to:
    - namespace: ${AWX_NAMESPACE}
      podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
EOF

    log "SUCCESS" "Configurações pós-instalação concluídas!"
}

# ============================
# MONITORAMENTO DA IMPLANTAÇÃO
# ============================
monitor_deployment() {
    log "INFO" "Monitorando status da implantação..."
    
    local attempts=0
    local max_attempts=30
    
    while [ ${attempts} -lt ${max_attempts} ]; do
        local status=$(kubectl get awx awx-${PROFILE} -n ${AWX_NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        
        if [ "${status}" == "True" ]; then
            log "SUCCESS" "AWX está pronto para uso!"
            return 0
        fi
        
        log "INFO" "Estado atual: $(kubectl get awx awx-${PROFILE} -n ${AWX_NAMESPACE} -o jsonpath='{.status.conditions[0].message}')"
        sleep 20
        attempts=$((attempts+1))
    done
    
    log "ERROR" "Timeout na implantação do AWX"
    exit 1
}

# ============================
# EXIBIÇÃO DAS INFORMAÇÕES
# ============================
show_access_info() {
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    local admin_password=$(kubectl get secret awx-${PROFILE}-admin-password -n ${AWX_NAMESPACE} -o jsonpath='{.data.password}' | base64 -d)
    
    log "INFO" "╔════════════════════════════════════════════╗"
    log "INFO" "║          IMPLANTAÇÃO CONCLUÍDA!            ║"
    log "INFO" "╠════════════════════════════════════════════╣"
    log "INFO" "║ URL:        http://${node_ip}:${HOST_PORT} ║"
    log "INFO" "║ Usuário:    admin                          ║"
    log "INFO" "║ Senha:      ${admin_password}              ║"
    log "INFO" "║ Namespace:  ${AWX_NAMESPACE}               ║"
    log "INFO" "║ Cluster:    ${CLUSTER_NAME}                ║"
    log "INFO" "╚════════════════════════════════════════════╝"
}

# ============================
# FUNÇÃO PRINCIPAL
# ============================
main() {
    detect_resources
    verify_dependencies
    setup_registry
    create_kind_cluster
    install_awx_operator
    build_execution_environment
    deploy_awx
    post_installation
    monitor_deployment
    show_access_info
}

# Execução principal
main
