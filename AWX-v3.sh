#!/bin/bash
set -e

# ============================
# CORES E FUNÇÕES DE LOG
# ============================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

log_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

# ============================
# VALIDAÇÃO E UTILITÁRIOS
# ============================

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para verificar se usuário está no grupo docker
user_in_docker_group() {
    groups | grep -q docker
}

# Função para validar número
is_number() {
    [[ $1 =~ ^[0-9]+$ ]]
}

# Função para validar porta
validate_port() {
    if ! is_number "$1" || [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
        log_error "Porta inválida: $1. Use um valor entre 1 e 65535."
        return 1
    fi
    return 0
}

# Função para validar CPU
validate_cpu() {
    if ! is_number "$1" || [ "$1" -lt 1 ] || [ "$1" -gt 64 ]; then
        log_error "CPU inválida: $1. Use um valor entre 1 e 64."
        return 1
    fi
    return 0
}

# Função para validar memória
validate_memory() {
    if ! is_number "$1" || [ "$1" -lt 512 ] || [ "$1" -gt 131072 ]; then
        log_error "Memória inválida: $1. Use um valor entre 512 MB e 131072 MB (128 GB)."
        return 1
    fi
    return 0
}

# ============================
# DETECÇÃO DE RECURSOS
# ============================

# Detecta recursos do sistema com cálculos precisos
detect_cores() {
    if [ -n "$FORCE_CPU" ]; then 
        echo "$FORCE_CPU"
        return
    fi
    nproc --all
}

detect_mem_mb() {
    if [ -n "$FORCE_MEM_MB" ]; then 
        echo "$FORCE_MEM_MB"
        return
    fi
    awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
}

# Calcula recursos disponíveis considerando overhead do sistema
calculate_available_resources() {
    local total_cores=$1
    local total_mem_mb=$2
    local profile=$3
    
    # Reserva recursos para o sistema operacional
    local system_cpu_reserve=1
    local system_mem_reserve_mb=1024
    
    # Calcula recursos disponíveis
    local available_cores=$((total_cores - system_cpu_reserve))
    local available_mem_mb=$((total_mem_mb - system_mem_reserve_mb))
    
    # Aplica percentual baseado no perfil
    if [ "$profile" = "prod" ]; then
        # Produção: usa 70% dos recursos disponíveis para dar margem
        NODE_CPU=$((available_cores * 70 / 100))
        NODE_MEM_MB=$((available_mem_mb * 70 / 100))
    else
        # Desenvolvimento: usa 80% dos recursos disponíveis
        NODE_CPU=$((available_cores * 80 / 100))
        NODE_MEM_MB=$((available_mem_mb * 80 / 100))
    fi
    
    # Garante valores mínimos
    [ "$NODE_CPU" -lt 1 ] && NODE_CPU=1
    [ "$NODE_MEM_MB" -lt 512 ] && NODE_MEM_MB=512
    
    log_debug "Recursos totais: CPU=$total_cores, MEM=${total_mem_mb}MB"
    log_debug "Recursos sistema: CPU=$system_cpu_reserve, MEM=${system_mem_reserve_mb}MB"
    log_debug "Recursos disponíveis: CPU=$available_cores, MEM=${available_mem_mb}MB"
    log_debug "Recursos alocados: CPU=$NODE_CPU, MEM=${NODE_MEM_MB}MB"
}

# ============================
# FUNÇÃO DE AJUDA
# ============================

show_help() {
    cat << EOF
${CYAN}=== Script de Implantação AWX com Kind ===${NC}

${WHITE}USO:${NC}
    $0 [OPÇÕES]

${WHITE}OPÇÕES:${NC}
    ${GREEN}-c NOME${NC}      Nome do cluster Kind (padrão: awx-cluster-${PERFIL})
    ${GREEN}-p PORTA${NC}     Porta do host para acessar AWX (padrão: 30080)
    ${GREEN}-f CPU${NC}       Forçar número de CPUs (ex: 4)
    ${GREEN}-m MEMORIA${NC}   Forçar quantidade de memória em MB (ex: 8192)
    ${GREEN}-d${NC}           Instalar apenas dependências
    ${GREEN}-v${NC}           Modo verboso (debug)
    ${GREEN}-h${NC}           Exibir esta ajuda

${WHITE}EXEMPLOS:${NC}
    $0                                    # Usar valores padrão
    $0 -c meu-cluster -p 8080            # Cluster personalizado na porta 8080
    $0 -f 4 -m 8192                     # Forçar 4 CPUs e 8GB RAM
    $0 -d                                # Instalar apenas dependências
    $0 -v -c test-cluster                # Modo verboso com cluster personalizado

${WHITE}DEPENDÊNCIAS INSTALADAS AUTOMATICAMENTE:${NC}
    - Docker
    - Kind
    - kubectl
    - Helm
    - Ansible
    - ansible-builder
    - Python 3.9 + venv

${WHITE}RECURSOS:${NC}
    O script detecta automaticamente os recursos do sistema e calcula
    a configuração ideal para o AWX baseado no perfil detectado:
    
    ${GREEN}Produção${NC}: ≥4 CPUs e ≥8GB RAM - Múltiplas réplicas
    ${YELLOW}Desenvolvimento${NC}: <4 CPUs ou <8GB RAM - Réplica única

${WHITE}ACESSO AWX:${NC}
    Após a instalação, acesse: http://localhost:PORTA
    Usuário: admin
    Senha: (exibida no final da instalação)
EOF
}

# ============================
# INSTALAÇÃO DE DEPENDÊNCIAS
# ============================

install_dependencies() {
    log_header "VERIFICAÇÃO E INSTALAÇÃO DE DEPENDÊNCIAS"
    
    # Verificar se estamos no Ubuntu
    if [[ ! -f /etc/os-release ]] || ! grep -q "Ubuntu" /etc/os-release; then
        log_warning "Este script foi testado apenas no Ubuntu. Prosseguindo mesmo assim..."
    fi
    
    # Atualizar sistema
    log_info "Atualizando sistema..."
    sudo apt-get update -qq
    sudo apt-get upgrade -y
    
    # Instalar dependências básicas
    log_info "Instalando dependências básicas..."
    sudo apt-get install -y \
        python3 python3-pip python3-venv git curl wget \
        ca-certificates gnupg2 lsb-release build-essential \
        software-properties-common apt-transport-https
    
    # Instalar Python 3.9
    install_python39
    
    # Instalar Docker
    install_docker
    
    # Instalar Kind
    install_kind
    
    # Instalar kubectl
    install_kubectl
    
    # Instalar Helm
    install_helm
    
    # Instalar Ansible e ansible-builder
    install_ansible_tools
    
    # Verificar se Docker está funcionando
    check_docker_running
    
    # Iniciar registry local
    start_local_registry
    
    log_success "Todas as dependências foram instaladas e verificadas!"
}

install_python39() {
    if command_exists python3.9; then
        log_info "Python 3.9 já está instalado: $(python3.9 --version)"
        return 0
    fi
    
    log_info "Instalando Python 3.9..."
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt-get update -qq
    sudo apt-get install -y python3.9 python3.9-venv python3.9-distutils python3.9-dev
    
    # Instalar pip para Python 3.9
    curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
    sudo python3.9 /tmp/get-pip.py
    rm /tmp/get-pip.py
    
    log_success "Python 3.9 instalado com sucesso: $(python3.9 --version)"
}

install_docker() {
    if command_exists docker; then
        log_info "Docker já está instalado: $(docker --version)"
        if ! user_in_docker_group; then
            log_warning "Usuário não está no grupo docker. Adicionando..."
            sudo usermod -aG docker $USER
            log_warning "ATENÇÃO: Você precisa fazer logout e login novamente para as mudanças de grupo terem efeito."
            log_warning "Ou execute: newgrp docker"
        fi
        return 0
    fi

    log_info "Instalando Docker..."
    
    # Remover versões antigas
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Instalar dependências
    sudo apt-get install -y ca-certificates curl
    
    # Criar diretório para keyrings
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Adicionar chave GPG do Docker
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    # Adicionar repositório
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Atualizar cache e instalar Docker
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Adicionar usuário ao grupo docker
    sudo usermod -aG docker $USER
    
    # Iniciar e habilitar Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker instalado com sucesso!"
    log_warning "ATENÇÃO: Você precisa fazer logout e login novamente para as mudanças de grupo terem efeito."
}

install_kind() {
    if command_exists kind; then
        log_info "Kind já está instalado: $(kind version)"
        return 0
    fi

    log_info "Instalando Kind..."
    
    # Download do Kind
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    
    log_success "Kind instalado com sucesso: $(kind version)"
}

install_kubectl() {
    if command_exists kubectl; then
        log_info "kubectl já está instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return 0
    fi

    log_info "Instalando kubectl..."
    
    # Download do kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    log_success "kubectl instalado com sucesso: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

install_helm() {
    if command_exists helm; then
        log_info "Helm já está instalado: $(helm version --short)"
        return 0
    fi

    log_info "Instalando Helm..."
    
    # Adicionar chave GPG do Helm
    curl -fsSL https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    
    # Adicionar repositório do Helm
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    
    # Atualizar e instalar Helm
    sudo apt-get update -qq
    sudo apt-get install -y helm
    
    log_success "Helm instalado com sucesso: $(helm version --short)"
}

install_ansible_tools() {
    # Verificar se já existe ambiente virtual
    if [ -d "$HOME/ansible-ee-venv" ]; then
        log_info "Ambiente virtual Ansible já existe"
        source "$HOME/ansible-ee-venv/bin/activate"
    else
        log_info "Criando ambiente virtual Python para Ansible..."
        python3.9 -m venv "$HOME/ansible-ee-venv"
        source "$HOME/ansible-ee-venv/bin/activate"
    fi
    
    if command_exists ansible; then
        log_info "Ansible já está instalado: $(ansible --version | head -n1)"
    else
        log_info "Instalando Ansible e ansible-builder..."
        pip install --upgrade pip
        pip install "ansible>=7.0.0" "ansible-builder>=3.0.0"
        log_success "Ansible e ansible-builder instalados com sucesso!"
    fi
}

check_docker_running() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker não está funcionando. Verificando..."
        
        if ! user_in_docker_group; then
            log_error "Usuário não está no grupo docker. Execute: newgrp docker"
            log_error "Ou faça logout/login e execute o script novamente."
            exit 1
        fi
        
        # Tentar iniciar Docker se não estiver rodando
        if ! systemctl is-active --quiet docker; then
            log_info "Iniciando Docker..."
            sudo systemctl start docker
            sleep 5
        fi
        
        if ! docker info >/dev/null 2>&1; then
            log_error "Não foi possível conectar ao Docker. Verifique a instalação."
            exit 1
        fi
    fi
    log_success "Docker está funcionando corretamente!"
}

start_local_registry() {
    if docker ps | grep -q kind-registry; then
        log_info "Registry local já está rodando"
        return 0
    fi
    
    log_info "Iniciando registry local para Kind..."
    docker run -d --restart=always -p 5001:5000 --name kind-registry registry:2
    
    # Conectar ao network do kind se existir
    if docker network ls | grep -q kind; then
        docker network connect kind kind-registry 2>/dev/null || true
    fi
    
    log_success "Registry local iniciado em localhost:5001"
}

# ============================
# CRIAÇÃO E CONFIGURAÇÃO DO CLUSTER
# ============================

create_kind_cluster() {
    log_header "CRIAÇÃO DO CLUSTER KIND"
    
    # Verificar cluster existente
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_warning "Cluster '$CLUSTER_NAME' já existe. Deletando..."
        kind delete cluster --name "$CLUSTER_NAME"
    fi
    
    log_info "Criando cluster Kind '$CLUSTER_NAME'..."
    
    # Configuração do cluster Kind
    cat > /tmp/kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
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
  - |
    kind: KubeletConfiguration
    maxPods: 110
EOF

    # Adicionar workers se for produção
    if [ "$PERFIL" = "prod" ] && [ "$CORES" -ge 6 ]; then
        log_info "Adicionando nó worker para ambiente de produção..."
        cat >> /tmp/kind-config.yaml << EOF
- role: worker
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    maxPods: 110
EOF
    fi
    
    # Criar cluster
    kind create cluster --name "$CLUSTER_NAME" --config /tmp/kind-config.yaml
    rm /tmp/kind-config.yaml
    
    log_success "Cluster criado com sucesso!"
    
    # Aguardar cluster estar pronto
    log_info "Aguardando cluster estar pronto..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Conectar registry ao cluster
    if ! docker network ls | grep -q kind; then
        docker network create kind
    fi
    docker network connect kind kind-registry 2>/dev/null || true
    
    # Configurar registry no cluster
    kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5001"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
}

# ============================
# CRIAÇÃO DO EXECUTION ENVIRONMENT
# ============================

create_execution_environment() {
    log_header "CRIAÇÃO DO EXECUTION ENVIRONMENT"
    
    # Ativar ambiente virtual
    source "$HOME/ansible-ee-venv/bin/activate"
    
    log_info "Preparando Execution Environment personalizado..."
    
    # Criar diretório temporário
    EE_DIR="/tmp/awx-ee-$$"
    mkdir -p "$EE_DIR"
    cd "$EE_DIR"
    
    # Arquivo requirements.yml para coleções
    cat > requirements.yml << EOF
collections:
  - name: community.windows
    version: ">=1.12.0"
  - name: ansible.windows
    version: ">=1.14.0"
  - name: microsoft.ad
    version: ">=1.3.0"
  - name: community.general
    version: ">=6.0.0"
  - name: community.crypto
    version: ">=2.10.0"
  - name: kubernetes.core
    version: ">=2.4.0"
EOF

    # Arquivo requirements.txt para pacotes Python
    cat > requirements.txt << EOF
pywinrm>=0.4.3
requests>=2.28.0
kubernetes>=24.2.0
pyyaml>=6.0
jinja2>=3.1.0
cryptography>=3.4.8
EOF

    # Arquivo execution-environment.yml
    cat > execution-environment.yml << EOF
---
version: 3
images:
  base_image:
    name: quay.io/ansible/awx-ee:24.6.1
dependencies:
  galaxy: requirements.yml
  python: requirements.txt
additional_build_steps:
  prepend_base:
    - RUN dnf clean all || yum clean all || true
    - RUN dnf makecache || yum makecache || true
    - RUN dnf update -y || yum update -y || true
  append_final:
    - RUN ansible-galaxy collection list
    - RUN pip list
EOF

    # Construir e enviar imagem
    log_info "Construindo Execution Environment personalizado..."
    if [ "$VERBOSE" = true ]; then
        ansible-builder build -t localhost:5001/awx-custom-ee:latest -f execution-environment.yml --verbosity 2
    else
        ansible-builder build -t localhost:5001/awx-custom-ee:latest -f execution-environment.yml
    fi
    
    log_info "Enviando imagem para registry local..."
    docker push localhost:5001/awx-custom-ee:latest
    
    # Limpar diretório temporário
    cd /
    rm -rf "$EE_DIR"
    
    log_success "Execution Environment criado e enviado com sucesso!"
}

# ============================
# INSTALAÇÃO DO AWX
# ============================

install_awx() {
    log_header "INSTALAÇÃO DO AWX OPERATOR"
    
    log_info "Adicionando repositório Helm do AWX Operator..."
    helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ 2>/dev/null || true
    helm repo update
    
    log_info "Criando namespace..."
    kubectl create namespace "$AWX_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    log_info "Instalando AWX Operator usando Helm..."
    helm upgrade --install awx-operator awx-operator/awx-operator \
        -n "$AWX_NAMESPACE" \
        --create-namespace \
        --wait \
        --timeout=10m
    
    log_success "AWX Operator instalado com sucesso!"
    
    # Criar instância AWX
    create_awx_instance
}

create_awx_instance() {
    log_info "Criando instância AWX..."
    
    # Calcular recursos para AWX baseado no perfil
    local awx_web_cpu_req="100m"
    local awx_web_mem_req="128Mi"
    local awx_web_cpu_lim="1000m"
    local awx_web_mem_lim="2Gi"
    
    local awx_task_cpu_req="100m"
    local awx_task_mem_req="128Mi"
    local awx_task_cpu_lim="2000m"
    local awx_task_mem_lim="2Gi"
    
    if [ "$PERFIL" = "prod" ]; then
        awx_web_cpu_lim="2000m"
        awx_web_mem_lim="4Gi"
        awx_task_cpu_lim="4000m"
        awx_task_mem_lim="4Gi"
    fi
    
    # Criar manifesto AWX com recursos calculados
    cat > /tmp/awx-instance.yaml << EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-${PERFIL}
  namespace: ${AWX_NAMESPACE}
spec:
  service_type: nodeport
  nodeport_port: ${HOST_PORT}
  admin_user: admin
  admin_email: admin@example.com
  
  # Execution Environment personalizado
  control_plane_ee_image: localhost:5001/awx-custom-ee:latest
  
  # Configuração de réplicas baseada no perfil
  replicas: ${WEB_REPLICAS}
  web_replicas: ${WEB_REPLICAS}
  task_replicas: ${TASK_REPLICAS}
  
  # Recursos para web containers
  web_resource_requirements:
    requests:
      cpu: ${awx_web_cpu_req}
      memory: ${awx_web_mem_req}
    limits:
      cpu: ${awx_web_cpu_lim}
      memory: ${awx_web_mem_lim}
  
  # Recursos para task containers
  task_resource_requirements:
    requests:
      cpu: ${awx_task_cpu_req}
      memory: ${awx_task_mem_req}
    limits:
      cpu: ${awx_task_cpu_lim}
      memory: ${awx_task_mem_lim}
  
  # Persistência de projetos
  projects_persistence: true
  projects_storage_size: 8Gi
  projects_storage_access_mode: ReadWriteOnce
  
  # Configurações adicionais
  postgres_configuration_secret: awx-postgres-configuration
  postgres_storage_requirements:
    requests:
      storage: 8Gi
    limits:
      storage: 8Gi
EOF

    # Aplicar manifesto
    kubectl apply -f /tmp/awx-instance.yaml -n "$AWX_NAMESPACE"
    rm /tmp/awx-instance.yaml
    
    log_success "Instância AWX criada!"
}

# ============================
# MONITORAMENTO E FINALIZAÇÃO
# ============================

wait_for_awx() {
    log_header "AGUARDANDO INSTALAÇÃO DO AWX"
    
    log_info "Aguardando pods do AWX ficarem prontos..."
    
    # Aguardar operator estar pronto
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=awx-operator -n "$AWX_NAMESPACE" --timeout=300s
    
    # Aguardar AWX instance ser criada
    local timeout=600
    local elapsed=0
    while ! kubectl get awx awx-${PERFIL} -n "$AWX_NAMESPACE" &> /dev/null; do
        if [ $elapsed -ge $timeout ]; then
            log_error "Timeout aguardando criação da instância AWX"
            exit 1
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        log_info "Aguardando instância AWX ser criada... (${elapsed}s)"
    done
    
    # Aguardar todos os pods estarem prontos
    log_info "Aguardando todos os pods ficarem prontos..."
    timeout=900
    elapsed=0
    while true; do
        local pending_pods=$(kubectl get pods -n "$AWX_NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
        
        if [ "$pending_pods" -eq 0 ]; then
            log_success "Todos os pods estão prontos!"
            break
        fi
        
        if [ $elapsed -ge $timeout ]; then
            log_error "Timeout aguardando pods ficarem prontos"
            kubectl get pods -n "$AWX_NAMESPACE"
            exit 1
        fi
        
        sleep 15
        elapsed=$((elapsed + 15))
        log_info "Aguardando $pending_pods pod(s) ficar(em) pronto(s)... (${elapsed}s)"
        
        # Mostrar status dos pods se verbose
        if [ "$VERBOSE" = true ]; then
            kubectl get pods -n "$AWX_NAMESPACE"
        fi
    done
}

get_awx_password() {
    log_info "Obtendo senha do administrador AWX..."
    
    # Aguardar secret da senha estar disponível
    local timeout=300
    local elapsed=0
    while ! kubectl get secret awx-${PERFIL}-admin-password -n "$AWX_NAMESPACE" &> /dev/null; do
        if [ $elapsed -ge $timeout ]; then
            log_error "Timeout aguardando senha do AWX. Verifique os logs:"
            log_error "kubectl logs -n $AWX_NAMESPACE deployment/awx-operator-controller-manager"
            exit 1
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    echo ""
    
    AWX_PASSWORD=$(kubectl get secret awx-${PERFIL}-admin-password -n "$AWX_NAMESPACE" -o jsonpath='{.data.password}' | base64 --decode)
}

show_final_info() {
    log_header "INSTALAÇÃO CONCLUÍDA"
    
    # Obter IP do nó
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    echo ""
    log_success "=== AWX IMPLANTADO COM SUCESSO ==="
    echo ""
    log_info "📋 INFORMAÇÕES DE ACESSO:"
    log_info "   URL: ${GREEN}http://${node_ip}:${HOST_PORT}${NC}"
    log_info "   Usuário: ${GREEN}admin${NC}"
    log_info "   Senha: ${GREEN}$AWX_PASSWORD${NC}"
    echo ""
    log_info "🔧 CONFIGURAÇÃO DO SISTEMA:"
    log_info "   Perfil: ${GREEN}$PERFIL${NC}"
    log_info "   CPUs Detectadas: ${GREEN}$CORES${NC}"
    log_info "   Memória Detectada: ${GREEN}${MEM_MB}MB${NC}"
    log_info "   Web Réplicas: ${GREEN}$WEB_REPLICAS${NC}"
    log_info "   Task Réplicas: ${GREEN}$TASK_REPLICAS${NC}"
    echo ""
    log_info "🚀 COMANDOS ÚTEIS:"
    log_info "   Ver pods: ${CYAN}kubectl get pods -n $AWX_NAMESPACE${NC}"
    log_info "   Ver logs web: ${CYAN}kubectl logs -n $AWX_NAMESPACE deployment/awx-${PERFIL}-web${NC}"
    log_info "   Ver logs task: ${CYAN}kubectl logs -n $AWX_NAMESPACE deployment/awx-${PERFIL}-task${NC}"
    log_info "   Deletar cluster: ${CYAN}kind delete cluster --name $CLUSTER_NAME${NC}"
    echo ""
    
    if [ "$VERBOSE" = true ]; then
        log_info "🔍 STATUS ATUAL DOS PODS:"
        kubectl get pods -n "$AWX_NAMESPACE" -o wide
    fi
}

# ============================
# CONFIGURAÇÃO PADRÃO E PARSING
# ============================

# Valores padrão
DEFAULT_CLUSTER_NAME="awx-cluster-${PERFIL}"
DEFAULT_HOST_PORT=8080
INSTALL_DEPS_ONLY=false
VERBOSE=false

# Variáveis de recursos (pode forçar)
FORCE_CPU=""
FORCE_MEM_MB=""

# Parse das opções da linha de comando
while getopts "c:p:f:m:dvh" opt; do
    case ${opt} in
        c)
            if [ -z "$OPTARG" ]; then
                log_error "Nome do cluster não pode estar vazio"
                exit 1
            fi
            CLUSTER_NAME="$OPTARG"
            ;;
        p)
            if ! validate_port "$OPTARG"; then
                exit 1
            fi
            HOST_PORT="$OPTARG"
            ;;
        f)
            if ! validate_cpu "$OPTARG"; then
                exit 1
            fi
            FORCE_CPU="$OPTARG"
            ;;
        m)
            if ! validate_memory "$OPTARG"; then
                exit 1
            fi
            FORCE_MEM_MB="$OPTARG"
            ;;
        d)
            INSTALL_DEPS_ONLY=true
            ;;
        v)
            VERBOSE=true
            ;;
        h)
            show_help
            exit 0
            ;;
        *)
            log_error "Opção inválida: -$OPTARG"
            show_help
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Aplicar valores padrão se não fornecidos
CLUSTER_NAME=${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}
HOST_PORT=${HOST_PORT:-$DEFAULT_HOST_PORT}
AWX_NAMESPACE="awx"

# ============================
# DETECÇÃO E CÁLCULO DE RECURSOS
# ============================

log_header "DETECÇÃO DE RECURSOS DO SISTEMA"

CORES=$(detect_cores)
MEM_MB=$(detect_mem_mb)

# Definir perfil baseado nos recursos
if [ "$CORES" -ge 4 ] && [ "$MEM_MB" -ge 8192 ]; then
    PERFIL="prod"
    WEB_REPLICAS=$((CORES / 2))
    TASK_REPLICAS=$((CORES / 2))
    # Mínimo de 1, máximo de 3 para cada
    [ "$WEB_REPLICAS" -lt 1 ] && WEB_REPLICAS=1
    [ "$TASK_REPLICAS" -lt 1 ] && TASK_REPLICAS=1
    [ "$WEB_REPLICAS" -gt 3 ] && WEB_REPLICAS=3
    [ "$TASK_REPLICAS" -gt 3 ] && TASK_REPLICAS=3
else
    PERFIL="dev"
    WEB_REPLICAS=1
    TASK_REPLICAS=1
fi

# Calcular recursos disponíveis
calculate_available_resources "$CORES" "$MEM_MB" "$PERFIL"

log_info "💻 Recursos do Sistema:"
log_info "   CPUs: ${GREEN}$CORES${NC}"
log_info "   Memória: ${GREEN}${MEM_MB}MB${NC}"
log_info "   Perfil: ${GREEN}$PERFIL${NC}"
log_info "   Web Réplicas: ${GREEN}$WEB_REPLICAS${NC}"
log_info "   Task Réplicas: ${GREEN}$TASK_REPLICAS${NC}"

# ============================
# EXECUÇÃO PRINCIPAL
# ============================

log_header "INICIANDO IMPLANTAÇÃO AWX"
log_info "🎯 Configuração:"
log_info "   Cluster: ${GREEN}$CLUSTER_NAME${NC}"
log_info "   Porta: ${GREEN}$HOST_PORT${NC}"
log_info "   Namespace: ${GREEN}$AWX_NAMESPACE${NC}"
log_info "   Verbose: ${GREEN}$VERBOSE${NC}"

# Instalar dependências
install_dependencies

# Se apenas instalação de dependências foi solicitada, sair
if [ "$INSTALL_DEPS_ONLY" = true ]; then
    log_success "✅ Dependências instaladas com sucesso!"
    log_info "Execute o script novamente sem a opção -d para instalar o AWX"
    exit 0
fi

# Continuar com a instalação completa
create_kind_cluster
create_execution_environment
install_awx
wait_for_awx
get_awx_password
show_final_info

log_success "🎉 Instalação do AWX concluída com sucesso!"
