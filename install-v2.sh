#!/bin/bash
set -e

# ============================
# CONFIGURAÇÕES AVANÇADAS DE UX
# ============================

# Caracteres especiais e ícones (compatível com terminais básicos)
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

# Cores aprimoradas
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
PRIMARY='\033[1;34m'    # Azul forte
SECONDARY='\033[0;36m'  # Ciano
SUCCESS='\033[1;32m'    # Verde forte
DANGER='\033[1;31m'     # Vermelho forte
WARNING='\033[1;33m'    # Amarelo forte
INFO='\033[1;36m'       # Ciano forte

# ============================
# FUNÇÕES DE LOG APRIMORADAS
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

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${GRAY}[DEBUG]${NC} $1"
    fi
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

# Barra de progresso visual
show_progress() {
    local current=$1
    local total=$2
    local message="$3"
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "\r${INFO}${ICON_LOADING}${NC} ${BOLD}%s${NC} [" "$message"
    
    for ((i=0; i<filled; i++)); do
        printf "${SUCCESS}█${NC}"
    done
    
    for ((i=filled; i<width; i++)); do
        printf "${GRAY}░${NC}"
    done
    
    printf "] ${BOLD}%d%%${NC}" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        echo " ${SUCCESS}${ICON_SUCCESS}${NC}"
    fi
}

# Spinner animado para operações longas
show_spinner() {
    local pid=$1
    local message="$2"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${INFO}%s${NC} ${BOLD}%s${NC}" "${chars:i++%${#chars}:1}" "$message"
        sleep 0.1
    done
    printf "\r${SUCCESS}${ICON_SUCCESS}${NC} ${BOLD}%s${NC} - Concluído!\n" "$message"
}

# ============================
# SISTEMA DE MENU INTERATIVO
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
    echo -ne "${PRIMARY}${ICON_CONFIG} Escolha uma opção [1-5]:${NC} "
}

read_user_choice() {
    local choice
    read -r choice
    echo "$choice"
}

# Menu de configuração manual
show_manual_config_menu() {
    log_header "Configuração Manual de Recursos" "⚙️"
    
    echo -e "${BOLD}${WHITE}Configure os recursos do seu ambiente:${NC}"
    echo ""
    
    # CPU
    echo -e "${SUCCESS}${ICON_CPU} CPU:${NC}"
    echo -e "  ${GRAY}• Mínimo recomendado: 2 cores${NC}"
    echo -e "  ${GRAY}• Produção: 4+ cores${NC}"
    echo -e "  ${GRAY}• Detectado no sistema: ${BOLD}$(nproc --all)${NC} cores${NC}"
    echo -ne "  ${PRIMARY}Quantos cores usar? [padrão: auto]:${NC} "
    read -r manual_cpu
    
    echo ""
    
    # Memória
    echo -e "${SUCCESS}${ICON_MEMORY} Memória:${NC}"
    echo -e "  ${GRAY}• Mínimo recomendado: 4GB (4096MB)${NC}"
    echo -e "  ${GRAY}• Produção: 8GB+ (8192MB)${NC}"
    echo -e "  ${GRAY}• Detectado no sistema: ${BOLD}$(detect_mem_mb)${NC} MB${NC}"
    echo -ne "  ${PRIMARY}Quanta memória usar (em MB)? [padrão: auto]:${NC} "
    read -r manual_memory
    
    echo ""
    
    # Porta
    echo -e "${SUCCESS}${ICON_NETWORK} Rede:${NC}"
    echo -e "  ${GRAY}• Porta padrão: 8080${NC}"
    echo -e "  ${GRAY}• Faixa válida: 1-65535${NC}"
    echo -ne "  ${PRIMARY}Porta para acesso ao AWX? [padrão: 8080]:${NC} "
    read -r manual_port
    
    echo ""
    
    # Nome do cluster
    echo -e "${SUCCESS}${ICON_KUBERNETES} Kubernetes:${NC}"
    echo -e "  ${GRAY}• Nome padrão será gerado automaticamente${NC}"
    echo -ne "  ${PRIMARY}Nome do cluster Kind? [padrão: auto]:${NC} "
    read -r manual_cluster
    
    # Aplicar configurações manuais
    [ -n "$manual_cpu" ] && FORCE_CPU="$manual_cpu"
    [ -n "$manual_memory" ] && FORCE_MEM_MB="$manual_memory"
    [ -n "$manual_port" ] && HOST_PORT="$manual_port"
    [ -n "$manual_cluster" ] && CLUSTER_NAME="$manual_cluster"
}

# ============================
# CÁLCULOS AVANÇADOS DE RECURSOS
# ============================

# Especificações baseadas nas recomendações oficiais do AWX e Kubernetes
AWX_MIN_CPU_CORES=2
AWX_MIN_MEMORY_MB=4096
AWX_PROD_CPU_CORES=4
AWX_PROD_MEMORY_MB=8192

# Overhead do sistema e Kubernetes (percentuais)
SYSTEM_CPU_OVERHEAD=20    # 20% reservado para SO
K8S_CPU_OVERHEAD=10       # 10% reservado para Kubernetes
SYSTEM_MEMORY_OVERHEAD=15 # 15% reservado para SO
K8S_MEMORY_OVERHEAD=10    # 10% reservado para Kubernetes

# Função avançada para detectar e calcular recursos
advanced_resource_detection() {
    local total_cores=$(detect_cores)
    local total_memory_mb=$(detect_mem_mb)
    
    log_section "Análise Detalhada de Recursos"
    
    # Calcular overhead do sistema
    local system_cpu_reserve=$((total_cores * SYSTEM_CPU_OVERHEAD / 100))
    local k8s_cpu_reserve=$((total_cores * K8S_CPU_OVERHEAD / 100))
    local system_memory_reserve=$((total_memory_mb * SYSTEM_MEMORY_OVERHEAD / 100))
    local k8s_memory_reserve=$((total_memory_mb * K8S_MEMORY_OVERHEAD / 100))
    
    # Garantir mínimos
    [ "$system_cpu_reserve" -lt 1 ] && system_cpu_reserve=1
    [ "$k8s_cpu_reserve" -lt 1 ] && k8s_cpu_reserve=1
    [ "$system_memory_reserve" -lt 512 ] && system_memory_reserve=512
    [ "$k8s_memory_reserve" -lt 256 ] && k8s_memory_reserve=256
    
    # Calcular recursos disponíveis para AWX
    local available_cpu=$((total_cores - system_cpu_reserve - k8s_cpu_reserve))
    local available_memory=$((total_memory_mb - system_memory_reserve - k8s_memory_reserve))
    
    # Determinar perfil baseado em recursos disponíveis e requisitos do AWX
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
    
    # Calcular recursos específicos para pods AWX
    calculate_awx_pod_resources "$available_cpu" "$available_memory"
    
    # Calcular réplicas baseado no perfil e recursos
    calculate_optimal_replicas "$available_cpu" "$PERFIL"
    
    # Armazenar valores calculados
    TOTAL_CPU="$total_cores"
    TOTAL_MEMORY_MB="$total_memory_mb"
    AVAILABLE_CPU="$available_cpu"
    AVAILABLE_MEMORY_MB="$available_memory"
    SYSTEM_CPU_RESERVE="$system_cpu_reserve"
    SYSTEM_MEMORY_RESERVE_MB="$system_memory_reserve"
    K8S_CPU_RESERVE="$k8s_cpu_reserve"
    K8S_MEMORY_RESERVE_MB="$k8s_memory_reserve"
    
    log_debug "Recursos totais: CPU=$total_cores, MEM=${total_memory_mb}MB"
    log_debug "Reserva sistema: CPU=$system_cpu_reserve, MEM=${system_memory_reserve}MB"
    log_debug "Reserva K8s: CPU=$k8s_cpu_reserve, MEM=${k8s_memory_reserve}MB"
    log_debug "Disponível AWX: CPU=$available_cpu, MEM=${available_memory}MB"
    log_debug "Perfil determinado: $PERFIL ($ENVIRONMENT_TYPE)"
}

# Calcular recursos específicos para pods AWX baseado em best practices
calculate_awx_pod_resources() {
    local available_cpu=$1
    local available_memory=$2
    
    # Cálculos baseados nas recomendações da Red Hat/AWX
    case "$PERFIL" in
        "prod")
            # Produção: distribuir recursos de forma conservadora
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
            # Homologação: recursos médios
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
            # Desenvolvimento: recursos mínimos
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

# Calcular réplicas otimizadas
calculate_optimal_replicas() {
    local available_cpu=$1
    local profile=$2
    
    case "$profile" in
        "prod")
            # Produção: múltiplas réplicas para alta disponibilidade
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
            # Homologação: réplicas moderadas
            if [ "$available_cpu" -ge 4 ]; then
                WEB_REPLICAS=2
                TASK_REPLICAS=1
            else
                WEB_REPLICAS=1
                TASK_REPLICAS=1
            fi
            ;;
        "dev")
            # Desenvolvimento: única réplica
            WEB_REPLICAS=1
            TASK_REPLICAS=1
            ;;
    esac
}

# ============================
# FUNÇÃO DE EXIBIÇÃO DE RECURSOS
# ============================

show_resource_summary() {
    log_header "Resumo da Configuração de Recursos" "📊"
    
    # Tabela de recursos do sistema
    echo -e "${BOLD}${WHITE}RECURSOS DO SISTEMA:${NC}"
    echo -e "${GRAY}┌─────────────────────┬──────────────┬──────────────┬──────────────┐${NC}"
    echo -e "${GRAY}│${NC} ${BOLD}Componente${NC}          ${GRAY}│${NC} ${BOLD}Total${NC}        ${GRAY}│${NC} ${BOLD}Reservado${NC}    ${GRAY}│${NC} ${BOLD}Disponível${NC}   ${GRAY}│${NC}"
    echo -e "${GRAY}├─────────────────────┼──────────────┼──────────────┼──────────────┤${NC}"
    echo -e "${GRAY}│${NC} ${ICON_CPU} CPU (cores)      ${GRAY}│${NC} ${GREEN}$(printf "%12s" "$TOTAL_CPU")${NC} ${GRAY}│${NC} ${YELLOW}$(printf "%12s" "$((SYSTEM_CPU_RESERVE + K8S_CPU_RESERVE))")${NC} ${GRAY}│${NC} ${SUCCESS}$(printf "%12s" "$AVAILABLE_CPU")${NC} ${GRAY}│${NC}"
    echo -e "${GRAY}│${NC} ${ICON_MEMORY} Memória (MB)    ${GRAY}│${NC} ${GREEN}$(printf "%12s" "$TOTAL_MEMORY_MB")${NC} ${GRAY}│${NC} ${YELLOW}$(printf "%12s" "$((SYSTEM_MEMORY_RESERVE_MB + K8S_MEMORY_RESERVE_MB))")${NC} ${GRAY}│${NC} ${SUCCESS}$(printf "%12s" "$AVAILABLE_MEMORY_MB")${NC} ${GRAY}│${NC}"
    echo -e "${GRAY}└─────────────────────┴──────────────┴──────────────┴──────────────┘${NC}"
    
    echo ""
    
    # Configuração do AWX
    echo -e "${BOLD}${WHITE}CONFIGURAÇÃO AWX:${NC}"
    echo -e "${GRAY}┌─────────────────────┬──────────────┬──────────────┬──────────────┐${NC}"
    echo -e "${GRAY}│${NC} ${BOLD}Perfil${NC}              ${GRAY}│${NC} ${BOLD}Tipo${NC}         ${GRAY}│${NC} ${BOLD}Web Réplicas${NC} ${GRAY}│${NC} ${BOLD}Task Réplicas${NC}${GRAY}│${NC}"
    echo -e "${GRAY}├─────────────────────┼──────────────┼──────────────┼──────────────┤${NC}"
    echo -e "${GRAY}│${NC} ${SUCCESS}$(printf "%-19s" "$PERFIL")${NC} ${GRAY}│${NC} ${INFO}$(printf "%-12s" "$ENVIRONMENT_TYPE")${NC} ${GRAY}│${NC} ${PRIMARY}$(printf "%12s" "$WEB_REPLICAS")${NC} ${GRAY}│${NC} ${PRIMARY}$(printf "%12s" "$TASK_REPLICAS")${NC} ${GRAY}│${NC}"
    echo -e "${GRAY}└─────────────────────┴──────────────┴──────────────┴──────────────┘${NC}"
    
    echo ""
    
    # Recursos por pod
    echo -e "${BOLD}${WHITE}RECURSOS POR POD:${NC}"
    echo -e "${GRAY}┌─────────────────┬──────────────┬──────────────┬──────────────┬──────────────┐${NC}"
    echo -e "${GRAY}│${NC} ${BOLD}Componente${NC}      ${GRAY}│${NC} ${BOLD}CPU Request${NC}  ${GRAY}│${NC} ${BOLD}CPU Limit${NC}    ${GRAY}│${NC} ${BOLD}Mem Request${NC}  ${GRAY}│${NC} ${BOLD}Mem Limit${NC}    ${GRAY}│${NC}"
    echo -e "${GRAY}├─────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤${NC}"
    echo -e "${GRAY}│${NC} AWX Web         ${GRAY}│${NC} ${CYAN}$(printf "%12s" "$AWX_WEB_CPU_REQUEST")${NC} ${GRAY}│${NC} ${CYAN}$(printf "%12s" "$AWX_WEB_CPU_LIMIT")${NC} ${GRAY}│${NC} ${PURPLE}$(printf "%12s" "$AWX_WEB_MEMORY_REQUEST")${NC} ${GRAY}│${NC} ${PURPLE}$(printf "%12s" "$AWX_WEB_MEMORY_LIMIT")${NC} ${GRAY}│${NC}"
    echo -e "${GRAY}│${NC} AWX Task        ${GRAY}│${NC} ${CYAN}$(printf "%12s" "$AWX_TASK_CPU_REQUEST")${NC} ${GRAY}│${NC} ${CYAN}$(printf "%12s" "$AWX_TASK_CPU_LIMIT")${NC} ${GRAY}│${NC} ${PURPLE}$(printf "%12s" "$AWX_TASK_MEMORY_REQUEST")${NC} ${GRAY}│${NC} ${PURPLE}$(printf "%12s" "$AWX_TASK_MEMORY_LIMIT")${NC} ${GRAY}│${NC}"
    echo -e "${GRAY}│${NC} PostgreSQL      ${GRAY}│${NC} ${CYAN}$(printf "%12s" "$AWX_POSTGRES_CPU_REQUEST")${NC} ${GRAY}│${NC} ${CYAN}$(printf "%12s" "$AWX_POSTGRES_CPU_LIMIT")${NC} ${GRAY}│${NC} ${PURPLE}$(printf "%12s" "$AWX_POSTGRES_MEMORY_REQUEST")${NC} ${GRAY}│${NC} ${PURPLE}$(printf "%12s" "$AWX_POSTGRES_MEMORY_LIMIT")${NC} ${GRAY}│${NC}"
    echo -e "${GRAY}└─────────────────┴──────────────┴──────────────┴──────────────┴──────────────┘${NC}"
    
    echo ""
    
    # Informações de acesso
    echo -e "${BOLD}${WHITE}CONFIGURAÇÕES DE ACESSO:${NC}"
    echo -e "  ${ICON_KUBERNETES} ${BOLD}Cluster:${NC} ${SUCCESS}$CLUSTER_NAME${NC}"
    echo -e "  ${ICON_NETWORK} ${BOLD}Porta:${NC} ${SUCCESS}$HOST_PORT${NC}"
    echo -e "  ${ICON_CONFIG} ${BOLD}Namespace:${NC} ${SUCCESS}$AWX_NAMESPACE${NC}"
    
    echo ""
    echo -e "${WARNING}${ICON_WARNING}${NC} ${BOLD}Verificações:${NC}"
    
    # Validações de recursos
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
# MELHORIAS NAS FUNÇÕES EXISTENTES
# ============================

# Função melhorada de instalação de dependências com progresso
install_dependencies() {
    log_header "Instalação e Verificação de Dependências" "📦"
    
    local dependencies=("sistema" "python39" "docker" "kind" "kubectl" "helm" "ansible")
    local total=${#dependencies[@]}
    local current=0
    
    # Verificar Ubuntu
    if [[ ! -f /etc/os-release ]] || ! grep -q "Ubuntu" /etc/os-release; then
        log_warning "Este script foi testado apenas no Ubuntu. Prosseguindo..."
    fi
    
    for dep in "${dependencies[@]}"; do
        case "$dep" in
            "sistema")
                show_progress $((++current)) $total "Atualizando sistema"
                {
                    sudo apt-get update -qq
                    sudo apt-get upgrade -y
                    sudo apt-get install -y python3 python3-pip python3-venv git curl wget \
                        ca-certificates gnupg2 lsb-release build-essential \
                        software-properties-common apt-transport-https
                } > /dev/null 2>&1
                ;;
            "python39")
                show_progress $((++current)) $total "Instalando Python 3.9"
                install_python39 > /dev/null 2>&1
                ;;
            "docker")
                show_progress $((++current)) $total "Instalando Docker"
                install_docker > /dev/null 2>&1
                ;;
            "kind")
                show_progress $((++current)) $total "Instalando Kind"
                install_kind > /dev/null 2>&1
                ;;
            "kubectl")
                show_progress $((++current)) $total "Instalando kubectl"
                install_kubectl > /dev/null 2>&1
                ;;
            "helm")
                show_progress $((++current)) $total "Instalando Helm"
                install_helm > /dev/null 2>&1
                ;;
            "ansible")
                show_progress $((++current)) $total "Instalando Ansible"
                install_ansible_tools > /dev/null 2>&1
                ;;
        esac
    done
    
    check_docker_running
    start_local_registry
    
    log_success "Todas as dependências foram instaladas!"
}

# Função melhorada de criação do cluster com feedback visual
create_kind_cluster() {
    log_header "Criação do Cluster Kubernetes" "☸️"
    
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_warning "Cluster '$CLUSTER_NAME' já existe. Recriando..."
        kind delete cluster --name "$CLUSTER_NAME"
    fi
    
    log_info "Criando cluster '$CLUSTER_NAME' com configuração otimizada..."
    
    # Criar configuração do cluster baseada no perfil
    create_cluster_config
    
    # Criar cluster com spinner
    (kind create cluster --name "$CLUSTER_NAME" --config /tmp/kind-config.yaml > /dev/null 2>&1) &
    show_spinner $! "Criando cluster Kubernetes"
    
    rm /tmp/kind-config.yaml
    
    log_info "Aguardando cluster estar pronto..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    setup_local_registry
    
    log_success "Cluster criado e configurado!"
}

# Configuração otimizada do cluster baseada no perfil
create_cluster_config() {
    local worker_nodes=""
    
    # Adicionar workers para produção
    if [ "$PERFIL" = "prod" ] && [ "$AVAILABLE_CPU" -ge 6 ]; then
        worker_nodes='
- role: worker
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    maxPods: 110
    systemReserved:
      cpu: "100m"
      memory: "128Mi"
    kubeReserved:
      cpu: "100m"
      memory: "128Mi"'
    fi
    
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
          max-requests-inflight: "400"
          max-mutating-requests-inflight: "200"
  - |
    kind: KubeletConfiguration
    maxPods: 110
    systemReserved:
      cpu: "100m"
      memory: "128Mi"
    kubeReserved:
      cpu: "100m"
      memory: "128Mi"
    evictionHard:
      memory.available: "100Mi"
      nodefs.available: "10%"${worker_nodes}
EOF
}

# ============================
# CRIAÇÃO AWX COM RECURSOS CALCULADOS
# ============================

create_awx_instance() {
    log_info "Criando instância AWX com recursos otimizados..."
    
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
      cpu: ${AWX_WEB_CPU_REQUEST}
      memory: ${AWX_WEB_MEMORY_REQUEST}
    limits:
      cpu: ${AWX_WEB_CPU_LIMIT}
      memory: ${AWX_WEB_MEMORY_LIMIT}
  
  # Recursos para task containers
  task_resource_requirements:
    requests:
      cpu: ${AWX_TASK_CPU_REQUEST}
      memory: ${AWX_TASK_MEMORY_REQUEST}
    limits:
      cpu: ${AWX_TASK_CPU_LIMIT}
      memory: ${AWX_TASK_MEMORY_LIMIT}
  
  # Recursos para PostgreSQL
  postgres_resource_requirements:
    requests:
      cpu: ${AWX_POSTGRES_CPU_REQUEST}
      memory: ${AWX_POSTGRES_MEMORY_REQUEST}
    limits:
      cpu: ${AWX_POSTGRES_CPU_LIMIT}
      memory: ${AWX_POSTGRES_MEMORY_LIMIT}
  
  # Persistência otimizada
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

    kubectl apply -f /tmp/awx-instance.yaml -n "$AWX_NAMESPACE"
    rm /tmp/awx-instance.yaml
    
    log_success "Instância AWX criada com configuração otimizada!"
}

# ============================
# FUNÇÃO PRINCIPAL INTERATIVA
# ============================

main() {
    show_welcome
    
    while true; do
        show_main_menu
        choice=$(read_user_choice)
        
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
                ;;
            5)
                log_info "Saindo..."
                exit 0
                ;;
            *)
                log_error "Opção inválida. Escolha um número de 1 a 5."
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
    create_execution_environment
    install_awx
    wait_for_awx
    get_awx_password
    show_final_info
}

# ============================
# INICIALIZAÇÃO
# ============================

# Valores padrão
DEFAULT_HOST_PORT=8080
INSTALL_DEPS_ONLY=false
VERBOSE=false
FORCE_CPU=""
FORCE_MEM_MB=""
AWX_NAMESPACE="awx"

# Parse de argumentos da linha de comando (mantém compatibilidade)
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

# Aplicar padrões
HOST_PORT=${HOST_PORT:-$DEFAULT_HOST_PORT}

# Se argumentos foram passados, usar modo não-interativo
if [ $# -gt 0 ]; then
    advanced_resource_detection
    CLUSTER_NAME=${CLUSTER_NAME:-"awx-cluster-${PERFIL}"}
    
    if [ "$INSTALL_DEPS_ONLY" = true ]; then
        install_dependencies
        exit 0
    fi
    
    install_dependencies
    create_kind_cluster
    create_execution_environment
    install_awx
    wait_for_awx
    get_awx_password
    show_final_info
else
    # Modo interativo
    main
fi
