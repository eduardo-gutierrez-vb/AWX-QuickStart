#!/bin/bash
set -e

# ============================
# CONFIGURAÇÃO E INICIALIZAÇÃO
# ============================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/awx-config.conf"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Variáveis de progresso
TOTAL_STEPS=0
CURRENT_STEP=0
STEP_START_TIME=0

# ============================
# SISTEMA DE LOGGING MELHORADO
# ============================

init_progress() {
    TOTAL_STEPS=$1
    CURRENT_STEP=0
    log_header "INICIANDO PROCESSO ($TOTAL_STEPS etapas)"
}

next_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    STEP_START_TIME=$(date +%s)
    local step_name="$1"
    local percentage=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    
    echo ""
    echo -e "${CYAN}[ETAPA $CURRENT_STEP/$TOTAL_STEPS - $percentage%]${NC} ${WHITE}$step_name${NC}"
    echo -e "${GRAY}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}${'='*60}${NC}"
}

step_completed() {
    local duration=$(($(date +%s) - STEP_START_TIME))
    echo -e "${GREEN}✓ Etapa concluída em ${duration}s${NC}"
}

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
    if [ "$VERBOSE" = true ]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

log_header() {
    echo ""
    echo -e "${CYAN}${'='*80}${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${CYAN}${'='*80}${NC}"
}

progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${BLUE}["
    printf "%*s" $completed | tr ' ' '='
    printf "%*s" $remaining | tr ' ' '-'
    printf "] %d%% (%d/%d)${NC}" $percentage $current $total
}

# ============================
# SISTEMA DE CONFIGURAÇÃO
# ============================

load_config() {
    log_info "Carregando configurações..."
    
    if [ -f "$CONFIG_FILE" ]; then
        log_success "Arquivo de configuração encontrado: $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log_warning "Arquivo de configuração não encontrado, criando padrão..."
        create_default_config
        source "$CONFIG_FILE"
    fi
    
    # Aplicar templates para gerar nomes padronizados
    apply_name_templates
    
    log_debug "Configurações carregadas:"
    log_debug "  Environment: $ENVIRONMENT_NAME"
    log_debug "  Cluster: $CLUSTER_NAME"
    log_debug "  Namespace: $AWX_NAMESPACE"
}

create_default_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# Configuração AWX - Gerada automaticamente
ENVIRONMENT_NAME="development"
PROJECT_PREFIX="awx"
ORGANIZATION="company"
DEFAULT_HOST_PORT=8080
FORCE_CPU=""
FORCE_MEM_MB=""
SAFETY_FACTOR_PROD=70
SAFETY_FACTOR_DEV=80
CLUSTER_NAME_TEMPLATE="{prefix}-cluster-{env}"
ENABLE_MULTI_NODE=true
MAX_PODS_PER_NODE=110
ADMIN_USERNAME="admin"
ADMIN_EMAIL="admin@company.com"
AWX_NAMESPACE_TEMPLATE="{prefix}-{env}"
PROJECTS_STORAGE_SIZE="8Gi"
POSTGRES_STORAGE_SIZE="8Gi"
ENABLE_PROJECTS_PERSISTENCE=true
CUSTOM_EE_NAME_TEMPLATE="{prefix}-custom-ee"
EE_BASE_IMAGE="quay.io/ansible/awx-ee:24.6.1"
PROGRESS_UPDATE_INTERVAL=10
DEPLOYMENT_TIMEOUT=600
HEALTH_CHECK_RETRIES=30
VERBOSE_DEFAULT=false
CLEANUP_ON_ERROR=true
BACKUP_BEFORE_UPGRADE=true
EOF
    log_success "Arquivo de configuração padrão criado: $CONFIG_FILE"
}

apply_name_templates() {
    # Aplicar templates usando substituição de variáveis
    CLUSTER_NAME=$(echo "$CLUSTER_NAME_TEMPLATE" | sed "s/{prefix}/$PROJECT_PREFIX/g" | sed "s/{env}/$ENVIRONMENT_NAME/g" | sed "s/{org}/$ORGANIZATION/g")
    AWX_NAMESPACE=$(echo "$AWX_NAMESPACE_TEMPLATE" | sed "s/{prefix}/$PROJECT_PREFIX/g" | sed "s/{env}/$ENVIRONMENT_NAME/g" | sed "s/{org}/$ORGANIZATION/g")
    AWX_INSTANCE_NAME="$PROJECT_PREFIX-$ENVIRONMENT_NAME"
    CUSTOM_EE_NAME=$(echo "$CUSTOM_EE_NAME_TEMPLATE" | sed "s/{prefix}/$PROJECT_PREFIX/g" | sed "s/{env}/$ENVIRONMENT_NAME/g" | sed "s/{org}/$ORGANIZATION/g")
    
    log_debug "Nomes gerados:"
    log_debug "  Cluster: $CLUSTER_NAME"
    log_debug "  Namespace: $AWX_NAMESPACE"
    log_debug "  AWX Instance: $AWX_INSTANCE_NAME"
    log_debug "  Custom EE: $CUSTOM_EE_NAME"
}

# ============================
# VALIDAÇÃO MELHORADA
# ============================

validate_config() {
    log_info "Validando configurações..."
    
    local errors=0
    
    # Validar nome do ambiente
    if [[ ! "$ENVIRONMENT_NAME" =~ ^[a-z0-9-]+$ ]]; then
        log_error "Nome do ambiente inválido: $ENVIRONMENT_NAME (use apenas letras minúsculas, números e hífens)"
        errors=$((errors + 1))
    fi
    
    # Validar porta
    if ! validate_port "$DEFAULT_HOST_PORT"; then
        errors=$((errors + 1))
    fi
    
    # Validar recursos forçados se especificados
    if [ -n "$FORCE_CPU" ] && ! validate_cpu "$FORCE_CPU"; then
        errors=$((errors + 1))
    fi
    
    if [ -n "$FORCE_MEM_MB" ] && ! validate_memory "$FORCE_MEM_MB"; then
        errors=$((errors + 1))
    fi
    
    # Validar storage sizes
    if ! validate_storage_size "$PROJECTS_STORAGE_SIZE"; then
        log_error "Tamanho de storage para projetos inválido: $PROJECTS_STORAGE_SIZE"
        errors=$((errors + 1))
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "Encontrados $errors erro(s) de configuração. Corrija e execute novamente."
        exit 1
    fi
    
    log_success "Configurações validadas com sucesso!"
}

validate_port() {
    if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
        log_error "Porta inválida: $1. Use um valor entre 1 e 65535."
        return 1
    fi
    return 0
}

validate_cpu() {
    if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ] || [ "$1" -gt 64 ]; then
        log_error "CPU inválida: $1. Use um valor entre 1 e 64."
        return 1
    fi
    return 0
}

validate_memory() {
    if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 512 ] || [ "$1" -gt 131072 ]; then
        log_error "Memória inválida: $1. Use um valor entre 512 MB e 131072 MB (128 GB)."
        return 1
    fi
    return 0
}

validate_storage_size() {
    if [[ "$1" =~ ^[0-9]+[GMKgmk]i?$ ]]; then
        return 0
    else
        return 1
    fi
}

# ============================
# DETECÇÃO E CÁLCULO DE RECURSOS MELHORADO
# ============================

initialize_resources() {
    log_info "Detectando recursos do sistema..."
    
    # Detectar recursos (considerando valores forçados se existirem)
    CORES=$([ -n "$FORCE_CPU" ] && echo "$FORCE_CPU" || nproc --all)
    MEM_MB=$([ -n "$FORCE_MEM_MB" ] && echo "$FORCE_MEM_MB" || awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    
    # Determinar perfil baseado nos recursos
    PERFIL=$(determine_profile "$CORES" "$MEM_MB")
    
    # Calcular recursos disponíveis com fator de segurança configurável
    calculate_available_resources "$CORES" "$MEM_MB" "$PERFIL"
    
    # Calcular réplicas baseado no perfil e recursos
    WEB_REPLICAS=$(calculate_replicas "$PERFIL" "$AVAILABLE_CPU_MILLICORES" "web")
    TASK_REPLICAS=$(calculate_replicas "$PERFIL" "$AVAILABLE_CPU_MILLICORES" "task")
    
    # Exibir relatório detalhado de recursos
    show_resource_report
}

determine_profile() {
    local cores=$1
    local mem_mb=$2
    
    if [ "$cores" -ge 4 ] && [ "$mem_mb" -ge 8192 ]; then
        echo "production"
    else
        echo "development"
    fi
}

calculate_available_resources() {
    local total_cores=$1
    local total_mem_mb=$2
    local profile=$3

    # Calcular reservas usando fórmulas otimizadas
    local cpu_reserved_millicores=$(calculate_cpu_reserved "$total_cores")
    local mem_reserved_mb=$(calculate_memory_reserved "$total_mem_mb")

    # Recursos disponíveis após reservas
    local available_cpu=$((total_cores * 1000 - cpu_reserved_millicores))
    local available_mem=$((total_mem_mb - mem_reserved_mb))

    # Aplicar fator de segurança configurável
    local safety_factor=$SAFETY_FACTOR_DEV
    [ "$profile" = "production" ] && safety_factor=$SAFETY_FACTOR_PROD

    available_cpu=$((available_cpu * safety_factor / 100))
    available_mem=$((available_mem * safety_factor / 100))

    # Garantir valores mínimos operacionais
    [ "$available_cpu" -lt 500 ] && available_cpu=500  # 0.5 core mínimo
    [ "$available_mem" -lt 512 ] && available_mem=512   # 512MB mínimo

    AVAILABLE_CPU_MILLICORES=$available_cpu
    AVAILABLE_MEMORY_MB=$available_mem
}

calculate_cpu_reserved() {
    local total_cores=$1
    local reserved_millicores=0

    # Fórmula baseada nas reservas padrão do GKE/EKS/AKS
    if [ "$total_cores" -ge 1 ]; then
        reserved_millicores=$((reserved_millicores + 60))  # Primeiro core: 60m
        remaining_cores=$((total_cores - 1))
    fi

    if [ "$remaining_cores" -ge 1 ]; then
        reserved_millicores=$((reserved_millicores + 10))  # Segundo core: 10m
        remaining_cores=$((remaining_cores - 1))
    fi

    if [ "$remaining_cores" -ge 2 ]; then
        reserved_millicores=$((reserved_millicores + 10))  # Próximos 2 cores: 5m cada
        remaining_cores=$((remaining_cores - 2))
    fi

    if [ "$remaining_cores" -gt 0 ]; then
        reserved_millicores=$((reserved_millicores + (remaining_cores * 25 / 10)))  # Demais: 2.5m cada
    fi

    echo $reserved_millicores
}

calculate_memory_reserved() {
    local total_mem_mb=$1
    local reserved_mb=0

    # Fórmula escalonada baseada no modelo da GKE
    if [ "$total_mem_mb" -lt 1024 ]; then
        reserved_mb=255
    else
        # 25% dos primeiros 4 GiB
        first_4gb=$((total_mem_mb > 4096 ? 4096 : total_mem_mb))
        reserved_mb=$((first_4gb * 25 / 100))
        remaining_mb=$((total_mem_mb - first_4gb))

        # 20% dos próximos 4 GiB
        if [ "$remaining_mb" -gt 0 ]; then
            next_4gb=$((remaining_mb > 4096 ? 4096 : remaining_mb))
            reserved_mb=$((reserved_mb + next_4gb * 20 / 100))
            remaining_mb=$((remaining_mb - next_4gb))
        fi

        # 10% dos próximos 8 GiB
        if [ "$remaining_mb" -gt 0 ]; then
            next_8gb=$((remaining_mb > 8192 ? 8192 : remaining_mb))
            reserved_mb=$((reserved_mb + next_8gb * 10 / 100))
            remaining_mb=$((remaining_mb - next_8gb))
        fi

        # 6% dos próximos 112 GiB
        if [ "$remaining_mb" -gt 0 ]; then
            next_112gb=$((remaining_mb > 114688 ? 114688 : remaining_mb))
            reserved_mb=$((reserved_mb + next_112gb * 6 / 100))
            remaining_mb=$((remaining_mb - next_112gb))
        fi

        # 2% do restante
        if [ "$remaining_mb" -gt 0 ]; then
            reserved_mb=$((reserved_mb + remaining_mb * 2 / 100))
        fi
    fi

    # Adicionar buffer para eviction threshold
    reserved_mb=$((reserved_mb + 100))

    echo $reserved_mb
}

calculate_replicas() {
    local profile=$1
    local available_cpu_millicores=$2
    local workload_type=$3

    local replicas=1

    if [ "$profile" = "production" ]; then
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

        # Limites operacionais
        [ "$replicas" -lt 2 ] && replicas=2
        [ "$replicas" -gt 10 ] && replicas=10
    else
        replicas=1
        [ "$available_cpu_millicores" -ge 2000 ] && replicas=2
    fi

    echo $replicas
}

show_resource_report() {
    echo ""
    log_header "RELATÓRIO DE RECURSOS DO SISTEMA"
    
    echo -e "${WHITE}Hardware Detectado:${NC}"
    echo -e "  CPUs Total: ${GREEN}$CORES${NC}"
    echo -e "  Memória Total: ${GREEN}${MEM_MB}MB ($(echo "$MEM_MB/1024" | bc)GB)${NC}"
    
    echo ""
    echo -e "${WHITE}Recursos Reservados (Sistema):${NC}"
    local cpu_reserved=$(calculate_cpu_reserved "$CORES")
    local mem_reserved=$(calculate_memory_reserved "$MEM_MB")
    echo -e "  CPU Reservada: ${YELLOW}${cpu_reserved}m ($(echo "scale=1; $cpu_reserved/1000" | bc) cores)${NC}"
    echo -e "  Memória Reservada: ${YELLOW}${mem_reserved}MB ($(echo "$mem_reserved/1024" | bc)GB)${NC}"
    
    echo ""
    echo -e "${WHITE}Recursos Disponíveis (AWX):${NC}"
    echo -e "  CPU Disponível: ${GREEN}${AVAILABLE_CPU_MILLICORES}m ($(echo "scale=1; $AVAILABLE_CPU_MILLICORES/1000" | bc) cores)${NC}"
    echo -e "  Memória Disponível: ${GREEN}${AVAILABLE_MEMORY_MB}MB ($(echo "$AVAILABLE_MEMORY_MB/1024" | bc)GB)${NC}"
    
    echo ""
    echo -e "${WHITE}Configuração Calculada:${NC}"
    echo -e "  Perfil: ${GREEN}$PERFIL${NC}"
    echo -e "  Web Réplicas: ${GREEN}$WEB_REPLICAS${NC}"
    echo -e "  Task Réplicas: ${GREEN}$TASK_REPLICAS${NC}"
    
    local safety_factor=$SAFETY_FACTOR_DEV
    [ "$PERFIL" = "production" ] && safety_factor=$SAFETY_FACTOR_PROD
    echo -e "  Fator de Segurança: ${GREEN}${safety_factor}%${NC}"
}

# ============================
# INSTALAÇÃO DO AWX MELHORADA
# ============================

install_awx() {
    next_step "Instalação do AWX Operator"
    
    log_info "Adicionando repositório Helm do AWX Operator..."
    helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ 2>/dev/null || true
    helm repo update
    
    log_info "Criando namespace '$AWX_NAMESPACE'..."
    kubectl create namespace "$AWX_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Labels padronizados para namespace
    kubectl label namespace "$AWX_NAMESPACE" \
        app.kubernetes.io/name="$PROJECT_PREFIX" \
        app.kubernetes.io/instance="$AWX_INSTANCE_NAME" \
        app.kubernetes.io/environment="$ENVIRONMENT_NAME" \
        app.kubernetes.io/managed-by="awx-deployment-script" \
        --overwrite
    
    log_info "Instalando AWX Operator com nome padronizado..."
    helm upgrade --install "$PROJECT_PREFIX-operator" awx-operator/awx-operator \
        -n "$AWX_NAMESPACE" \
        --create-namespace \
        --wait \
        --timeout=10m \
        --set nameOverride="$PROJECT_PREFIX-operator" \
        --set fullnameOverride="$PROJECT_PREFIX-operator-$ENVIRONMENT_NAME"
    
    step_completed
    
    # Criar instância AWX
    create_awx_instance
}

create_awx_instance() {
    next_step "Criação da Instância AWX"
    
    log_info "Calculando recursos para containers AWX..."
    
    # Calcular recursos baseado no perfil e disponibilidade
    local web_cpu_req="100m"
    local web_mem_req="256Mi"
    local web_cpu_lim="1000m"
    local web_mem_lim="2Gi"
    
    local task_cpu_req="100m"
    local task_mem_req="256Mi"
    local task_cpu_lim="2000m"
    local task_mem_lim="4Gi"
    
    if [ "$PERFIL" = "production" ]; then
        web_cpu_lim="2000m"
        web_mem_lim="4Gi"
        task_cpu_lim="4000m"
        task_mem_lim="8Gi"
    fi
    
    log_info "Criando manifesto AWX com configurações otimizadas..."
    
    # Criar manifesto AWX com nomes padronizados
    cat > /tmp/awx-instance.yaml << EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: $AWX_INSTANCE_NAME
  namespace: $AWX_NAMESPACE
  labels:
    app.kubernetes.io/name: $PROJECT_PREFIX
    app.kubernetes.io/instance: $AWX_INSTANCE_NAME
    app.kubernetes.io/environment: $ENVIRONMENT_NAME
    app.kubernetes.io/component: awx-instance
    app.kubernetes.io/managed-by: awx-deployment-script
spec:
  service_type: nodeport
  nodeport_port: $DEFAULT_HOST_PORT
  admin_user: $ADMIN_USERNAME
  admin_email: $ADMIN_EMAIL
  
  # Execution Environment personalizado com nome padronizado
  control_plane_ee_image: localhost:5001/$CUSTOM_EE_NAME:latest
  
  # Configuração de réplicas baseada no perfil
  replicas: $WEB_REPLICAS
  web_replicas: $WEB_REPLICAS
  task_replicas: $TASK_REPLICAS
  
  # Recursos otimizados para web containers
  web_resource_requirements:
    requests:
      cpu: $web_cpu_req
      memory: $web_mem_req
    limits:
      cpu: $web_cpu_lim
      memory: $web_mem_lim
  
  # Recursos otimizados para task containers
  task_resource_requirements:
    requests:
      cpu: $task_cpu_req
      memory: $task_mem_req
    limits:
      cpu: $task_cpu_lim
      memory: $task_mem_lim
  
  # Configurações de persistência
  projects_persistence: $ENABLE_PROJECTS_PERSISTENCE
  projects_storage_size: $PROJECTS_STORAGE_SIZE
  projects_storage_access_mode: ReadWriteOnce
  
  # Configurações do PostgreSQL com nome padronizado
  postgres_configuration_secret: $AWX_INSTANCE_NAME-postgres-configuration
  postgres_storage_requirements:
    requests:
      storage: $POSTGRES_STORAGE_SIZE
    limits:
      storage: $POSTGRES_STORAGE_SIZE
  
  # Labels adicionais para todos os recursos
  extra_labels:
    environment: $ENVIRONMENT_NAME
    project: $PROJECT_PREFIX
    organization: $ORGANIZATION
EOF

    # Aplicar manifesto
    kubectl apply -f /tmp/awx-instance.yaml -n "$AWX_NAMESPACE"
    rm /tmp/awx-instance.yaml
    
    step_completed
    log_success "Instância AWX '$AWX_INSTANCE_NAME' criada com nomes padronizados!"
}

# ============================
# MONITORAMENTO MELHORADO
# ============================

wait_for_awx() {
    next_step "Aguardando Implantação do AWX"
    
    log_info "Monitorando progresso da implantação..."
    
    local timeout=$DEPLOYMENT_TIMEOUT
    local elapsed=0
    local last_status=""
    
    # Aguardar com feedback visual melhorado
    while [ $elapsed -lt $timeout ]; do
        # Verificar status dos pods
        local pod_status=$(kubectl get pods -n "$AWX_NAMESPACE" --no-headers 2>/dev/null | grep "$AWX_INSTANCE_NAME" | head -5)
        
        if [ -n "$pod_status" ]; then
            local running_pods=$(echo "$pod_status" | grep -c "Running" || echo "0")
            local total_pods=$(echo "$pod_status" | wc -l)
            
            # Exibir progresso apenas se houver mudança
            local current_status="$running_pods/$total_pods pods Running"
            if [ "$current_status" != "$last_status" ]; then
                progress_bar $running_pods $total_pods
                echo -e " - $current_status"
                last_status="$current_status"
            fi
            
            # Verificar se todos os pods estão prontos
            if [ "$running_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
                echo ""
                log_success "Todos os pods estão funcionando!"
                break
            fi
        else
            echo -n "."
        fi
        
        sleep $PROGRESS_UPDATE_INTERVAL
        elapsed=$((elapsed + PROGRESS_UPDATE_INTERVAL))
    done
    
    if [ $elapsed -ge $timeout ]; then
        echo ""
        log_error "Timeout aguardando implantação do AWX"
        show_troubleshooting_info
        exit 1
    fi
    
    # Verificação final de saúde
    kubectl wait --for=condition=Ready pods --all -n "$AWX_NAMESPACE" --timeout=300s
    step_completed
}

show_troubleshooting_info() {
    log_header "INFORMAÇÕES PARA TROUBLESHOOTING"
    
    echo -e "${WHITE}Status dos Pods:${NC}"
    kubectl get pods -n "$AWX_NAMESPACE" -o wide 2>/dev/null || echo "Nenhum pod encontrado"
    
    echo ""
    echo -e "${WHITE}Events do Namespace:${NC}"
    kubectl get events -n "$AWX_NAMESPACE" --sort-by='.lastTimestamp' | tail -10
    
    echo ""
    echo -e "${WHITE}Comandos Úteis para Debug:${NC}"
    echo "  kubectl describe awx $AWX_INSTANCE_NAME -n $AWX_NAMESPACE"
    echo "  kubectl logs -n $AWX_NAMESPACE deployment/$PROJECT_PREFIX-operator-$ENVIRONMENT_NAME"
    echo "  kubectl get all -n $AWX_NAMESPACE"
}

# ============================
# INFORMAÇÕES FINAIS MELHORADAS
# ============================

show_final_info() {
    log_header "🎉 IMPLANTAÇÃO CONCLUÍDA COM SUCESSO"
    
    # Obter senha do AWX
    local awx_password=""
    local password_secret="$AWX_INSTANCE_NAME-admin-password"
    
    if kubectl get secret "$password_secret" -n "$AWX_NAMESPACE" &> /dev/null; then
        awx_password=$(kubectl get secret "$password_secret" -n "$AWX_NAMESPACE" -o jsonpath='{.data.password}' | base64 --decode)
    else
        awx_password="<Aguarde alguns minutos e execute: kubectl get secret $password_secret -n $AWX_NAMESPACE -o jsonpath='{.data.password}' | base64 --decode>"
    fi
    
    # Obter IP do nó
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                           AWX DEPLOYMENT SUCCESS                               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${WHITE}📋 INFORMAÇÕES DE ACESSO:${NC}"
    echo -e "   ${CYAN}URL:${NC} ${GREEN}http://${node_ip}:${DEFAULT_HOST_PORT}${NC}"
    echo -e "   ${CYAN}Usuário:${NC} ${GREEN}$ADMIN_USERNAME${NC}"
    echo -e "   ${CYAN}Senha:${NC} ${GREEN}$awx_password${NC}"
    echo ""
    
    echo -e "${WHITE}🔧 CONFIGURAÇÃO DO AMBIENTE:${NC}"
    echo -e "   ${CYAN}Environment:${NC} ${GREEN}$ENVIRONMENT_NAME${NC}"
    echo -e "   ${CYAN}Cluster:${NC} ${GREEN}$CLUSTER_NAME${NC}"
    echo -e "   ${CYAN}Namespace:${NC} ${GREEN}$AWX_NAMESPACE${NC}"
    echo -e "   ${CYAN}AWX Instance:${NC} ${GREEN}$AWX_INSTANCE_NAME${NC}"
    echo ""
    
    echo -e "${WHITE}💻 RECURSOS ALOCADOS:${NC}"
    echo -e "   ${CYAN}Perfil:${NC} ${GREEN}$PERFIL${NC}"
    echo -e "   ${CYAN}CPUs Disponíveis:${NC} ${GREEN}$(echo "scale=1; $AVAILABLE_CPU_MILLICORES/1000" | bc) cores${NC}"
    echo -e "   ${CYAN}Memória Disponível:${NC} ${GREEN}$(echo "$AVAILABLE_MEMORY_MB/1024" | bc)GB${NC}"
    echo -e "   ${CYAN}Web Réplicas:${NC} ${GREEN}$WEB_REPLICAS${NC}"
    echo -e "   ${CYAN}Task Réplicas:${NC} ${GREEN}$TASK_REPLICAS${NC}"
    echo ""
    
    echo -e "${WHITE}🚀 COMANDOS ÚTEIS:${NC}"
    echo -e "   ${CYAN}Status dos pods:${NC} kubectl get pods -n $AWX_NAMESPACE"
    echo -e "   ${CYAN}Logs AWX web:${NC} kubectl logs -n $AWX_NAMESPACE deployment/$AWX_INSTANCE_NAME-web"
    echo -e "   ${CYAN}Logs AWX task:${NC} kubectl logs -n $AWX_INSTANCE_NAME deployment/$AWX_INSTANCE_NAME-task"
    echo -e "   ${CYAN}Logs operator:${NC} kubectl logs -n $AWX_NAMESPACE deployment/$PROJECT_PREFIX-operator-$ENVIRONMENT_NAME"
    echo -e "   ${CYAN}Deletar cluster:${NC} kind delete cluster --name $CLUSTER_NAME"
    echo ""
    
    echo -e "${WHITE}📁 ARQUIVOS DE CONFIGURAÇÃO:${NC}"
    echo -e "   ${CYAN}Config:${NC} $CONFIG_FILE"
    echo -e "   ${CYAN}Script:${NC} $0"
    echo ""
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${WHITE}🔍 STATUS DETALHADO DOS RECURSOS:${NC}"
        kubectl get all -n "$AWX_NAMESPACE" -o wide
        echo ""
    fi
    
    # Salvar informações em arquivo
    save_deployment_info "$node_ip" "$awx_password"
}

save_deployment_info() {
    local node_ip=$1
    local password=$2
    local info_file="$SCRIPT_DIR/awx-deployment-info.txt"
    
    cat > "$info_file" << EOF
AWX Deployment Information
==========================
Generated: $(date)

Access Information:
- URL: http://${node_ip}:${DEFAULT_HOST_PORT}
- Username: $ADMIN_USERNAME
- Password: $password

Environment Configuration:
- Environment: $ENVIRONMENT_NAME
- Cluster: $CLUSTER_NAME
- Namespace: $AWX_NAMESPACE
- AWX Instance: $AWX_INSTANCE_NAME

Resource Allocation:
- Profile: $PERFIL
- Available CPUs: $(echo "scale=1; $AVAILABLE_CPU_MILLICORES/1000" | bc) cores
- Available Memory: $(echo "$AVAILABLE_MEMORY_MB/1024" | bc)GB
- Web Replicas: $WEB_REPLICAS
- Task Replicas: $TASK_REPLICAS

Useful Commands:
- kubectl get pods -n $AWX_NAMESPACE
- kubectl logs -n $AWX_NAMESPACE deployment/$AWX_INSTANCE_NAME-web
- kubectl logs -n $AWX_NAMESPACE deployment/$AWX_INSTANCE_NAME-task
- kind delete cluster --name $CLUSTER_NAME
EOF
    
    log_success "Informações salvas em: $info_file"
}

# ============================
# FUNÇÃO PRINCIPAL
# ============================

main() {
    # Inicializar sistema de progresso
    init_progress 8
    
    # Carregar e validar configurações
    next_step "Carregamento de Configurações"
    load_config
    validate_config
    step_completed
    
    # Inicializar recursos
    next_step "Detecção de Recursos do Sistema"
    initialize_resources
    step_completed
    
    # Instalar dependências (implementar função similar ao original)
    next_step "Instalação de Dependências"
    install_dependencies  # Manter função original
    step_completed
    
    # Criar cluster Kind (implementar função similar ao original)
    next_step "Criação do Cluster Kind"
    create_kind_cluster  # Manter função original
    step_completed
    
    # Criar Execution Environment (implementar função similar ao original)
    next_step "Criação do Execution Environment"
    create_execution_environment  # Manter função original
    step_completed
    
    # Instalar AWX
    install_awx
    
    # Aguardar implantação
    wait_for_awx
    
    # Exibir informações finais
    next_step "Finalização e Relatório"
    show_final_info
    step_completed
    
    echo ""
    log_success "🎉 Processo concluído com sucesso em $(date)!"
}

# ============================
# PARSING DE ARGUMENTOS E EXECUÇÃO
# ============================

show_help() {
    cat << EOF
${CYAN}=== Script de Implantação AWX Melhorado ===${NC}

${WHITE}USO:${NC}
    $0 [OPÇÕES]

${WHITE}OPÇÕES:${NC}
    ${GREEN}-e AMBIENTE${NC}   Nome do ambiente (ex: prod, dev, test)
    ${GREEN}-p PORTA${NC}      Porta do host para acessar AWX
    ${GREEN}-c CLUSTER${NC}    Nome do cluster Kind (opcional)
    ${GREEN}-f CPU${NC}        Forçar número de CPUs
    ${GREEN}-m MEMORIA${NC}    Forçar quantidade de memória em MB
    ${GREEN}-d${NC}            Instalar apenas dependências
    ${GREEN}-v${NC}            Modo verboso (debug)
    ${GREEN}-h${NC}            Exibir esta ajuda

${WHITE}CONFIGURAÇÃO:${NC}
    O script usa o arquivo 'awx-config.conf' para configurações.
    Se não existir, um arquivo padrão será criado automaticamente.

${WHITE}EXEMPLOS:${NC}
    $0                           # Usar configurações padrão
    $0 -e production -p 8080     # Ambiente production na porta 8080
    $0 -f 4 -m 8192 -v          # Forçar recursos com modo verboso
    $0 -d                        # Instalar apenas dependências

${WHITE}RECURSOS:${NC}
    O script detecta automaticamente os recursos e calcula a configuração
    ideal baseada no ambiente detectado/especificado.
EOF
}

# Parse das opções
INSTALL_DEPS_ONLY=false
VERBOSE=${VERBOSE_DEFAULT:-false}

while getopts "e:p:c:f:m:dvh" opt; do
    case ${opt} in
        e)
            ENVIRONMENT_NAME="$OPTARG"
            ;;
        p)
            DEFAULT_HOST_PORT="$OPTARG"
            ;;
        c)
            CLUSTER_NAME="$OPTARG"
            ;;
        f)
            FORCE_CPU="$OPTARG"
            ;;
        m)
            FORCE_MEM_MB="$OPTARG"
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

# Execução principal
if [ "$INSTALL_DEPS_ONLY" = true ]; then
    log_header "INSTALAÇÃO DE DEPENDÊNCIAS"
    install_dependencies
    log_success "Dependências instaladas! Execute sem -d para continuar."
else
    main
fi
