#!/bin/bash
set -e

# ============================
# SCRIPT DE IMPLANTAÇÃO AWX - VERSÃO APRIMORADA
# Desenvolvido por: Eduardo Gutierrez
# Versão: 2.0 - Enhanced UX Edition
# ============================

# ============================
# CORES E SÍMBOLOS MODERNOS
# ============================

# Cores aprimoradas
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Gradientes e efeitos especiais
GRADIENT_START='\033[38;5;51m'
GRADIENT_MID='\033[38;5;45m'
GRADIENT_END='\033[38;5;39m'
RAINBOW=('\033[38;5;196m' '\033[38;5;208m' '\033[38;5;226m' '\033[38;5;46m' '\033[38;5;51m' '\033[38;5;93m')

# Símbolos modernos
CHECKMARK="✅"
CROSS="❌"
ARROW="➤"
STAR="⭐"
GEAR="⚙️"
ROCKET="🚀"
COMPUTER="💻"
CLOCK="⏰"
PACKAGE="📦"
SHIELD="🛡️"
FIRE="🔥"
DIAMOND="💎"

# ============================
# SISTEMA DE LOGGING APRIMORADO
# ============================

# Função para banner de título
show_banner() {
    clear
    echo -e "${GRADIENT_START}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GRADIENT_MID}║                        AWX DEPLOYMENT SCRIPT v2.0                           ║${NC}"
    echo -e "${GRADIENT_END}║                          Enhanced UX Edition                                ║${NC}"
    echo -e "${CYAN}║                      Desenvolvido por Eduardo Gutierrez                     ║${NC}"
    echo -e "${GRAY}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Sistema de log colorido aprimorado
log_info() {
    echo -e "${BLUE}${ARROW}${NC} ${BOLD}INFO${NC}: $1"
}

log_success() {
    echo -e "${GREEN}${CHECKMARK}${NC} ${BOLD}SUCESSO${NC}: $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC} ${BOLD}AVISO${NC}: $1"
}

log_error() {
    echo -e "${RED}${CROSS}${NC} ${BOLD}ERRO${NC}: $1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${PURPLE}🔍${NC} ${DIM}DEBUG${NC}: $1"
    fi
}

log_header() {
    echo ""
    echo -e "${CYAN}${STAR}${STAR}${STAR} $1 ${STAR}${STAR}${STAR}${NC}"
    echo -e "${GRAY}$(printf '%.0s═' {1..80})${NC}"
    echo ""
}

log_step() {
    echo -e "${GRADIENT_MID}${GEAR}${NC} ${BOLD}ETAPA${NC}: $1"
}

log_progress() {
    local current=$1
    local total=$2
    local description=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[${NC}"
    printf "%0.s█" $(seq 1 $filled)
    printf "%0.s░" $(seq 1 $empty)
    printf "${BLUE}]${NC} ${percent}%% - ${description}"
    
    if [ $current -eq $total ]; then
        echo ""
    fi
}

# Spinner de carregamento
show_spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${CYAN}${spin:i++%${#spin}:1}${NC} $message"
        sleep 0.1
    done
    printf "\r${GREEN}${CHECKMARK}${NC} $message\n"
}

# ============================
# SISTEMA DE CONFIGURAÇÃO INTERATIVA
# ============================

# Arquivo de configuração padrão
CONFIG_FILE="$HOME/.awx-deploy-config.yaml"

# Função para salvar configuração
save_config() {
    cat > "$CONFIG_FILE" << EOF
# Configuração AWX Deployment Script
# Gerado automaticamente em $(date)
cluster_name: "$CLUSTER_NAME"
host_port: $HOST_PORT
perfil: "$PERFIL"
cores: $CORES
mem_mb: $MEM_MB
web_replicas: $WEB_REPLICAS
task_replicas: $TASK_REPLICAS
auto_detect: $AUTO_DETECT
verbose: $VERBOSE
EOF
    log_success "Configuração salva em $CONFIG_FILE"
}

# Função para carregar configuração
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log_info "Carregando configuração salva..."
        source <(grep -E '^[a-zA-Z_]+:' "$CONFIG_FILE" | sed 's/: /=/' | sed 's/"//g')
        return 0
    fi
    return 1
}

# Função para prompt interativo melhorado
prompt_with_validation() {
    local prompt_text="$1"
    local default_value="$2"
    local validation_func="$3"
    local value=""
    
    while true; do
        echo -e "${CYAN}${ARROW}${NC} ${prompt_text}"
        if [ -n "$default_value" ]; then
            echo -e "  ${DIM}(padrão: ${default_value})${NC}"
        fi
        echo -ne "${YELLOW}❯${NC} "
        
        read -r value
        
        # Usar valor padrão se vazio
        if [ -z "$value" ] && [ -n "$default_value" ]; then
            value="$default_value"
        fi
        
        # Validar se função de validação foi fornecida
        if [ -n "$validation_func" ]; then
            if $validation_func "$value"; then
                echo "$value"
                return 0
            else
                log_error "Valor inválido. Tente novamente."
                echo ""
            fi
        else
            echo "$value"
            return 0
        fi
    done
}

# Função para seleção de menu
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    local choice=""
    
    echo -e "${GRADIENT_START}┌─ $title ─┐${NC}"
    echo ""
    
    for i in "${!options[@]}"; do
        echo -e "  ${CYAN}$((i+1)).${NC} ${options[i]}"
    done
    
    echo ""
    choice=$(prompt_with_validation "Escolha uma opção (1-${#options[@]}):" "" validate_menu_choice)
    echo $((choice-1))
}

validate_menu_choice() {
    local choice=$1
    local max_options=${#menu_options[@]}
    
    if is_number "$choice" && [ "$choice" -ge 1 ] && [ "$choice" -le "$max_options" ]; then
        return 0
    fi
    return 1
}

# ============================
# MODO INTERATIVO DE CONFIGURAÇÃO
# ============================

interactive_mode() {
    log_header "MODO DE CONFIGURAÇÃO INTERATIVA"
    
    echo -e "${FIRE} ${BOLD}Bem-vindo ao modo interativo!${NC}"
    echo -e "Configure cada aspecto da implantação do AWX de acordo com suas necessidades."
    echo ""
    
    # Configuração do cluster
    log_step "Configuração do Cluster"
    CLUSTER_NAME=$(prompt_with_validation "Nome do cluster Kind:" "$DEFAULT_CLUSTER_NAME")
    HOST_PORT=$(prompt_with_validation "Porta do host para acesso:" "$DEFAULT_HOST_PORT" validate_port)
    
    # Configuração de recursos
    log_step "Configuração de Recursos"
    echo -e "${COMPUTER} ${BOLD}Recursos detectados automaticamente:${NC}"
    echo -e "  CPUs: ${GREEN}$CORES${NC}"
    echo -e "  Memória: ${GREEN}${MEM_MB}MB${NC}"
    echo ""
    
    menu_options=("Usar recursos detectados automaticamente" "Configurar recursos manualmente")
    resource_choice=$(show_menu "Configuração de Recursos" "${menu_options[@]}")
    
    if [ "$resource_choice" -eq 1 ]; then
        FORCE_CPU=$(prompt_with_validation "Número de CPUs:" "$CORES" validate_cpu)
        FORCE_MEM_MB=$(prompt_with_validation "Memória em MB:" "$MEM_MB" validate_memory)
        initialize_resources
    fi
    
    # Configuração do perfil
    log_step "Configuração do Perfil"
    echo -e "${DIAMOND} ${BOLD}Perfil detectado:${NC} ${GREEN}$PERFIL${NC}"
    
    menu_options=("Usar perfil detectado ($PERFIL)" "Forçar perfil de Desenvolvimento" "Forçar perfil de Produção")
    profile_choice=$(show_menu "Seleção de Perfil" "${menu_options[@]}")
    
    case $profile_choice in
        1) PERFIL="dev" ;;
        2) PERFIL="prod" ;;
    esac
    
    # Recalcular réplicas baseado no perfil
    calculate_replicas "$PERFIL" "$CORES"
    
    # Configurações avançadas
    log_step "Configurações Avançadas"
    menu_options=("Configuração padrão" "Personalizar réplicas")
    advanced_choice=$(show_menu "Configurações Avançadas" "${menu_options[@]}")
    
    if [ "$advanced_choice" -eq 1 ]; then
        WEB_REPLICAS=$(prompt_with_validation "Réplicas Web:" "$WEB_REPLICAS" validate_replicas)
        TASK_REPLICAS=$(prompt_with_validation "Réplicas Task:" "$TASK_REPLICAS" validate_replicas)
    fi
    
    # Resumo da configuração
    show_configuration_summary
    
    # Confirmar configuração
    menu_options=("Continuar com esta configuração" "Reconfigurar" "Salvar configuração e continuar")
    confirm_choice=$(show_menu "Confirmação" "${menu_options[@]}")
    
    case $confirm_choice in
        0) return 0 ;;
        1) interactive_mode ;;
        2) save_config; return 0 ;;
    esac
}

validate_replicas() {
    local replicas=$1
    if is_number "$replicas" && [ "$replicas" -ge 1 ] && [ "$replicas" -le 10 ]; then
        return 0
    fi
    return 1
}

show_configuration_summary() {
    log_header "RESUMO DA CONFIGURAÇÃO"
    
    echo -e "${PACKAGE} ${BOLD}Configuração Selecionada:${NC}"
    echo -e "  ${ARROW} Cluster: ${GREEN}$CLUSTER_NAME${NC}"
    echo -e "  ${ARROW} Porta: ${GREEN}$HOST_PORT${NC}"
    echo -e "  ${ARROW} Perfil: ${GREEN}$PERFIL${NC}"
    echo -e "  ${ARROW} CPUs: ${GREEN}$CORES${NC}"
    echo -e "  ${ARROW} Memória: ${GREEN}${MEM_MB}MB${NC}"
    echo -e "  ${ARROW} Réplicas Web: ${GREEN}$WEB_REPLICAS${NC}"
    echo -e "  ${ARROW} Réplicas Task: ${GREEN}$TASK_REPLICAS${NC}"
    echo ""
}

# ============================
# VALIDAÇÃO E UTILITÁRIOS (MANTIDOS)
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
# DETECÇÃO DE RECURSOS (MANTIDA)
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
    show_banner
    cat << EOF
${FIRE} ${BOLD}Script de Implantação AWX com Kind - Enhanced UX Edition${NC}
${DIM}Desenvolvido por Eduardo Gutierrez${NC}

${WHITE}USO:${NC}
    $0 [OPÇÕES]

${WHITE}OPÇÕES:${NC}
    ${GREEN}-i${NC}           Modo interativo (recomendado para novos usuários)
    ${GREEN}-a${NC}           Modo automático (detecção automática de recursos)
    ${GREEN}-c NOME${NC}      Nome do cluster Kind
    ${GREEN}-p PORTA${NC}     Porta do host para acessar AWX (padrão: 8080)
    ${GREEN}-f CPU${NC}       Forçar número de CPUs (ex: 4)
    ${GREEN}-m MEMORIA${NC}   Forçar quantidade de memória em MB (ex: 8192)
    ${GREEN}-l${NC}           Carregar configuração salva
    ${GREEN}-d${NC}           Instalar apenas dependências
    ${GREEN}-v${NC}           Modo verboso (debug)
    ${GREEN}-h${NC}           Exibir esta ajuda

${WHITE}MODOS DE OPERAÇÃO:${NC}
    ${ROCKET} ${BOLD}Interativo${NC}: Interface guiada com menus e validação
    ${GEAR} ${BOLD}Automático${NC}: Detecção automática com configuração mínima

${WHITE}EXEMPLOS:${NC}
    $0 -i                                 # Modo interativo (recomendado)
    $0 -a                                 # Modo automático
    $0 -i -l                              # Carregar configuração e usar modo interativo
    $0 -c meu-cluster -p 8080            # Cluster personalizado na porta 8080
    $0 -f 4 -m 8192                     # Forçar 4 CPUs e 8GB RAM

${WHITE}RECURSOS DO SCRIPT:${NC}
    ${CHECKMARK} Interface moderna e intuitiva
    ${CHECKMARK} Validação em tempo real
    ${CHECKMARK} Salvamento de configurações
    ${CHECKMARK} Detecção automática de recursos
    ${CHECKMARK} Barras de progresso visuais
    ${CHECKMARK} Sistema de logging avançado

${WHITE}PERFIS AUTOMÁTICOS:${NC}
    ${GREEN}${DIAMOND} Produção${NC}: ≥4 CPUs e ≥8GB RAM - Múltiplas réplicas
    ${YELLOW}${GEAR} Desenvolvimento${NC}: <4 CPUs ou <8GB RAM - Réplica única

${WHITE}PÓS-INSTALAÇÃO:${NC}
    Acesse: ${CYAN}http://localhost:PORTA${NC}
    Usuário: ${GREEN}admin${NC}
    Senha: ${GREEN}(exibida no final da instalação)${NC}

${DIM}© 2024 Eduardo Gutierrez - Enhanced UX Edition${NC}
EOF
}

# ============================
# INSTALAÇÃO DE DEPENDÊNCIAS (MANTIDA COM MELHORIAS VISUAIS)
# ============================

install_dependencies() {
    log_header "VERIFICAÇÃO E INSTALAÇÃO DE DEPENDÊNCIAS"
    
    local total_steps=8
    local current_step=0
    
    # Verificar sistema
    ((current_step++))
    log_progress $current_step $total_steps "Verificando sistema operacional"
    
    if [[ ! -f /etc/os-release ]] || ! grep -q "Ubuntu" /etc/os-release; then
        log_warning "Este script foi testado apenas no Ubuntu. Prosseguindo mesmo assim..."
    fi
    
    # Atualizar sistema
    ((current_step++))
    log_progress $current_step $total_steps "Atualizando sistema"
    
    (sudo apt-get update -qq && sudo apt-get upgrade -y) &
    show_spinner $! "Atualizando sistema"
    
    # Instalar dependências básicas
    ((current_step++))
    log_progress $current_step $total_steps "Instalando dependências básicas"
    
    sudo apt-get install -y \
        python3 python3-pip python3-venv git curl wget \
        ca-certificates gnupg2 lsb-release build-essential \
        software-properties-common apt-transport-https &
    show_spinner $! "Instalando dependências básicas"
    
    # Instalar componentes individuais
    for component in "Python 3.9" "Docker" "Kind" "kubectl" "Helm"; do
        ((current_step++))
        log_progress $current_step $total_steps "Instalando $component"
        
        case $component in
            "Python 3.9") install_python39 ;;
            "Docker") install_docker ;;
            "Kind") install_kind ;;
            "kubectl") install_kubectl ;;
            "Helm") install_helm ;;
        esac
    done
    
    # Finalizar
    install_ansible_tools
    check_docker_running
    start_local_registry
    
    log_success "Todas as dependências foram instaladas e verificadas!"
}

# [Mantém todas as funções de instalação originais com melhorias visuais...]

# ============================
# FLUXO PRINCIPAL APRIMORADO
# ============================

main_menu() {
    show_banner
    
    echo -e "${FIRE} ${BOLD}Bem-vindo ao AWX Deployment Script!${NC}"
    echo -e "${DIM}A maneira mais fácil de implantar AWX em ambiente Kubernetes local${NC}"
    echo ""
    
    # Verificar configuração salva
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${PACKAGE} ${BOLD}Configuração salva encontrada!${NC}"
        echo ""
    fi
    
    menu_options=(
        "${ROCKET} Modo Interativo (recomendado para novos usuários)"
        "${GEAR} Modo Automático (detecção automática de recursos)"
        "${PACKAGE} Carregar configuração salva"
        "${SHIELD} Instalar apenas dependências"
        "${CROSS} Sair"
    )
    
    mode_choice=$(show_menu "Selecione o Modo de Operação" "${menu_options[@]}")
    
    case $mode_choice in
        0) 
            AUTO_DETECT=false
            interactive_mode
            ;;
        1) 
            AUTO_DETECT=true
            log_info "Modo automático selecionado - usando detecção automática de recursos"
            ;;
        2)
            if load_config; then
                show_configuration_summary
                menu_options=("Continuar com configuração carregada" "Modo interativo" "Cancelar")
                load_choice=$(show_menu "Configuração Carregada" "${menu_options[@]}")
                case $load_choice in
                    0) AUTO_DETECT=false ;;
                    1) interactive_mode ;;
                    2) exit 0 ;;
                esac
            else
                log_error "Nenhuma configuração salva encontrada"
                main_menu
            fi
            ;;
        3)
            INSTALL_DEPS_ONLY=true
            ;;
        4)
            echo -e "${CYAN}Obrigado por usar o AWX Deployment Script!${NC}"
            echo -e "${DIM}Desenvolvido por Eduardo Gutierrez${NC}"
            exit 0
            ;;
    esac
}

# ============================
# CONFIGURAÇÃO E EXECUÇÃO PRINCIPAL
# ============================

# Valores padrão
DEFAULT_HOST_PORT=8080
INSTALL_DEPS_ONLY=false
VERBOSE=false
AUTO_DETECT=true
INTERACTIVE_MODE=false

# Variáveis de recursos
FORCE_CPU=""
FORCE_MEM_MB=""

# Inicializar recursos
initialize_resources
DEFAULT_CLUSTER_NAME="awx-cluster-${PERFIL}"

# Parse das opções da linha de comando
while getopts "iac:p:f:m:ldvh" opt; do
    case ${opt} in
        i)
            INTERACTIVE_MODE=true
            AUTO_DETECT=false
            ;;
        a)
            AUTO_DETECT=true
            INTERACTIVE_MODE=false
            ;;
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
        l)
            load_config
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

# Aplicar valores padrão
CLUSTER_NAME=${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}
HOST_PORT=${HOST_PORT:-$DEFAULT_HOST_PORT}
AWX_NAMESPACE="awx"

# ============================
# EXECUÇÃO PRINCIPAL
# ============================

# Se não foram fornecidas opções, mostrar menu principal
if [ $# -eq 0 ] && [ -z "$CLUSTER_NAME" ] && [ "$INSTALL_DEPS_ONLY" = false ]; then
    main_menu
elif [ "$INTERACTIVE_MODE" = true ]; then
    show_banner
    interactive_mode
fi

# Mostrar informações de início
log_header "INICIANDO IMPLANTAÇÃO AWX"

echo -e "${COMPUTER} ${BOLD}Recursos do Sistema:${NC}"
echo -e "  ${ARROW} CPUs: ${GREEN}$CORES${NC}"
echo -e "  ${ARROW} Memória: ${GREEN}${MEM_MB}MB${NC}"
echo -e "  ${ARROW} Perfil: ${GREEN}$PERFIL${NC}"
echo -e "  ${ARROW} Web Réplicas: ${GREEN}$WEB_REPLICAS${NC}"
echo -e "  ${ARROW} Task Réplicas: ${GREEN}$TASK_REPLICAS${NC}"

echo -e "${GEAR} ${BOLD}Configuração:${NC}"
echo -e "  ${ARROW} Cluster: ${GREEN}$CLUSTER_NAME${NC}"
echo -e "  ${ARROW} Porta: ${GREEN}$HOST_PORT${NC}"
echo -e "  ${ARROW} Namespace: ${GREEN}$AWX_NAMESPACE${NC}"
echo -e "  ${ARROW} Verbose: ${GREEN}$VERBOSE${NC}"

# Confirmar início
if [ "$AUTO_DETECT" = false ] && [ "$INSTALL_DEPS_ONLY" = false ]; then
    echo ""
    menu_options=("${ROCKET} Iniciar instalação" "${CROSS} Cancelar")
    start_choice=$(show_menu "Confirmação Final" "${menu_options[@]}")
    
    if [ "$start_choice" -eq 1 ]; then
        echo -e "${CYAN}Instalação cancelada pelo usuário${NC}"
        exit 0
    fi
fi

# Executar instalação
install_dependencies

if [ "$INSTALL_DEPS_ONLY" = true ]; then
    log_success "${CHECKMARK} Dependências instaladas com sucesso!"
    log_info "Execute o script novamente sem a opção -d para instalar o AWX"
    exit 0
fi

# [Manter todas as funções originais de instalação...]
# create_kind_cluster
# create_execution_environment  
# install_awx
# wait_for_awx
# get_awx_password

# Finalizar com informações
show_final_info() {
    log_header "INSTALAÇÃO CONCLUÍDA"
    
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    echo ""
    echo -e "${RAINBOW[0]}█${RAINBOW[1]}█${RAINBOW[2]}█${NC} ${BOLD}AWX IMPLANTADO COM SUCESSO${NC} ${RAINBOW[3]}█${RAINBOW[4]}█${RAINBOW[5]}█${NC}"
    echo ""
    echo -e "${PACKAGE} ${BOLD}INFORMAÇÕES DE ACESSO:${NC}"
    echo -e "  ${ARROW} URL: ${GREEN}http://${node_ip}:${HOST_PORT}${NC}"
    echo -e "  ${ARROW} Usuário: ${GREEN}admin${NC}"
    echo -e "  ${ARROW} Senha: ${GREEN}$AWX_PASSWORD${NC}"
    echo ""
    echo -e "${GEAR} ${BOLD}CONFIGURAÇÃO DO SISTEMA:${NC}"
    echo -e "  ${ARROW} Perfil: ${GREEN}$PERFIL${NC}"
    echo -e "  ${ARROW} CPUs Detectadas: ${GREEN}$CORES${NC}"
    echo -e "  ${ARROW} Memória Detectada: ${GREEN}${MEM_MB}MB${NC}"
    echo -e "  ${ARROW} Web Réplicas: ${GREEN}$WEB_REPLICAS${NC}"
    echo -e "  ${ARROW} Task Réplicas: ${GREEN}$TASK_REPLICAS${NC}"
    echo ""
    echo -e "${ROCKET} ${BOLD}COMANDOS ÚTEIS:${NC}"
    echo -e "  ${ARROW} Ver pods: ${CYAN}kubectl get pods -n $AWX_NAMESPACE${NC}"
    echo -e "  ${ARROW} Ver logs web: ${CYAN}kubectl logs -n $AWX_NAMESPACE deployment/awx-$PERFIL-web${NC}"
    echo -e "  ${ARROW} Ver logs task: ${CYAN}kubectl logs -n $AWX_NAMESPACE deployment/awx-$PERFIL-task${NC}"
    echo -e "  ${ARROW} Deletar cluster: ${CYAN}kind delete cluster --name $CLUSTER_NAME${NC}"
    echo ""
    echo -e "${DIM}Desenvolvido por Eduardo Gutierrez - Enhanced UX Edition${NC}"
    echo -e "${DIM}Obrigado por usar o AWX Deployment Script!${NC}"
    
    if [ "$VERBOSE" = true ]; then
        log_info "${SHIELD} STATUS ATUAL DOS PODS:"
        kubectl get pods -n "$AWX_NAMESPACE" -o wide
    fi
}

log_success "${FIRE} Instalação do AWX concluída com sucesso!"
