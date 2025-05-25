#!/bin/bash
set -e

# ============================
# INFORMAÇÕES E CRÉDITOS
# ============================

SCRIPT_VERSION="2.0"
SCRIPT_AUTHOR="Eduardo Gutierrez"
SCRIPT_DESCRIPTION="Script de Implantação AWX com Kind - Versão Interativa"

# ============================
# CORES E FUNÇÕES DE LOG APRIMORADAS
# ============================

# Cores expandidas para melhor UX
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
NC='\033[0m' # No Color

# Símbolos Unicode para melhor visual
CHECK="✓"
CROSS="✗"
ARROW="→"
STAR="★"
GEAR="⚙"
ROCKET="🚀"
INFO="ℹ"
WARNING="⚠"

# Função para log colorido aprimorada
log_info() {
    echo -e "${BLUE}${INFO}${NC} ${DIM}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}${CHECK}${NC} ${DIM}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}${WARNING}${NC} ${DIM}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}${CROSS}${NC} ${DIM}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${PURPLE}${GEAR}${NC} ${DIM}[DEBUG]${NC} $1"
}

log_step() {
    echo -e "${CYAN}${ARROW}${NC} ${BOLD}$1${NC}"
}

log_header() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}${BOLD}$1${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

log_credits() {
    echo -e "\n${PURPLE}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${NC} ${BOLD}${SCRIPT_DESCRIPTION}${NC} ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC} ${DIM}Versão: ${SCRIPT_VERSION}${NC} ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC} ${DIM}Autor: ${GREEN}${SCRIPT_AUTHOR}${NC} ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC} ${DIM}Desenvolvido com ${RED}♥${NC} para a comunidade${NC} ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────╯${NC}\n"
}

# ============================
# FUNÇÕES DE ANIMAÇÃO E UX
# ============================

# Spinner moderno para operações longas
show_spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    tput civis # Esconder cursor
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "\r${BLUE}%c${NC} ${message}" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    
    printf "\r${GREEN}${CHECK}${NC} ${message} - Concluído!\n"
    tput cnorm # Mostrar cursor
}

# Barra de progresso moderna
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}${message}${NC} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${BOLD}%d%%${NC}" $percentage
    
    if [ $current -eq $total ]; then
        printf " ${GREEN}${CHECK} Completo!${NC}\n"
    fi
}

# Função para pausar com estilo
pause_with_style() {
    local message=${1:-"Pressione qualquer tecla para continuar"}
    echo -e "\n${DIM}${message}...${NC}"
    read -n 1 -s
    echo
}

# ============================
# INTERFACE INTERATIVA PRINCIPAL
# ============================

show_welcome() {
    clear
    log_credits
    
    echo -e "${BOLD}${WHITE}Bem-vindo ao Instalador AWX Interativo!${NC}\n"
    echo -e "${DIM}Este script irá configurar um ambiente AWX completo usando Kind e Kubernetes.${NC}"
    echo -e "${DIM}Você pode escolher entre configuração automática ou personalizada.${NC}\n"
}

show_system_info() {
    log_header "INFORMAÇÕES DO SISTEMA"
    
    local cores=$(nproc --all)
    local mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    local disk_gb=$(df -h / | awk 'NR==2 {print $4}')
    local os_info=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Linux")
    
    echo -e "${CYAN}${INFO} Sistema Operacional:${NC} ${os_info}"
    echo -e "${CYAN}${INFO} CPUs Disponíveis:${NC} ${cores} cores"
    echo -e "${CYAN}${INFO} Memória Total:${NC} ${mem_mb} MB"
    echo -e "${CYAN}${INFO} Espaço em Disco:${NC} ${disk_gb} disponível"
    echo -e "${CYAN}${INFO} Docker Status:${NC} $(command_exists docker && echo "${GREEN}Instalado${NC}" || echo "${YELLOW}Não instalado${NC}")"
    
    local profile=$(determine_profile "$cores" "$mem_mb")
    echo -e "\n${BOLD}Perfil Recomendado:${NC} ${GREEN}${profile}${NC}"
    
    if [ "$profile" = "prod" ]; then
        echo -e "${DIM}• Múltiplas réplicas para alta disponibilidade${NC}"
        echo -e "${DIM}• Recursos otimizados para produção${NC}"
    else
        echo -e "${DIM}• Configuração single-node para desenvolvimento${NC}"
        echo -e "${DIM}• Uso eficiente de recursos limitados${NC}"
    fi
}

interactive_main_menu() {
    while true; do
        show_welcome
        show_system_info
        
        echo -e "\n${BOLD}${WHITE}Escolha uma opção:${NC}\n"
        
        PS3=$'\n'"${CYAN}${ARROW} Digite sua escolha: ${NC}"
        
        options=(
            "🤖 Instalação Automática (Recomendado)"
            "⚙️  Configuração Manual Personalizada"  
            "📋 Ver Informações Detalhadas do Sistema"
            "📖 Exibir Ajuda e Documentação"
            "🚪 Sair"
        )
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    log_step "Iniciando instalação automática..."
                    MODE="auto"
                    initialize_resources
                    start_installation
                    return 0
                    ;;
                2)
                    log_step "Iniciando configuração manual..."
                    MODE="manual"
                    interactive_configuration
                    return 0
                    ;;
                3)
                    show_detailed_system_info
                    break
                    ;;
                4)
                    show_help_interactive
                    break
                    ;;
                5)
                    log_step "Saindo do instalador. Até logo!"
                    exit 0
                    ;;
                *)
                    log_error "Opção inválida. Tente novamente."
                    break
                    ;;
            esac
        done
    done
}

show_detailed_system_info() {
    clear
    log_header "ANÁLISE DETALHADA DO SISTEMA"
    
    # Detecção de recursos
    local cores=$(detect_cores)
    local mem_mb=$(detect_mem_mb)
    local profile=$(determine_profile "$cores" "$mem_mb")
    
    echo -e "${BOLD}Recursos Detectados:${NC}"
    echo -e "├─ ${CYAN}CPUs:${NC} ${cores} cores"
    echo -e "├─ ${CYAN}Memória:${NC} ${mem_mb} MB ($(echo "scale=1; $mem_mb/1024" | bc) GB)"
    echo -e "└─ ${CYAN}Perfil:${NC} ${profile}"
    
    echo -e "\n${BOLD}Dependências:${NC}"
    local deps=("docker" "kind" "kubectl" "helm" "python3.9")
    for dep in "${deps[@]}"; do
        if command_exists "$dep"; then
            echo -e "├─ ${GREEN}${CHECK}${NC} ${dep}"
        else
            echo -e "├─ ${YELLOW}${CROSS}${NC} ${dep} (será instalado)"
        fi
    done
    
    echo -e "\n${BOLD}Configuração AWX Calculada:${NC}"
    calculate_replicas "$profile" "$cores"
    calculate_available_resources "$cores" "$mem_mb" "$profile"
    echo -e "├─ ${CYAN}Web Réplicas:${NC} ${WEB_REPLICAS}"
    echo -e "├─ ${CYAN}Task Réplicas:${NC} ${TASK_REPLICAS}"
    echo -e "├─ ${CYAN}CPU Alocada:${NC} ${NODE_CPU} cores"
    echo -e "└─ ${CYAN}Memória Alocada:${NC} ${NODE_MEM_MB} MB"
    
    pause_with_style "Pressione qualquer tecla para voltar ao menu principal"
}

interactive_configuration() {
    clear
    log_header "CONFIGURAÇÃO MANUAL PERSONALIZADA"
    
    echo -e "${BOLD}Vamos configurar seu ambiente AWX passo a passo!${NC}\n"
    
    # Configuração do cluster
    configure_cluster_interactive
    
    # Configuração de recursos
    configure_resources_interactive
    
    # Configuração da porta
    configure_port_interactive
    
    # Resumo da configuração
    show_configuration_summary
    
    # Confirmação final
    if confirm_installation; then
        start_installation
    else
        log_step "Retornando ao menu principal..."
        return
    fi
}

configure_cluster_interactive() {
    echo -e "${CYAN}${GEAR} Configuração do Cluster${NC}\n"
    
    # Nome do cluster
    while true; do
        echo -e "${DIM}Nome do cluster (deixe vazio para usar padrão):${NC}"
        read -p "$(echo -e "${CYAN}${ARROW}${NC} ")" cluster_input
        
        if [ -z "$cluster_input" ]; then
            CLUSTER_NAME="awx-cluster-$(date +%Y%m%d)"
            log_info "Usando nome padrão: ${CLUSTER_NAME}"
            break
        elif [[ "$cluster_input" =~ ^[a-zA-Z0-9-]+$ ]]; then
            CLUSTER_NAME="$cluster_input"
            log_success "Nome do cluster definido: ${CLUSTER_NAME}"
            break
        else
            log_error "Nome inválido. Use apenas letras, números e hífens."
        fi
    done
    echo
}

configure_resources_interactive() {
    echo -e "${CYAN}${GEAR} Configuração de Recursos${NC}\n"
    
    # CPU
    local default_cpu=$(detect_cores)
    echo -e "${DIM}CPUs detectadas: ${default_cpu}${NC}"
    echo -e "${DIM}Quantas CPUs usar? (deixe vazio para usar automático):${NC}"
    read -p "$(echo -e "${CYAN}${ARROW}${NC} ")" cpu_input
    
    if [ -n "$cpu_input" ] && validate_cpu "$cpu_input"; then
        FORCE_CPU="$cpu_input"
        log_success "CPUs configuradas: ${FORCE_CPU}"
    else
        log_info "Usando detecção automática de CPU"
    fi
    
    # Memória
    local default_mem=$(detect_mem_mb)
    echo -e "\n${DIM}Memória detectada: ${default_mem} MB${NC}"
    echo -e "${DIM}Quanta memória usar (MB)? (deixe vazio para usar automático):${NC}"
    read -p "$(echo -e "${CYAN}${ARROW}${NC} ")" mem_input
    
    if [ -n "$mem_input" ] && validate_memory "$mem_input"; then
        FORCE_MEM_MB="$mem_input"
        log_success "Memória configurada: ${FORCE_MEM_MB} MB"
    else
        log_info "Usando detecção automática de memória"
    fi
    
    # Recalcular recursos com valores fornecidos
    initialize_resources
    echo
}

configure_port_interactive() {
    echo -e "${CYAN}${GEAR} Configuração de Rede${NC}\n"
    
    echo -e "${DIM}Porta para acessar o AWX (padrão: 8080):${NC}"
    read -p "$(echo -e "${CYAN}${ARROW}${NC} ")" port_input
    
    if [ -n "$port_input" ] && validate_port "$port_input"; then
        HOST_PORT="$port_input"
        log_success "Porta configurada: ${HOST_PORT}"
    else
        HOST_PORT=8080
        log_info "Usando porta padrão: ${HOST_PORT}"
    fi
    echo
}

show_configuration_summary() {
    log_header "RESUMO DA CONFIGURAÇÃO"
    
    echo -e "${BOLD}Sua configuração personalizada:${NC}\n"
    
    echo -e "╭─ ${CYAN}Cluster${NC}"
    echo -e "│  ├─ Nome: ${GREEN}${CLUSTER_NAME}${NC}"
    echo -e "│  └─ Porta: ${GREEN}${HOST_PORT}${NC}"
    echo -e "│"
    echo -e "├─ ${CYAN}Recursos${NC}"
    echo -e "│  ├─ CPUs: ${GREEN}${CORES} cores${NC}"
    echo -e "│  ├─ Memória: ${GREEN}${MEM_MB} MB${NC}"
    echo -e "│  └─ Perfil: ${GREEN}${PERFIL}${NC}"
    echo -e "│"
    echo -e "├─ ${CYAN}AWX${NC}"
    echo -e "│  ├─ Web Réplicas: ${GREEN}${WEB_REPLICAS}${NC}"
    echo -e "│  ├─ Task Réplicas: ${GREEN}${TASK_REPLICAS}${NC}"
    echo -e "│  ├─ CPU Alocada: ${GREEN}${NODE_CPU} cores${NC}"
    echo -e "│  └─ Memória Alocada: ${GREEN}${NODE_MEM_MB} MB${NC}"
    echo -e "│"
    echo -e "└─ ${CYAN}Acesso${NC}"
    echo -e "   └─ URL: ${GREEN}http://localhost:${HOST_PORT}${NC}"
    echo
}

confirm_installation() {
    echo -e "${BOLD}${WHITE}Confirmar instalação?${NC}\n"
    
    PS3=$'\n'"${CYAN}${ARROW} Sua escolha: ${NC}"
    
    options=(
        "✅ Sim, iniciar instalação"
        "📝 Revisar configuração"
        "🔙 Voltar ao menu principal"
    )
    
    select choice in "${options[@]}"; do
        case $REPLY in
            1)
                return 0
                ;;
            2)
                show_configuration_summary
                break
                ;;
            3)
                return 1
                ;;
            *)
                log_error "Opção inválida."
                break
                ;;
        esac
    done
    
    # Se chegou aqui, não confirmou
    return 1
}

show_help_interactive() {
    clear
    log_header "AJUDA E DOCUMENTAÇÃO"
    
    cat << EOF
${BOLD}${WHITE}Guia de Uso do Instalador AWX${NC}

${CYAN}${ROCKET} Instalação Automática:${NC}
  • Detecta recursos automaticamente
  • Configura ambiente otimizado
  • Ideal para a maioria dos usuários
  • Processo completamente automatizado

${CYAN}${GEAR} Configuração Manual:${NC}
  • Controle total sobre recursos
  • Personalização de nomes e portas
  • Recomendado para usuários avançados
  • Validação de entrada em tempo real

${CYAN}${INFO} Recursos Mínimos:${NC}
  • CPU: 2 cores (recomendado 4+)
  • RAM: 4 GB (recomendado 8 GB+)
  • Disco: 20 GB livre
  • SO: Ubuntu 18.04+ (testado)

${CYAN}${WARNING} Dependências:${NC}
  • Docker CE
  • Kind (Kubernetes in Docker)
  • kubectl
  • Helm 3
  • Python 3.9+

${CYAN}${CHECK} Pós-instalação:${NC}
  • AWX acessível via navegador
  • Usuário: admin
  • Senha: exibida no final
  • Logs disponíveis via kubectl

${DIM}Para mais informações, visite: https://github.com/ansible/awx${NC}
EOF
    
    pause_with_style "Pressione qualquer tecla para voltar"
}

# ============================
# FUNÇÕES DE INSTALAÇÃO APRIMORADAS
# ============================

start_installation() {
    log_header "INICIANDO INSTALAÇÃO AWX"
    
    if [ "$MODE" = "auto" ]; then
        log_step "Modo automático selecionado - detectando configuração ideal..."
        CLUSTER_NAME=${CLUSTER_NAME:-"awx-cluster-auto"}
        HOST_PORT=${HOST_PORT:-8080}
    fi
    
    log_info "Configuração selecionada:"
    log_info "  • Cluster: ${CLUSTER_NAME}"
    log_info "  • Porta: ${HOST_PORT}"
    log_info "  • Perfil: ${PERFIL}"
    log_info "  • CPUs: ${CORES} (${NODE_CPU} alocadas)"
    log_info "  • Memória: ${MEM_MB}MB (${NODE_MEM_MB}MB alocadas)"
    
    echo -e "\n${BOLD}Fases da instalação:${NC}"
    echo -e "1. ${DIM}Instalação de dependências${NC}"
    echo -e "2. ${DIM}Criação do cluster Kind${NC}"
    echo -e "3. ${DIM}Criação do Execution Environment${NC}"
    echo -e "4. ${DIM}Instalação do AWX${NC}"
    echo -e "5. ${DIM}Configuração final${NC}"
    
    pause_with_style "Pressione qualquer tecla para iniciar"
    
    # Instalar dependências com progresso
    install_dependencies_with_progress
    
    # Continuar com instalação original
    create_kind_cluster
    create_execution_environment  
    install_awx
    wait_for_awx
    get_awx_password
    show_final_info_enhanced
}

install_dependencies_with_progress() {
    log_header "INSTALAÇÃO DE DEPENDÊNCIAS"
    
    local deps=("python3.9" "docker" "kind" "kubectl" "helm" "ansible")
    local total=${#deps[@]}
    local current=0
    
    for dep in "${deps[@]}"; do
        current=$((current + 1))
        show_progress $current $total "Instalando $dep"
        
        case $dep in
            "python3.9")
                install_python39 > /dev/null 2>&1 &
                show_spinner $! "Instalando Python 3.9"
                ;;
            "docker")
                install_docker > /dev/null 2>&1 &
                show_spinner $! "Instalando Docker"
                ;;
            "kind")
                install_kind > /dev/null 2>&1 &
                show_spinner $! "Instalando Kind"
                ;;
            "kubectl")
                install_kubectl > /dev/null 2>&1 &
                show_spinner $! "Instalando kubectl"
                ;;
            "helm")
                install_helm > /dev/null 2>&1 &
                show_spinner $! "Instalando Helm"
                ;;
            "ansible")
                install_ansible_tools > /dev/null 2>&1 &
                show_spinner $! "Instalando Ansible"
                ;;
        esac
        
        sleep 0.5 # Pequena pausa para melhor UX
    done
    
    check_docker_running
    start_local_registry
    
    log_success "Todas as dependências foram instaladas!"
}

show_final_info_enhanced() {
    clear
    log_header "🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO! 🎉"
    
    # Obter IP do nó
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    echo -e "${GREEN}${BOLD}Seu ambiente AWX está pronto para uso!${NC}\n"
    
    # Informações de acesso em box estilizado
    echo -e "${CYAN}╭─────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}${WHITE}🌐 INFORMAÇÕES DE ACESSO${NC} ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}URL:${NC} ${GREEN}http://${node_ip}:${HOST_PORT}${NC} ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}Usuário:${NC} ${GREEN}admin${NC} ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}Senha:${NC} ${GREEN}$AWX_PASSWORD${NC} ${CYAN}│${NC}"
    echo -e "${CYAN}╰─────────────────────────────────────────────╯${NC}"
    
    # Informações técnicas
    echo -e "\n${PURPLE}╭─────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${NC} ${BOLD}${WHITE}⚙️  CONFIGURAÇÃO TÉCNICA${NC} ${PURPLE}│${NC}"
    echo -e "${PURPLE}├─────────────────────────────────────────────┤${NC}"
    echo -e "${PURPLE}│${NC} ${BOLD}Cluster:${NC} ${GREEN}${CLUSTER_NAME}${NC} ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC} ${BOLD}Perfil:${NC} ${GREEN}${PERFIL}${NC} ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC} ${BOLD}Web Réplicas:${NC} ${GREEN}${WEB_REPLICAS}${NC} ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC} ${BOLD}Task Réplicas:${NC} ${GREEN}${TASK_REPLICAS}${NC} ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC} ${BOLD}Recursos:${NC} ${GREEN}${NODE_CPU} CPU, ${NODE_MEM_MB}MB${NC} ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────╯${NC}"
    
    # Comandos úteis
    echo -e "\n${YELLOW}╭─────────────────────────────────────────────╮${NC}"
    echo -e "${YELLOW}│${NC} ${BOLD}${WHITE}🛠️  COMANDOS ÚTEIS${NC} ${YELLOW}│${NC}"
    echo -e "${YELLOW}├─────────────────────────────────────────────┤${NC}"
    echo -e "${YELLOW}│${NC} ${DIM}Ver pods:${NC}"
    echo -e "${YELLOW}│${NC}   ${CYAN}kubectl get pods -n $AWX_NAMESPACE${NC}"
    echo -e "${YELLOW}│${NC} ${DIM}Ver logs web:${NC}"
    echo -e "${YELLOW}│${NC}   ${CYAN}kubectl logs -n $AWX_NAMESPACE deployment/awx-$PERFIL-web${NC}"
    echo -e "${YELLOW}│${NC} ${DIM}Deletar cluster:${NC}"
    echo -e "${YELLOW}│${NC}   ${CYAN}kind delete cluster --name $CLUSTER_NAME${NC}"
    echo -e "${YELLOW}╰─────────────────────────────────────────────╯${NC}"
    
    # Créditos finais
    echo -e "\n${DIM}───────────────────────────────────────────────────${NC}"
    echo -e "${DIM}Desenvolvido por ${GREEN}${BOLD}Eduardo Gutierrez${NC}${DIM} com ${RED}♥${NC}${DIM} para a comunidade${NC}"
    echo -e "${DIM}Versão ${SCRIPT_VERSION} - Script AWX Interativo${NC}"
    echo -e "${DIM}───────────────────────────────────────────────────${NC}"
    
    echo -e "\n${BOLD}${GREEN}🎉 Aproveite seu novo ambiente AWX! 🎉${NC}\n"
}

# ============================
# INSERIR TODAS AS FUNÇÕES ORIGINAIS AQUI
# ============================
# [Todas as funções originais do script permanecem inalteradas]
# Incluindo: command_exists, user_in_docker_group, validate_*, detect_*, 
# calculate_*, initialize_resources, install_*, create_*, wait_for_awx, etc.

# [FUNÇÕES ORIGINAIS MANTIDAS - inserir todo o código original aqui]

# ============================
# EXECUÇÃO PRINCIPAL MODIFICADA
# ============================

# Valores padrão
MODE="interactive"
DEFAULT_HOST_PORT=8080
INSTALL_DEPS_ONLY=false
VERBOSE=false
FORCE_CPU=""
FORCE_MEM_MB=""

# Parse das opções da linha de comando (mantendo compatibilidade)
while getopts "c:p:f:m:dvha" opt; do
    case ${opt} in
        c)
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
        a)
            MODE="auto"
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

# Inicializar recursos
initialize_resources

# Aplicar valores padrão
CLUSTER_NAME=${CLUSTER_NAME:-"awx-cluster-${PERFIL}"}
HOST_PORT=${HOST_PORT:-$DEFAULT_HOST_PORT}
AWX_NAMESPACE="awx"

# Execução principal
if [ "$MODE" = "auto" ] || [ "$INSTALL_DEPS_ONLY" = true ]; then
    # Modo automático original (linha de comando)
    if [ "$INSTALL_DEPS_ONLY" = true ]; then
        install_dependencies
        log_success "✅ Dependências instaladas com sucesso!"
        exit 0
    fi
    
    # Instalação automática completa
    start_installation
else
    # Modo interativo (novo)
    interactive_main_menu
fi

log_success "🎉 Script executado com sucesso!"
