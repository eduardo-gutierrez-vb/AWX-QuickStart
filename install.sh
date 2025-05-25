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

log_subheader() {
    echo -e "${CYAN}--- $1 ---${NC}"
}

# ============================
# CONFIGURAÇÃO E CONSTANTES
# ============================

# Fatores de segurança para cálculo de recursos
SAFETY_FACTOR_PROD=85
SAFETY_FACTOR_DEV=90

# Portas padrão
DEFAULT_HOST_PORT=8080
REGISTRY_PORT=5000

# ============================
# COMANDOS DE DIAGNÓSTICO MELHORADOS
# ============================

# Função completa de diagnóstico de pods AWX
diagnose_awx_pods() {
    echo "=== STATUS DOS PODS AWX ==="
    kubectl get pods -n $AWX_NAMESPACE -o wide
    
    echo -e "\n=== EVENTOS DOS PODS ==="
    kubectl get events -n $AWX_NAMESPACE --sort-by=.metadata.creationTimestamp
    
    echo -e "\n=== LOGS DOS PODS COM PROBLEMA ==="
    for pod in $(kubectl get pods -n $AWX_NAMESPACE --field-selector=status.phase=Failed -o name 2>/dev/null); do
        echo "Logs do $pod:"
        kubectl logs -n $AWX_NAMESPACE $pod --previous --tail=50 2>/dev/null || true
    done
}

# Verificação de recursos do cluster
check_cluster_resources() {
    echo "=== RECURSOS DO CLUSTER ==="
    kubectl top nodes 2>/dev/null || echo "Metrics server não disponível"
    kubectl top pods -n $AWX_NAMESPACE 2>/dev/null || echo "Metrics server não disponível"
    
    echo -e "\n=== CAPACIDADE DO CLUSTER ==="
    kubectl describe nodes | grep -A 5 "Allocated resources"
}

# Verificação do registry local
check_registry() {
    echo "=== STATUS DO REGISTRY LOCAL ==="
    docker ps | grep kind-registry
    curl -s http://localhost:${REGISTRY_PORT}/v2/_catalog 2>/dev/null || echo "Registry não disponível"
}

# Limpeza e restart completo
reset_awx_deployment() {
    log_warning "Resetando deployment AWX..."
    kubectl delete awx awx-${PERFIL} -n $AWX_NAMESPACE --ignore-not-found=true
    kubectl delete pods --all -n $AWX_NAMESPACE
    sleep 30
    kubectl apply -f /tmp/awx-instance.yaml -n $AWX_NAMESPACE
}

# Verificação de conectividade com registry
test_registry_connectivity() {
    kubectl run test-registry --image=quay.io/ansible/awx-ee:latest \
        --restart=Never -n $AWX_NAMESPACE --command -- sleep 3600 2>/dev/null || true
    kubectl wait --for=condition=Ready pod/test-registry -n $AWX_NAMESPACE --timeout=60s 2>/dev/null || true
    kubectl delete pod test-registry -n $AWX_NAMESPACE 2>/dev/null || true
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

# Adicione estas funções no início do script
validate_environment() {
    log_header "VERIFICAÇÃO DE AMBIENTE"
    
    # 1. Verificar porta obrigatoriamente
    check_port_availability "$HOST_PORT"
    
    # 2. Verificar e remover clusters conflitantes
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_warning "Removendo cluster existente '${CLUSTER_NAME}'..."
        kind delete cluster --name "$CLUSTER_NAME"
        sleep 15  # Tempo para limpeza completa
    fi
    
    # 3. Limpar containers órfãos
    docker rm -f $(docker ps -aq --filter "label=io.x-k8s.kind.cluster=${CLUSTER_NAME}") 2>/dev/null || true
    
    # 4. Verificar redes residuais
    if docker network inspect kind >/dev/null 2>&1; then
        log_info "Removendo rede kind residual..."
        docker network rm kind 2>/dev/null || true
    fi
}

check_port_availability() {
    local port=$1
    log_subheader "VERIFICANDO PORTA $port"
    
    # Verificar processos locais
    local pid=$(lsof -t -i :$port 2>/dev/null || true)
    if [ -n "$pid" ]; then
        log_error "Conflito de porta detectado:"
        lsof -i :$port
        log_info "Execute para liberar: kill -9 $pid"
        exit 1
    fi
    
    # Verificar containers Docker
    local container=$(docker ps --format '{{.Names}}' | grep ".*${port}->${port}/tcp" || true)
    if [ -n "$container" ]; then
        log_error "Container Docker usando a porta:"
        docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep "$port"
        log_info "Execute para liberar: docker rm -f $container"
        exit 1
    fi
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

# Função para determinar perfil baseado nos recursos
determine_profile() {
    local cores=$1
    local mem_mb=$2
    
    if [ "$cores" -ge 4 ] && [ "$mem_mb" -ge 8192 ]; then
        echo "prod"
    else
        echo "dev"
    fi
}

calculate_cpu_reserved() {
    local total_cores=$1
    local reserved_millicores=0

    # Fórmula baseada nas reservas padrão do GKE/EKS/AKS
    if [ "$total_cores" -ge 1 ]; then
        # Primeiro core: 6% (60 millicores)
        reserved_millicores=$((reserved_millicores + 60))
        remaining_cores=$((total_cores - 1))
    fi

    if [ "$remaining_cores" -ge 1 ]; then
        # Segundo core: 1% (10 millicores)
        reserved_millicores=$((reserved_millicores + 10))
        remaining_cores=$((remaining_cores - 1))
    fi

    if [ "$remaining_cores" -ge 2 ]; then
        # Próximos 2 cores: 0.5% cada (5 millicores por core)
        reserved_millicores=$((reserved_millicores + 10))
        remaining_cores=$((remaining_cores - 2))
    fi

    if [ "$remaining_cores" -gt 0 ]; then
        # Cores restantes: 0.25% cada (2.5 millicores por core)
        reserved_millicores=$((reserved_millicores + (remaining_cores * 25 / 10)))
    fi

    echo $reserved_millicores
}

calculate_memory_reserved() {
    local total_mem_mb=$1
    local reserved_mb=0

    # Fórmula baseada no modelo escalonado da GKE
    if [ "$total_mem_mb" -lt 1024 ]; then
        reserved_mb=255
    else
        # 25% dos primeiros 4 GiB
        first_4gb=$((total_mem_mb > 4096 ? 4096 : total_mem_mb))
        reserved_mb=$((first_4gb * 25 / 100))
        remaining_mb=$((total_mem_mb - first_4gb))

        # 20% dos próximos 4 GiB (até 8 GiB)
        if [ "$remaining_mb" -gt 0 ]; then
            next_4gb=$((remaining_mb > 4096 ? 4096 : remaining_mb))
            reserved_mb=$((reserved_mb + next_4gb * 20 / 100))
            remaining_mb=$((remaining_mb - next_4gb))
        fi

        # 10% dos próximos 8 GiB (até 16 GiB)
        if [ "$remaining_mb" -gt 0 ]; then
            next_8gb=$((remaining_mb > 8192 ? 8192 : remaining_mb))
            reserved_mb=$((reserved_mb + next_8gb * 10 / 100))
            remaining_mb=$((remaining_mb - next_8gb))
        fi

        # 6% dos próximos 112 GiB (até 128 GiB)
        if [ "$remaining_mb" -gt 0 ]; then
            next_112gb=$((remaining_mb > 114688 ? 114688 : remaining_mb))
            reserved_mb=$((reserved_mb + next_112gb * 6 / 100))
            remaining_mb=$((remaining_mb - next_112gb))
        fi

        # 2% de qualquer memória acima de 128 GiB
        if [ "$remaining_mb" -gt 0 ]; then
            reserved_mb=$((reserved_mb + remaining_mb * 2 / 100))
        fi
    fi

    # Adicionar reserva para eviction threshold
    reserved_mb=$((reserved_mb + 100))

    echo $reserved_mb
}

# Calcula réplicas baseado no perfil e recursos
calculate_replicas() {
    local profile=$1
    local available_cpu_millicores=$2
    local workload_type=$3  # web, task, etc

    if [ "$profile" = "prod" ]; then
        # Cálculo baseado em densidade de carga com margem de segurança
        local base_replicas=$((available_cpu_millicores / 1000))
        
        # Ajustes por tipo de workload
        case "$workload_type" in
            "web")
                replicas=$((base_replicas * 2 / 3))  # Prioriza CPUs para tarefas
                ;;
            "task")
                replicas=$((base_replicas / 2))
                ;;
            *)
                replicas=$base_replicas
                ;;
        esac
        
        # Limites operacionais
        [ "$replicas" -lt 2 ] && replicas=2  # Mínimo 2 em produção
        [ "$replicas" -gt 10 ] && replicas=10 # Máximo 10 por serviço
    else
        # Desenvolvimento: 1 réplica com possibilidade de override
        replicas=1
        [ "$available_cpu_millicores" -ge 2000 ] && replicas=2 # Caso máquinas grandes
    fi

    echo $replicas
}

# ============================
# CÁLCULO DE RECURSOS CORRIGIDO
# ============================

calculate_resources_with_feedback() {
    local total_cores=$1
    local total_mem_mb=$2
    local profile=$3
    
    log_subheader "ANÁLISE DETALHADA DE RECURSOS"
    
    # Mostrar recursos detectados
    log_info "Recursos do Sistema Detectados:"
    log_info "   CPUs Totais: ${GREEN}${total_cores}${NC} cores"
    log_info "   Memória Total: ${GREEN}${total_mem_mb}MB${NC} ($(echo "scale=1; $total_mem_mb/1024" | bc -l)GB)"
    
    # Calcular reservas do sistema
    local cpu_reserved_millicores=$(calculate_cpu_reserved "$total_cores")
    local mem_reserved_mb=$(calculate_memory_reserved "$total_mem_mb")
    
    log_info "Reservas do Sistema (baseado em padrões GKE/EKS):"
    log_info "   CPU Reservada: ${YELLOW}${cpu_reserved_millicores}m${NC} ($(echo "scale=2; $cpu_reserved_millicores/1000" | bc -l) cores)"
    log_info "   Memória Reservada: ${YELLOW}${mem_reserved_mb}MB${NC} ($(echo "scale=1; $mem_reserved_mb/1024" | bc -l)GB)"
    
    # Aplicar fator de segurança
    local safety_factor=$SAFETY_FACTOR_PROD
    [ "$profile" = "dev" ] && safety_factor=$SAFETY_FACTOR_DEV
    
    log_info "Fator de Segurança Aplicado: ${CYAN}${safety_factor}%${NC} (perfil: $profile)"
    
    # Calcular recursos finais
    local available_cpu=$((total_cores * 1000 - cpu_reserved_millicores))
    local available_mem=$((total_mem_mb - mem_reserved_mb))
    
    available_cpu=$((available_cpu * safety_factor / 100))
    available_mem=$((available_mem * safety_factor / 100))
    
    # Garantir valores mínimos operacionais
    [ "$available_cpu" -lt 1000 ] && available_cpu=1000  # 1 core mínimo
    [ "$available_mem" -lt 1024 ] && available_mem=1024   # 1024MB mínimo
    
    log_success "Recursos Disponíveis para AWX:"
    log_success "   > CPU Disponível: ${GREEN}${available_cpu}m${NC} ($(echo "scale=1; $available_cpu/1000" | bc -l) cores)"
    log_success "   > Memória Disponível: ${GREEN}${available_mem}MB${NC} ($(echo "scale=1; $available_mem/1024" | bc -l)GB)"
    
    # Calcular réplicas
    local web_replicas=$(calculate_replicas "$profile" "$available_cpu" "web")
    local task_replicas=$(calculate_replicas "$profile" "$available_cpu" "task")
    
    log_success "Configuração Final de Réplicas:"
    log_success "   Web Réplicas: ${GREEN}$web_replicas${NC}"
    log_success "   Task Réplicas: ${GREEN}$task_replicas${NC}"
    
    # Exportar variáveis calculadas - CORREÇÃO CRÍTICA
    export AVAILABLE_CPU_MILLICORES=$available_cpu
    export AVAILABLE_MEMORY_MB=$available_mem
    export WEB_REPLICAS=$web_replicas
    export TASK_REPLICAS=$task_replicas
    export CORES=$total_cores
    export MEM_MB=$total_mem_mb
    export PERFIL=$profile
}

# ============================
# INICIALIZAÇÃO DE RECURSOS CORRIGIDA
# ============================

initialize_resources() {
    # Detectar recursos (considerando valores forçados se existirem)
    CORES=$(detect_cores)
    MEM_MB=$(detect_mem_mb)
    
    # Determinar perfil baseado nos recursos
    PERFIL=$(determine_profile "$CORES" "$MEM_MB")
    
    # Calcular recursos disponíveis COM feedback
    calculate_resources_with_feedback "$CORES" "$MEM_MB" "$PERFIL"
    
    log_debug "Recursos inicializados: PERFIL=$PERFIL, CORES=$CORES, MEM_MB=${MEM_MB}MB"
    log_debug "Variáveis exportadas: WEB_REPLICAS=$WEB_REPLICAS, TASK_REPLICAS=$TASK_REPLICAS"
}

# ============================
# FUNÇÃO DE AJUDA
# ============================

show_help() {
    cat << EOF
${CYAN}=== Script de Implantação AWX com Kind ===${NC}

${WHITE}USO:${NC}
    $0 [OPÇÕES]... 

${WHITE}OPÇÕES:${NC}
    ${GREEN}-c NOME${NC}      Nome do cluster Kind (padrão: será calculado baseado no perfil)
    ${GREEN}-p PORTA${NC}     Porta do host para acessar AWX (padrão: 8080)
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
        software-properties-common apt-transport-https bc jq lsof
    
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
    # Remover registry existente se houver
    docker rm -f kind-registry 2>/dev/null || true
    
    # Criar network se não existir
    docker network create kind 2>/dev/null || true
    
    # Iniciar registry
    docker run -d --network kind --restart=always -p ${REGISTRY_PORT}:5000 --name kind-registry registry:2
    
    # Aguardar registry estar pronto
    sleep 10
    
    # Verificar se está funcionando
    if curl -s http://localhost:${REGISTRY_PORT}/v2/ > /dev/null; then
        log_success "Registry local iniciado com sucesso"
    else
        log_error "Falha ao iniciar registry local"
        exit 1
    fi
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
        sleep 15
    fi
    
    log_info "Criando cluster Kind '$CLUSTER_NAME'..."
    
    # Configuração do cluster Kind
    cat > /tmp/kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
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
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://kind-registry:5000"]
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
    
    # Configurar registry no cluster
    configure_registry_for_cluster
}

configure_registry_for_cluster() {
    log_subheader "Configurando Registry Local"
    
    # Conectar registry ao network do kind
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
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
    
    log_success "Registry configurado no cluster"
}

# ============================
# CRIAÇÃO DO EXECUTION ENVIRONMENT SIMPLIFICADA
# ============================

create_execution_environment() {
    log_header "CONFIGURAÇÃO DO EXECUTION ENVIRONMENT"
    
    # Usar EE padrão em vez de criar customizado
    log_info "Usando Execution Environment padrão do AWX..."
    export EE_IMAGE="quay.io/ansible/awx-ee:latest"
    
    # Fazer pull da imagem para garantir disponibilidade
    log_info "Fazendo pull da imagem EE..."
    if docker pull "$EE_IMAGE"; then
        log_success "EE padrão disponível: $EE_IMAGE"
        return 0
    else
        log_error "Falha ao baixar EE padrão"
        return 1
    fi
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
    
    # Aguardar operator estar pronto
    kubectl wait --for=condition=Available deployment/awx-operator-controller-manager -n "$AWX_NAMESPACE" --timeout=300s
    
    # Criar instância AWX
    create_awx_instance
}

calculate_awx_resources() {
    # Usar variáveis calculadas anteriormente
    local available_cpu=$AVAILABLE_CPU_MILLICORES
    local available_mem=$AVAILABLE_MEMORY_MB

    # Cálculos dinâmicos mais generosos para garantir funcionamento
    local web_cpu_req="$((available_cpu * 20 / 100))m"    # 20% do CPU disponível
    local web_cpu_lim="$((available_cpu * 50 / 100))m"    # 50% do CPU disponível
    local web_mem_req="$((available_mem * 20 / 100))Mi"   # 20% da memória disponível
    local web_mem_lim="$((available_mem * 40 / 100))Mi"   # 40% da memória disponível
    
    local task_cpu_req="$((available_cpu * 15 / 100))m"   # 15% do CPU disponível
    local task_cpu_lim="$((available_cpu * 60 / 100))m"   # 60% do CPU disponível
    local task_mem_req="$((available_mem * 15 / 100))Mi"  # 15% da memória disponível
    local task_mem_lim="$((available_mem * 50 / 100))Mi"  # 50% da memória disponível
    
    # Garantir valores mínimos operacionais mais altos
    [ "${web_cpu_req%m}" -lt 500 ] && web_cpu_req="500m"
    [ "${web_mem_req%Mi}" -lt 1024 ] && web_mem_req="1024Mi"
    [ "${task_cpu_req%m}" -lt 500 ] && task_cpu_req="500m"
    [ "${task_mem_req%Mi}" -lt 1024 ] && task_mem_req="1024Mi"
    
    # Exportar valores calculados
    export AWX_WEB_CPU_REQ="$web_cpu_req"
    export AWX_WEB_CPU_LIM="$web_cpu_lim"
    export AWX_WEB_MEM_REQ="$web_mem_req"
    export AWX_WEB_MEM_LIM="$web_mem_lim"
    export AWX_TASK_CPU_REQ="$task_cpu_req"
    export AWX_TASK_CPU_LIM="$task_cpu_lim"
    export AWX_TASK_MEM_REQ="$task_mem_req"
    export AWX_TASK_MEM_LIM="$task_mem_lim"
    
    log_debug "Recursos AWX calculados dinamicamente:"
    log_debug "  Web CPU: $web_cpu_req - $web_cpu_lim"
    log_debug "  Web Mem: $web_mem_req - $web_mem_lim"
    log_debug "  Task CPU: $task_cpu_req - $task_cpu_lim"
    log_debug "  Task Mem: $task_mem_req - $task_mem_lim"
}

create_awx_instance() {
    log_info "Criando instância AWX..."
    
    # Calcular recursos AWX dinamicamente
    calculate_awx_resources
    
    # Configuração simplificada para desenvolvimento
    if [ "$PERFIL" = "dev" ]; then
        cat > /tmp/awx-instance.yaml << EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-${PERFIL}
  namespace: ${AWX_NAMESPACE}
spec:
  service_type: nodeport
  nodeport_port: 30000
  admin_user: admin
  admin_email: admin@example.com
  
  # Configuração simplificada para dev
  replicas: 1
  
  # Recursos mínimos garantidos
  web_resource_requirements:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  
  task_resource_requirements:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  
  postgres_resource_requirements:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi
  
  postgres_storage_requirements:
    requests:
      storage: 8Gi
    limits:
      storage: 8Gi
EOF
    else
        # Configuração completa para produção
        cat > /tmp/awx-instance.yaml << EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-${PERFIL}
  namespace: ${AWX_NAMESPACE}
spec:
  service_type: nodeport
  nodeport_port: 30000
  admin_user: admin
  admin_email: admin@example.com
  
  # Configuração de réplicas baseada no perfil
  replicas: ${WEB_REPLICAS}
  web_replicas: ${WEB_REPLICAS}
  task_replicas: ${TASK_REPLICAS}
  
  # Recursos para web containers
  web_resource_requirements:
    requests:
      cpu: ${AWX_WEB_CPU_REQ}
      memory: ${AWX_WEB_MEM_REQ}
    limits:
      cpu: ${AWX_WEB_CPU_LIM}
      memory: ${AWX_WEB_MEM_LIM}
  
  # Recursos para task containers
  task_resource_requirements:
    requests:
      cpu: ${AWX_TASK_CPU_REQ}
      memory: ${AWX_TASK_MEM_REQ}
    limits:
      cpu: ${AWX_TASK_CPU_LIM}
      memory: ${AWX_TASK_MEM_LIM}
  
  postgres_resource_requirements:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 2Gi
  
  postgres_storage_requirements:
    requests:
      storage: 8Gi
    limits:
      storage: 8Gi
EOF
    fi

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
    
    # Verificar se o namespace existe
    if ! kubectl get namespace "$AWX_NAMESPACE" &> /dev/null; then
        log_error "Namespace $AWX_NAMESPACE não existe!"
        return 1
    fi
    
    # Aguardar deployment AWX ser criado
    log_info "Aguardando deployment AWX ser criado..."
    local timeout=300
    local elapsed=0
    while ! kubectl get awx awx-"$PERFIL" -n "$AWX_NAMESPACE" &> /dev/null; do
        if [ $elapsed -ge $timeout ]; then
            log_error "Timeout aguardando AWX ser criado"
            exit 1
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        echo -n "."
    done
    echo ""
    
    # Aguardar pods estarem prontos
    log_info "Aguardando pods do AWX estarem prontos..."
    if ! kubectl wait --for=condition=Ready pods --all -n "$AWX_NAMESPACE" --timeout=900s; then
        log_error "Pods não ficaram prontos. Executando diagnóstico..."
        diagnose_awx_pods
        check_cluster_resources
        exit 1
    fi
    
    log_success "AWX está pronto!"
}

get_awx_password() {
    log_info "Obtendo senha do administrador AWX..."
    
    # Aguardar secret da senha estar disponível
    local timeout=300
    local elapsed=0
    while ! kubectl get secret awx-"$PERFIL"-admin-password -n "$AWX_NAMESPACE" &> /dev/null; do
        if [ $elapsed -ge $timeout ]; then
            log_error "Timeout aguardando senha do AWX"
            exit 1
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    echo ""
    
    AWX_PASSWORD=$(kubectl get secret awx-"$PERFIL"-admin-password -n "$AWX_NAMESPACE" -o jsonpath='{.data.password}' | base64 --decode)
}

show_final_info() {
    log_header "INSTALAÇÃO CONCLUÍDA"
    
    echo ""
    log_success "=== AWX IMPLANTADO COM SUCESSO ==="
    echo ""
    log_info "📋 INFORMAÇÕES DE ACESSO:"
    log_info "   URL: ${GREEN}http://localhost:${HOST_PORT}${NC}"
    log_info "   Usuário: ${GREEN}admin${NC}"
    log_info "   Senha: ${GREEN}$AWX_PASSWORD${NC}"
    echo ""
    log_info "🔧 CONFIGURAÇÃO DO SISTEMA:"
    log_info "   Perfil: ${GREEN}$PERFIL${NC}"
    log_info "   CPUs Detectadas: ${GREEN}$CORES${NC}"
    log_info "   Memória Detectada: ${GREEN}${MEM_MB}MB${NC}"
    if [ "$PERFIL" = "prod" ]; then
        log_info "   Web Réplicas: ${GREEN}$WEB_REPLICAS${NC}"
        log_info "   Task Réplicas: ${GREEN}$TASK_REPLICAS${NC}"
    else
        log_info "   Réplicas: ${GREEN}1${NC} (desenvolvimento)"
    fi
    echo ""
    log_info "🚀 COMANDOS ÚTEIS:"
    log_info "   Ver pods: ${CYAN}kubectl get pods -n $AWX_NAMESPACE${NC}"
    log_info "   Ver logs web: ${CYAN}kubectl logs -n $AWX_NAMESPACE deployment/awx-$PERFIL-web${NC}"
    log_info "   Ver logs task: ${CYAN}kubectl logs -n $AWX_NAMESPACE deployment/awx-$PERFIL-task${NC}"
    log_info "   Deletar cluster: ${CYAN}kind delete cluster --name $CLUSTER_NAME${NC}"
    echo ""
}

# ============================
# CONFIGURAÇÃO PADRÃO E PARSING
# ============================

# Valores padrão que não dependem do perfil
INSTALL_DEPS_ONLY=false
VERBOSE=false

# Variáveis de recursos (pode forçar)
FORCE_CPU=""
FORCE_MEM_MB=""

# Inicializar recursos ANTES do parsing das opções
initialize_resources

# Definir valores padrão que dependem do perfil
DEFAULT_CLUSTER_NAME="awx-cluster-${PERFIL}"
DEFAULT_HOST_PORT=$DEFAULT_HOST_PORT

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
            # Recalcular recursos com valor forçado
            initialize_resources
            DEFAULT_CLUSTER_NAME="awx-cluster-${PERFIL}"
            ;;
        m)
            if ! validate_memory "$OPTARG"; then
                exit 1
            fi
            FORCE_MEM_MB="$OPTARG"
            # Recalcular recursos com valor forçado
            initialize_resources
            DEFAULT_CLUSTER_NAME="awx-cluster-${PERFIL}"
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
# EXECUÇÃO PRINCIPAL
# ============================

log_header "INICIANDO IMPLANTAÇÃO AWX"

log_info "💻 Recursos do Sistema:"
log_info "   CPUs: ${GREEN}$CORES${NC}"
log_info "   Memória: ${GREEN}${MEM_MB}MB${NC}"
log_info "   Perfil: ${GREEN}$PERFIL${NC}"

log_info "🎯 Configuração de Implantação:"
log_info "   Ambiente: ${GREEN}$PERFIL${NC}"
log_info "   Cluster: ${GREEN}$CLUSTER_NAME${NC}"
log_info "   Porta: ${GREEN}$HOST_PORT${NC}"
log_info "   Namespace: ${GREEN}$AWX_NAMESPACE${NC}"

# Validar ambiente
validate_environment

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

# Configurar EE
create_execution_environment

# Instalar AWX
install_awx
wait_for_awx
get_awx_password
show_final_info

log_success "🎉 Instalação do AWX concluída com sucesso!"
