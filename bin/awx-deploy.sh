#!/bin/bash
# bin/awx-deploy - Script principal executável

set -e

# Configuração de cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Verificar e clonar repositório se necessário
REPO_DIR="AWX-QuickStart"
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${BLUE}Clonando repositório AWX-QuickStart...${NC}"
    git clone https://github.com/eduardo-gutierrez-vb/AWX-QuickStart.git "$REPO_DIR"
else
    echo -e "${YELLOW}Repositório já existe, atualizando...${NC}"
    cd "$REPO_DIR"
    git pull origin main || git pull origin master
    cd ..
fi

# Entrar no diretório do projeto
cd "$REPO_DIR"

# Diretório base do script (agora dentro do repositório)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Importar módulos com verificação
import_module() {
    local module="$1"
    if [ -f "$module" ]; then
        source "$module"
    else
        echo -e "${RED}Erro: Módulo não encontrado: $module${NC}"
        exit 1
    fi
}

# Importar módulos
source "$LIB_DIR/core/logger.sh"
source "$LIB_DIR/core/validator.sh"
source "$LIB_DIR/core/resource_calculator.sh"
source "$LIB_DIR/services/dependency_manager.sh"
source "$LIB_DIR/services/kind_manager.sh"
source "$LIB_DIR/services/ee_builder.sh"
source "$LIB_DIR/services/awx_installer.sh"

# Configurações padrão
REGISTRY_PORT=${REGISTRY_PORT:-5001}
DEFAULT_HOST_PORT=8080

# Variáveis globais
INSTALL_DEPS_ONLY="false"
VERBOSE="false"
FORCE_CPU=""
FORCE_MEM_MB=""

# Função para exportar variáveis de recursos calculados
export_resource_variables() {
    # Exportar variáveis do sistema
    export CORES="${SYSTEM_RESOURCES[CPU_CORES]}"
    export MEM_MB="${SYSTEM_RESOURCES[MEMORY_MB]}"
    export PERFIL="${SYSTEM_RESOURCES[PROFILE]}"
    
    export SCRIPT_DIR

    # Exportar recursos disponíveis
    export AVAILABLE_CPU_MILLICORES="${AVAILABLE_RESOURCES[CPU_MILLICORES]}"
    export AVAILABLE_MEMORY_MB="${AVAILABLE_RESOURCES[MEMORY_MB]}"
    
    # Exportar configurações AWX
    export WEB_REPLICAS="${AWX_RESOURCES[WEB_REPLICAS]}"
    export TASK_REPLICAS="${AWX_RESOURCES[TASK_REPLICAS]}"
    export WEB_CPU_REQ="${AWX_RESOURCES[WEB_CPU_REQ]}"
    export WEB_CPU_LIM="${AWX_RESOURCES[WEB_CPU_LIM]}"
    export WEB_MEM_REQ="${AWX_RESOURCES[WEB_MEM_REQ]}"
    export WEB_MEM_LIM="${AWX_RESOURCES[WEB_MEM_LIM]}"
    export TASK_CPU_REQ="${AWX_RESOURCES[TASK_CPU_REQ]}"
    export TASK_CPU_LIM="${AWX_RESOURCES[TASK_CPU_LIM]}"
    export TASK_MEM_REQ="${AWX_RESOURCES[TASK_MEM_REQ]}"
    export TASK_MEM_LIM="${AWX_RESOURCES[TASK_MEM_LIM]}"
}

show_help() {
    cat << EOF
${CYAN}Script de Implantação AWX com Kind${NC}

${WHITE}USO:${NC}
    $0 [OPÇÕES...]

${WHITE}OPÇÕES:${NC}
    ${GREEN}-c NOME${NC}      Nome do cluster Kind (padrão será calculado baseado no perfil)
    ${GREEN}-p PORTA${NC}     Porta do host para acessar AWX (padrão: 8080)
    ${GREEN}-f CPU${NC}       Forçar número de CPUs (ex: 4)
    ${GREEN}-m MEMORIA${NC}   Forçar quantidade de memória em MB (ex: 8192)
    ${GREEN}-d${NC}           Instalar apenas dependências
    ${GREEN}-v${NC}           Modo verboso (debug)
    ${GREEN}-h${NC}           Exibir esta ajuda

${WHITE}EXEMPLOS:${NC}
    $0                      Usar valores padrão
    $0 -c meu-cluster -p 8080    Cluster personalizado na porta 8080
    $0 -f 4 -m 8192         Forçar 4 CPUs e 8GB RAM
    $0 -d                   Instalar apenas dependências
    $0 -v -c test-cluster   Modo verboso com cluster personalizado
EOF
}

main() {
    # Processar argumentos primeiro para capturar FORCE_CPU e FORCE_MEM_MB
    while getopts "c:p:f:m:dvh" opt; do
        case $opt in
            c)
                if [[ -z "$OPTARG" ]]; then
                    echo -e "${RED}Erro: Nome do cluster não pode estar vazio${NC}"
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
                FORCE_MEM_MB="$OPTARG"
                ;;
            d)
                INSTALL_DEPS_ONLY="true"
                ;;
            v)
                VERBOSE="true"
                export LOG_LEVEL="debug"
                ;;
            h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Erro: Opção inválida: -$OPTARG${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    shift $((OPTIND - 1))
    
    # Inicializar recursos do sistema
    detect_system_resources
    calculate_available_resources
    calculate_awx_resources
    export_resource_variables
    
    # Configurações derivadas (após calcular recursos)
    DEFAULT_CLUSTER_NAME="awx-cluster-$PERFIL"
    CLUSTER_NAME="${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}"
    HOST_PORT="${HOST_PORT:-$DEFAULT_HOST_PORT}"
    AWX_NAMESPACE="awx"
    
    # Validar parâmetros
    validate_input_parameters "$CLUSTER_NAME" "$HOST_PORT" "$FORCE_CPU" "$FORCE_MEM_MB"
    
    log_header "INICIANDO IMPLANTAÇÃO AWX"
    
    log_info "Recursos do Sistema:"
    log_info "CPUs: ${GREEN}$CORES${NC}"
    log_info "Memória: ${GREEN}$MEM_MB MB${NC}"
    log_info "Perfil: ${GREEN}$PERFIL${NC}"
    
    log_info "Recursos Disponíveis:"
    log_info "CPU Disponível: ${GREEN}$AVAILABLE_CPU_MILLICORES m${NC}"
    log_info "Memória Disponível: ${GREEN}$AVAILABLE_MEMORY_MB MB${NC}"
    
    log_info "Configuração de Implantação:"
    log_info "Ambiente: ${GREEN}$PERFIL${NC}"
    log_info "Cluster: ${GREEN}$CLUSTER_NAME${NC}"
    log_info "Porta: ${GREEN}$HOST_PORT${NC}"
    log_info "Namespace: ${GREEN}$AWX_NAMESPACE${NC}"
    log_info "Web Réplicas: ${GREEN}$WEB_REPLICAS${NC}"
    log_info "Task Réplicas: ${GREEN}$TASK_REPLICAS${NC}"
    log_info "Verbose: ${GREEN}$VERBOSE${NC}"
    
    log_info "Recursos AWX Calculados:"
    log_info "Web CPU: ${GREEN}$WEB_CPU_REQ${NC} - ${GREEN}$WEB_CPU_LIM${NC}"
    log_info "Web Memória: ${GREEN}$WEB_MEM_REQ${NC} - ${GREEN}$WEB_MEM_LIM${NC}"
    log_info "Task CPU: ${GREEN}$TASK_CPU_REQ${NC} - ${GREEN}$TASK_CPU_LIM${NC}"
    log_info "Task Memória: ${GREEN}$TASK_MEM_REQ${NC} - ${GREEN}$TASK_MEM_LIM${NC}"
    
    # Executar instalação
    install_dependencies
    
    if [[ "$INSTALL_DEPS_ONLY" == "true" ]]; then
        log_success "Dependências instaladas com sucesso!"
        log_info "Execute o script novamente sem a opção -d para instalar o AWX"
        exit 0
    fi
    
    create_kind_cluster
    create_execution_environment
    install_awx
    create_awx_instance
    wait_for_awx
    get_awx_password
    show_final_info
    
    log_success "Instalação do AWX concluída com sucesso!"
    
    # Retornar ao diretório pai e cleanup opcional
    cd ../
    log_info "Instalação finalizada. Diretório de trabalho: $(pwd)"
}

# Executar função principal
main "$@"
