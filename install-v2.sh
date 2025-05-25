#!/bin/bash
set -e

# ============================
# CONFIGURAÇÕES AVANÇADAS DE UX
# ============================

# Configurações de interface
ENABLE_COLORS=true
ENABLE_ANIMATIONS=true
ENABLE_SOUNDS=false
PROGRESS_BAR_WIDTH=50
ANIMATION_SPEED=0.1

# Caracteres especiais para interface
readonly CHECKMARK="✓"
readonly CROSSMARK="✗"
readonly ARROW="→"
readonly WARNING="⚠"
readonly INFO="ℹ"
readonly GEAR="⚙"
readonly ROCKET="🚀"
readonly COMPUTER="💻"
readonly WRENCH="🔧"
readonly PACKAGE="📦"
readonly DOWNLOAD="⬇"
readonly UPLOAD="⬆"
readonly HOURGLASS="⏳"
readonly SUCCESS="🎉"

# Cores avançadas
if [[ $ENABLE_COLORS == true ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly PURPLE='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly WHITE='\033[1;37m'
    readonly GRAY='\033[0;90m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly UNDERLINE='\033[4m'
    readonly BLINK='\033[5m'
    readonly REVERSE='\033[7m'
    readonly NC='\033[0m'
    
    # Cores de fundo
    readonly BG_RED='\033[41m'
    readonly BG_GREEN='\033[42m'
    readonly BG_YELLOW='\033[43m'
    readonly BG_BLUE='\033[44m'
    readonly BG_PURPLE='\033[45m'
    readonly BG_CYAN='\033[46m'
    readonly BG_WHITE='\033[47m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly PURPLE=''
    readonly CYAN=''
    readonly WHITE=''
    readonly GRAY=''
    readonly BOLD=''
    readonly DIM=''
    readonly UNDERLINE=''
    readonly BLINK=''
    readonly REVERSE=''
    readonly NC=''
    readonly BG_RED=''
    readonly BG_GREEN=''
    readonly BG_YELLOW=''
    readonly BG_BLUE=''
    readonly BG_PURPLE=''
    readonly BG_CYAN=''
    readonly BG_WHITE=''
fi

# ============================
# FUNÇÕES DE INTERFACE AVANÇADA
# ============================

# Spinner animado para operações longas
show_spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    echo -n "${BLUE}${HOURGLASS} ${message}${NC} "
    
    while kill -0 $pid 2>/dev/null; do
        if [[ $ENABLE_ANIMATIONS == true ]]; then
            i=$(( (i+1) %10 ))
            printf "\b${YELLOW}${spin:$i:1}${NC}"
            sleep $ANIMATION_SPEED
        else
            printf "."
            sleep 0.5
        fi
    done
    
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "\b${GREEN}${CHECKMARK}${NC}\n"
    else
        printf "\b${RED}${CROSSMARK}${NC}\n"
    fi
    
    return $exit_code
}

# Barra de progresso avançada
show_progress_bar() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    local filled=$((current * PROGRESS_BAR_WIDTH / total))
    local empty=$((PROGRESS_BAR_WIDTH - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done
    
    printf "\r${BLUE}${message}${NC} [${GREEN}${bar}${NC}] ${BOLD}${percent}%%${NC} (${current}/${total})"
    
    if [ $current -eq $total ]; then
        echo -e " ${GREEN}${CHECKMARK}${NC}"
    fi
}

# Box decorativo para mensagens importantes
draw_box() {
    local message="$1"
    local color="${2:-$CYAN}"
    local width=$(( ${#message} + 4 ))
    
    echo -e "${color}╭$(printf '─%.0s' $(seq 1 $((width-2))))╮${NC}"
    echo -e "${color}│ ${BOLD}${message}${NC}${color} │${NC}"
    echo -e "${color}╰$(printf '─%.0s' $(seq 1 $((width-2))))╯${NC}"
}

# Banner principal do sistema
show_banner() {
    clear
    echo -e "${BOLD}${BLUE}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════════════╗
    ║                                                                      ║
    ║      █████╗ ██╗    ██╗██╗  ██╗    ██████╗ ███████╗██████╗ ██╗      ██╗║
    ║     ██╔══██╗██║    ██║╚██╗██╔╝    ██╔══██╗██╔════╝██╔══██╗██║     ██╔╝║
    ║     ███████║██║ █╗ ██║ ╚███╔╝     ██║  ██║█████╗  ██████╔╝██║    ██╔╝ ║
    ║     ██╔══██║██║███╗██║ ██╔██╗     ██║  ██║██╔══╝  ██╔═══╝ ██║   ██╔╝  ║
    ║     ██║  ██║╚███╔███╔╝██╔╝ ██╗    ██████╔╝███████╗██║     ███████╔╝   ║
    ║     ╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═╝    ╚═════╝ ╚══════╝╚═╝     ╚══════╝    ║
    ║                                                                      ║
    ║              🚀 Sistema Avançado de Implantação AWX 🚀              ║
    ║                                                                      ║
    ╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${GRAY}${DIM}                        Versão 2.0 - Interface Moderna${NC}"
    echo
}

# Menu principal interativo
show_main_menu() {
    while true; do
        show_banner
        
        echo -e "${BOLD}${CYAN}🎯 Escolha o modo de operação:${NC}\n"
        
        PS3="${BLUE}${ARROW} Digite sua escolha (1-4): ${NC}"
        
        local options=(
            "${ROCKET} Detecção Automática Completa (Recomendado)"
            "${WRENCH} Configuração Manual Assistida"
            "${GEAR} Modo Avançado (Especialistas)"
            "${CROSSMARK} Sair"
        )
        
        select opt in "${options[@]}"; do
            case $REPLY in
                1)
                    echo -e "\n${GREEN}${CHECKMARK} Modo automático selecionado${NC}"
                    AUTO_MODE=true
                    MANUAL_MODE=false
                    return 0
                    ;;
                2)
                    echo -e "\n${YELLOW}${WRENCH} Modo manual selecionado${NC}"
                    AUTO_MODE=false
                    MANUAL_MODE=true
                    return 0
                    ;;
                3)
                    echo -e "\n${PURPLE}${GEAR} Modo avançado selecionado${NC}"
                    AUTO_MODE=false
                    MANUAL_MODE=false
                    show_advanced_menu
                    return $?
                    ;;
                4)
                    echo -e "\n${RED}${CROSSMARK} Saindo...${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "\n${RED}${WARNING} Opção inválida. Tente novamente.${NC}\n"
                    sleep 1
                    break
                    ;;
            esac
        done
    done
}

# Menu avançado para especialistas
show_advanced_menu() {
    while true; do
        clear
        draw_box "CONFIGURAÇÕES AVANÇADAS" "$PURPLE"
        echo
        
        PS3="${PURPLE}${ARROW} Escolha uma opção: ${NC}"
        
        local advanced_options=(
            "${DOWNLOAD} Instalar apenas dependências"
            "${COMPUTER} Forçar recursos específicos"
            "${PACKAGE} Configurar registry personalizado"
            "${WRENCH} Configurações de cluster personalizadas"
            "${ARROW} Voltar ao menu principal"
        )
        
        select opt in "${advanced_options[@]}"; do
            case $REPLY in
                1)
                    echo -e "\n${BLUE}${INFO} Instalando apenas dependências...${NC}"
                    INSTALL_DEPS_ONLY=true
                    return 0
                    ;;
                2)
                    configure_resources_manually
                    return 0
                    ;;
                3)
                    configure_custom_registry
                    return 0
                    ;;
                4)
                    configure_cluster_settings
                    return 0
                    ;;
                5)
                    return 1
                    ;;
                *)
                    echo -e "\n${RED}${WARNING} Opção inválida.${NC}"
                    sleep 1
                    break
                    ;;
            esac
        done
    done
}

# Configuração manual de recursos
configure_resources_manually() {
    clear
    draw_box "CONFIGURAÇÃO MANUAL DE RECURSOS" "$YELLOW"
    echo
    
    # CPU Configuration
    while true; do
        echo -e "${COMPUTER} ${BOLD}Configuração de CPU:${NC}"
        echo -e "${GRAY}CPUs detectadas automaticamente: ${GREEN}$(nproc --all)${NC}"
        echo -ne "${BLUE}Digite o número de CPUs para usar (1-64) ou Enter para auto: ${NC}"
        read -r cpu_input
        
        if [[ -z "$cpu_input" ]]; then
            echo -e "${GREEN}${CHECKMARK} Usando detecção automática de CPU${NC}"
            break
        elif validate_cpu "$cpu_input"; then
            FORCE_CPU="$cpu_input"
            echo -e "${GREEN}${CHECKMARK} CPU configurada para: ${BOLD}$cpu_input${NC}"
            break
        else
            echo -e "${RED}${CROSSMARK} Valor inválido. Tente novamente.${NC}\n"
        fi
    done
    
    echo
    
    # Memory Configuration
    while true; do
        echo -e "${COMPUTER} ${BOLD}Configuração de Memória:${NC}"
        local auto_mem=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
        echo -e "${GRAY}Memória detectada automaticamente: ${GREEN}${auto_mem}MB${NC}"
        echo -ne "${BLUE}Digite a quantidade de memória em MB (512-131072) ou Enter para auto: ${NC}"
        read -r mem_input
        
        if [[ -z "$mem_input" ]]; then
            echo -e "${GREEN}${CHECKMARK} Usando detecção automática de memória${NC}"
            break
        elif validate_memory "$mem_input"; then
            FORCE_MEM_MB="$mem_input"
            echo -e "${GREEN}${CHECKMARK} Memória configurada para: ${BOLD}${mem_input}MB${NC}"
            break
        else
            echo -e "${RED}${CROSSMARK} Valor inválido. Tente novamente.${NC}\n"
        fi
    done
    
    echo
    
    # Port Configuration
    while true; do
        echo -e "${COMPUTER} ${BOLD}Configuração de Porta:${NC}"
        echo -e "${GRAY}Porta padrão: ${GREEN}8080${NC}"
        echo -ne "${BLUE}Digite a porta para o AWX (1-65535) ou Enter para padrão: ${NC}"
        read -r port_input
        
        if [[ -z "$port_input" ]]; then
            HOST_PORT=8080
            echo -e "${GREEN}${CHECKMARK} Usando porta padrão: ${BOLD}8080${NC}"
            break
        elif validate_port "$port_input"; then
            HOST_PORT="$port_input"
            echo -e "${GREEN}${CHECKMARK} Porta configurada para: ${BOLD}$port_input${NC}"
            break
        else
            echo -e "${RED}${CROSSMARK} Porta inválida. Tente novamente.${NC}\n"
        fi
    done
    
    echo
    
    # Cluster Name Configuration
    while true; do
        echo -e "${COMPUTER} ${BOLD}Nome do Cluster:${NC}"
        echo -ne "${BLUE}Digite o nome do cluster ou Enter para automático: ${NC}"
        read -r cluster_input
        
        if [[ -z "$cluster_input" ]]; then
            echo -e "${GREEN}${CHECKMARK} Nome será gerado automaticamente${NC}"
            break
        elif [[ "$cluster_input" =~ ^[a-z0-9-]+$ ]]; then
            CLUSTER_NAME="$cluster_input"
            echo -e "${GREEN}${CHECKMARK} Cluster configurado: ${BOLD}$cluster_input${NC}"
            break
        else
            echo -e "${RED}${CROSSMARK} Nome inválido. Use apenas letras minúsculas, números e hífens.${NC}\n"
        fi
    done
    
    echo
    echo -e "${GREEN}${SUCCESS} Configuração manual concluída!${NC}"
    echo -e "${BLUE}Pressione Enter para continuar...${NC}"
    read -r
    
    AUTO_MODE=false
    MANUAL_MODE=true
}

# Configuração de registry personalizado
configure_custom_registry() {
    clear
    draw_box "CONFIGURAÇÃO DE REGISTRY PERSONALIZADO" "$CYAN"
    echo
    
    echo -e "${INFO} ${BOLD}Registry Docker Personalizado${NC}"
    echo -e "${GRAY}Deixe em branco para usar o registry local padrão (localhost:5001)${NC}"
    echo
    
    echo -ne "${BLUE}Registry URL: ${NC}"
    read -r registry_url
    
    if [[ -n "$registry_url" ]]; then
        CUSTOM_REGISTRY="$registry_url"
        echo -e "${GREEN}${CHECKMARK} Registry personalizado configurado: ${BOLD}$registry_url${NC}"
    else
        echo -e "${GREEN}${CHECKMARK} Usando registry local padrão${NC}"
    fi
    
    echo
    echo -e "${BLUE}Pressione Enter para continuar...${NC}"
    read -r
}

# Configuração de cluster personalizada
configure_cluster_settings() {
    clear
    draw_box "CONFIGURAÇÕES AVANÇADAS DO CLUSTER" "$PURPLE"
    echo
    
    echo -e "${GEAR} ${BOLD}Configurações do Kubernetes${NC}"
    echo
    
    # Número de nós worker
    while true; do
        echo -e "${BLUE}Número de nós worker (0-5): ${NC}"
        echo -e "${GRAY}0 = Apenas control-plane, 1-5 = Adicionar workers${NC}"
        echo -ne "${ARROW} "
        read -r worker_nodes
        
        if [[ "$worker_nodes" =~ ^[0-5]$ ]]; then
            WORKER_NODES="$worker_nodes"
            echo -e "${GREEN}${CHECKMARK} Configurado para $worker_nodes nó(s) worker${NC}"
            break
        else
            echo -e "${RED}${CROSSMARK} Número inválido. Use 0-5.${NC}\n"
        fi
    done
    
    echo
    
    # Versão do Kubernetes
    echo -e "${BLUE}Versão do Kubernetes (ou Enter para padrão):${NC}"
    echo -ne "${ARROW} "
    read -r k8s_version
    
    if [[ -n "$k8s_version" ]]; then
        K8S_VERSION="$k8s_version"
        echo -e "${GREEN}${CHECKMARK} Versão do Kubernetes: ${BOLD}$k8s_version${NC}"
    else
        echo -e "${GREEN}${CHECKMARK} Usando versão padrão do Kind${NC}"
    fi
    
    echo
    echo -e "${BLUE}Pressione Enter para continuar...${NC}"
    read -r
}

# Confirmação com detalhes da configuração
show_configuration_summary() {
    clear
    draw_box "RESUMO DA CONFIGURAÇÃO" "$GREEN"
    echo
    
    echo -e "${INFO} ${BOLD}Configurações que serão aplicadas:${NC}\n"
    
    if [[ $AUTO_MODE == true ]]; then
        echo -e "${COMPUTER} ${BOLD}Modo:${NC} Detecção Automática"
        echo -e "${COMPUTER} ${BOLD}CPUs:${NC} ${GREEN}$(detect_cores)${NC} (detectado)"
        echo -e "${COMPUTER} ${BOLD}Memória:${NC} ${GREEN}$(detect_mem_mb)MB${NC} (detectado)"
    else
        echo -e "${COMPUTER} ${BOLD}Modo:${NC} Configuração Manual"
        echo -e "${COMPUTER} ${BOLD}CPUs:${NC} ${GREEN}${FORCE_CPU:-$(detect_cores)}${NC}"
        echo -e "${COMPUTER} ${BOLD}Memória:${NC} ${GREEN}${FORCE_MEM_MB:-$(detect_mem_mb)}MB${NC}"
    fi
    
    echo -e "${COMPUTER} ${BOLD}Porta:${NC} ${GREEN}${HOST_PORT:-8080}${NC}"
    echo -e "${COMPUTER} ${BOLD}Cluster:${NC} ${GREEN}${CLUSTER_NAME:-"Auto-gerado"}${NC}"
    echo -e "${COMPUTER} ${BOLD}Namespace:${NC} ${GREEN}${AWX_NAMESPACE:-awx}${NC}"
    
    if [[ -n "$CUSTOM_REGISTRY" ]]; then
        echo -e "${COMPUTER} ${BOLD}Registry:${NC} ${GREEN}$CUSTOM_REGISTRY${NC}"
    fi
    
    if [[ -n "$WORKER_NODES" ]]; then
        echo -e "${COMPUTER} ${BOLD}Worker Nodes:${NC} ${GREEN}$WORKER_NODES${NC}"
    fi
    
    echo
    
    while true; do
        echo -e "${YELLOW}${WARNING} Deseja prosseguir com esta configuração? (s/N): ${NC}"
        read -r confirmation
        
        case "$confirmation" in
            [sS]|[sS][iI][mM])
                echo -e "${GREEN}${CHECKMARK} Confirmado! Iniciando instalação...${NC}"
                return 0
                ;;
            [nN]|[nN][aA][oO]|"")
                echo -e "${RED}${CROSSMARK} Instalação cancelada pelo usuário.${NC}"
                return 1
                ;;
            *)
                echo -e "${RED}${WARNING} Resposta inválida. Digite 's' para sim ou 'n' para não.${NC}\n"
                ;;
        esac
    done
}

# ============================
# FUNÇÕES DE LOG AVANÇADAS
# ============================

# Sistema de log com múltiplos níveis
log_with_level() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%H:%M:%S')
    
    case "$level" in
        "DEBUG")
            if [[ $VERBOSE == true ]]; then
                echo -e "${GRAY}[${timestamp}]${PURPLE}[DEBUG]${NC} ${DIM}${message}${NC}"
            fi
            ;;
        "INFO")
            echo -e "${GRAY}[${timestamp}]${BLUE}[INFO]${NC} ${message}"
            ;;
        "SUCCESS")
            echo -e "${GRAY}[${timestamp}]${GREEN}[SUCCESS]${NC} ${GREEN}${CHECKMARK} ${message}${NC}"
            ;;
        "WARNING")
            echo -e "${GRAY}[${timestamp}]${YELLOW}[WARNING]${NC} ${YELLOW}${WARNING} ${message}${NC}"
            ;;
        "ERROR")
            echo -e "${GRAY}[${timestamp}]${RED}[ERROR]${NC} ${RED}${CROSSMARK} ${message}${NC}"
            ;;
        "HEADER")
            echo
            echo -e "${CYAN}╭─$(printf '─%.0s' $(seq 1 ${#message}))─╮${NC}"
            echo -e "${CYAN}│ ${BOLD}${WHITE}${message}${NC}${CYAN} │${NC}"
            echo -e "${CYAN}╰─$(printf '─%.0s' $(seq 1 ${#message}))─╯${NC}"
            echo
            ;;
    esac
}

# Aliases para backward compatibility com funções originais
log_info() { log_with_level "INFO" "$1"; }
log_success() { log_with_level "SUCCESS" "$1"; }
log_warning() { log_with_level "WARNING" "$1"; }
log_error() { log_with_level "ERROR" "$1"; }
log_debug() { log_with_level "DEBUG" "$1"; }
log_header() { log_with_level "HEADER" "$1"; }

# ============================
# FUNÇÕES DE VALIDAÇÃO APRIMORADAS
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

# Função para validar porta com verificação de disponibilidade
validate_port() {
    if ! is_number "$1" || [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
        log_error "Porta inválida: $1. Use um valor entre 1 e 65535."
        return 1
    fi
    
    # Verificar se a porta está em uso
    if netstat -ln 2>/dev/null | grep -q ":$1 "; then
        log_warning "Porta $1 parece estar em uso. Deseja continuar? (s/N)"
        read -r continue_anyway
        if [[ ! "$continue_anyway" =~ ^[sS]$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

# Função para validar CPU
validate_cpu() {
    if ! is_number "$1" || [ "$1" -lt 1 ] || [ "$1" -gt 64 ]; then
        log_error "CPU inválida: $1. Use um valor entre 1 e 64."
        return 1
    fi
    
    local max_cpu=$(nproc --all)
    if [ "$1" -gt "$max_cpu" ]; then
        log_warning "CPU solicitada ($1) é maior que a disponível ($max_cpu). Continuar? (s/N)"
        read -r continue_anyway
        if [[ ! "$continue_anyway" =~ ^[sS]$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

# Função para validar memória
validate_memory() {
    if ! is_number "$1" || [ "$1" -lt 512 ] || [ "$1" -gt 131072 ]; then
        log_error "Memória inválida: $1. Use um valor entre 512 MB e 131072 MB (128 GB)."
        return 1
    fi
    
    local max_mem=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    if [ "$1" -gt "$max_mem" ]; then
        log_warning "Memória solicitada ($1 MB) é maior que a disponível ($max_mem MB). Continuar? (s/N)"
        read -r continue_anyway
        if [[ ! "$continue_anyway" =~ ^[sS]$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

# ============================
# DETECÇÃO DE RECURSOS (ORIGINAL)
# ============================

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

determine_profile() {
    local cores=$1
    local mem_mb=$2
    
    if [ "$cores" -ge 4 ] && [ "$mem_mb" -ge 8192 ]; then
        echo "prod"
    else
        echo "dev"
    fi
}

calculate_available_resources() {
    local total_cores=$1
    local total_mem_mb=$2
    local profile=$3
    
    local system_cpu_reserve=1
    local system_mem_reserve_mb=1024
    
    local available_cores=$((total_cores - system_cpu_reserve))
    local available_mem_mb=$((total_mem_mb - system_mem_reserve_mb))
    
    if [ "$profile" = "prod" ]; then
        NODE_CPU=$((available_cores * 70 / 100))
        NODE_MEM_MB=$((available_mem_mb * 70 / 100))
    else
        NODE_CPU=$((available_cores * 80 / 100))
        NODE_MEM_MB=$((available_mem_mb * 80 / 100))
    fi
    
    [ "$NODE_CPU" -lt 1 ] && NODE_CPU=1
    [ "$NODE_MEM_MB" -lt 512 ] && NODE_MEM_MB=512
    
    log_debug "Recursos totais: CPU=$total_cores, MEM=${total_mem_mb}MB"
    log_debug "Recursos sistema: CPU=$system_cpu_reserve, MEM=${system_mem_reserve_mb}MB"
    log_debug "Recursos disponíveis: CPU=$available_cores, MEM=${available_mem_mb}MB"
    log_debug "Recursos alocados: CPU=$NODE_CPU, MEM=${NODE_MEM_MB}MB"
}

calculate_replicas() {
    local profile=$1
    local cores=$2
    
    if [ "$profile" = "prod" ]; then
        WEB_REPLICAS=$((cores / 2))
        TASK_REPLICAS=$((cores / 2))
        [ "$WEB_REPLICAS" -lt 1 ] && WEB_REPLICAS=1
        [ "$TASK_REPLICAS" -lt 1 ] && TASK_REPLICAS=1
        [ "$WEB_REPLICAS" -gt 3 ] && WEB_REPLICAS=3
        [ "$TASK_REPLICAS" -gt 3 ] && TASK_REPLICAS=3
    else
        WEB_REPLICAS=1
        TASK_REPLICAS=1
    fi
}

initialize_resources() {
    CORES=$(detect_cores)
    MEM_MB=$(detect_mem_mb)
    PERFIL=$(determine_profile "$CORES" "$MEM_MB")
    calculate_replicas "$PERFIL" "$CORES"
    calculate_available_resources "$CORES" "$MEM_MB" "$PERFIL"
    log_debug "Recursos inicializados: PERFIL=$PERFIL, CORES=$CORES, MEM_MB=${MEM_MB}MB"
}

# ============================
# FUNÇÃO DE AJUDA APRIMORADA
# ============================

show_help() {
    clear
    show_banner
    
    cat << EOF
${WHITE}USO:${NC}
    $0 [OPÇÕES]

${WHITE}OPÇÕES:${NC}
    ${GREEN}-c NOME${NC}      Nome do cluster Kind
    ${GREEN}-p PORTA${NC}     Porta do host para acessar AWX (padrão: 8080)
    ${GREEN}-f CPU${NC}       Forçar número de CPUs
    ${GREEN}-m MEMORIA${NC}   Forçar quantidade de memória em MB
    ${GREEN}-d${NC}           Instalar apenas dependências
    ${GREEN}-v${NC}           Modo verboso (debug)
    ${GREEN}-s${NC}           Modo silencioso (automação)
    ${GREEN}-i${NC}           Modo interativo (padrão)
    ${GREEN}-h${NC}           Exibir esta ajuda

${WHITE}MODOS DE OPERAÇÃO:${NC}
    ${ROCKET} ${BOLD}Interativo${NC}     Interface moderna com menus (padrão)
    ${GEAR} ${BOLD}Automático${NC}      Detecção automática de recursos
    ${WRENCH} ${BOLD}Manual${NC}         Configuração assistida passo a passo
    ${COMPUTER} ${BOLD}Silencioso${NC}     Para scripts e automação

${WHITE}EXEMPLOS:${NC}
    $0                                    # Interface interativa moderna
    $0 -s -c meu-cluster -p 8080         # Modo silencioso
    $0 -v -f 4 -m 8192                   # Verboso com recursos forçados
    $0 -d                                # Instalar apenas dependências
    $0 -i                                # Forçar modo interativo

${WHITE}RECURSOS DETECTADOS AUTOMATICAMENTE:${NC}
    ${COMPUTER} CPUs: ${GREEN}$(detect_cores)${NC}
    ${COMPUTER} Memória: ${GREEN}$(detect_mem_mb)MB${NC}
    ${COMPUTER} Perfil Sugerido: ${GREEN}$(determine_profile "$(detect_cores)" "$(detect_mem_mb)")${NC}

EOF
}

# ============================
# INSTALAÇÃO DE DEPENDÊNCIAS COM PROGRESSO
# ============================

install_dependencies() {
    log_header "VERIFICAÇÃO E INSTALAÇÃO DE DEPENDÊNCIAS"
    
    local total_steps=8
    local current_step=0
    
    echo -e "${INFO} Verificando compatibilidade do sistema..."
    if [[ ! -f /etc/os-release ]] || ! grep -q "Ubuntu" /etc/os-release; then
        log_warning "Este script foi testado apenas no Ubuntu. Prosseguindo mesmo assim..."
    fi
    
    current_step=$((current_step + 1))
    show_progress_bar $current_step $total_steps "Atualizando sistema"
    
    (
        sudo apt-get update -qq
        sudo apt-get upgrade -y >/dev/null 2>&1
    ) &
    show_spinner $! "Atualizando repositórios e sistema"
    
    current_step=$((current_step + 1))
    show_progress_bar $current_step $total_steps "Instalando dependências básicas"
    
    (
        sudo apt-get install -y \
            python3 python3-pip python3-venv git curl wget \
            ca-certificates gnupg2 lsb-release build-essential \
            software-properties-common apt-transport-https >/dev/null 2>&1
    ) &
    show_spinner $! "Instalando pacotes básicos"
    
    current_step=$((current_step + 1))
    show_progress_bar $current_step $total_steps "Instalando Python 3.9"
    install_python39
    
    current_step=$((current_step + 1))
    show_progress_bar $current_step $total_steps "Instalando Docker"
    install_docker
    
    current_step=$((current_step + 1))
    show_progress_bar $current_step $total_steps "Instalando Kind"
    install_kind
    
    current_step=$((current_step + 1))
    show_progress_bar $current_step $total_steps "Instalando kubectl"
    install_kubectl
    
    current_step=$((current_step + 1))
    show_progress_bar $current_step $total_steps "Instalando Helm"
    install_helm
    
    current_step=$((current_step + 1))
    show_progress_bar $current_step $total_steps "Configurando Ansible"
    install_ansible_tools
    
    echo -e "\n${SUCCESS} Verificando instalações..."
    check_docker_running
    start_local_registry
    
    log_success "Todas as dependências foram instaladas e verificadas!"
}

install_python39() {
    if command_exists python3.9; then
        log_info "Python 3.9 já está instalado: $(python3.9 --version)"
        return 0
    fi
    
    (
        sudo add-apt-repository ppa:deadsnakes/ppa -y >/dev/null 2>&1
        sudo apt-get update -qq
        sudo apt-get install -y python3.9 python3.9-venv python3.9-distutils python3.9-dev >/dev/null 2>&1
        curl -s https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
        sudo python3.9 /tmp/get-pip.py >/dev/null 2>&1
        rm /tmp/get-pip.py
    ) &
    show_spinner $! "Instalando Python 3.9"
    
    log_success "Python 3.9 instalado: $(python3.9 --version)"
}

install_docker() {
    if command_exists docker; then
        log_info "Docker já está instalado: $(docker --version)"
        if ! user_in_docker_group; then
            log_warning "Adicionando usuário ao grupo docker..."
            sudo usermod -aG docker $USER
        fi
        return 0
    fi

    (
        sudo apt-get remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true
        sudo apt-get install -y ca-certificates curl >/dev/null 2>&1
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
        sudo usermod -aG docker $USER
        sudo systemctl start docker
        sudo systemctl enable docker
    ) &
    show_spinner $! "Instalando Docker"
    
    log_success "Docker instalado com sucesso!"
    log_warning "Execute 'newgrp docker' ou faça logout/login para ativar as permissões"
}

install_kind() {
    if command_exists kind; then
        log_info "Kind já está instalado: $(kind version)"
        return 0
    fi

    (
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    ) &
    show_spinner $! "Instalando Kind"
    
    log_success "Kind instalado: $(kind version)"
}

install_kubectl() {
    if command_exists kubectl; then
        log_info "kubectl já está instalado"
        return 0
    fi

    (
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    ) &
    show_spinner $! "Instalando kubectl"
    
    log_success "kubectl instalado com sucesso"
}

install_helm() {
    if command_exists helm; then
        log_info "Helm já está instalado: $(helm version --short)"
        return 0
    fi

    (
        curl -fsSL https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg >/dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y helm >/dev/null 2>&1
    ) &
    show_spinner $! "Instalando Helm"
    
    log_success "Helm instalado: $(helm version --short)"
}

install_ansible_tools() {
    if [ -d "$HOME/ansible-ee-venv" ]; then
        log_info "Ambiente virtual Ansible já existe"
        source "$HOME/ansible-ee-venv/bin/activate"
    else
        (
            python3.9 -m venv "$HOME/ansible-ee-venv"
            source "$HOME/ansible-ee-venv/bin/activate"
            pip install --upgrade pip >/dev/null 2>&1
            pip install "ansible>=7.0.0" "ansible-builder>=3.0.0" >/dev/null 2>&1
        ) &
        show_spinner $! "Criando ambiente virtual Ansible"
    fi
    
    log_success "Ansible configurado com sucesso"
}

check_docker_running() {
    if ! docker info >/dev/null 2>&1; then
        if ! user_in_docker_group; then
            log_error "Execute: newgrp docker"
            exit 1
        fi
        
        if ! systemctl is-active --quiet docker; then
            sudo systemctl start docker
            sleep 5
        fi
        
        if ! docker info >/dev/null 2>&1; then
            log_error "Erro ao conectar com Docker"
            exit 1
        fi
    fi
    log_success "Docker funcionando corretamente"
}

start_local_registry() {
    if docker ps | grep -q kind-registry; then
        log_info "Registry local já está rodando"
        return 0
    fi
    
    (
        docker run -d --restart=always -p 5001:5000 --name kind-registry registry:2 >/dev/null 2>&1
        if docker network ls | grep -q kind; then
            docker network connect kind kind-registry 2>/dev/null || true
        fi
    ) &
    show_spinner $! "Iniciando registry local"
    
    log_success "Registry local ativo em localhost:5001"
}

# ============================
# CRIAÇÃO DO CLUSTER COM PROGRESSO
# ============================

create_kind_cluster() {
    log_header "CRIAÇÃO DO CLUSTER KIND"
    
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_warning "Cluster '$CLUSTER_NAME' já existe"
        echo -ne "${YELLOW}Deseja deletá-lo e recriar? (s/N): ${NC}"
        read -r recreate
        if [[ "$recreate" =~ ^[sS]$ ]]; then
            (kind delete cluster --name "$CLUSTER_NAME") &
            show_spinner $! "Deletando cluster existente"
        else
            log_error "Operação cancelada"
            exit 1
        fi
    fi
    
    log_info "Criando configuração do cluster..."
    
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

    if [ "$PERFIL" = "prod" ] && [ "$CORES" -ge 6 ]; then
        log_info "Adicionando nó worker para ambiente de produção"
        cat >> /tmp/kind-config.yaml << EOF
- role: worker
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    maxPods: 110
EOF
    fi
    
    (kind create cluster --name "$CLUSTER_NAME" --config /tmp/kind-config.yaml) &
    show_spinner $! "Criando cluster Kubernetes"
    rm /tmp/kind-config.yaml
    
    log_success "Cluster criado com sucesso!"
    
    (kubectl wait --for=condition=Ready nodes --all --timeout=300s) &
    show_spinner $! "Aguardando cluster ficar pronto"
    
    if ! docker network ls | grep -q kind; then
        docker network create kind >/dev/null 2>&1
    fi
    docker network connect kind kind-registry 2>/dev/null || true
    
    kubectl apply -f - << EOF >/dev/null 2>&1
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

    log_success "Cluster configurado e conectado ao registry local"
}

# ============================
# EXECUTION ENVIRONMENT COM PROGRESSO
# ============================

create_execution_environment() {
    log_header "CRIAÇÃO DO EXECUTION ENVIRONMENT"
    
    source "$HOME/ansible-ee-venv/bin/activate"
    
    EE_DIR="/tmp/awx-ee-$$"
    mkdir -p "$EE_DIR"
    cd "$EE_DIR"
    
    log_info "Preparando arquivos de configuração..."
    
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

    if [ "$VERBOSE" = true ]; then
        (ansible-builder build -t localhost:5001/awx-custom-ee:latest -f execution-environment.yml --verbosity 2) &
    else
        (ansible-builder build -t localhost:5001/awx-custom-ee:latest -f execution-environment.yml >/dev/null 2>&1) &
    fi
    show_spinner $! "Construindo Execution Environment personalizado"
    
    (docker push localhost:5001/awx-custom-ee:latest >/dev/null 2>&1) &
    show_spinner $! "Enviando imagem para registry local"
    
    cd /
    rm -rf "$EE_DIR"
    
    log_success "Execution Environment criado e publicado"
}

# ============================
# INSTALAÇÃO DO AWX COM PROGRESSO
# ============================

install_awx() {
    log_header "INSTALAÇÃO DO AWX OPERATOR"
    
    (
        helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ >/dev/null 2>&1 || true
        helm repo update >/dev/null 2>&1
    ) &
    show_spinner $! "Atualizando repositórios Helm"
    
    kubectl create namespace "$AWX_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
    
    (
        helm upgrade --install awx-operator awx-operator/awx-operator \
            -n "$AWX_NAMESPACE" \
            --create-namespace \
            --wait \
            --timeout=10m >/dev/null 2>&1
    ) &
    show_spinner $! "Instalando AWX Operator"
    
    log_success "AWX Operator instalado com sucesso!"
    
    create_awx_instance
}

create_awx_instance() {
    log_info "Criando instância AWX personalizada..."
    
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
  
  control_plane_ee_image: localhost:5001/awx-custom-ee:latest
  
  replicas: ${WEB_REPLICAS}
  web_replicas: ${WEB_REPLICAS}
  task_replicas: ${TASK_REPLICAS}
  
  web_resource_requirements:
    requests:
      cpu: ${awx_web_cpu_req}
      memory: ${awx_web_mem_req}
    limits:
      cpu: ${awx_web_cpu_lim}
      memory: ${awx_web_mem_lim}
  
  task_resource_requirements:
    requests:
      cpu: ${awx_task_cpu_req}
      memory: ${awx_task_mem_req}
    limits:
      cpu: ${awx_task_cpu_lim}
      memory: ${awx_task_mem_lim}
  
  projects_persistence: true
  projects_storage_size: 8Gi
  projects_storage_access_mode: ReadWriteOnce
  
  postgres_configuration_secret: awx-postgres-configuration
  postgres_storage_requirements:
    requests:
      storage: 8Gi
    limits:
      storage: 8Gi
EOF

    kubectl apply -f /tmp/awx-instance.yaml -n "$AWX_NAMESPACE" >/dev/null 2>&1
    rm /tmp/awx-instance.yaml
    
    log_success "Instância AWX criada e configurada!"
}

# ============================
# MONITORAMENTO AVANÇADO
# ============================

wait_for_awx() {
    log_header "AGUARDANDO INSTALAÇÃO DO AWX"
    
    if ! kubectl get namespace "$AWX_NAMESPACE" &> /dev/null; then
        log_error "Namespace $AWX_NAMESPACE não existe!"
        return 1
    fi
    
    local phases=("Pending" "ContainerCreating" "Running")
    local timeout=120
    
    for phase in "${phases[@]}"; do
        echo -e "${INFO} Aguardando pods na fase: ${BOLD}$phase${NC}"
        local elapsed=0
        
        while [ $elapsed -lt $timeout ]; do
            local pod_count=$(kubectl get pods -n "$AWX_NAMESPACE" --field-selector=status.phase="$phase" --no-headers 2>/dev/null | wc -l)
            
            if [ "$pod_count" -gt 0 ]; then
                log_success "Encontrados $pod_count pod(s) na fase $phase"
                if [[ $VERBOSE == true ]]; then
                    kubectl get pods -n "$AWX_NAMESPACE"
                fi
                break
            fi
            
            sleep 10
            elapsed=$((elapsed + 10))
            printf "${GRAY}.${NC}"
        done
        echo
    done
    
    (kubectl wait --for=condition=Ready pods --all -n "$AWX_NAMESPACE" --timeout=600s >/dev/null 2>&1) &
    show_spinner $! "Verificação final dos pods"
}

get_awx_password() {
    log_info "Obtendo credenciais de acesso..."
    
    local timeout=300
    local elapsed=0
    while ! kubectl get secret awx-"$PERFIL"-admin-password -n "$AWX_NAMESPACE" &> /dev/null; do
        if [ $elapsed -ge $timeout ]; then
            log_error "Timeout aguardando senha do AWX"
            log_error "Execute: kubectl logs -n $AWX_NAMESPACE deployment/awx-operator-controller-manager"
            exit 1
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        printf "${GRAY}.${NC}"
    done
    echo
    
    AWX_PASSWORD=$(kubectl get secret awx-"$PERFIL"-admin-password -n "$AWX_NAMESPACE" -o jsonpath='{.data.password}' | base64 --decode)
    log_success "Credenciais obtidas com sucesso"
}

# ============================
# APRESENTAÇÃO FINAL APRIMORADA
# ============================

show_final_info() {
    clear
    
    # Banner de sucesso
    echo -e "${BOLD}${GREEN}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════════════╗
    ║                                                                      ║
    ║    🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO! 🎉                          ║
    ║                                                                      ║
    ╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    echo
    draw_box "INFORMAÇÕES DE ACESSO" "$GREEN"
    echo
    echo -e "${COMPUTER} ${BOLD}URL de Acesso:${NC} ${GREEN}${UNDERLINE}http://${node_ip}:${HOST_PORT}${NC}"
    echo -e "${COMPUTER} ${BOLD}Usuário:${NC} ${GREEN}admin${NC}"
    echo -e "${COMPUTER} ${BOLD}Senha:${NC} ${GREEN}${BOLD}$AWX_PASSWORD${NC}"
    echo
    
    draw_box "CONFIGURAÇÃO DO SISTEMA" "$BLUE"
    echo
    echo -e "${GEAR} ${BOLD}Perfil:${NC} ${GREEN}$PERFIL${NC}"
    echo -e "${GEAR} ${BOLD}CPUs Utilizadas:${NC} ${GREEN}$CORES${NC}"
    echo -e "${GEAR} ${BOLD}Memória:${NC} ${GREEN}${MEM_MB}MB${NC}"
    echo -e "${GEAR} ${BOLD}Web Réplicas:${NC} ${GREEN}$WEB_REPLICAS${NC}"
    echo -e "${GEAR} ${BOLD}Task Réplicas:${NC} ${GREEN}$TASK_REPLICAS${NC}"
    echo -e "${GEAR} ${BOLD}Cluster:${NC} ${GREEN}$CLUSTER_NAME${NC}"
    echo -e "${GEAR} ${BOLD}Namespace:${NC} ${GREEN}$AWX_NAMESPACE${NC}"
    echo
    
    draw_box "COMANDOS ÚTEIS" "$PURPLE"
    echo
    echo -e "${WRENCH} ${BOLD}Ver pods:${NC} ${CYAN}kubectl get pods -n $AWX_NAMESPACE${NC}"
    echo -e "${WRENCH} ${BOLD}Logs web:${NC} ${CYAN}kubectl logs -n $AWX_NAMESPACE deployment/awx-$PERFIL-web${NC}"
    echo -e "${WRENCH} ${BOLD}Logs task:${NC} ${CYAN}kubectl logs -n $AWX_NAMESPACE deployment/awx-$PERFIL-task${NC}"
    echo -e "${WRENCH} ${BOLD}Deletar cluster:${NC} ${CYAN}kind delete cluster --name $CLUSTER_NAME${NC}"
    echo -e "${WRENCH} ${BOLD}Parar registry:${NC} ${CYAN}docker stop kind-registry && docker rm kind-registry${NC}"
    echo
    
    if [ "$VERBOSE" = true ]; then
        draw_box "STATUS ATUAL DOS PODS" "$YELLOW"
        echo
        kubectl get pods -n "$AWX_NAMESPACE" -o wide
        echo
    fi
    
    draw_box "PRÓXIMOS PASSOS" "$CYAN"
    echo
    echo -e "${ARROW} Acesse ${GREEN}http://${node_ip}:${HOST_PORT}${NC} em seu navegador"
    echo -e "${ARROW} Faça login com as credenciais fornecidas acima"
    echo -e "${ARROW} Configure seus projetos e inventários no AWX"
    echo -e "${ARROW} Consulte a documentação em ${BLUE}https://ansible.readthedocs.io/projects/awx/en/latest/${NC}"
    echo
    
    # Som de conclusão (se habilitado)
    if [[ $ENABLE_SOUNDS == true ]] && command_exists paplay; then
        echo -e "${INFO} Reproduzindo som de conclusão..."
        paplay /usr/share/sounds/alsa/Front_Right.wav 2>/dev/null || true
    fi
}

# ============================
# CONFIGURAÇÕES E PARSING
# ============================

# Valores padrão
DEFAULT_HOST_PORT=8080
INSTALL_DEPS_ONLY=false
VERBOSE=false
SILENT=false
INTERACTIVE=true
AUTO_MODE=false
MANUAL_MODE=false

# Variáveis de recursos
FORCE_CPU=""
FORCE_MEM_MB=""
CUSTOM_REGISTRY=""
WORKER_NODES=""
K8S_VERSION=""

# Inicializar recursos
initialize_resources

# Valores padrão dependentes do perfil
DEFAULT_CLUSTER_NAME="awx-cluster-${PERFIL}"

# Parse das opções
while getopts "c:p:f:m:dvsih" opt; do
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
            initialize_resources
            DEFAULT_CLUSTER_NAME="awx-cluster-${PERFIL}"
            ;;
        m)
            if ! validate_memory "$OPTARG"; then
                exit 1
            fi
            FORCE_MEM_MB="$OPTARG"
            initialize_resources
            DEFAULT_CLUSTER_NAME="awx-cluster-${PERFIL}"
            ;;
        d)
            INSTALL_DEPS_ONLY=true
            ;;
        v)
            VERBOSE=true
            ;;
        s)
            INTERACTIVE=false
            AUTO_MODE=true
            ;;
        i)
            INTERACTIVE=true
            SILENT=false
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

# Aplicar valores padrão
CLUSTER_NAME=${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}
HOST_PORT=${HOST_PORT:-$DEFAULT_HOST_PORT}
AWX_NAMESPACE="awx"

# ============================
# EXECUÇÃO PRINCIPAL
# ============================

# Verificar modo de operação
if [[ $SILENT == true ]]; then
    log_header "AWX DEPLOYMENT - MODO SILENCIOSO"
    AUTO_MODE=true
elif [[ $INTERACTIVE == true ]] && [[ $AUTO_MODE == false ]] && [[ $MANUAL_MODE == false ]]; then
    # Mostrar menu principal apenas se não foi especificado modo
    show_main_menu
fi

# Mostrar configuração se não estiver em modo silencioso
if [[ $SILENT == false ]]; then
    if ! show_configuration_summary; then
        log_error "Instalação cancelada"
        exit 1
    fi
fi

# Log inicial
if [[ $SILENT == false ]]; then
    log_header "INICIANDO IMPLANTAÇÃO AWX"
    
    echo -e "${COMPUTER} ${BOLD}Recursos do Sistema:${NC}"
    echo -e "   ${GEAR} CPUs: ${GREEN}$CORES${NC}"
    echo -e "   ${GEAR} Memória: ${GREEN}${MEM_MB}MB${NC}"
    echo -e "   ${GEAR} Perfil: ${GREEN}$PERFIL${NC}"
    echo -e "   ${GEAR} Web Réplicas: ${GREEN}$WEB_REPLICAS${NC}"
    echo -e "   ${GEAR} Task Réplicas: ${GREEN}$TASK_REPLICAS${NC}"
    echo
    echo -e "${ROCKET} ${BOLD}Configuração da Implantação:${NC}"
    echo -e "   ${GEAR} Cluster: ${GREEN}$CLUSTER_NAME${NC}"
    echo -e "   ${GEAR} Porta: ${GREEN}$HOST_PORT${NC}"
    echo -e "   ${GEAR} Namespace: ${GREEN}$AWX_NAMESPACE${NC}"
    echo -e "   ${GEAR} Modo: ${GREEN}$([ $AUTO_MODE == true ] && echo "Automático" || echo "Manual")${NC}"
    echo
fi

# Execução principal
install_dependencies

if [ "$INSTALL_DEPS_ONLY" = true ]; then
    log_success "Dependências instaladas com sucesso!"
    if [[ $SILENT == false ]]; then
        echo -e "${INFO} Execute o script novamente sem a opção -d para instalar o AWX"
    fi
    exit 0
fi

create_kind_cluster
create_execution_environment
install_awx
wait_for_awx
get_awx_password

if [[ $SILENT == false ]]; then
    show_final_info
else
    echo "AWX_URL=http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'):${HOST_PORT}"
    echo "AWX_USER=admin"
    echo "AWX_PASSWORD=$AWX_PASSWORD"
fi

log_success "Instalação do AWX concluída com sucesso!"
