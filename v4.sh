#!/bin/bash
set -e

# ============================
# CONFIGURAÇÃO E CONSTANTES
# ============================

# Arquivo de configuração personalizável
CONFIG_FILE="${HOME}/.awx-installer.conf"
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="AWX Installer"

# Cores para output
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [PURPLE]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [WHITE]='\033[1;37m'
    [GRAY]='\033[0;37m'
    [NC]='\033[0m'
)

# ============================
# SISTEMA DE LOGGING AVANÇADO
# ============================

# Função para log com timestamp e níveis
log_with_level() {
    local level=$1
    local color=$2
    local message=$3
    local timestamp=$(date '+%H:%M:%S')
    echo -e "${color}[$timestamp][$level]${COLORS[NC]} $message"
}

log_info() {
    log_with_level "INFO" "${COLORS[BLUE]}" "$1"
}

log_success() {
    log_with_level "SUCCESS" "${COLORS[GREEN]}" "$1"
}

log_warning() {
    log_with_level "WARNING" "${COLORS[YELLOW]}" "$1"
}

log_error() {
    log_with_level "ERROR" "${COLORS[RED]}" "$1"
}

log_debug() {
    [ "$VERBOSE" = true ] && log_with_level "DEBUG" "${COLORS[PURPLE]}" "$1"
}

log_step() {
    echo -e "${COLORS[CYAN]}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLORS[NC]}"
    echo -e "${COLORS[WHITE]}🔧 $1${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLORS[NC]}"
}

# Progress bar melhorado
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${COLORS[CYAN]}%-30s${COLORS[NC]} [" "$message"
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '░'
    printf "] %d%%" $percentage
    
    if [ $current -eq $total ]; then
        echo -e " ${COLORS[GREEN]}✓${COLORS[NC]}"
    fi
}

# Spinner para operações longas
show_spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    echo -n "$message "
    while kill -0 $pid 2>/dev/null; do
        printf "\b${spin:i++%${#spin}:1}"
        sleep 0.1
    done
    echo -e "\b${COLORS[GREEN]}✓${COLORS[NC]}"
}

# ============================
# CONFIGURAÇÃO PERSONALIZÁVEL
# ============================

# Criar arquivo de configuração padrão
create_default_config() {
    cat > "$CONFIG_FILE" << EOF
# Configuração do AWX Installer v$SCRIPT_VERSION
# Edite este arquivo para personalizar a instalação

[CLUSTER]
# Nome do cluster (deixe vazio para auto-gerar baseado no perfil)
CLUSTER_NAME=""

# Porta do host para acessar AWX
HOST_PORT=8080

# Namespace do AWX
AWX_NAMESPACE="awx"

[RESOURCES]
# Forçar número de CPUs (deixe vazio para auto-detectar)
FORCE_CPU=""

# Forçar quantidade de memória em MB (deixe vazio para auto-detectar)
FORCE_MEM_MB=""

# Fator de segurança para recursos (70-90, menor = mais conservador)
SAFETY_FACTOR_PROD=70
SAFETY_FACTOR_DEV=80

[AWX]
# Versão do AWX Operator
AWX_OPERATOR_VERSION="2.19.1"

# Versão da imagem base do Execution Environment
EE_BASE_IMAGE="quay.io/ansible/awx-ee:24.6.1"

# Nome da imagem personalizada do EE
EE_CUSTOM_IMAGE="localhost:5001/awx-custom-ee:latest"

# Timeout para aguardar pods (em segundos)
POD_WAIT_TIMEOUT=600

[STORAGE]
# Tamanho do storage para projetos
PROJECTS_STORAGE_SIZE="8Gi"

# Tamanho do storage para PostgreSQL
POSTGRES_STORAGE_SIZE="8Gi"

[ADVANCED]
# Habilitar registry local
ENABLE_LOCAL_REGISTRY=true

# Porta do registry local
REGISTRY_PORT=5001

# Limpar recursos existentes antes de instalar
CLEAN_BEFORE_INSTALL=false

# Aguardar confirmação para operações destrutivas
CONFIRM_DESTRUCTIVE_OPERATIONS=true
EOF
    log_success "Arquivo de configuração criado em: $CONFIG_FILE"
}

# Carregar configuração
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_info "Criando arquivo de configuração padrão..."
        create_default_config
    fi
    
    # Carregar configurações usando source com validação
    if ! source "$CONFIG_FILE" 2>/dev/null; then
        log_error "Erro ao carregar configuração de $CONFIG_FILE"
        exit 1
    fi
    
    log_debug "Configuração carregada de: $CONFIG_FILE"
}

# ============================
# VALIDAÇÃO ROBUSTA
# ============================

# Validação aprimorada de recursos
validate_system_requirements() {
    log_step "VALIDAÇÃO DOS REQUISITOS DO SISTEMA"
    
    local errors=0
    
    # Verificar sistema operacional
    if [[ ! -f /etc/os-release ]] || ! grep -q "Ubuntu\|Debian" /etc/os-release; then
        log_warning "Sistema não testado. Recomendado: Ubuntu 20.04+"
    fi
    
    # Verificar versão do kernel
    local kernel_version=$(uname -r | cut -d. -f1-2)
    if ! (( $(echo "$kernel_version >= 5.4" | bc -l) )); then
        log_warning "Kernel antigo detectado: $kernel_version. Recomendado: 5.4+"
    fi
    
    # Verificar espaço em disco
    local disk_space=$(df / | awk 'NR==2 {print $4}')
    local disk_space_gb=$((disk_space / 1024 / 1024))
    
    if [ "$disk_space_gb" -lt 20 ]; then
        log_error "Espaço em disco insuficiente: ${disk_space_gb}GB. Mínimo: 20GB"
        ((errors++))
    else
        log_success "Espaço em disco: ${disk_space_gb}GB ✓"
    fi
    
    # Verificar arquitetura
    local arch=$(uname -m)
    if [ "$arch" != "x86_64" ]; then
        log_error "Arquitetura não suportada: $arch. Requerido: x86_64"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "Encontrados $errors erro(s) nos requisitos do sistema"
        exit 1
    fi
    
    log_success "Todos os requisitos do sistema atendidos ✓"
}

# ============================
# CÁLCULOS DE RECURSOS VISUAIS
# ============================

# Exibir tabela de recursos do sistema
show_system_resources() {
    log_step "ANÁLISE DE RECURSOS DO SISTEMA"
    
    local total_cores=$(detect_cores)
    local total_mem_mb=$(detect_mem_mb)
    local profile=$(determine_profile "$total_cores" "$total_mem_mb")
    
    # Calcular reservas e recursos disponíveis
    local cpu_reserved_millicores=$(calculate_cpu_reserved "$total_cores")
    local mem_reserved_mb=$(calculate_memory_reserved "$total_mem_mb")
    
    local available_cpu=$((total_cores * 1000 - cpu_reserved_millicores))
    local available_mem=$((total_mem_mb - mem_reserved_mb))
    
    # Aplicar fator de segurança
    local safety_factor
    if [ "$profile" = "prod" ]; then
        safety_factor=${SAFETY_FACTOR_PROD:-70}
    else
        safety_factor=${SAFETY_FACTOR_DEV:-80}
    fi
    
    local usable_cpu=$((available_cpu * safety_factor / 100))
    local usable_mem=$((available_mem * safety_factor / 100))
    
    # Exibir tabela formatada
    echo ""
    echo -e "${COLORS[CYAN]}┌─────────────────────────────────────────────────────────────────┐${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}│${COLORS[WHITE]}                    RECURSOS DO SISTEMA                          ${COLORS[CYAN]}│${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}├─────────────────────────────────────────────────────────────────┤${COLORS[NC]}"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-20s │ %-15s │ %-15s │ %-8s ${COLORS[CYAN]}│${COLORS[NC]}\n" "Recurso" "Total" "Disponível" "Usável"
    echo -e "${COLORS[CYAN]}├─────────────────────────────────────────────────────────────────┤${COLORS[NC]}"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-20s │ %-15s │ %-15s │ %-8s ${COLORS[CYAN]}│${COLORS[NC]}\n" "CPU (cores)" "$total_cores" "$(echo "scale=2; $available_cpu/1000" | bc)" "$(echo "scale=2; $usable_cpu/1000" | bc)"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-20s │ %-15s │ %-15s │ %-8s ${COLORS[CYAN]}│${COLORS[NC]}\n" "Memória (MB)" "$total_mem_mb" "$available_mem" "$usable_mem"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-20s │ %-15s │ %-15s │ %-8s ${COLORS[CYAN]}│${COLORS[NC]}\n" "Perfil" "$profile" "-" "-"
    echo -e "${COLORS[CYAN]}└─────────────────────────────────────────────────────────────────┘${COLORS[NC]}"
    echo ""
    
    # Exibir recomendações baseadas no perfil
    if [ "$profile" = "prod" ]; then
        echo -e "${COLORS[GREEN]}🚀 Perfil PRODUÇÃO detectado:${COLORS[NC]}"
        echo -e "   • Múltiplas réplicas habilitadas"
        echo -e "   • Alta disponibilidade configurada"
        echo -e "   • Recursos otimizados para cargas de trabalho"
    else
        echo -e "${COLORS[YELLOW]}🧪 Perfil DESENVOLVIMENTO detectado:${COLORS[NC]}"
        echo -e "   • Configuração otimizada para desenvolvimento"
        echo -e "   • Menor consumo de recursos"
        echo -e "   • Réplica única para componentes"
    fi
    echo ""
    
    # Salvar valores calculados em variáveis globais
    export CALCULATED_PROFILE="$profile"
    export CALCULATED_CORES="$total_cores"
    export CALCULATED_MEM_MB="$total_mem_mb"
    export CALCULATED_USABLE_CPU_MILLICORES="$usable_cpu"
    export CALCULATED_USABLE_MEM_MB="$usable_mem"
}

# ============================
# INSTALAÇÃO COM NOMES FIXOS
# ============================

# Instalação do AWX Operator com nomes determinísticos
install_awx_operator_fixed() {
    log_step "INSTALAÇÃO DO AWX OPERATOR (NOMES FIXOS)"
    
    log_info "Criando namespace..."
    kubectl create namespace "$AWX_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Criar manifesto personalizado com nomes fixos
    local operator_name="awx-operator"
    local operator_deployment="awx-operator-controller"
    
    log_info "Baixando e customizando manifesto do AWX Operator..."
    
    # Baixar manifesto oficial
    curl -s https://raw.githubusercontent.com/ansible/awx-operator/${AWX_OPERATOR_VERSION}/config/default/kustomization.yaml > /tmp/kustomization.yaml
    
    # Criar manifesto customizado com nomes fixos
    cat > /tmp/awx-operator-custom.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${AWX_NAMESPACE}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${operator_deployment}
  namespace: ${AWX_NAMESPACE}
  labels:
    app.kubernetes.io/name: awx-operator
    app.kubernetes.io/version: "${AWX_OPERATOR_VERSION}"
    app.kubernetes.io/component: operator
    app.kubernetes.io/managed-by: kubectl
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: awx-operator
  template:
    metadata:
      labels:
        app.kubernetes.io/name: awx-operator
        app.kubernetes.io/version: "${AWX_OPERATOR_VERSION}"
    spec:
      serviceAccountName: awx-operator
      containers:
      - name: manager
        image: quay.io/ansible/awx-operator:${AWX_OPERATOR_VERSION}
        resources:
          limits:
            cpu: 1000m
            memory: 768Mi
          requests:
            cpu: 100m
            memory: 256Mi
        env:
        - name: WATCH_NAMESPACE
          value: "${AWX_NAMESPACE}"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: OPERATOR_NAME
          value: "${operator_name}"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: awx-operator
  namespace: ${AWX_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: awx-operator
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["awx.ansible.com"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: awx-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: awx-operator
subjects:
- kind: ServiceAccount
  name: awx-operator
  namespace: ${AWX_NAMESPACE}
EOF

    log_info "Aplicando manifesto customizado..."
    kubectl apply -f /tmp/awx-operator-custom.yaml
    
    # Aguardar operator estar pronto
    log_info "Aguardando AWX Operator estar pronto..."
    kubectl wait --for=condition=Available deployment/${operator_deployment} -n "$AWX_NAMESPACE" --timeout=300s
    
    # Verificar se está funcionando
    local pod_count=$(kubectl get pods -n "$AWX_NAMESPACE" -l app.kubernetes.io/name=awx-operator --no-headers | wc -l)
    if [ "$pod_count" -eq 0 ]; then
        log_error "Nenhum pod do AWX Operator encontrado"
        exit 1
    fi
    
    local ready_pods=$(kubectl get pods -n "$AWX_NAMESPACE" -l app.kubernetes.io/name=awx-operator --no-headers | grep -c "Running")
    if [ "$ready_pods" -eq 0 ]; then
        log_error "AWX Operator não está em execução"
        kubectl get pods -n "$AWX_NAMESPACE" -l app.kubernetes.io/name=awx-operator
        exit 1
    fi
    
    log_success "AWX Operator instalado com nome fixo: $operator_deployment"
    rm -f /tmp/awx-operator-custom.yaml /tmp/kustomization.yaml
}

# ============================
# MONITORAMENTO AVANÇADO
# ============================

# Monitorar instalação com feedback em tempo real
monitor_awx_installation() {
    log_step "MONITORAMENTO DA INSTALAÇÃO AWX"
    
    local awx_name="awx-${CALCULATED_PROFILE}"
    local timeout=${POD_WAIT_TIMEOUT:-600}
    local check_interval=10
    local elapsed=0
    
    log_info "Monitorando instalação do AWX: $awx_name"
    
    # Aguardar AWX resource ser criado
    while ! kubectl get awx "$awx_name" -n "$AWX_NAMESPACE" &>/dev/null; do
        if [ $elapsed -ge 60 ]; then
            log_error "Timeout aguardando resource AWX ser criado"
            exit 1
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        show_progress $elapsed 60 "Aguardando AWX resource"
    done
    
    echo ""
    log_success "Resource AWX criado com sucesso"
    
    # Monitorar componentes individuais
    local components=("postgres" "web" "task")
    
    for component in "${components[@]}"; do
        log_info "Aguardando componente: $component"
        elapsed=0
        
        while [ $elapsed -lt $timeout ]; do
            local pod_count=$(kubectl get pods -n "$AWX_NAMESPACE" -l "app.kubernetes.io/name=awx-${CALCULATED_PROFILE},app.kubernetes.io/component=$component" --no-headers 2>/dev/null | wc -l)
            local ready_count=$(kubectl get pods -n "$AWX_NAMESPACE" -l "app.kubernetes.io/name=awx-${CALCULATED_PROFILE},app.kubernetes.io/component=$component" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
            
            if [ "$pod_count" -gt 0 ] && [ "$ready_count" -eq "$pod_count" ]; then
                log_success "Componente $component pronto ($ready_count/$pod_count pods)"
                break
            fi
            
            show_progress $elapsed $timeout "Componente $component ($ready_count/$pod_count pods prontos)"
            sleep $check_interval
            elapsed=$((elapsed + check_interval))
        done
        
        if [ $elapsed -ge $timeout ]; then
            log_error "Timeout aguardando componente: $component"
            kubectl get pods -n "$AWX_NAMESPACE" -l "app.kubernetes.io/name=awx-${CALCULATED_PROFILE},app.kubernetes.io/component=$component"
            exit 1
        fi
    done
    
    echo ""
    log_success "Todos os componentes AWX estão funcionando!"
}

# ============================
# INTERFACE DE USUÁRIO MELHORADA
# ============================

# Menu interativo para configuração
interactive_setup() {
    log_step "CONFIGURAÇÃO INTERATIVA"
    
    echo -e "${COLORS[CYAN]}Bem-vindo ao $SCRIPT_NAME v$SCRIPT_VERSION!${COLORS[NC]}"
    echo ""
    
    # Mostrar configuração atual
    echo -e "${COLORS[WHITE]}Configuração atual:${COLORS[NC]}"
    echo -e "  Cluster: ${COLORS[GREEN]}${CLUSTER_NAME:-auto}${COLORS[NC]}"
    echo -e "  Porta: ${COLORS[GREEN]}$HOST_PORT${COLORS[NC]}"
    echo -e "  Namespace: ${COLORS[GREEN]}$AWX_NAMESPACE${COLORS[NC]}"
    echo ""
    
    # Permitir alterações
    read -p "Deseja alterar alguma configuração? (s/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        read -p "Nome do cluster (Enter para auto): " input_cluster
        [ -n "$input_cluster" ] && CLUSTER_NAME="$input_cluster"
        
        read -p "Porta do host [$HOST_PORT]: " input_port
        if [ -n "$input_port" ] && validate_port "$input_port"; then
            HOST_PORT="$input_port"
        fi
        
        read -p "Namespace [$AWX_NAMESPACE]: " input_namespace
        [ -n "$input_namespace" ] && AWX_NAMESPACE="$input_namespace"
    fi
    
    # Confirmar instalação
    echo ""
    echo -e "${COLORS[YELLOW]}Configuração final:${COLORS[NC]}"
    echo -e "  Cluster: ${COLORS[GREEN]}${CLUSTER_NAME:-awx-cluster-$CALCULATED_PROFILE}${COLORS[NC]}"
    echo -e "  Porta: ${COLORS[GREEN]}$HOST_PORT${COLORS[NC]}"
    echo -e "  Namespace: ${COLORS[GREEN]}$AWX_NAMESPACE${COLORS[NC]}"
    echo ""
    
    if [ "$CONFIRM_DESTRUCTIVE_OPERATIONS" = true ]; then
        read -p "Continuar com a instalação? (S/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_info "Instalação cancelada pelo usuário"
            exit 0
        fi
    fi
}

# Exibir informações finais melhoradas
show_installation_summary() {
    log_step "INSTALAÇÃO CONCLUÍDA COM SUCESSO"
    
    # Obter informações do cluster
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    local awx_name="awx-${CALCULATED_PROFILE}"
    
    # Obter senha
    local password=""
    if kubectl get secret "${awx_name}-admin-password" -n "$AWX_NAMESPACE" &>/dev/null; then
        password=$(kubectl get secret "${awx_name}-admin-password" -n "$AWX_NAMESPACE" -o jsonpath='{.data.password}' | base64 --decode)
    fi
    
    # Obter status dos pods
    local total_pods=$(kubectl get pods -n "$AWX_NAMESPACE" --no-headers | wc -l)
    local running_pods=$(kubectl get pods -n "$AWX_NAMESPACE" --no-headers | grep -c "Running" || echo "0")
    
    echo ""
    echo -e "${COLORS[GREEN]}🎉 AWX INSTALADO COM SUCESSO! 🎉${COLORS[NC]}"
    echo ""
    
    # Tabela de informações de acesso
    echo -e "${COLORS[CYAN]}┌─────────────────────────────────────────────────────────────────┐${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}│${COLORS[WHITE]}                     INFORMAÇÕES DE ACESSO                       ${COLORS[CYAN]}│${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}├─────────────────────────────────────────────────────────────────┤${COLORS[NC]}"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-15s │ %-45s ${COLORS[CYAN]}│${COLORS[NC]}\n" "URL:" "http://${node_ip}:${HOST_PORT}"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-15s │ %-45s ${COLORS[CYAN]}│${COLORS[NC]}\n" "Usuário:" "admin"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-15s │ %-45s ${COLORS[CYAN]}│${COLORS[NC]}\n" "Senha:" "${password:-'Obtendo...'}"
    echo -e "${COLORS[CYAN]}└─────────────────────────────────────────────────────────────────┘${COLORS[NC]}"
    echo ""
    
    # Tabela de status do sistema
    echo -e "${COLORS[CYAN]}┌─────────────────────────────────────────────────────────────────┐${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}│${COLORS[WHITE]}                      STATUS DO SISTEMA                          ${COLORS[CYAN]}│${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}├─────────────────────────────────────────────────────────────────┤${COLORS[NC]}"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-15s │ %-45s ${COLORS[CYAN]}│${COLORS[NC]}\n" "Cluster:" "${CLUSTER_NAME:-awx-cluster-$CALCULATED_PROFILE}"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-15s │ %-45s ${COLORS[CYAN]}│${COLORS[NC]}\n" "Namespace:" "$AWX_NAMESPACE"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-15s │ %-45s ${COLORS[CYAN]}│${COLORS[NC]}\n" "Perfil:" "$CALCULATED_PROFILE"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-15s │ %-45s ${COLORS[CYAN]}│${COLORS[NC]}\n" "Pods:" "$running_pods/$total_pods rodando"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-15s │ %-45s ${COLORS[CYAN]}│${COLORS[NC]}\n" "CPUs:" "${CALCULATED_CORES} cores"
    printf "${COLORS[CYAN]}│${COLORS[NC]} %-15s │ %-45s ${COLORS[CYAN]}│${COLORS[NC]}\n" "Memória:" "${CALCULATED_MEM_MB}MB"
    echo -e "${COLORS[CYAN]}└─────────────────────────────────────────────────────────────────┘${COLORS[NC]}"
    echo ""
    
    # Comandos úteis
    echo -e "${COLORS[WHITE]}📋 COMANDOS ÚTEIS:${COLORS[NC]}"
    echo -e "${COLORS[GRAY]}  # Ver todos os pods${COLORS[NC]}"
    echo -e "  ${COLORS[CYAN]}kubectl get pods -n $AWX_NAMESPACE${COLORS[NC]}"
    echo ""
    echo -e "${COLORS[GRAY]}  # Ver logs do operator (nome fixo)${COLORS[NC]}"
    echo -e "  ${COLORS[CYAN]}kubectl logs -n $AWX_NAMESPACE deployment/awx-operator-controller${COLORS[NC]}"
    echo ""
    echo -e "${COLORS[GRAY]}  # Ver logs do AWX web${COLORS[NC]}"
    echo -e "  ${COLORS[CYAN]}kubectl logs -n $AWX_NAMESPACE deployment/${awx_name}-web${COLORS[NC]}"
    echo ""
    echo -e "${COLORS[GRAY]}  # Ver logs do AWX task${COLORS[NC]}"
    echo -e "  ${COLORS[CYAN]}kubectl logs -n $AWX_NAMESPACE deployment/${awx_name}-task${COLORS[NC]}"
    echo ""
    echo -e "${COLORS[GRAY]}  # Deletar cluster${COLORS[NC]}"
    echo -e "  ${COLORS[CYAN]}kind delete cluster --name ${CLUSTER_NAME:-awx-cluster-$CALCULATED_PROFILE}${COLORS[NC]}"
    echo ""
    echo -e "${COLORS[GRAY]}  # Editar configuração${COLORS[NC]}"
    echo -e "  ${COLORS[CYAN]}nano $CONFIG_FILE${COLORS[NC]}"
    echo ""
    
    # Status detalhado se verbose
    if [ "$VERBOSE" = true ]; then
        echo -e "${COLORS[WHITE]}🔍 STATUS DETALHADO DOS PODS:${COLORS[NC]}"
        kubectl get pods -n "$AWX_NAMESPACE" -o wide
        echo ""
    fi
    
    # Salvar informações em arquivo
    cat > "${HOME}/awx-installation-info.txt" << EOF
AWX Installation Summary
========================
Date: $(date)
URL: http://${node_ip}:${HOST_PORT}
Username: admin
Password: ${password}
Cluster: ${CLUSTER_NAME:-awx-cluster-$CALCULATED_PROFILE}
Namespace: ${AWX_NAMESPACE}
Profile: ${CALCULATED_PROFILE}
Pods: ${running_pods}/${total_pods} running

Configuration file: ${CONFIG_FILE}
EOF
    
    log_info "Informações salvas em: ${HOME}/awx-installation-info.txt"
}

# ============================
# FUNCÕES ORIGINAIS MANTIDAS
# ============================

# [Manter todas as funções de cálculo de recursos originais]
# [Manter funções de validação]
# [Manter funções de instalação de dependências]
# [etc...]

# ============================
# EXECUÇÃO PRINCIPAL MELHORADA
# ============================

main() {
    # Carregar configuração
    load_config
    
    # Parse dos argumentos (manter original)
    while getopts "c:p:f:m:dvhio" opt; do
        case ${opt} in
            i)
                interactive_setup
                ;;
            o)
                log_info "Editando arquivo de configuração..."
                ${EDITOR:-nano} "$CONFIG_FILE"
                load_config
                ;;
            # [outros casos mantidos]
        esac
    done
    
    # Validar sistema
    validate_system_requirements
    
    # Mostrar recursos do sistema
    show_system_resources
    
    # Confirmar se não foi modo interativo
    if [ "$INTERACTIVE" != true ]; then
        interactive_setup
    fi
    
    # Executar instalação com feedback melhorado
    log_step "INICIANDO INSTALAÇÃO COMPLETA"
    
    local total_steps=7
    local current_step=0
    
    # Passo 1: Dependências
    ((current_step++))
    show_progress $current_step $total_steps "Instalando dependências"
    install_dependencies
    
    # Passo 2: Cluster
    ((current_step++))
    show_progress $current_step $total_steps "Criando cluster Kind"
    create_kind_cluster
    
    # Passo 3: Registry
    ((current_step++))
    show_progress $current_step $total_steps "Configurando registry"
    start_local_registry
    
    # Passo 4: Execution Environment
    ((current_step++))
    show_progress $current_step $total_steps "Criando Execution Environment"
    create_execution_environment
    
    # Passo 5: AWX Operator
    ((current_step++))
    show_progress $current_step $total_steps "Instalando AWX Operator"
    install_awx_operator_fixed
    
    # Passo 6: AWX Instance
    ((current_step++))
    show_progress $current_step $total_steps "Criando instância AWX"
    create_awx_instance
    
    # Passo 7: Monitoramento
    ((current_step++))
    show_progress $current_step $total_steps "Finalizando instalação"
    monitor_awx_installation
    
    # Exibir resumo final
    show_installation_summary
}

# Executar função principal
main "$@"
