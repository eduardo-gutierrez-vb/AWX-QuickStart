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

# Diretório base do script
SCRIPT_DIR="https://raw.githubusercontent.com/eduardo-gutierrez-vb/AWX-QuickStart/refs/heads/main"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

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
    # Inicializar recursos
    initialize_resource_calculations
    export_resource_variables
    
    # Configurações derivadas
    DEFAULT_CLUSTER_NAME="awx-cluster-$PERFIL"
    
    # Processar argumentos
    while getopts "c:p:f:m:dvh" opt; do
        case $opt in
            c)
                if [[ -z "$OPTARG" ]]; then
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
                initialize_resource_calculations
                export_resource_variables
                DEFAULT_CLUSTER_NAME="awx-cluster-$PERFIL"
                ;;
            m)
                if ! validate_memory "$OPTARG"; then
                    exit 1
                fi
                FORCE_MEM_MB="$OPTARG"
                initialize_resource_calculations
                export_resource_variables
                DEFAULT_CLUSTER_NAME="awx-cluster-$PERFIL"
                ;;
            d)
                INSTALL_DEPS_ONLY="true"
                ;;
            v)
                VERBOSE="true"
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
    
    # Configurar variáveis finais
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
    
    log_info "Configuração de Implantação:"
    log_info "Ambiente: ${GREEN}$PERFIL${NC}"
    log_info "Cluster: ${GREEN}$CLUSTER_NAME${NC}"
    log_info "Porta: ${GREEN}$HOST_PORT${NC}"
    log_info "Namespace: ${GREEN}$AWX_NAMESPACE${NC}"
    log_info "Web Réplicas: ${GREEN}$WEB_REPLICAS${NC}"
    log_info "Task Réplicas: ${GREEN}$TASK_REPLICAS${NC}"
    log_info "Verbose: ${GREEN}$VERBOSE${NC}"
    
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
}

# Executar função principal
main "$@"
