#!/bin/bash
set -e

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

# Função para criar caixas decorativas
create_box() {
    local title="$1"
    local width="${2:-80}"
    local color="${3:-$CYAN}"
    
    local top_line="╔$(printf '═%.0s' $(seq 1 $((width-2))))╗"
    local bottom_line="╚$(printf '═%.0s' $(seq 1 $((width-2))))╝"
    local title_padding=$(( (width - ${#title} - 4) / 2 ))
    local title_line="║$(printf ' %.0s' $(seq 1 $title_padding)) ${title} $(printf ' %.0s' $(seq 1 $title_padding))║"
    
    echo -e "${color}${top_line}${NC}"
    echo -e "${color}${title_line}${NC}"
    echo -e "${color}${bottom_line}${NC}"
}

# Função para criar separadores estilizados
create_separator() {
    local char="${1:-─}"
    local width="${2:-80}"
    local color="${3:-$BLUE}"
    
    printf "${color}"
    printf "${char}%.0s" $(seq 1 $width)
    printf "${NC}\n"
}

# Função para exibir banner principal
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
   ║           ${FIRE} Script de Implantação AWX com Kubernetes Kind ${FIRE}               ║
   ║                      ${LIGHTNING} Versão Moderna e Aprimorada ${LIGHTNING}                       ║
   ╚═══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Spinner animado para operações longas
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
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b"
    done
    echo -e "${GREEN}${ICON_CHECKMARK} Concluído!${NC}"
}

# Barra de progresso avançada
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${CYAN}${BOLD}Progress:${NC} ["
    printf "${GREEN}${'#' * $completed}${NC}"
    printf "${DIM}${'.' * $remaining}${NC}"
    printf "] ${YELLOW}%d%%${NC} ${BLUE}(%d/%d)${NC}" "$percentage" "$current" "$total"
}

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                        FUNÇÕES DE LOG AVANÇADAS                            │
# └─────────────────────────────────────────────────────────────────────────────┘

# Sistema de log aprimorado com timestamps e ícones
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

# Função para exibir informações do sistema de forma estilizada
show_system_info() {
    local cores="$1"
    local memory="$2"
    local profile="$3"
    
    echo -e "${CYAN}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}${BOLD}│                    ${GEAR} INFORMAÇÕES DO SISTEMA                    │${NC}"
    echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│ ${ICON_GEAR} CPUs Detectadas:    ${GREEN}${BOLD}${cores} cores${NC}${CYAN}                          │${NC}"
    echo -e "${CYAN}│ ${ICON_GEAR} Memória Disponível: ${GREEN}${BOLD}${memory} MB${NC}${CYAN}                         │${NC}"
    echo -e "${CYAN}│ ${ICON_STAR} Perfil Selecionado: ${YELLOW}${BOLD}${profile}${NC}${CYAN}                            │${NC}"
    echo -e "${CYAN}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}"
}

# Função para exibir configurações de deployment
show_deployment_config() {
    local cluster_name="$1"
    local host_port="$2"
    local web_replicas="$3"
    local task_replicas="$4"
    
    echo -e "${PURPLE}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}${BOLD}│                 ${ROCKET} CONFIGURAÇÃO DE DEPLOYMENT               │${NC}"
    echo -e "${PURPLE}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${PURPLE}│ ${ICON_GEAR} Nome do Cluster:   ${CYAN}${BOLD}${cluster_name}${NC}${PURPLE}                     │${NC}"
    echo -e "${PURPLE}│ ${ICON_GEAR} Porta de Acesso:   ${CYAN}${BOLD}${host_port}${NC}${PURPLE}                             │${NC}"
    echo -e "${PURPLE}│ ${ICON_GEAR} Réplicas Web:      ${CYAN}${BOLD}${web_replicas}${NC}${PURPLE}                               │${NC}"
    echo -e "${PURPLE}│ ${ICON_GEAR} Réplicas Task:     ${CYAN}${BOLD}${task_replicas}${NC}${PURPLE}                              │${NC}"
    echo -e "${PURPLE}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}"
}


# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                    SISTEMA DE MONITORAMENTO AVANÇADO                       │
# └─────────────────────────────────────────────────────────────────────────────┘

# Função para monitorar progresso de instalação com feedback visual
monitor_installation_progress() {
    local component="$1"
    local namespace="$2"
    local timeout="${3:-300}"
    
    log_subheader "Monitorando instalação de ${component}"
    
    local elapsed=0
    local spinner_pid
    
    # Iniciar spinner em background
    (while true; do
        for char in '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'; do
            printf "\r${BLUE}${char} Aguardando ${component}...${NC}"
            sleep 0.1
        done
    done) &
    spinner_pid=$!
    
    # Monitorar pods
    while [ $elapsed -lt $timeout ]; do
        local ready_pods=$(kubectl get pods -n "$namespace" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        local total_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
        
        if [ "$ready_pods" -gt 0 ] && [ "$ready_pods" -eq "$total_pods" ]; then
            kill $spinner_pid 2>/dev/null || true
            printf "\r${GREEN}${ICON_SUCCESS} ${component} instalado com sucesso! (${ready_pods}/${total_pods} pods prontos)${NC}\n"
            return 0
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    kill $spinner_pid 2>/dev/null || true
    printf "\r${RED}${ICON_ERROR} Timeout na instalação de ${component}${NC}\n"
    return 1
}

# Função para exibir status detalhado do cluster
show_cluster_status() {
    local cluster_name="$1"
    
    log_header "STATUS DO CLUSTER ${cluster_name}"
    
    echo -e "${BLUE}${BOLD}┌─ Nós do Cluster ─┐${NC}"
    kubectl get nodes -o wide --no-headers | while read line; do
        local node_name=$(echo $line | awk '{print $1}')
        local status=$(echo $line | awk '{print $2}')
        local role=$(echo $line | awk '{print $3}')
        
        if [ "$status" = "Ready" ]; then
            echo -e "  ${GREEN}${ICON_CHECKMARK} ${node_name}${NC} ${CYAN}(${role})${NC}"
        else
            echo -e "  ${RED}${ICON_CROSS} ${node_name}${NC} ${YELLOW}(${status})${NC}"
        fi
    done
    
    echo ""
    echo -e "${BLUE}${BOLD}┌─ Recursos do Sistema ─┐${NC}"
    local cpu_usage=$(kubectl top nodes --no-headers 2>/dev/null | awk '{sum+=$3} END {print sum "%"}' || echo "N/A")
    local mem_usage=$(kubectl top nodes --no-headers 2>/dev/null | awk '{sum+=$5} END {print sum "%"}' || echo "N/A")
    
    echo -e "  ${CYAN}CPU:${NC} ${cpu_usage}"
    echo -e "  ${CYAN}Memória:${NC} ${mem_usage}"
}

# Função para validar e exibir pré-requisitos
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
        
        if command_exists "$cmd"; then
            local version=$(get_version "$cmd")
            echo -e "  ${GREEN}${ICON_CHECKMARK} ${name}${NC} ${DIM}(${version})${NC}"
        else
            echo -e "  ${RED}${ICON_CROSS} ${name}${NC} ${YELLOW}(não instalado)${NC}"
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

# Função auxiliar para obter versões
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
    echo -e "${CYAN}${BOLD}│                      ${ICON_INFO} GUIA DE USO                         │${NC}"
    echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│                                                             │${NC}"
    echo -e "${CYAN}│ ${GREEN}${BOLD}Uso Básico:${NC}${CYAN}                                             │${NC}"
    echo -e "${CYAN}│   ${YELLOW}$0${NC}${CYAN} [OPÇÕES]                                        │${NC}"
    echo -e "${CYAN}│                                                             │${NC}"
    echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│                     ${GEAR} OPÇÕES DISPONÍVEIS                    │${NC}"
    echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    
    local options=(
        "-c NOME:Nome do cluster Kind:awx-cluster-${PERFIL:-auto}"
        "-p PORTA:Porta de acesso ao AWX:${DEFAULT_HOST_PORT}"
        "-f CPU:Forçar número de CPUs:auto-detectar"
        "-m MEMORIA:Forçar quantidade de memória (MB):auto-detectar"
        "-d:Instalar apenas dependências:não"
        "-v:Modo verboso (debug):não"
        "-h:Exibir esta ajuda:N/A"
    )
    
    for option in "${options[@]}"; do
        local flag=$(echo $option | cut -d: -f1)
        local desc=$(echo $option | cut -d: -f2)
        local default=$(echo $option | cut -d: -f3)
        
        echo -e "${CYAN}│ ${GREEN}${BOLD}${flag}${NC}${CYAN} │ ${desc}${NC}"
        echo -e "${CYAN}│     ${DIM}Padrão: ${default}${NC}${CYAN}                                    │${NC}"
    done
    
    echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│                    ${ROCKET} EXEMPLOS DE USO                       │${NC}"
    echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│                                                             │${NC}"
    echo -e "${CYAN}│ ${GREEN}${BOLD}1.${NC}${CYAN} Instalação padrão:                                 │${NC}"
    echo -e "${CYAN}│    ${YELLOW}$0${NC}${CYAN}                                                   │${NC}"
    echo -e "${CYAN}│                                                             │${NC}"
    echo -e "${CYAN}│ ${GREEN}${BOLD}2.${NC}${CYAN} Cluster customizado na porta 8080:                │${NC}"
    echo -e "${CYAN}│    ${YELLOW}$0 -c meu-cluster -p 8080${NC}${CYAN}                           │${NC}"
    echo -e "${CYAN}│                                                             │${NC}"
    echo -e "${CYAN}│ ${GREEN}${BOLD}3.${NC}${CYAN} Forçar recursos específicos:                       │${NC}"
    echo -e "${CYAN}│    ${YELLOW}$0 -f 4 -m 8192${NC}${CYAN}                                     │${NC}"
    echo -e "${CYAN}│                                                             │${NC}"
    echo -e "${CYAN}│ ${GREEN}${BOLD}4.${NC}${CYAN} Apenas instalar dependências:                      │${NC}"
    echo -e "${CYAN}│    ${YELLOW}$0 -d${NC}${CYAN}                                                │${NC}"
    echo -e "${CYAN}│                                                             │${NC}"
    echo -e "${CYAN}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}"
    
    echo ""
    show_system_requirements
    show_access_information
}

show_system_requirements() {
    echo -e "${PURPLE}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}${BOLD}│                   ${SHIELD} REQUISITOS DO SISTEMA                   │${NC}"
    echo -e "${PURPLE}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${PURPLE}│                                                             │${NC}"
    echo -e "${PURPLE}│ ${GREEN}${BOLD}Sistema Operacional:${NC}${PURPLE}                               │${NC}"
    echo -e "${PURPLE}│   ${CYAN}• Ubuntu 20.04+ (recomendado)${NC}${PURPLE}                       │${NC}"
    echo -e "${PURPLE}│   ${CYAN}• Debian 11+ (suportado)${NC}${PURPLE}                            │${NC}"
    echo -e "${PURPLE}│                                                             │${NC}"
    echo -e "${PURPLE}│ ${GREEN}${BOLD}Recursos Mínimos (Desenvolvimento):${NC}${PURPLE}                │${NC}"
    echo -e "${PURPLE}│   ${CYAN}• CPU: 2 cores${NC}${PURPLE}                                      │${NC}"
    echo -e "${PURPLE}│   ${CYAN}• Memória: 4 GB RAM${NC}${PURPLE}                                │${NC}"
    echo -e "${PURPLE}│   ${CYAN}• Armazenamento: 20 GB livres${NC}${PURPLE}                      │${NC}"
    echo -e "${PURPLE}│                                                             │${NC}"
    echo -e "${PURPLE}│ ${GREEN}${BOLD}Recursos Recomendados (Produção):${NC}${PURPLE}                  │${NC}"
    echo -e "${PURPLE}│   ${CYAN}• CPU: 4+ cores${NC}${PURPLE}                                    │${NC}"
    echo -e "${PURPLE}│   ${CYAN}• Memória: 8+ GB RAM${NC}${PURPLE}                              │${NC}"
    echo -e "${PURPLE}│   ${CYAN}• Armazenamento: 50+ GB livres${NC}${PURPLE}                    │${NC}"
    echo -e "${PURPLE}│                                                             │${NC}"
    echo -e "${PURPLE}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}"
}

show_access_information() {
    echo -e "${GREEN}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${GREEN}${BOLD}│                    ${KEY} INFORMAÇÕES DE ACESSO                    │${NC}"
    echo -e "${GREEN}${BOLD}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${GREEN}│                                                             │${NC}"
    echo -e "${GREEN}│ ${YELLOW}${BOLD}Após a instalação:${NC}${GREEN}                                │${NC}"
    echo -e "${GREEN}│                                                             │${NC}"
    echo -e "${GREEN}│ ${CYAN}• URL:${NC}${GREEN} http://localhost:PORTA                           │${NC}"
    echo -e "${GREEN}│ ${CYAN}• Usuário:${NC}${GREEN} admin                                       │${NC}"
    echo -e "${GREEN}│ ${CYAN}• Senha:${NC}${GREEN} (será exibida no final)                      │${NC}"
    echo -e "${GREEN}│                                                             │${NC}"
    echo -e "${GREEN}│ ${YELLOW}${BOLD}Comandos úteis:${NC}${GREEN}                                    │${NC}"
    echo -e "${GREEN}│                                                             │${NC}"
    echo -e "${GREEN}│ ${CYAN}• Ver pods:${NC}${GREEN}                                           │${NC}"
    echo -e "${GREEN}│   ${DIM}kubectl get pods -n awx${NC}${GREEN}                            │${NC}"
    echo -e "${GREEN}│                                                             │${NC}"
    echo -e "${GREEN}│ ${CYAN}• Ver logs:${NC}${GREEN}                                           │${NC}"
    echo -e "${GREEN}│   ${DIM}kubectl logs -n awx deployment/awx-web${NC}${GREEN}             │${NC}"
    echo -e "${GREEN}│                                                             │${NC}"
    echo -e "${GREEN}│ ${CYAN}• Deletar cluster:${NC}${GREEN}                                    │${NC}"
    echo -e "${GREEN}│   ${DIM}kind delete cluster --name CLUSTER_NAME${NC}${GREEN}            │${NC}"
    echo -e "${GREEN}│                                                             │${NC}"
    echo -e "${GREEN}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}"
}

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                   DETECÇÃO DE CAPACIDADES DO TERMINAL                      │
# └─────────────────────────────────────────────────────────────────────────────┘

detect_terminal_capabilities() {
    # Detectar suporte a cores
    local color_support="basic"
    if [[ "$TERM" =~ 256color ]] || [[ "$COLORTERM" =~ (truecolor|24bit) ]]; then
        color_support="256"
    elif [[ "$COLORTERM" =~ (truecolor|24bit) ]]; then
        color_support="truecolor"
    fi
    
    # Detectar suporte a Unicode
    local unicode_support=false
    if [[ "$LANG" =~ UTF-8 ]] || [[ "$LC_ALL" =~ UTF-8 ]] || [[ "$LC_CTYPE" =~ UTF-8 ]]; then
        unicode_support=true
    fi
    
    # Detectar largura do terminal
    local terminal_width=$(tput cols 2>/dev/null || echo "80")
    
    # Definir configurações globais baseadas nas capacidades
    if [ "$unicode_support" = true ]; then
        USE_UNICODE_ICONS=true
        USE_BOX_DRAWING=true
    else
        USE_UNICODE_ICONS=false
        USE_BOX_DRAWING=false
        # Fallback para caracteres ASCII
        ICON_SUCCESS="[OK]"
        ICON_ERROR="[ERR]"
        ICON_WARNING="[WARN]"
        ICON_INFO="[INFO]"
    fi
    
    # Ajustar paleta de cores baseada no suporte
    if [ "$color_support" = "basic" ]; then
        # Usar apenas cores básicas ANSI
        RED='\033[31m'
        GREEN='\033[32m'
        YELLOW='\033[33m'
        BLUE='\033[34m'
        PURPLE='\033[35m'
        CYAN='\033[36m'
        WHITE='\033[37m'
    fi
    
    TERMINAL_WIDTH="$terminal_width"
    export USE_UNICODE_ICONS USE_BOX_DRAWING TERMINAL_WIDTH
}
