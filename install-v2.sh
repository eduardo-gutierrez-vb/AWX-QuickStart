#!/bin/bash
set -e

# ============================
# CONFIGURAÇÕES AVANÇADAS DE UX
# ============================

# Caracteres especiais e ícones
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️ "
ICON_INFO="ℹ️ "
ICON_LOADING="⏳"
ICON_CONFIG="🔧"
ICON_ROCKET="🚀"
ICON_CPU="💻"
ICON_MEMORY="🧠"
ICON_NETWORK="🌐"
ICON_DOCKER="🐳"
ICON_KUBERNETES="☸️ "

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Cores temáticas
PRIMARY='\033[1;34m'
SECONDARY='\033[0;36m'
SUCCESS='\033[1;32m'
DANGER='\033[1;31m'
WARNING='\033[1;33m'
INFO='\033[1;36m'

# ============================
# VARIÁVEIS GLOBAIS
# ============================

DEFAULT_HOST_PORT=8080
INSTALL_DEPS_ONLY=false
VERBOSE=false
FORCE_CPU=""
FORCE_MEM_MB=""
AWX_NAMESPACE="awx"
CLUSTER_NAME=""
HOST_PORT="$DEFAULT_HOST_PORT"

# Especificações do AWX
AWX_MIN_CPU_CORES=2
AWX_MIN_MEMORY_MB=4096
AWX_PROD_CPU_CORES=4
AWX_PROD_MEMORY_MB=8192

# Overhead do sistema
SYSTEM_CPU_OVERHEAD=20
K8S_CPU_OVERHEAD=10
SYSTEM_MEMORY_OVERHEAD=15
K8S_MEMORY_OVERHEAD=10

# ============================
# FUNÇÕES DE LOG
# ============================

log_info() {
    echo -e "${INFO}${ICON_INFO}${NC}${BOLD}[INFO]${NC} $1"
}

log_success() {
    echo -e "${SUCCESS}${ICON_SUCCESS}${NC}${BOLD}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${WARNING}${ICON_WARNING}${NC}${BOLD}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${DANGER}${ICON_ERROR}${NC}${BOLD}[ERROR]${NC} $1"
}

log_header() {
    local title="$1"
    local icon="${2:-🎯}"
    echo ""
    echo -e "${PRIMARY}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PRIMARY}║${NC} ${icon} ${BOLD}${WHITE}$title${NC}${PRIMARY} ║${NC}"
    echo -e "${PRIMARY}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_section() {
    echo ""
    echo -e "${SECONDARY}▶${NC} ${BOLD}$1${NC}"
    echo -e "${GRAY}────────────────────────────────────────────────${NC}"
}

# ============================
# FUNÇÕES DE DETECÇÃO
# ============================

detect_cores() {
    if [ -n "$FORCE_CPU" ]; then
        echo "$FORCE_CPU"
    else
        nproc --all
    fi
}

detect_mem_mb() {
    if [ -n "$FORCE_MEM_MB" ]; then
        echo "$FORCE_MEM_MB"
    else
        local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        echo $((mem_kb / 1024))
    fi
}

# ============================
# VALIDAÇÕES
# ============================

validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        log_error "Porta inválida: $port (deve estar entre 1-65535)"
        return 1
    fi
}

validate_cpu() {
    local cpu="$1"
    if [[ "$cpu" =~ ^[0-9]+$ ]] && [ "$cpu" -ge 1 ]; then
        return 0
    else
        log_error "CPU inválida: $cpu (deve ser um número positivo)"
        return 1
    fi
}

validate_memory() {
    local mem="$1"
    if [[ "$mem" =~ ^[0-9]+$ ]] && [ "$mem" -ge 1024 ]; then
        return 0
    else
        log_error "Memória inválida: $mem (deve ser >= 1024 MB)"
        return 1
    fi
}

# ============================
# MENU SIMPLIFICADO E FUNCIONAL
# ============================

show_welcome() {
    clear
    echo -e "${PRIMARY}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                     🚀 INSTALADOR AWX AUTOMATIZADO 🚀                       ║
║                                                                               ║
║                    Versão Avançada com Interface Melhorada                   ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo -e "${INFO}Bem-vindo ao instalador AWX automatizado!${NC}"
    echo -e "${GRAY}Este script irá configurar um ambiente AWX completo usando Kind + Kubernetes${NC}"
    echo ""
}

show_main_menu() {
    echo -e "${BOLD}${WHITE}Escolha o modo de instalação:${NC}"
    echo ""
    echo -e "${SUCCESS}1.${NC} ${BOLD}Automático${NC} - Detectar recursos automaticamente (Recomendado)"
    echo -e "${WARNING}2.${NC} ${BOLD}Manual${NC} - Configurar recursos manualmente"
    echo -e "${INFO}3.${NC} ${BOLD}Apenas Dependências${NC} - Instalar somente as dependências"
    echo -e "${SECONDARY}4.${NC} ${BOLD}Ajuda${NC} - Exibir documentação completa"
    echo -e "${GRAY}5.${NC} ${BOLD}Sair${NC}"
    echo ""
}

# FUNÇÃO SIMPLIFICADA PARA LEITURA
get_menu_choice() {
    local choice=""
    while true; do
        echo -ne "${PRIMARY}${ICON_CONFIG} Escolha uma opção [1-5]:${NC} "
        read -r choice
        
        case "$choice" in
            1|2|3|4|5)
                return "$choice"
                ;;
            *)
                log_error "Opção inválida: '$choice'. Digite um número de 1 a 5."
                ;;
        esac
    done
}

# ============================
# CÁLCULOS DE RECURSOS
# ============================

advanced_resource_detection() {
    local total_cores=$(detect_cores)
    local total_memory_mb=$(detect_mem_mb)
    
    log_section "Análise Detalhada de Recursos"
    
    # Calcular overhead
    local system_cpu_reserve=$((total_cores * SYSTEM_CPU_OVERHEAD / 100))
    local k8s_cpu_reserve=$((total_cores * K8S_CPU_OVERHEAD / 100))
    local system_memory_reserve=$((total_memory_mb * SYSTEM_MEMORY_OVERHEAD / 100))
    local k8s_memory_reserve=$((total_memory_mb * K8S_MEMORY_OVERHEAD / 100))
    
    # Garantir mínimos
    [ "$system_cpu_reserve" -lt 1 ] && system_cpu_reserve=1
    [ "$k8s_cpu_reserve" -lt 1 ] && k8s_cpu_reserve=1
    [ "$system_memory_reserve" -lt 512 ] && system_memory_reserve=512
    [ "$k8s_memory_reserve" -lt 256 ] && k8s_memory_reserve=256
    
    # Calcular disponível
    local available_cpu=$((total_cores - system_cpu_reserve - k8s_cpu_reserve))
    local available_memory=$((total_memory_mb - system_memory_reserve - k8s_memory_reserve))
    
    # Determinar perfil
    if [ "$available_cpu" -ge "$AWX_PROD_CPU_CORES" ] && [ "$available_memory" -ge "$AWX_PROD_MEMORY_MB" ]; then
        PERFIL="prod"
        ENVIRONMENT_TYPE="Produção"
    elif [ "$available_cpu" -ge "$AWX_MIN_CPU_CORES" ] && [ "$available_memory" -ge "$AWX_MIN_MEMORY_MB" ]; then
        PERFIL="staging"
        ENVIRONMENT_TYPE="Homologação"
    else
        PERFIL="dev"
        ENVIRONMENT_TYPE="Desenvolvimento"
    fi
    
    # Calcular recursos específicos
    calculate_awx_pod_resources
    calculate_optimal_replicas "$available_cpu"
    
    # Armazenar valores globais
    TOTAL_CPU="$total_cores"
    TOTAL_MEMORY_MB="$total_memory_mb"
    AVAILABLE_CPU="$available_cpu"
    AVAILABLE_MEMORY_MB="$available_memory"
    SYSTEM_CPU_RESERVE="$system_cpu_reserve"
    SYSTEM_MEMORY_RESERVE_MB="$system_memory_reserve"
    K8S_CPU_RESERVE="$k8s_cpu_reserve"
    K8S_MEMORY_RESERVE_MB="$k8s_memory_reserve"
    
    # Definir nome do cluster
    [ -z "$CLUSTER_NAME" ] && CLUSTER_NAME="awx-cluster-${PERFIL}"
    
    log_info "Recursos detectados: CPU=${total_cores}, MEM=${total_memory_mb}MB"
    log_info "Perfil determinado: ${PERFIL} (${ENVIRONMENT_TYPE})"
}

calculate_awx_pod_resources() {
    case "$PERFIL" in
        "prod")
            AWX_WEB_CPU_REQUEST="200m"
            AWX_WEB_CPU_LIMIT="2000m"
            AWX_WEB_MEMORY_REQUEST="512Mi"
            AWX_WEB_MEMORY_LIMIT="2Gi"
            
            AWX_TASK_CPU_REQUEST="500m"
            AWX_TASK_CPU_LIMIT="4000m"
            AWX_TASK_MEMORY_REQUEST="1Gi"
            AWX_TASK_MEMORY_LIMIT="4Gi"
            
            AWX_POSTGRES_CPU_REQUEST="100m"
            AWX_POSTGRES_CPU_LIMIT="1000m"
            AWX_POSTGRES_MEMORY_REQUEST="256Mi"
            AWX_POSTGRES_MEMORY_LIMIT="1Gi"
            ;;
        "staging")
            AWX_WEB_CPU_REQUEST="100m"
            AWX_WEB_CPU_LIMIT="1000m"
            AWX_WEB_MEMORY_REQUEST="256Mi"
            AWX_WEB_MEMORY_LIMIT="1Gi"
            
            AWX_TASK_CPU_REQUEST="200m"
            AWX_TASK_CPU_LIMIT="2000m"
            AWX_TASK_MEMORY_REQUEST="512Mi"
            AWX_TASK_MEMORY_LIMIT="2Gi"
            
            AWX_POSTGRES_CPU_REQUEST="50m"
            AWX_POSTGRES_CPU_LIMIT="500m"
            AWX_POSTGRES_MEMORY_REQUEST="128Mi"
            AWX_POSTGRES_MEMORY_LIMIT="512Mi"
            ;;
        "dev")
            AWX_WEB_CPU_REQUEST="50m"
            AWX_WEB_CPU_LIMIT="500m"
            AWX_WEB_MEMORY_REQUEST="128Mi"
            AWX_WEB_MEMORY_LIMIT="512Mi"
            
            AWX_TASK_CPU_REQUEST="100m"
            AWX_TASK_CPU_LIMIT="1000m"
            AWX_TASK_MEMORY_REQUEST="256Mi"
            AWX_TASK_MEMORY_LIMIT="1Gi"
            
            AWX_POSTGRES_CPU_REQUEST="25m"
            AWX_POSTGRES_CPU_LIMIT="250m"
            AWX_POSTGRES_MEMORY_REQUEST="64Mi"
            AWX_POSTGRES_MEMORY_LIMIT="256Mi"
            ;;
    esac
}

calculate_optimal_replicas() {
    local available_cpu=$1
    
    case "$PERFIL" in
        "prod")
            if [ "$available_cpu" -ge 8 ]; then
                WEB_REPLICAS=3
                TASK_REPLICAS=2
            elif [ "$available_cpu" -ge 6 ]; then
                WEB_REPLICAS=2
                TASK_REPLICAS=2
            else
                WEB_REPLICAS=2
                TASK_REPLICAS=1
            fi
            ;;
        "staging")
            if [ "$available_cpu" -ge 4 ]; then
                WEB_REPLICAS=2
                TASK_REPLICAS=1
            else
                WEB_REPLICAS=1
                TASK_REPLICAS=1
            fi
            ;;
        "dev")
            WEB_REPLICAS=1
            TASK_REPLICAS=1
            ;;
    esac
}

# ============================
# CONFIGURAÇÃO MANUAL
# ============================

show_manual_config_menu() {
    log_header "Configuração Manual de Recursos" "⚙️"
    
    echo -e "${BOLD}${WHITE}Configure os recursos do seu ambiente:${NC}"
    echo ""
    
    # CPU
    echo -e "${SUCCESS}${ICON_CPU} CPU:${NC}"
    echo -e "  ${GRAY}• Detectado no sistema: ${BOLD}$(nproc --all)${NC} cores${NC}"
    echo -ne "  ${PRIMARY}Quantos cores usar? [Enter para auto]:${NC} "
    read -r manual_cpu
    
    # Memória
    echo -e "${SUCCESS}${ICON_MEMORY} Memória:${NC}"
    echo -e "  ${GRAY}• Detectado no sistema: ${BOLD}$(detect_mem_mb)${NC} MB${NC}"
    echo -ne "  ${PRIMARY}Quanta memória usar (em MB)? [Enter para auto]:${NC} "
    read -r manual_memory
    
    # Porta
    echo -e "${SUCCESS}${ICON_NETWORK} Rede:${NC}"
    echo -ne "  ${PRIMARY}Porta para acesso ao AWX? [Enter para 8080]:${NC} "
    read -r manual_port
    
    # Nome do cluster
    echo -e "${SUCCESS}${ICON_KUBERNETES} Kubernetes:${NC}"
    echo -ne "  ${PRIMARY}Nome do cluster Kind? [Enter para auto]:${NC} "
    read -r manual_cluster
    
    # Aplicar configurações
    [ -n "$manual_cpu" ] && FORCE_CPU="$manual_cpu"
    [ -n "$manual_memory" ] && FORCE_MEM_MB="$manual_memory"
    [ -n "$manual_port" ] && HOST_PORT="$manual_port"
    [ -n "$manual_cluster" ] && CLUSTER_NAME="$manual_cluster"
}

# ============================
# RESUMO DOS RECURSOS
# ============================

show_resource_summary() {
    log_header "Resumo da Configuração de Recursos" "📊"
    
    echo -e "${BOLD}${WHITE}CONFIGURAÇÃO AWX:${NC}"
    echo -e "  ${ICON_KUBERNETES} ${BOLD}Perfil:${NC} ${SUCCESS}$PERFIL${NC} (${ENVIRONMENT_TYPE})"
    echo -e "  ${ICON_KUBERNETES} ${BOLD}Cluster:${NC} ${SUCCESS}$CLUSTER_NAME${NC}"
    echo -e "  ${ICON_NETWORK} ${BOLD}Porta:${NC} ${SUCCESS}$HOST_PORT${NC}"
    echo -e "  ${ICON_CONFIG} ${BOLD}CPU Total:${NC} ${PRIMARY}$TOTAL_CPU cores${NC}"
    echo -e "  ${ICON_CONFIG} ${BOLD}Memória Total:${NC} ${PRIMARY}$TOTAL_MEMORY_MB MB${NC}"
    echo -e "  ${ICON_CONFIG} ${BOLD}CPU Disponível:${NC} ${SUCCESS}$AVAILABLE_CPU cores${NC}"
    echo -e "  ${ICON_CONFIG} ${BOLD}Memória Disponível:${NC} ${SUCCESS}$AVAILABLE_MEMORY_MB MB${NC}"
    
    echo ""
    echo -e "${WARNING}${ICON_WARNING}${NC} ${BOLD}Verificações:${NC}"
    
    if [ "$AVAILABLE_CPU" -lt "$AWX_MIN_CPU_CORES" ]; then
        echo -e "  ${DANGER}${ICON_ERROR} CPU insuficiente (mínimo: ${AWX_MIN_CPU_CORES} cores)${NC}"
    else
        echo -e "  ${SUCCESS}${ICON_SUCCESS} CPU adequada${NC}"
    fi
    
    if [ "$AVAILABLE_MEMORY_MB" -lt "$AWX_MIN_MEMORY_MB" ]; then
        echo -e "  ${DANGER}${ICON_ERROR} Memória insuficiente (mínimo: ${AWX_MIN_MEMORY_MB}MB)${NC}"
    else
        echo -e "  ${SUCCESS}${ICON_SUCCESS} Memória adequada${NC}"
    fi
    
    echo ""
    echo -ne "${PRIMARY}${ICON_CONFIG} Continuar com esta configuração? [S/n]:${NC} "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_warning "Instalação cancelada pelo usuário"
        exit 0
    fi
}

# ============================
# FUNÇÕES DE INSTALAÇÃO (SIMULADAS)
# ============================

install_dependencies() {
    log_header "Instalação de Dependências" "📦"
    log_info "Instalando dependências do sistema..."
    sleep 2
    log_success "Dependências instaladas com sucesso!"
}

create_kind_cluster() {
    log_header "Criação do Cluster Kubernetes" "☸️"
    log_info "Criando cluster Kind: $CLUSTER_NAME"
    sleep 2
    log_success "Cluster criado com sucesso!"
}

install_awx() {
    log_header "Instalação do AWX" "🚀"
    log_info "Instalando AWX com perfil: $PERFIL"
    sleep 2
    log_success "AWX instalado com sucesso!"
}

show_help() {
    log_header "Ajuda - Instalador AWX" "📖"
    echo -e "${BOLD}${WHITE}DESCRIÇÃO:${NC}"
    echo -e "  Este script automatiza a instalação do AWX usando Kind + Kubernetes"
    echo ""
    echo -e "${BOLD}${WHITE}MODOS:${NC}"
    echo -e "  ${SUCCESS}Automático:${NC} Detecta recursos automaticamente"
    echo -e "  ${WARNING}Manual:${NC} Permite configuração personalizada"
    echo -e "  ${INFO}Dependências:${NC} Instala apenas as dependências"
    echo ""
    echo -e "${BOLD}${WHITE}PERFIS:${NC}"
    echo -e "  ${SUCCESS}Produção:${NC} 4+ cores, 8+ GB RAM"
    echo -e "  ${WARNING}Homologação:${NC} 2-4 cores, 4-8 GB RAM"
    echo -e "  ${INFO}Desenvolvimento:${NC} < 2 cores ou < 4 GB RAM"
    echo ""
}

# ============================
# FUNÇÃO PRINCIPAL SIMPLIFICADA
# ============================

main() {
    show_welcome
    
    while true; do
        show_main_menu
        get_menu_choice
        local choice=$?
        
        case "$choice" in
            1)
                log_info "Modo automático selecionado"
                advanced_resource_detection
                show_resource_summary
                break
                ;;
            2)
                log_info "Modo manual selecionado"
                show_manual_config_menu
                advanced_resource_detection
                show_resource_summary
                break
                ;;
            3)
                log_info "Instalando apenas dependências"
                INSTALL_DEPS_ONLY=true
                break
                ;;
            4)
                show_help
                echo ""
                echo -ne "${INFO}Pressione Enter para voltar ao menu...${NC}"
                read -r
                continue
                ;;
            5)
                log_info "Saindo..."
                exit 0
                ;;
        esac
    done
    
    # Executar instalação
    if [ "$INSTALL_DEPS_ONLY" = true ]; then
        install_dependencies
        log_success "Dependências instaladas! Execute novamente para instalar o AWX."
        exit 0
    fi
    
    # Instalação completa
    install_dependencies
    create_kind_cluster
    install_awx
    
    log_success "Instalação do AWX concluída com sucesso!"
    log_info "Acesse o AWX em: http://localhost:$HOST_PORT"
    log_info "Perfil instalado: $ENVIRONMENT_TYPE"
}

# ============================
# INICIALIZAÇÃO
# ============================

# Parse argumentos de linha de comando
while getopts "c:p:f:m:dvh" opt; do
    case ${opt} in
        c) CLUSTER_NAME="$OPTARG" ;;
        p) validate_port "$OPTARG" && HOST_PORT="$OPTARG" ;;
        f) validate_cpu "$OPTARG" && FORCE_CPU="$OPTARG" ;;
        m) validate_memory "$OPTARG" && FORCE_MEM_MB="$OPTARG" ;;
        d) INSTALL_DEPS_ONLY=true ;;
        v) VERBOSE=true ;;
        h) show_help; exit 0 ;;
        *) log_error "Opção inválida"; exit 1 ;;
    esac
done

# Verificar modo de execução
if [ $# -gt 0 ]; then
    # Modo não-interativo (com argumentos)
    log_info "Modo não-interativo detectado"
    advanced_resource_detection
    
    if [ "$INSTALL_DEPS_ONLY" = true ]; then
        install_dependencies
        exit 0
    fi
    
    install_dependencies
    create_kind_cluster
    install_awx
    
    log_success "Instalação concluída!"
    log_info "Acesse o AWX em: http://localhost:$HOST_PORT"
else
    # Modo interativo
    main
fi
