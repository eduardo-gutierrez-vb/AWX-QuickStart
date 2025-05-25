#!/bin/bash
set -euo pipefail

# ============================
# CARREGAMENTO DE CONFIGURAÇÃO
# ============================

# Arquivo de configuração padrão
CONFIG_FILE="$(dirname "$0")/awx-deploy.conf"

# Configurações padrão (podem ser sobrescritas pelo arquivo .conf)
ENVIRONMENT_NAME="dev"
CLUSTER_PREFIX="awx"
NAMESPACE_PREFIX="awx"
FORCE_CPU=""
FORCE_MEMORY_MB=""
SAFETY_FACTOR_PROD=70
SAFETY_FACTOR_DEV=80
DEFAULT_HOST_PORT=8080
REGISTRY_PORT=5001
ENABLE_COLORS=true
ENABLE_PROGRESS_BARS=true
ENABLE_SPINNERS=true
VERBOSE_CALCULATIONS=true

# Carregar configuração se arquivo existir
if [ -f "$CONFIG_FILE" ]; then
    echo "📁 Carregando configuração de $CONFIG_FILE"
    source "$CONFIG_FILE"
fi

# ============================
# SISTEMA DE CORES AVANÇADO
# ============================

declare -A COLORS=(
    [RESET]='\033[0m'
    [BOLD]='\033[1m'
    [DIM]='\033[2m'
    [UNDERLINE]='\033[4m'
    [BLINK]='\033[5m'
    # Cores primárias
    [RED]='\033[31m'
    [GREEN]='\033[32m'
    [YELLOW]='\033[33m'
    [BLUE]='\033[34m'
    [MAGENTA]='\033[35m'
    [CYAN]='\033[36m'
    [WHITE]='\033[37m'
    [GRAY]='\033[90m'
    # Cores de fundo
    [BG_RED]='\033[41m'
    [BG_GREEN]='\033[42m'
    [BG_YELLOW]='\033[43m'
    [BG_BLUE]='\033[44m'
    [BG_GRAY]='\033[100m'
    # Combinações especiais
    [SUCCESS]="${COLORS[BOLD]}${COLORS[GREEN]}"
    [ERROR]="${COLORS[BOLD]}${COLORS[RED]}"
    [WARNING]="${COLORS[BOLD]}${COLORS[YELLOW]}"
    [INFO]="${COLORS[BOLD]}${COLORS[BLUE]}"
    [DEBUG]="${COLORS[DIM]}${COLORS[MAGENTA]}"
    [HEADER]="${COLORS[BOLD]}${COLORS[CYAN]}"
)

# Função para verificar se cores estão habilitadas
use_colors() {
    [ "$ENABLE_COLORS" = "true" ] && [ -t 1 ]
}

# Função auxiliar para aplicar cores
colorize() {
    local color="$1"
    local text="$2"
    if use_colors; then
        echo -e "${COLORS[$color]}${text}${COLORS[RESET]}"
    else
        echo "$text"
    fi
}

# ============================
# SISTEMA DE LOGGING AVANÇADO
# ============================

log_info() {
    colorize INFO "[INFO] $1"
}

log_success() {
    colorize SUCCESS "[✅] $1"
}

log_warning() {
    colorize WARNING "[⚠️] $1"
}

log_error() {
    colorize ERROR "[❌] $1"
}

log_debug() {
    [ "$VERBOSE_CALCULATIONS" = "true" ] && colorize DEBUG "[🔍] $1"
}

log_header() {
    echo ""
    colorize HEADER "════════════════════════════════════════"
    colorize HEADER "  $1"
    colorize HEADER "════════════════════════════════════════"
}

log_subheader() {
    echo ""
    colorize CYAN "── $1"
}

# ============================
# PROGRESS BARS E SPINNERS
# ============================

# Progress bar com caracteres Unicode
show_progress_bar() {
    [ "$ENABLE_PROGRESS_BARS" != "true" ] && return
    
    local current=$1
    local total=$2
    local message="${3:-Processando}"
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    if use_colors; then
        printf "\r${COLORS[CYAN]}%s${COLORS[RESET]} [%s] %d%% (%d/%d)" \
            "$message" "$bar" "$percentage" "$current" "$total"
    else
        printf "\r%s [%s] %d%% (%d/%d)" \
            "$message" "$bar" "$percentage" "$current" "$total"
    fi
}

# Spinner animado
show_spinner() {
    [ "$ENABLE_SPINNERS" != "true" ] && return
    
    local message="$1"
    local pid="$2"
    local delay=0.1
    local spinstr='|/-\'
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        if use_colors; then
            printf "\r${COLORS[BLUE]}%s${COLORS[RESET]} %s ${COLORS[DIM]}(aguarde...)${COLORS[RESET]}" \
                "${spinstr%"$temp"}" "$message"
        else
            printf "\r%s %s (aguarde...)" "${spinstr%"$temp"}" "$message"
        fi
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    
    printf "\r"
    log_success "$message concluído!"
}

# Executa comando com spinner
execute_with_spinner() {
    local message="$1"
    shift
    
    if [ "$ENABLE_SPINNERS" = "true" ]; then
        "$@" &
        local pid=$!
        show_spinner "$message" "$pid"
        wait $pid
        return $?
    else
        log_info "$message..."
        "$@"
    fi
}

# ============================
# SISTEMA DE NOMENCLATURA PADRONIZADA
# ============================

# Gera timestamp consistente para o dia
get_timestamp() {
    date +%Y%m%d
}

# Gera nome do cluster baseado no ambiente
generate_cluster_name() {
    local env_name="${ENVIRONMENT_NAME:-dev}"
    local timestamp=$(get_timestamp)
    echo "${CLUSTER_PREFIX:-awx}-${env_name}-${timestamp}"
}

# Gera namespace baseado no ambiente
generate_namespace() {
    local env_name="${ENVIRONMENT_NAME:-dev}"
    echo "${NAMESPACE_PREFIX:-awx}-${env_name}"
}

# Gera nome da instância AWX
generate_awx_instance_name() {
    local env_name="${ENVIRONMENT_NAME:-dev}"
    echo "awx-${env_name}-${PERFIL}"
}

# Gera labels padronizados
generate_labels() {
    local component="$1"
    echo "app.kubernetes.io/name=awx,app.kubernetes.io/component=${component},app.kubernetes.io/instance=${ENVIRONMENT_NAME},app.kubernetes.io/managed-by=awx-deploy-script"
}

# ============================
# VALIDAÇÃO E UTILITÁRIOS
# ============================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

user_in_docker_group() {
    groups | grep -q docker
}

is_number() {
    [[ $1 =~ ^[0-9]+$ ]]
}

validate_port() {
    if ! is_number "$1" || [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
        log_error "Porta inválida: $1. Use um valor entre 1 e 65535."
        return 1
    fi
    return 0
}

validate_cpu() {
    if ! is_number "$1" || [ "$1" -lt 1 ] || [ "$1" -gt 64 ]; then
        log_error "CPU inválida: $1. Use um valor entre 1 e 64."
        return 1
    fi
    return 0
}

validate_memory() {
    if ! is_number "$1" || [ "$1" -lt 512 ] || [ "$1" -gt 131072 ]; then
        log_error "Memória inválida: $1. Use um valor entre 512 MB e 131072 MB (128 GB)."
        return 1
    fi
    return 0
}

# ============================
# DETECÇÃO E CÁLCULO DE RECURSOS
# ============================

detect_cores() {
    if [ -n "$FORCE_CPU" ]; then 
        echo "$FORCE_CPU"
        return
    fi
    nproc --all
}

detect_mem_mb() {
    if [ -n "$FORCE_MEMORY_MB" ]; then 
        echo "$FORCE_MEMORY_MB"
        return
    fi
    awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
}

determine_profile() {
    local cores=$1
    local mem_mb=$2
    
    if [ "$cores" -ge 4 ] && [ "$mem_mb" -ge 8192 ]; then
        echo "prod"
    else
        echo "dev"
    fi
}

# Cálculo de CPU reservada baseado em padrões de nuvem
calculate_cpu_reserved() {
    local total_cores=$1
    local reserved_millicores=0

    log_debug "Calculando reserva de CPU para $total_cores cores"
    
    # Baseado nas reservas padrão do GKE/EKS/AKS
    if [ "$total_cores" -ge 1 ]; then
        reserved_millicores=$((reserved_millicores + 60))  # Primeiro core: 6%
        local remaining_cores=$((total_cores - 1))
        log_debug "  Primeiro core: 60m"
    fi

    if [ "$remaining_cores" -ge 1 ]; then
        reserved_millicores=$((reserved_millicores + 10))  # Segundo core: 1%
        remaining_cores=$((remaining_cores - 1))
        log_debug "  Segundo core: 10m"
    fi

    if [ "$remaining_cores" -ge 2 ]; then
        reserved_millicores=$((reserved_millicores + 10))  # Próximos 2 cores: 0.5% cada
        remaining_cores=$((remaining_cores - 2))
        log_debug "  Próximos 2 cores: 10m"
    fi

    if [ "$remaining_cores" -gt 0 ]; then
        local additional=$((remaining_cores * 25 / 10))
        reserved_millicores=$((reserved_millicores + additional))
        log_debug "  Cores restantes ($remaining_cores): ${additional}m"
    fi

    log_debug "Total CPU reservada: ${reserved_millicores}m"
    echo $reserved_millicores
}

# Cálculo de memória reservada baseado em modelo escalonado
calculate_memory_reserved() {
    local total_mem_mb=$1
    local reserved_mb=0

    log_debug "Calculando reserva de memória para ${total_mem_mb}MB"

    if [ "$total_mem_mb" -lt 1024 ]; then
        reserved_mb=255
        log_debug "  Sistema pequeno (<1GB): 255MB"
    else
        # 25% dos primeiros 4 GiB
        local first_4gb=$((total_mem_mb > 4096 ? 4096 : total_mem_mb))
        reserved_mb=$((first_4gb * 25 / 100))
        local remaining_mb=$((total_mem_mb - first_4gb))
        log_debug "  Primeiros 4GB: $((reserved_mb))MB (25%)"

        # 20% dos próximos 4 GiB (até 8 GiB)
        if [ "$remaining_mb" -gt 0 ]; then
            local next_4gb=$((remaining_mb > 4096 ? 4096 : remaining_mb))
            local next_reserved=$((next_4gb * 20 / 100))
            reserved_mb=$((reserved_mb + next_reserved))
            remaining_mb=$((remaining_mb - next_4gb))
            log_debug "  Próximos 4GB: ${next_reserved}MB (20%)"
        fi

        # 10% dos próximos 8 GiB (até 16 GiB)
        if [ "$remaining_mb" -gt 0 ]; then
            local next_8gb=$((remaining_mb > 8192 ? 8192 : remaining_mb))
            local next_reserved=$((next_8gb * 10 / 100))
            reserved_mb=$((reserved_mb + next_reserved))
            remaining_mb=$((remaining_mb - next_8gb))
            log_debug "  Próximos 8GB: ${next_reserved}MB (10%)"
        fi

        # 6% dos próximos 112 GiB (até 128 GiB)
        if [ "$remaining_mb" -gt 0 ]; then
            local next_112gb=$((remaining_mb > 114688 ? 114688 : remaining_mb))
            local next_reserved=$((next_112gb * 6 / 100))
            reserved_mb=$((reserved_mb + next_reserved))
            remaining_mb=$((remaining_mb - next_112gb))
            log_debug "  Próximos 112GB: ${next_reserved}MB (6%)"
        fi

        # 2% de qualquer memória acima de 128 GiB
        if [ "$remaining_mb" -gt 0 ]; then
            local final_reserved=$((remaining_mb * 2 / 100))
            reserved_mb=$((reserved_mb + final_reserved))
            log_debug "  Memória restante: ${final_reserved}MB (2%)"
        fi
    fi

    # Adicionar 100MB para eviction threshold
    reserved_mb=$((reserved_mb + 100))
    log_debug "Total memória reservada: ${reserved_mb}MB (incluindo 100MB para eviction)"

    echo $reserved_mb
}

# Calcula réplicas baseado no perfil e recursos
calculate_replicas() {
    local profile=$1
    local available_cpu_millicores=$2
    local workload_type=$3
    local replicas=1

    if [ "$profile" = "prod" ]; then
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

        # Limites operacionais para produção
        [ "$replicas" -lt 2 ] && replicas=2
        [ "$replicas" -gt 10 ] && replicas=10
    else
        # Desenvolvimento: baseado na capacidade
        replicas=1
        [ "$available_cpu_millicores" -ge 2000 ] && replicas=2
    fi

    echo $replicas
}

# Cálculo detalhado com feedback completo
calculate_resources_with_feedback() {
    local total_cores=$1
    local total_mem_mb=$2
    local profile=$3
    
    log_header "ANÁLISE DETALHADA DE RECURSOS"
    
    # Mostrar recursos detectados
    log_info "Recursos do Sistema Detectados:"
    log_info "  💻 CPUs Totais: $(colorize GREEN "${total_cores}") cores"
    log_info "  🧠 Memória Total: $(colorize GREEN "${total_mem_mb}MB") ($(echo "scale=1; $total_mem_mb/1024" | bc -l)GB)"
    echo ""
    
    # Calcular reservas do sistema
    local cpu_reserved_millicores=$(calculate_cpu_reserved "$total_cores")
    local mem_reserved_mb=$(calculate_memory_reserved "$total_mem_mb")
    
    log_info "Reservas do Sistema (baseado em padrões GKE/EKS):"
    log_info "  🔒 CPU Reservada: $(colorize YELLOW "${cpu_reserved_millicores}m") ($(echo "scale=1; $cpu_reserved_millicores/1000" | bc -l) cores)"
    log_info "  🔒 Memória Reservada: $(colorize YELLOW "${mem_reserved_mb}MB") ($(echo "scale=1; $mem_reserved_mb/1024" | bc -l)GB)"
    echo ""
    
    # Aplicar fator de segurança
    local safety_factor=${SAFETY_FACTOR_PROD}
    [ "$profile" = "dev" ] && safety_factor=${SAFETY_FACTOR_DEV}
    
    log_info "Fator de Segurança Aplicado: $(colorize CYAN "${safety_factor}%")"
    echo ""
    
    # Calcular recursos finais
    local available_cpu=$((total_cores * 1000 - cpu_reserved_millicores))
    local available_mem=$((total_mem_mb - mem_reserved_mb))
    
    available_cpu=$((available_cpu * safety_factor / 100))
    available_mem=$((available_mem * safety_factor / 100))
    
    # Garantir valores mínimos
    [ "$available_cpu" -lt 500 ] && available_cpu=500
    [ "$available_mem" -lt 512 ] && available_mem=512
    
    log_success "Recursos Disponíveis para AWX:"
    log_success "  ⚡ CPU Disponível: $(colorize GREEN "${available_cpu}m") ($(echo "scale=1; $available_cpu/1000" | bc -l) cores)"
    log_success "  💾 Memória Disponível: $(colorize GREEN "${available_mem}MB") ($(echo "scale=1; $available_mem/1024" | bc -l)GB)"
    echo ""
    
    # Calcular réplicas
    local web_replicas=$(calculate_replicas "$profile" "$available_cpu" "web")
    local task_replicas=$(calculate_replicas "$profile" "$available_cpu" "task")
    
    log_success "Configuração Final de Réplicas:"
    log_success "  🌐 Web Réplicas: $(colorize GREEN "${web_replicas}")"
    log_success "  ⚙️ Task Réplicas: $(colorize GREEN "${task_replicas}")"
    echo ""
    
    # Exportar variáveis globais
    export AVAILABLE_CPU_MILLICORES=$available_cpu
    export AVAILABLE_MEMORY_MB=$available_mem
    export WEB_REPLICAS=$web_replicas
    export TASK_REPLICAS=$task_replicas
}

# ============================
# VALIDAÇÃO DE AMBIENTE
# ============================

validate_environment() {
    log_header "VALIDAÇÃO DO AMBIENTE"
    local errors=0
    
    # Verificar espaço em disco
    log_subheader "Verificando Espaço em Disco"
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=5242880  # 5GB em KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_error "Espaço insuficiente em disco. Necessário: 5GB, Disponível: $(echo "scale=2; $available_space/1048576" | bc -l)GB"
        ((errors++))
    else
        log_success "Espaço em disco suficiente: $(echo "scale=2; $available_space/1048576" | bc -l)GB disponível"
    fi
    
    # Verificar conectividade
    log_subheader "Verificando Conectividade"
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_success "Conectividade de rede verificada"
    else
        log_error "Falha na conectividade de rede"
        ((errors++))
    fi
    
    # Verificar permissões Docker
    log_subheader "Verificando Docker"
    if command_exists docker; then
        if docker info >/dev/null 2>&1; then
            log_success "Docker está funcionando"
        else
            log_error "Docker instalado mas não está acessível"
            ((errors++))
        fi
    else
        log_warning "Docker não encontrado - será instalado automaticamente"
    fi
    
    if groups | grep -q docker; then
        log_success "Usuário está no grupo docker"
    else
        log_warning "Usuário não está no grupo docker - será adicionado automaticamente"
    fi
    
    return $errors
}

# ============================
# INICIALIZAÇÃO DE RECURSOS
# ============================

initialize_resources() {
    CORES=$(detect_cores)
    MEM_MB=$(detect_mem_mb)
    PERFIL=$(determine_profile "$CORES" "$MEM_MB")
    
    if [ "$VERBOSE_CALCULATIONS" = "true" ]; then
        calculate_resources_with_feedback "$CORES" "$MEM_MB" "$PERFIL"
    else
        # Cálculo silencioso
        local cpu_reserved=$(calculate_cpu_reserved "$CORES")
        local mem_reserved=$(calculate_memory_reserved "$MEM_MB")
        local safety_factor=${SAFETY_FACTOR_PROD}
        [ "$PERFIL" = "dev" ] && safety_factor=${SAFETY_FACTOR_DEV}
        
        local available_cpu=$(( (CORES * 1000 - cpu_reserved) * safety_factor / 100 ))
        local available_mem=$(( (MEM_MB - mem_reserved) * safety_factor / 100 ))
        
        [ "$available_cpu" -lt 500 ] && available_cpu=500
        [ "$available_mem" -lt 512 ] && available_mem=512
        
        export AVAILABLE_CPU_MILLICORES=$available_cpu
        export AVAILABLE_MEMORY_MB=$available_mem
        export WEB_REPLICAS=$(calculate_replicas "$PERFIL" "$available_cpu" "web")
        export TASK_REPLICAS=$(calculate_replicas "$PERFIL" "$available_cpu" "task")
    fi
    
    log_debug "Recursos inicializados: PERFIL=$PERFIL, CORES=$CORES, MEM_MB=${MEM_MB}MB"
}

# ============================
# INSTALAÇÃO DE DEPENDÊNCIAS
# ============================

install_dependencies() {
    log_header "VERIFICAÇÃO E INSTALAÇÃO DE DEPENDÊNCIAS"
    
    # Verificar sistema operacional
    if [[ ! -f /etc/os-release ]] || ! grep -q "Ubuntu" /etc/os-release; then
        log_warning "Este script foi testado apenas no Ubuntu. Prosseguindo mesmo assim..."
    fi
    
    # Atualizar sistema
    execute_with_spinner "Atualizando sistema" sudo apt-get update -qq
    execute_with_spinner "Upgrading packages" sudo apt-get upgrade -y
    
    # Instalar dependências básicas
    install_basic_dependencies
    install_python39
    install_docker
    install_kind
    install_kubectl
    install_helm
    install_ansible_tools
    
    # Verificações finais
    check_docker_running
    start_local_registry
    
    log_success "Todas as dependências foram instaladas e verificadas!"
}

install_basic_dependencies() {
    log_subheader "Instalando Dependências Básicas"
    
    local packages=(
        "python3" "python3-pip" "python3-venv" "git" "curl" "wget"
        "ca-certificates" "gnupg2" "lsb-release" "build-essential"
        "software-properties-common" "apt-transport-https" "bc"
    )
    
    execute_with_spinner "Instalando pacotes básicos" \
        sudo apt-get install -y "${packages[@]}"
}

install_python39() {
    if command_exists python3.9; then
        log_info "Python 3.9 já está instalado: $(python3.9 --version)"
        return 0
    fi
    
    log_subheader "Instalando Python 3.9"
    
    execute_with_spinner "Adicionando repositório Python" \
        sudo add-apt-repository ppa:deadsnakes/ppa -y
    
    execute_with_spinner "Atualizando cache" \
        sudo apt-get update -qq
    
    execute_with_spinner "Instalando Python 3.9" \
        sudo apt-get install -y python3.9 python3.9-venv python3.9-distutils python3.9-dev
    
    # Instalar pip para Python 3.9
    curl -s https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
    execute_with_spinner "Instalando pip para Python 3.9" \
        sudo python3.9 /tmp/get-pip.py
    rm -f /tmp/get-pip.py
    
    log_success "Python 3.9 instalado: $(python3.9 --version)"
}

install_docker() {
    if command_exists docker; then
        log_info "Docker já está instalado: $(docker --version)"
        if ! user_in_docker_group; then
            log_warning "Adicionando usuário ao grupo docker..."
            sudo usermod -aG docker "$USER"
            log_warning "Execute 'newgrp docker' ou faça logout/login"
        fi
        return 0
    fi

    log_subheader "Instalando Docker"
    
    # Remover versões antigas
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Preparar repositório
    execute_with_spinner "Preparando repositório Docker" bash -c '
        sudo apt-get install -y ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    '
    
    # Instalar Docker
    execute_with_spinner "Instalando Docker" bash -c '
        sudo apt-get update -qq
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    '
    
    # Configurar usuário
    sudo usermod -aG docker "$USER"
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker instalado com sucesso!"
    log_warning "Execute 'newgrp docker' ou faça logout/login para aplicar mudanças de grupo"
}

install_kind() {
    if command_exists kind; then
        log_info "Kind já está instalado: $(kind version)"
        return 0
    fi

    log_subheader "Instalando Kind"
    
    execute_with_spinner "Baixando e instalando Kind" bash -c '
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    '
    
    log_success "Kind instalado: $(kind version)"
}

install_kubectl() {
    if command_exists kubectl; then
        log_info "kubectl já está instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return 0
    fi

    log_subheader "Instalando kubectl"
    
    execute_with_spinner "Baixando e instalando kubectl" bash -c '
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    '
    
    log_success "kubectl instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

install_helm() {
    if command_exists helm; then
        log_info "Helm já está instalado: $(helm version --short)"
        return 0
    fi

    log_subheader "Instalando Helm"
    
    execute_with_spinner "Configurando repositório Helm" bash -c '
        curl -fsSL https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    '
    
    execute_with_spinner "Instalando Helm" bash -c '
        sudo apt-get update -qq
        sudo apt-get install -y helm
    '
    
    log_success "Helm instalado: $(helm version --short)"
}

install_ansible_tools() {
    local venv_path="$HOME/ansible-ee-venv"
    
    if [ -d "$venv_path" ]; then
        log_info "Ambiente virtual Ansible já existe"
        source "$venv_path/bin/activate"
    else
        log_subheader "Criando Ambiente Virtual Ansible"
        execute_with_spinner "Criando ambiente virtual" \
            python3.9 -m venv "$venv_path"
        source "$venv_path/bin/activate"
    fi
    
    if command_exists ansible; then
        log_info "Ansible já está instalado: $(ansible --version | head -n1)"
    else
        log_subheader "Instalando Ferramentas Ansible"
        execute_with_spinner "Instalando Ansible e ansible-builder" bash -c '
            pip install --upgrade pip
            pip install "ansible>=7.0.0" "ansible-builder>=3.0.0"
        '
        log_success "Ansible e ansible-builder instalados!"
    fi
}

check_docker_running() {
    log_subheader "Verificando Docker"
    
    if ! docker info >/dev/null 2>&1; then
        if ! user_in_docker_group; then
            log_error "Usuário não está no grupo docker. Execute: newgrp docker"
            exit 1
        fi
        
        if ! systemctl is-active --quiet docker; then
            execute_with_spinner "Iniciando Docker" sudo systemctl start docker
            sleep 5
        fi
        
        if ! docker info >/dev/null 2>&1; then
            log_error "Não foi possível conectar ao Docker"
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
    
    log_subheader "Iniciando Registry Local"
    
    execute_with_spinner "Iniciando container registry" \
        docker run -d --restart=always -p "${REGISTRY_PORT}":5000 --name kind-registry registry:2
    
    # Conectar ao network do kind se existir
    if docker network ls | grep -q kind; then
        docker network connect kind kind-registry 2>/dev/null || true
    fi
    
    log_success "Registry local iniciado em localhost:${REGISTRY_PORT}"
}

# ============================
# CRIAÇÃO DO CLUSTER KIND
# ============================

create_kind_cluster() {
    log_header "CRIAÇÃO DO CLUSTER KIND"
    
    # Verificar cluster existente
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_warning "Cluster '$CLUSTER_NAME' já existe. Deletando..."
        execute_with_spinner "Deletando cluster existente" \
            kind delete cluster --name "$CLUSTER_NAME"
    fi
    
    log_info "Criando cluster Kind: $(colorize CYAN "$CLUSTER_NAME")"
    
    # Gerar configuração do cluster
    local config_file="/tmp/kind-config-${CLUSTER_NAME}.yaml"
    generate_kind_config > "$config_file"
    
    # Criar cluster
    execute_with_spinner "Criando cluster Kind" \
        kind create cluster --name "$CLUSTER_NAME" --config "$config_file"
    
    rm -f "$config_file"
    
    # Aguardar cluster estar pronto
    execute_with_spinner "Aguardando cluster estar pronto" \
        kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Configurar registry
    configure_registry_for_cluster
    
    log_success "Cluster '$CLUSTER_NAME' criado e configurado!"
}

generate_kind_config() {
    cat << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  labels:
    environment: ${ENVIRONMENT_NAME}
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
      labels:
        $(generate_labels "control-plane")
  - |
    kind: KubeletConfiguration
    maxPods: 110
EOF

    # Adicionar workers para produção
    if [ "$PERFIL" = "prod" ] && [ "$CORES" -ge 6 ]; then
        cat << EOF
- role: worker
  labels:
    environment: ${ENVIRONMENT_NAME}
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    maxPods: 110
    metadata:
      labels:
        $(generate_labels "worker")
EOF
    fi
}

configure_registry_for_cluster() {
    log_subheader "Configurando Registry Local"
    
    # Conectar registry ao network do kind
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
  labels:
    $(generate_labels "registry-config")
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
    environment: "${ENVIRONMENT_NAME}"
EOF
}

# ============================
# EXECUTION ENVIRONMENT
# ============================

create_execution_environment() {
    log_header "CRIAÇÃO DO EXECUTION ENVIRONMENT"
    
    # Ativar ambiente virtual
    source "$HOME/ansible-ee-venv/bin/activate"
    
    local ee_dir="/tmp/awx-ee-${ENVIRONMENT_NAME}-$$"
    mkdir -p "$ee_dir"
    cd "$ee_dir"
    
    # Gerar arquivos de configuração
    generate_ee_requirements
    generate_ee_config
    
    # Construir imagem
    local image_name="localhost:${REGISTRY_PORT}/awx-custom-ee:${ENVIRONMENT_NAME}-latest"
    
    log_info "Construindo Execution Environment: $(colorize CYAN "$image_name")"
    
    if [ "$VERBOSE_CALCULATIONS" = "true" ]; then
        ansible-builder build -t "$image_name" -f execution-environment.yml --verbosity 2
    else
        execute_with_spinner "Construindo Execution Environment" \
            ansible-builder build -t "$image_name" -f execution-environment.yml
    fi
    
    execute_with_spinner "Enviando para registry local" \
        docker push "$image_name"
    
    # Limpar
    cd /
    rm -rf "$ee_dir"
    
    # Exportar nome da imagem
    export CUSTOM_EE_IMAGE="$image_name"
    
    log_success "Execution Environment criado: $image_name"
}

generate_ee_requirements() {
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

    cat > requirements.txt << EOF
pywinrm>=0.4.3
requests>=2.28.0
kubernetes>=24.2.0
pyyaml>=6.0
jinja2>=3.1.0
cryptography>=3.4.8
EOF
}

generate_ee_config() {
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
    - LABEL environment="${ENVIRONMENT_NAME}"
    - LABEL managed-by="awx-deploy-script"
  append_final:
    - RUN ansible-galaxy collection list
    - RUN pip list
    - LABEL build-date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
}

# ============================
# INSTALAÇÃO DO AWX
# ============================

install_awx() {
    log_header "INSTALAÇÃO DO AWX OPERATOR"
    
    # Adicionar repositório Helm
    execute_with_spinner "Adicionando repositório Helm do AWX" bash -c '
        helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ 2>/dev/null || true
        helm repo update
    '
    
    # Criar namespace
    log_info "Criando namespace: $(colorize CYAN "$AWX_NAMESPACE")"
    kubectl create namespace "$AWX_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Adicionar labels ao namespace
    kubectl label namespace "$AWX_NAMESPACE" $(generate_labels "namespace") --overwrite
    
    # Instalar AWX Operator
    execute_with_spinner "Instalando AWX Operator" \
        helm upgrade --install awx-operator awx-operator/awx-operator \
            -n "$AWX_NAMESPACE" \
            --create-namespace \
            --wait \
            --timeout=10m \
            --set nameOverride="awx-operator-${ENVIRONMENT_NAME}" \
            --set fullnameOverride="awx-operator-${ENVIRONMENT_NAME}"
    
    log_success "AWX Operator instalado!"
    
    # Criar instância AWX
    create_awx_instance
}

create_awx_instance() {
    log_subheader "Criando Instância AWX"
    
    local awx_instance_name=$(generate_awx_instance_name)
    log_info "Nome da instância: $(colorize CYAN "$awx_instance_name")"
    
    # Calcular recursos baseados no perfil
    calculate_awx_resources
    
    # Gerar manifesto
    local manifest_file="/tmp/awx-instance-${ENVIRONMENT_NAME}.yaml"
    generate_awx_manifest "$awx_instance_name" > "$manifest_file"
    
    # Aplicar manifesto
    execute_with_spinner "Criando instância AWX" \
        kubectl apply -f "$manifest_file" -n "$AWX_NAMESPACE"
    
    rm -f "$manifest_file"
    
    # Exportar nome para uso posterior
    export AWX_INSTANCE_NAME="$awx_instance_name"
    
    log_success "Instância AWX criada: $awx_instance_name"
}

calculate_awx_resources() {
    # Recursos baseados no perfil e recursos disponíveis
    if [ "$PERFIL" = "prod" ]; then
        export AWX_WEB_CPU_REQ="100m"
        export AWX_WEB_MEM_REQ="256Mi"
        export AWX_WEB_CPU_LIM="2000m"
        export AWX_WEB_MEM_LIM="4Gi"
        
        export AWX_TASK_CPU_REQ="100m"
        export AWX_TASK_MEM_REQ="256Mi"
        export AWX_TASK_CPU_LIM="4000m"
        export AWX_TASK_MEM_LIM="8Gi"
        
        export AWX_POSTGRES_MEM_REQ="512Mi"
        export AWX_POSTGRES_MEM_LIM="2Gi"
        export AWX_POSTGRES_STORAGE="16Gi"
    else
        export AWX_WEB_CPU_REQ="50m"
        export AWX_WEB_MEM_REQ="128Mi"
        export AWX_WEB_CPU_LIM="1000m"
        export AWX_WEB_MEM_LIM="2Gi"
        
        export AWX_TASK_CPU_REQ="50m"
        export AWX_TASK_MEM_REQ="128Mi"
        export AWX_TASK_CPU_LIM="2000m"
        export AWX_TASK_MEM_LIM="4Gi"
        
        export AWX_POSTGRES_MEM_REQ="256Mi"
        export AWX_POSTGRES_MEM_LIM="1Gi"
        export AWX_POSTGRES_STORAGE="8Gi"
    fi
}

generate_awx_manifest() {
    local instance_name="$1"
    
    cat << EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: ${instance_name}
  namespace: ${AWX_NAMESPACE}
  labels:
    $(generate_labels "awx-instance")
    environment: ${ENVIRONMENT_NAME}
    profile: ${PERFIL}
spec:
  service_type: nodeport
  nodeport_port: ${HOST_PORT}
  
  # Configuração de administrador
  admin_user: admin
  admin_email: admin@${ENVIRONMENT_NAME}.local
  
  # Execution Environment personalizado
  control_plane_ee_image: ${CUSTOM_EE_IMAGE}
  
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
  
  # Configuração PostgreSQL
  postgres_resource_requirements:
    requests:
      memory: ${AWX_POSTGRES_MEM_REQ}
    limits:
      memory: ${AWX_POSTGRES_MEM_LIM}
  
  postgres_storage_requirements:
    requests:
      storage: ${AWX_POSTGRES_STORAGE}
    limits:
      storage: ${AWX_POSTGRES_STORAGE}
  
  # Persistência de projetos
  projects_persistence: true
  projects_storage_size: 8Gi
  projects_storage_access_mode: ReadWriteOnce
  
  # Configurações de rede
  hostname: awx-${ENVIRONMENT_NAME}.local
  
  # Labels customizados
  web_extra_labels:
    environment: ${ENVIRONMENT_NAME}
    component: web
  
  task_extra_labels:
    environment: ${ENVIRONMENT_NAME}
    component: task
  
  postgres_extra_labels:
    environment: ${ENVIRONMENT_NAME}
    component: postgres
EOF
}

# ============================
# MONITORAMENTO E FINALIZAÇÃO
# ============================

wait_for_awx() {
    log_header "AGUARDANDO INSTALAÇÃO DO AWX"
    
    local timeout=900  # 15 minutos
    local interval=10
    local elapsed=0
    
    log_info "Aguardando todos os pods ficarem prontos (timeout: ${timeout}s)..."
    
    while [ $elapsed -lt $timeout ]; do
        local ready_pods=$(kubectl get pods -n "$AWX_NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        local total_pods=$(kubectl get pods -n "$AWX_NAMESPACE" --no-headers 2>/dev/null | wc -l)
        
        if [ "$total_pods" -gt 0 ]; then
            show_progress_bar "$ready_pods" "$total_pods" "Pods prontos"
            
            if [ "$ready_pods" -eq "$total_pods" ]; then
                printf "\n"
                log_success "Todos os pods estão prontos!"
                break
            fi
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    if [ $elapsed -ge $timeout ]; then
        printf "\n"
        log_error "Timeout aguardando pods. Status atual:"
        kubectl get pods -n "$AWX_NAMESPACE"
        return 1
    fi
    
    # Verificação final com kubectl wait
    execute_with_spinner "Verificação final de saúde" \
        kubectl wait --for=condition=Ready pods --all -n "$AWX_NAMESPACE" --timeout=300s
}

get_awx_password() {
    log_subheader "Obtendo Credenciais AWX"
    
    local secret_name="${AWX_INSTANCE_NAME}-admin-password"
    local timeout=300
    local elapsed=0
    
    # Aguardar secret estar disponível
    while ! kubectl get secret "$secret_name" -n "$AWX_NAMESPACE" &> /dev/null; do
        if [ $elapsed -ge $timeout ]; then
            log_error "Timeout aguardando senha do AWX. Verifique os logs:"
            log_error "kubectl logs -n $AWX_NAMESPACE deployment/awx-operator-${ENVIRONMENT_NAME}"
            return 1
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    echo ""
    
    AWX_PASSWORD=$(kubectl get secret "$secret_name" -n "$AWX_NAMESPACE" -o jsonpath='{.data.password}' | base64 --decode)
    log_success "Senha obtida com sucesso!"
}

show_final_info() {
    log_header "INSTALAÇÃO CONCLUÍDA COM SUCESSO"
    
    # Obter informações do cluster
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    local access_url="http://localhost:${HOST_PORT}"
    
    echo ""
    colorize SUCCESS "🎉 AWX IMPLANTADO COM SUCESSO!"
    echo ""
    
    # Informações de acesso
    colorize HEADER "📋 INFORMAÇÕES DE ACESSO"
    echo "   🌐 URL: $(colorize GREEN "$access_url")"
    echo "   👤 Usuário: $(colorize GREEN "admin")"
    echo "   🔑 Senha: $(colorize GREEN "$AWX_PASSWORD")"
    echo ""
    
    # Configuração do sistema
    colorize HEADER "🔧 CONFIGURAÇÃO DO SISTEMA"
    echo "   📊 Perfil: $(colorize GREEN "$PERFIL")"
    echo "   🖥️  Ambiente: $(colorize GREEN "$ENVIRONMENT_NAME")"
    echo "   💻 CPUs Detectadas: $(colorize GREEN "$CORES")"
    echo "   🧠 Memória Detectada: $(colorize GREEN "${MEM_MB}MB")"
    echo "   🌐 Web Réplicas: $(colorize GREEN "$WEB_REPLICAS")"
    echo "   ⚙️  Task Réplicas: $(colorize GREEN "$TASK_REPLICAS")"
    echo "   📦 Cluster: $(colorize GREEN "$CLUSTER_NAME")"
    echo "   📁 Namespace: $(colorize GREEN "$AWX_NAMESPACE")"
    echo ""
    
    # Comandos úteis
    colorize HEADER "🚀 COMANDOS ÚTEIS"
    echo "   Ver pods:"
    echo "     $(colorize CYAN "kubectl get pods -n $AWX_NAMESPACE")"
    echo "   Ver logs web:"
    echo "     $(colorize CYAN "kubectl logs -n $AWX_NAMESPACE deployment/${AWX_INSTANCE_NAME}-web")"
    echo "   Ver logs task:"
    echo "     $(colorize CYAN "kubectl logs -n $AWX_NAMESPACE deployment/${AWX_INSTANCE_NAME}-task")"
    echo "   Ver status AWX:"
    echo "     $(colorize CYAN "kubectl get awx -n $AWX_NAMESPACE")"
    echo "   Deletar cluster:"
    echo "     $(colorize CYAN "kind delete cluster --name $CLUSTER_NAME")"
    echo ""
    
    # Status atual se verbose
    if [ "$VERBOSE_CALCULATIONS" = "true" ]; then
        colorize HEADER "🔍 STATUS ATUAL DOS RECURSOS"
        kubectl get all -n "$AWX_NAMESPACE" -o wide
        echo ""
    fi
    
    # Informações de customização
    colorize HEADER "⚙️  CUSTOMIZAÇÃO"
    echo "   Para personalizar a instalação, crie/edite:"
    echo "     $(colorize CYAN "$(dirname "$0")/awx-deploy.conf")"
    echo ""
    echo "   Exemplo de configuração:"
    echo "     $(colorize GRAY "ENVIRONMENT_NAME=\"producao\"")"
    echo "     $(colorize GRAY "CLUSTER_PREFIX=\"meu-awx\"")"
    echo "     $(colorize GRAY "DEFAULT_HOST_PORT=9090")"
    echo "     $(colorize GRAY "SAFETY_FACTOR_PROD=60")"
    echo ""
}

# ============================
# FUNÇÃO DE AJUDA
# ============================

show_help() {
    colorize HEADER "═══════════════════════════════════════════════════════"
    colorize HEADER "  Script de Implantação AWX com Kind - Versão Melhorada"
    colorize HEADER "═══════════════════════════════════════════════════════"
    echo ""
    
    colorize WHITE "USO:"
    echo "    $0 [OPÇÕES]"
    echo ""
    
    colorize WHITE "OPÇÕES:"
    echo "    $(colorize GREEN "-c NOME")      Nome do cluster Kind (padrão: awx-\$AMBIENTE-\$DATA)"
    echo "    $(colorize GREEN "-p PORTA")     Porta do host para acessar AWX (padrão: 8080)"
    echo "    $(colorize GREEN "-f CPU")       Forçar número de CPUs (ex: 4)"
    echo "    $(colorize GREEN "-m MEMORIA")   Forçar quantidade de memória em MB (ex: 8192)"
    echo "    $(colorize GREEN "-d")           Instalar apenas dependências"
    echo "    $(colorize GREEN "-v")           Modo verboso (cálculos detalhados)"
    echo "    $(colorize GREEN "-h")           Exibir esta ajuda"
    echo ""
    
    colorize WHITE "EXEMPLOS:"
    echo "    $0                                    # Usar configuração padrão/arquivo .conf"
    echo "    $0 -c meu-cluster -p 8080            # Cluster personalizado na porta 8080"
    echo "    $0 -f 4 -m 8192                     # Forçar 4 CPUs e 8GB RAM"
    echo "    $0 -d                                # Instalar apenas dependências"
    echo "    $0 -v                                # Modo verboso com cálculos detalhados"
    echo ""
    
    colorize WHITE "ARQUIVO DE CONFIGURAÇÃO:"
    echo "    Crie o arquivo $(colorize CYAN "awx-deploy.conf") no mesmo diretório do script:"
    echo ""
    echo "    $(colorize GRAY "# Configuração do ambiente")"
    echo "    $(colorize GRAY "ENVIRONMENT_NAME=\"producao\"")"
    echo "    $(colorize GRAY "CLUSTER_PREFIX=\"awx\"")"
    echo "    $(colorize GRAY "NAMESPACE_PREFIX=\"awx\"")"
    echo "    $(colorize GRAY "")"
    echo "    $(colorize GRAY "# Configuração de recursos")"
    echo "    $(colorize GRAY "SAFETY_FACTOR_PROD=70")"
    echo "    $(colorize GRAY "SAFETY_FACTOR_DEV=80")"
    echo "    $(colorize GRAY "")"
    echo "    $(colorize GRAY "# Configuração visual")"
    echo "    $(colorize GRAY "ENABLE_COLORS=true")"
    echo "    $(colorize GRAY "ENABLE_PROGRESS_BARS=true")"
    echo "    $(colorize GRAY "VERBOSE_CALCULATIONS=true")"
    echo ""
    
    colorize WHITE "DEPENDÊNCIAS INSTALADAS AUTOMATICAMENTE:"
    echo "    - Docker"
    echo "    - Kind"
    echo "    - kubectl"
    echo "    - Helm"
    echo "    - Ansible + ansible-builder"
    echo "    - Python 3.9 + venv"
    echo ""
    
    colorize WHITE "RECURSOS AUTOMATICAMENTE CALCULADOS:"
    echo "    O script detecta recursos do sistema e calcula a configuração ideal:"
    echo ""
    echo "    $(colorize GREEN "Produção"): ≥4 CPUs e ≥8GB RAM"
    echo "      - Múltiplas réplicas baseadas em recursos disponíveis"
    echo "      - Reservas de sistema baseadas em padrões GKE/EKS/AKS"
    echo "      - Fator de segurança configurável (padrão: 70%)"
    echo ""
    echo "    $(colorize YELLOW "Desenvolvimento"): <4 CPUs ou <8GB RAM"
    echo "      - Configuração otimizada para recursos limitados"
    echo "      - Fator de segurança mais conservador (padrão: 80%)"
    echo ""
    
    colorize WHITE "NOMENCLATURA PADRONIZADA:"
    echo "    Todos os recursos seguem padrão determinístico:"
    echo "    - Cluster: $(colorize CYAN "\${CLUSTER_PREFIX}-\${ENVIRONMENT_NAME}-\${DATA}")"
    echo "    - Namespace: $(colorize CYAN "\${NAMESPACE_PREFIX}-\${ENVIRONMENT_NAME}")"
    echo "    - Instância AWX: $(colorize CYAN "awx-\${ENVIRONMENT_NAME}-\${PERFIL}")"
    echo ""
    
    colorize WHITE "ACESSO AWX:"
    echo "    Após a instalação:"
    echo "    - URL: $(colorize GREEN "http://localhost:\$PORTA")"
    echo "    - Usuário: $(colorize GREEN "admin")"
    echo "    - Senha: $(colorize GREEN "exibida no final da instalação")"
    echo ""
}

# ============================
# CONFIGURAÇÃO PADRÃO E PARSING
# ============================

# Valores padrão que não dependem do perfil
INSTALL_DEPS_ONLY=false
VERBOSE_ARG=false

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
            FORCE_MEMORY_MB="$OPTARG"
            ;;
        d)
            INSTALL_DEPS_ONLY=true
            ;;
        v)
            VERBOSE_ARG=true
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

# Aplicar verbose se especificado via argumento
[ "$VERBOSE_ARG" = "true" ] && VERBOSE_CALCULATIONS=true

# Inicializar recursos após parsing das opções
initialize_resources

# Aplicar valores padrão se não fornecidos
CLUSTER_NAME=${CLUSTER_NAME:-$(generate_cluster_name)}
HOST_PORT=${HOST_PORT:-$DEFAULT_HOST_PORT}
AWX_NAMESPACE=$(generate_namespace)

# ============================
# EXECUÇÃO PRINCIPAL
# ============================

# Banner inicial
log_header "SCRIPT DE IMPLANTAÇÃO AWX - VERSÃO MELHORADA"

log_info "💻 Recursos do Sistema:"
log_info "   CPUs: $(colorize GREEN "$CORES")"
log_info "   Memória: $(colorize GREEN "${MEM_MB}MB") ($(echo "scale=1; $MEM_MB/1024" | bc -l)GB)"
log_info "   Perfil: $(colorize GREEN "$PERFIL")"

log_info "🎯 Configuração de Implantação:"
log_info "   Ambiente: $(colorize GREEN "$ENVIRONMENT_NAME")"
log_info "   Cluster: $(colorize GREEN "$CLUSTER_NAME")"
log_info "   Porta: $(colorize GREEN "$HOST_PORT")"
log_info "   Namespace: $(colorize GREEN "$AWX_NAMESPACE")"
log_info "   Web Réplicas: $(colorize GREEN "$WEB_REPLICAS")"
log_info "   Task Réplicas: $(colorize GREEN "$TASK_REPLICAS")"

# Validar ambiente
if ! validate_environment; then
    log_error "Falhas na validação do ambiente. Corrija os problemas e tente novamente."
    exit 1
fi

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

colorize SUCCESS "🎉 INSTALAÇÃO DO AWX CONCLUÍDA COM SUCESSO!"
