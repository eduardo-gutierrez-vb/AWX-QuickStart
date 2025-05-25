#!/bin/bash
set -eo pipefail

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                        CONFIGURAÇÕES PRINCIPAIS                             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                            CORES E ESTILOS                                 │
# └─────────────────────────────────────────────────────────────────────────────┘

# Cores base aprimoradas
declare -r RED='\033[38;5;196m'        # Vermelho vibrante
declare -r GREEN='\033[38;5;46m'       # Verde neon
declare -r YELLOW='\033[38;5;226m'     # Amarelo brilhante
declare -r BLUE='\033[38;5;39m'        # Azul ciano
declare -r PURPLE='\033[38;5;165m'     # Roxo vibrante
declare -r CYAN='\033[38;5;51m'        # Ciano brilhante
declare -r WHITE='\033[38;5;231m'      # Branco puro
declare -r ORANGE='\033[38;5;208m'     # Laranja vibrante
declare -r PINK='\033[38;5;198m'       # Rosa neon
declare -r LIME='\033[38;5;118m'       # Verde lima

# Cores de fundo gradientes
declare -r BG_DARK='\033[48;5;235m'    # Fundo escuro
declare -r BG_LIGHT='\033[48;5;252m'   # Fundo claro
declare -r BG_SUCCESS='\033[48;5;22m'  # Fundo verde escuro
declare -r BG_ERROR='\033[48;5;52m'    # Fundo vermelho escuro
declare -r BG_WARNING='\033[48;5;58m'  # Fundo amarelo escuro

# Estilos de texto
declare -r BOLD='\033[1m'              # Negrito
declare -r DIM='\033[2m'               # Esmaecido
declare -r ITALIC='\033[3m'            # Itálico
declare -r UNDERLINE='\033[4m'         # Sublinhado
declare -r BLINK='\033[5m'             # Piscante
declare -r REVERSE='\033[7m'           # Invertido
declare -r STRIKETHROUGH='\033[9m'     # Riscado
declare -r NC='\033[0m'                # Reset

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                          ÍCONES UNICODE                                    │
# └─────────────────────────────────────────────────────────────────────────────┘

declare -r ICON_SUCCESS="✅"
declare -r ICON_ERROR="❌"
declare -r ICON_WARNING="⚠️ "
declare -r ICON_INFO="ℹ️ "
declare -r ICON_DEBUG="🔍"
declare -r ICON_ROCKET="🚀"
declare -r ICON_GEAR="⚙️ "
declare -r ICON_DOWNLOAD="⬇️ "
declare -r ICON_UPLOAD="⬆️ "
declare -r ICON_CLOCK="⏰"
declare -r ICON_CHECKMARK="✓"
declare -r ICON_CROSS="✗"
declare -r ICON_ARROW="→"
declare -r ICON_STAR="⭐"
declare -r ICON_FIRE="🔥"
declare -r ICON_LIGHTNING="⚡"
declare -r ICON_DIAMOND="💎"
declare -r ICON_SHIELD="🛡️ "
declare -r ICON_KEY="🔑"
declare -r ICON_LOCK="🔒"
declare -r ICON_UNLOCK="🔓"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                       CONFIGURAÇÕES DO SISTEMA                             │
# └─────────────────────────────────────────────────────────────────────────────┘

# Configurações de rede
DEFAULT_HOST_PORT=8080
DEFAULT_REGISTRY_PORT=5001

# Configurações de recursos
MIN_CPU_CORES=1
MAX_CPU_CORES=64
MIN_MEMORY_MB=512
MAX_MEMORY_MB=131072

# Configurações de timeout
DOCKER_TIMEOUT=300
KUBECTL_TIMEOUT=600
AWX_TIMEOUT=900

# Configurações de namespace
AWX_NAMESPACE="awx"
REGISTRY_NAME="kind-registry"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      CONFIGURAÇÕES DE PERFIL                               │
# └─────────────────────────────────────────────────────────────────────────────┘

# Limites para perfil de desenvolvimento
DEV_MAX_CPU=4
DEV_MAX_MEMORY=8192

# Limites para perfil de produção
PROD_MIN_CPU=4
PROD_MIN_MEMORY=8192

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                           FUNÇÕES DE INTERFACE                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                        FUNÇÕES DE DISPLAY                                  │
# └─────────────────────────────────────────────────────────────────────────────┘

create_box() {
    local title="$1"
    local width="${2:-80}"
    local color="${3:-$CYAN}"
    
    local top_line="╔$(printf '═%.0s' $(seq 1 $((width-2))))╗"
    local bottom_line="╚$(printf '═%.0s' $(seq 1 $((width-2))))╝"
    local title_padding=$(( (width - ${#title} - 4) / 2 ))
    [ $title_padding -lt 0 ] && title_padding=0
    local title_line="║$(printf ' %.0s' $(seq 1 $title_padding)) ${title} $(printf ' %.0s' $(seq 1 $((width - ${#title} - title_padding -3 ))))║"
    
    echo -e "${color}${top_line}${NC}"
    echo -e "${color}${title_line:0:$width}${NC}"
    echo -e "${color}${bottom_line}${NC}"
}

create_separator() {
    local char="${1:-─}"
    local width="${2:-80}"
    local color="${3:-$BLUE}"
    
    printf "${color}"
    printf "${char}%.0s" $(seq 1 $width)
    printf "${NC}\n"
}

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
   ╔═══════════════════════════════════════════════════════════════════════════════╗
   ║     ██████╗ ██╗    ██╗██╗  ██╗    ██████╗ ███████╗██████╗ ██╗      ██████╗    ║
   ║    ██╔══██╗██║    ██║╚██╗██╔╝    ██╔══██╗██╔════╝██╔══██╗██║     ██╔═══██╗   ║
   ║    ██████╔╝██║ █╗ ██║ ╚███╔╝     ██║  ██║█████╗  ██████╔╝██║     ██║   ██║   ║
   ║    ██╔══██╗██║███╗██║ ██╔██╗     ██║  ██║██╔══╝  ██╔═══╝ ██║     ██║   ██║   ║
   ║    ██║  ██║╚███╔███╔╝██╔╝ ██╗    ██████╔╝███████╗██║     ███████╗╚██████╔╝   ║
   ║    ╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═╝    ╚═════╝ ╚══════╝╚═╝     ╚══════╝ ╚═════╝    ║
   ║                                                                               ║
   ║           🔥 Script de Implantação AWX com Kubernetes Kind 🔥               ║
   ║                      ⚡ Versão Moderna e Aprimorada ⚡                       ║
   ╚═══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

show_spinner() {
    local pid=$1
    local message="$2"
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local temp
    
    echo -ne "${BLUE}${message}${NC} "
    while kill -0 $pid 2>/dev/null; do
        temp=${spinstr#?}
        printf "${YELLOW}[%c]${NC}" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b"
    done
    echo -e "${GREEN}${ICON_CHECKMARK} Concluído!${NC}"
}

show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${CYAN}${BOLD}Progresso:${NC} ["
    printf "${GREEN}%${completed}s" | tr ' ' '#'
    printf "${DIM}%${remaining}s" | tr ' ' '.'
    printf "] ${YELLOW}%d%%${NC} ${BLUE}(%d/%d)${NC}" "$percentage" "$current" "$total"
}

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                        FUNÇÕES DE LOG AVANÇADAS                            │
# └─────────────────────────────────────────────────────────────────────────────┘

log_with_style() {
    local level="$1"
    local message="$2"
    local icon="$3"
    local color="$4"
    local bg_color="${5:-}"
    local timestamp=$(date '+%H:%M:%S')
    
    echo -e "${bg_color}${color}${BOLD}[${timestamp}] ${icon} ${level}:${NC}${color} ${message}${NC}"
}

log_info() {
    log_with_style "INFO" "$1" "$ICON_INFO" "$BLUE"
}

log_success() {
    log_with_style "SUCCESS" "$1" "$ICON_SUCCESS" "$GREEN" "$BG_SUCCESS"
}

log_warning() {
    log_with_style "WARNING" "$1" "$ICON_WARNING" "$YELLOW" "$BG_WARNING"
}

log_error() {
    log_with_style "ERROR" "$1" "$ICON_ERROR" "$RED" "$BG_ERROR"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        log_with_style "DEBUG" "$1" "$ICON_DEBUG" "$PURPLE"
    fi
}

log_step() {
    local step_num="$1"
    local total_steps="$2"
    local message="$3"
    
    echo ""
    create_separator "═" 80 "$CYAN"
    echo -e "${CYAN}${BOLD}${ICON_ARROW} Passo ${step_num}/${total_steps}: ${WHITE}${message}${NC}"
    create_separator "─" 80 "$BLUE"
}

log_header() {
    local title="$1"
    echo ""
    create_box "$title" 80 "$CYAN"
    echo ""
}

log_subheader() {
    local title="$1"
    echo ""
    echo -e "${BLUE}${BOLD}┌─ ${title} ─┐${NC}"
}

show_system_info() {
    local cores="$1"
    local memory="$2"
    local profile="$3"
    
    echo -e "${CYAN}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}${BOLD}│                    ⚙️ INFORMAÇÕES DO SISTEMA                    │${NC}"
    echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│ ⚙️ CPUs Detectadas:    ${GREEN}${BOLD}${cores} cores${NC}${CYAN}                          │${NC}"
    echo -e "${CYAN}│ ⚙️ Memória Disponível: ${GREEN}${BOLD}${memory} MB${NC}${CYAN}                         │${NC}"
    echo -e "${CYAN}│ ⭐ Perfil Selecionado: ${YELLOW}${BOLD}${profile}${NC}${CYAN}                            │${NC}"
    echo -e "${CYAN}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}"
}

show_deployment_config() {
    local cluster_name="$1"
    local host_port="$2"
    local web_replicas="$3"
    local task_replicas="$4"
    
    echo -e "${PURPLE}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}${BOLD}│                 🚀 CONFIGURAÇÃO DE DEPLOYMENT               │${NC}"
    echo -e "${PURPLE}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${PURPLE}│ ⚙️ Nome do Cluster:   ${CYAN}${BOLD}${cluster_name}${NC}${PURPLE}                     │${NC}"
    echo -e "${PURPLE}│ ⚙️ Porta de Acesso:   ${CYAN}${BOLD}${host_port}${NC}${PURPLE}                             │${NC}"
    echo -e "${PURPLE}│ ⚙️ Réplicas Web:      ${CYAN}${BOLD}${web_replicas}${NC}${PURPLE}                               │${NC}"
    echo -e "${PURPLE}│ ⚙️ Réplicas Task:     ${CYAN}${BOLD}${task_replicas}${NC}${PURPLE}                              │${NC}"
    echo -e "${PURPLE}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}"
}

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                    SISTEMA DE MONITORAMENTO AVANÇADO                       │
# └─────────────────────────────────────────────────────────────────────────────┘

monitor_installation_progress() {
    local component="$1"
    local namespace="$2"
    local timeout="${3:-300}"
    
    log_subheader "Monitorando instalação de ${component}"
    
    local elapsed=0
    local spinner_pid
    
    (while true; do
        for char in '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'; do
            printf "\r${BLUE}${char} Aguardando ${component}...${NC}"
            sleep 0.1
        done
    done) &
    spinner_pid=$!
    
    while [ $elapsed -lt $timeout ]; do
        local ready_pods=$(kubectl get pods -n "$namespace" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        local total_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
        
        if [ "$ready_pods" -gt 0 ] && [ "$ready_pods" -eq "$total_pods" ]; then
            kill $spinner_pid 2>/dev/null
            printf "\r${GREEN}✅ ${component} instalado com sucesso! (${ready_pods}/${total_pods} pods prontos)${NC}\n"
            return 0
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    kill $spinner_pid 2>/dev/null
    printf "\r${RED}❌ Timeout na instalação de ${component}${NC}\n"
    return 1
}

show_cluster_status() {
    local cluster_name="$1"
    
    log_header "STATUS DO CLUSTER ${cluster_name}"
    
    echo -e "${BLUE}${BOLD}┌─ Nós do Cluster ─┐${NC}"
    kubectl get nodes -o wide --no-headers | while read line; do
        local node_name=$(echo $line | awk '{print $1}')
        local status=$(echo $line | awk '{print $2}')
        local role=$(echo $line | awk '{print $3}')
        
        if [ "$status" = "Ready" ]; then
            echo -e "  ${GREEN}✓ ${node_name}${NC} ${CYAN}(${role})${NC}"
        else
            echo -e "  ${RED}✗ ${node_name}${NC} ${YELLOW}(${status})${NC}"
        fi
    done
    
    echo ""
    echo -e "${BLUE}${BOLD}┌─ Recursos do Sistema ─┐${NC}"
    local cpu_usage=$(kubectl top nodes --no-headers 2>/dev/null | awk '{sum+=$3} END {print sum "%"}' || echo "N/A")
    local mem_usage=$(kubectl top nodes --no-headers 2>/dev/null | awk '{sum+=$5} END {print sum "%"}' || echo "N/A")
    
    echo -e "  ${CYAN}CPU:${NC} ${cpu_usage}"
    echo -e "  ${CYAN}Memória:${NC} ${mem_usage}"
}

validate_prerequisites() {
    log_header "VALIDAÇÃO DE PRÉ-REQUISITOS"
    
    local requirements=(
        "docker:Docker"
        "kind:Kind"
        "kubectl:Kubectl"
        "helm:Helm"
        "python3:Python 3"
    )
    
    local missing_count=0
    
    for req in "${requirements[@]}"; do
        local cmd=$(echo $req | cut -d: -f1)
        local name=$(echo $req | cut -d: -f2)
        
        if command -v "$cmd" &>/dev/null; then
            local version=$(get_version "$cmd")
            echo -e "  ${GREEN}✓ ${name}${NC} ${DIM}(${version})${NC}"
        else
            echo -e "  ${RED}✗ ${name}${NC} ${YELLOW}(não instalado)${NC}"
            ((missing_count++))
        fi
    done
    
    if [ $missing_count -gt 0 ]; then
        echo ""
        log_warning "Encontrados $missing_count pré-requisitos ausentes. Iniciando instalação automática..."
        return 1
    else
        echo ""
        log_success "Todos os pré-requisitos estão instalados!"
        return 0
    fi
}

get_version() {
    case "$1" in
        docker) docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo "unknown" ;;
        kind) kind version 2>/dev/null | grep -o 'v[0-9.]*' | head -1 || echo "unknown" ;;
        kubectl) kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown" ;;
        helm) helm version --short 2>/dev/null | cut -d' ' -f1 || echo "unknown" ;;
        python3) python3 --version 2>/dev/null | cut -d' ' -f2 || echo "unknown" ;;
        *) echo "unknown" ;;
    esac
}

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                       SISTEMA DE AJUDA AVANÇADO                            │
# └─────────────────────────────────────────────────────────────────────────────┘

show_interactive_help() {
    clear
    show_banner
    
    echo -e "${CYAN}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}${BOLD}│                      ℹ️ GUIA DE USO                         │${NC}"
    echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│ Uso Básico: ${YELLOW}$0 [OPÇÕES]${NC}${CYAN}                                │${NC}"
    echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    
    local options=(
        "-c:Nome do cluster Kind:awx-cluster-${PERFIL:-auto}"
        "-p:Porta de acesso ao AWX:${DEFAULT_HOST_PORT}"
        "-f:Forçar número de CPUs:auto-detectar"
        "-m:Forçar quantidade de memória (MB):auto-detectar"
        "-d:Instalar apenas dependências:não"
        "-v:Modo verboso (debug):não"
        "-h:Exibir esta ajuda:N/A"
    )
    
    for option in "${options[@]}"; do
        local flag=$(echo $option | cut -d: -f1)
        local desc=$(echo $option | cut -d: -f2)
        local default=$(echo $option | cut -d: -f3)
        
        echo -e "${CYAN}│ ${GREEN}${flag}${NC}${CYAN} │ ${desc}${NC}"
        echo -e "${CYAN}│     ${DIM}Padrão: ${default}${NC}${CYAN}                                    │${NC}"
    done
    
    echo -e "${CYAN}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}"
    
    show_system_requirements
    show_access_information
}

show_system_requirements() {
    echo -e "${PURPLE}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}${BOLD}│                   🛡️ REQUISITOS DO SISTEMA                   │${NC}"
    echo -e "${PURPLE}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${PURPLE}│ Sistema Operacional: Ubuntu 20.04+/Debian 11+                     │${NC}"
    echo -e "${PURPLE}│ Desenvolvimento: 2 CPUs, 4GB RAM, 20GB SSD                        │${NC}"
    echo -e "${PURPLE}│ Produção: 4+ CPUs, 8GB+ RAM, 50GB+ SSD                            │${NC}"
    echo -e "${PURPLE}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}"
}

show_access_information() {
    echo -e "${GREEN}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${GREEN}${BOLD}│                    🔑 INFORMAÇÕES DE ACESSO                  │${NC}"
    echo -e "${GREEN}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${GREEN}│ URL: http://localhost:PORTA                                        │${NC}"
    echo -e "${GREEN}│ Usuário: admin                                                     │${NC}"
    echo -e "${GREEN}│ Senha: (exibida no final)                                          │${NC}"
    echo -e "${GREEN}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}"
}

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                   DETECÇÃO DE CAPACIDADES DO TERMINAL                      │
# └─────────────────────────────────────────────────────────────────────────────┘

detect_terminal_capabilities() {
    export USE_UNICODE_ICONS=true
    export USE_BOX_DRAWING=true
    
    if [[ "$LANG" != *"UTF-8"* ]] || [[ "$TERM" != *"xterm"* ]]; then
        export USE_UNICODE_ICONS=false
        export USE_BOX_DRAWING=false
    fi
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                            LÓGICA PRINCIPAL                                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

install_dependencies() {
    log_step 1 7 "Instalando dependências do sistema"
    
    local packages=(
        "docker.io docker docker-compose-plugin"
        "curl"
        "python3-pip"
        "git"
        "make"
        "gcc"
    )
    
    for pkg in "${packages[@]}"; do
        log_info "Instalando pacote: ${pkg%% *}"
        apt-get install -y $pkg > /dev/null 2>&1 &
        show_spinner $! "Instalando ${pkg%% *}"
    done
}

create_kind_cluster() {
    local cluster_name="$1"
    local host_port="$2"
    
    log_step 2 7 "Criando cluster Kind"
    
    cat <<EOF | kind create cluster --name "$cluster_name" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: $host_port
    protocol: TCP
EOF
}

deploy_registry() {
    log_step 3 7 "Configurando registro local"
    
    docker run -d --name "$REGISTRY_NAME" --restart=always -p "$DEFAULT_REGISTRY_PORT":5000 registry:2 > /dev/null &
    show_spinner $! "Iniciando registro Docker"
}

build_cluster() {
    local cluster_name="$1"
    
    log_step 4 7 "Construindo ambiente Kubernetes"
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml > /dev/null &
    show_spinner $! "Instalando Ingress Controller"
    
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s > /dev/null
}

deploy_awx() {
    log_step 5 7 "Implantando AWX"
    
    git clone https://github.com/ansible/awx-operator.git > /dev/null &
    show_spinner $! "Clonando repositório AWX Operator"
    
    local AWX_OPERATOR_DIR="awx-operator"
    local AWX_OPERATOR_TAG=$(git describe --tags $(git rev-list --tags --max-count=1))
    git checkout "$AWX_OPERATOR_TAG" > /dev/null
    
    kubectl create namespace "$AWX_NAMESPACE" > /dev/null
    kubectl config set-context --current --namespace="$AWX_NAMESPACE" > /dev/null
    
    make deploy > /dev/null &
    show_spinner $! "Compilando operador AWX"
}

retrieve_credentials() {
    log_step 6 7 "Obtendo credenciais"
    
    local admin_password=$(kubectl get secret awx-admin-password -o jsonpath='{.data.password}' | base64 --decode)
    
    echo ""
    create_box "CREDENCIAIS DE ACESSO" 60 "$GREEN"
    echo -e "${CYAN}URL:${NC} http://localhost:$DEFAULT_HOST_PORT"
    echo -e "${CYAN}Usuário:${NC} admin"
    echo -e "${CYAN}Senha:${NC} ${admin_password}"
    create_box "" 60 "$GREEN"
}

main() {
    detect_terminal_capabilities
    show_banner
    
    local CLUSTER_NAME="awx-cluster"
    local HOST_PORT="$DEFAULT_HOST_PORT"
    
    while getopts "c:p:f:m:dvh" opt; do
        case $opt in
            c) CLUSTER_NAME="$OPTARG" ;;
            p) HOST_PORT="$OPTARG" ;;
            d) install_dependencies; exit 0 ;;
            v) VERBOSE=true ;;
            h) show_interactive_help; exit 0 ;;
            *) log_error "Opção inválida"; exit 1 ;;
        esac
    done
    
    if ! validate_prerequisites; then
        install_dependencies
    fi
    
    create_kind_cluster "$CLUSTER_NAME" "$HOST_PORT"
    deploy_registry
    build_cluster "$CLUSTER_NAME"
    deploy_awx
    monitor_installation_progress "AWX" "$AWX_NAMESPACE" "$AWX_TIMEOUT"
    show_cluster_status "$CLUSTER_NAME"
    retrieve_credentials
    
    log_success "Implantação do AWX concluída com sucesso!"
}

main "$@"
