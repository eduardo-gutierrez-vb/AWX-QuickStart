#!/bin/bash
set -e

# ============================
# CORES E FUNÇÕES DE LOG
# ============================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${PURPLE}[DEBUG]${NC} $1"; }
log_header() { echo -e "${CYAN}================================${NC}\n${WHITE}$1${NC}\n${CYAN}================================${NC}"; }

# ============================
# CONFIGURAÇÃO PADRÃO
# ============================
DEFAULT_CLUSTER_NAME="awx-cluster"
DEFAULT_HOST_PORT=8080
DEFAULT_ENV="prd"
AWX_NAMESPACE="awx"
EE_IMAGE="localhost:5001/awx-custom-ee:latest"

# ============================
# VALIDAÇÃO E UTILITÁRIOS
# ============================
command_exists() { command -v "$1" >/dev/null 2>&1; }
user_in_docker_group() { groups | grep -q docker; }
is_number() { [[ $1 =~ ^[0-9]+$ ]]; }

validate_port() {
    if ! is_number "$1" || [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
        log_error "Porta inválida: $1. Use entre 1-65535."
        exit 1
    fi
}

validate_cpu() {
    if ! is_number "$1" || [ "$1" -lt 1 ] || [ "$1" -gt 64 ]; then
        log_error "CPU inválida: $1. Use entre 1-64."
        exit 1
    fi
}

validate_memory() {
    if ! is_number "$1" || [ "$1" -lt 512 ] || [ "$1" -gt 131072 ]; then
        log_error "Memória inválida: $1. Use entre 512MB-128GB."
        exit 1
    fi
}

# ============================
# DETECÇÃO DE RECURSOS
# ============================
detect_cores() {
    if [ -n "$FORCE_CPU" ]; then echo "$FORCE_CPU"; return; fi
    nproc --all
}

detect_mem_mb() {
    if [ -n "$FORCE_MEM_MB" ]; then echo "$FORCE_MEM_MB"; return; fi
    awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
}

calculate_resources() {
    local total_cores=$1
    local total_mem_mb=$2
    
    local system_cpu_reserve=1
    local system_mem_reserve_mb=1024
    
    local available_cores=$((total_cores - system_cpu_reserve))
    local available_mem_mb=$((total_mem_mb - system_mem_reserve_mb))
    
    if [ "$available_cores" -ge 4 ] && [ "$available_mem_mb" -ge 7168 ]; then
        PERFIL="prd"
        NODE_CPU=$((available_cores * 70 / 100))
        NODE_MEM_MB=$((available_mem_mb * 70 / 100))
        WEB_REPLICAS=$((available_cores / 2))
        TASK_REPLICAS=$((available_cores / 2))
    else
        PERFIL="dev"
        NODE_CPU=$((available_cores * 90 / 100))
        NODE_MEM_MB=$((available_mem_mb * 90 / 100))
        WEB_REPLICAS=1
        TASK_REPLICAS=1
    fi

    [ "$NODE_CPU" -lt 1 ] && NODE_CPU=1
    [ "$NODE_MEM_MB" -lt 512 ] && NODE_MEM_MB=512
}

# ============================
# INSTALAÇÃO DE DEPENDÊNCIAS
# ============================
install_python39() {
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt-get update
    sudo apt-get install -y python3.9 python3.9-venv
}

install_docker() {
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
}

install_kind() {
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/
}

install_kubectl() {
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
}

install_helm() {
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install -y helm
}

# ============================
# CONFIGURAÇÃO DO CLUSTER
# ============================
create_kind_cluster() {
    cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config -
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: $HOST_PORT
    hostPort: $HOST_PORT
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    maxPods: 250
EOF
}

# ============================
# EXECUTION ENVIRONMENT
# ============================
build_ee_image() {
    python3.9 -m venv ~/ansible-ee-venv
    source ~/ansible-ee-venv/bin/activate
    pip install ansible-builder

    mkdir -p ~/awx-ee
    cat <<EOF > ~/awx-ee/execution-environment.yml
version: 3
images:
  base_image:
    name: quay.io/ansible/awx-ee:24.6.1
dependencies:
  galaxy: requirements.yml
  python: requirements.txt
EOF

    ansible-builder build -t $EE_IMAGE -f ~/awx-ee/execution-environment.yml
    docker push $EE_IMAGE
}

# ============================
# INSTALAÇÃO AWX
# ============================
install_awx() {
    helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
    helm repo update

    cat <<EOF | kubectl apply -f -
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-${PERFIL}
  namespace: $AWX_NAMESPACE
spec:
  service_type: nodeport
  nodeport_port: $HOST_PORT
  control_plane_ee_image: $EE_IMAGE
  web_resource_requirements:
    limits:
      cpu: "${NODE_CPU}m"
      memory: "${NODE_MEM_MB}Mi"
EOF
}

# ============================
# MAIN
# ============================
main() {
    # Parse arguments
    while getopts "c:p:e:f:m:h" opt; do
        case $opt in
            c) CLUSTER_NAME="$OPTARG" ;;
            p) validate_port "$OPTARG"; HOST_PORT="$OPTARG" ;;
            e) DEFAULT_ENV="$OPTARG" ;;
            f) validate_cpu "$OPTARG"; FORCE_CPU="$OPTARG" ;;
            m) validate_memory "$OPTARG"; FORCE_MEM_MB="$OPTARG" ;;
            h) show_help; exit 0 ;;
            *) log_error "Opção inválida: -$opt"; exit 1 ;;
        esac
    done

    log_header "INICIALIZANDO INSTALAÇÃO AWX ${PERFIL^^}"

    # Detecção de recursos
    CORES=$(detect_cores)
    MEM_MB=$(detect_mem_mb)
    calculate_resources $CORES $MEM_MB

    log_info "Recursos detectados:"
    log_info "CPUs: $CORES | Memória: ${MEM_MB}MB"
    log_info "Perfil: $PERFIL"
    log_info "Web Replicas: $WEB_REPLICAS | Task Replicas: $TASK_REPLICAS"

    # Instalação de dependências
    log_header "INSTALANDO DEPENDÊNCIAS"
    sudo apt-get update
    sudo apt-get install -y software-properties-common
    install_python39
    install_docker
    install_kind
    install_kubectl
    install_helm

    # Cluster Kind
    log_header "CRIANDO CLUSTER KIND"
    create_kind_cluster

    # EE Image
    log_header "CONSTRUINDO EXECUTION ENVIRONMENT"
    build_ee_image

    # Instalação AWX
    log_header "INSTALANDO AWX"
    kubectl create namespace $AWX_NAMESPACE
    install_awx

    # Finalização
    log_header "INSTALAÇÃO COMPLETADA"
    AWX_PASS=$(kubectl get secret awx-${PERFIL}-admin-password -n $AWX_NAMESPACE -o jsonpath='{.data.password}' | base64 --decode)
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')

    echo -e "${GREEN}URL: http://${NODE_IP}:${HOST_PORT}${NC}"
    echo -e "${GREEN}Usuário: admin${NC}"
    echo -e "${GREEN}Senha: ${AWX_PASS}${NC}"
}

show_help() {
    echo -e "${CYAN}Uso: $0 [opções]"
    echo "Opções:"
    echo "  -c <nome>  Nome do cluster (padrão: ${DEFAULT_CLUSTER_NAME})"
    echo "  -p <porta> Porta do host (padrão: ${DEFAULT_HOST_PORT})"
    echo "  -e <env>   Ambiente (prd/dev, padrão: ${DEFAULT_ENV})"
    echo "  -f <cpu>   Forçar número de CPUs"
    echo "  -m <mb>    Forçar memória em MB"
    echo "  -h         Exibir ajuda${NC}"
}

main "$@"
