#!/bin/bash
# lib/services/ee_builder.sh - Construção de Execution Environment Otimizada

# Importar dependências necessárias
source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/validator.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"

# Configurações do módulo
readonly EE_MODULE_NAME="ee_builder"
source "$(dirname "${BASH_SOURCE[0]}")/../config/templates"
readonly EE_TEMP_DIR="/tmp/awx-ee-$(date +%s)"

# Variáveis de configuração
EE_IMAGE_TAG="${EE_IMAGE_TAG:-awx-enterprise-ee:latest}"
EE_BASE_IMAGE="${EE_BASE_IMAGE:-quay.io/ansible/awx-ee:latest}"
ANSIBLE_CORE_VERSION="${ANSIBLE_CORE_VERSION:-2.14.0}"

# Função para validar pré-requisitos do módulo
validate_ee_prerequisites() {
    log_debug "Validando pré-requisitos para construção de EE..."
    
    # Verificar se ansible-builder está disponível
    if ! command -v ansible-builder &> /dev/null; then
        log_error "ansible-builder não encontrado. Execute install_dependencies primeiro."
        return 1
    fi
    
    # Verificar se docker está executando
    if ! docker info &> /dev/null; then
        log_error "Docker não está executando ou não está acessível."
        return 1
    fi
    
    # Verificar se o registry local está ativo
    if ! curl -s "http://localhost:${REGISTRY_PORT:-5001}/v2/" &> /dev/null; then
        log_error "Registry local não está disponível na porta ${REGISTRY_PORT:-5001}"
        return 1
    fi
    
    # Verificar se os templates existem
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        log_error "Diretório de templates não encontrado: $TEMPLATES_DIR"
        return 1
    fi
    
    log_debug "Todos os pré-requisitos validados com sucesso"
    return 0
}

# Função para processar templates com substituição de variáveis
process_template() {
    local template_file="$1"
    local output_file="$2"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template não encontrado: $template_file"
        return 1
    fi
    
    log_debug "Processando template: $template_file -> $output_file"
    
    # Criar mapa de substituições baseado em variáveis de ambiente
    local substitutions=(
        "s/\${REGISTRYPORT}/${REGISTRY_PORT:-5001}/g"
        "s/\${HOSTPORT}/${HOST_PORT:-8080}/g"
        "s/\${PERFIL}/${PERFIL:-dev}/g"
        "s/\${AWXNAMESPACE}/${AWX_NAMESPACE:-awx}/g"
        "s/\${WEBREPLICAS}/${WEB_REPLICAS:-1}/g"
        "s/\${TASKREPLICAS}/${TASK_REPLICAS:-1}/g"
        "s/\${AWXWEBCPUREQ}/${WEB_CPU_REQ:-500m}/g"
        "s/\${AWXWEBCPULIM}/${WEB_CPU_LIM:-1000m}/g"
        "s/\${AWXWEBMEMREQ}/${WEB_MEM_REQ:-1Gi}/g"
        "s/\${AWXWEBMEMLIM}/${WEB_MEM_LIM:-2Gi}/g"
        "s/\${AWXTASKCPUREQ}/${TASK_CPU_REQ:-1000m}/g"
        "s/\${AWXTASKCPULIM}/${TASK_CPU_LIM:-2000m}/g"
        "s/\${AWXTASKMEMREQ}/${TASK_MEM_REQ:-2Gi}/g"
        "s/\${AWXTASKMEMLIM}/${TASK_MEM_LIM}/g"
        "s/\${ANSIBLE_CORE_VERSION}/${ANSIBLE_CORE_VERSION}/g"
        "s/\${EE_BASE_IMAGE}/${EE_BASE_IMAGE}/g"
    )
    
    # Aplicar substituições usando sed
    local temp_content
    temp_content=$(cat "$template_file")
    
    for substitution in "${substitutions[@]}"; do
        temp_content=$(echo "$temp_content" | sed "$substitution")
    done
    
    echo "$temp_content" > "$output_file"
    
    if [[ $? -eq 0 ]]; then
        log_debug "Template processado com sucesso: $output_file"
        return 0
    else
        log_error "Falha ao processar template: $template_file"
        return 1
    fi
}

# Função para preparar arquivos de configuração EE
prepare_ee_configuration() {
    log_info "Preparando arquivos de configuração do Execution Environment..."
    
    # Criar diretório temporário para construção
    mkdir -p "$EE_TEMP_DIR" || {
        log_error "Falha ao criar diretório temporário: $EE_TEMP_DIR"
        return 1
    }
    
    cd "$EE_TEMP_DIR" || {
        log_error "Falha ao acessar diretório: $EE_TEMP_DIR"
        return 1
    }
    
    # Processar template principal do EE
    if ! process_template "$TEMPLATES_DIR/ee-config.yml.tpl" "execution-environment.yml"; then
        log_error "Falha ao processar template execution-environment.yml"
        return 1
    fi
    
    # Copiar arquivos de dependências dos templates
    local template_files=(
        "requirements.txt"
        "bindep.txt"
        "collections.yml"
    )
    
    for file in "${template_files[@]}"; do
        if [[ -f "$TEMPLATES_DIR/$file" ]]; then
            cp "$TEMPLATES_DIR/$file" "./$file" || {
                log_error "Falha ao copiar arquivo: $file"
                return 1
            }
            log_debug "Arquivo copiado: $file"
        else
            log_warning "Arquivo template não encontrado: $TEMPLATES_DIR/$file"
        fi
    done
    
    # Validar arquivos de configuração
    if ! validate_ee_configuration; then
        log_error "Validação dos arquivos de configuração falhou"
        return 1
    fi
    
    log_success "Arquivos de configuração preparados com sucesso"
    return 0
}

# Função para validar configuração do EE
validate_ee_configuration() {
    log_debug "Validando configuração do Execution Environment..."
    
    # Verificar se todos os arquivos necessários existem
    local required_files=(
        "execution-environment.yml"
        "requirements.txt"
        "bindep.txt"
        "collections.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Arquivo obrigatório não encontrado: $file"
            return 1
        fi
    done
    
    # Validar sintaxe YAML do arquivo principal
    if command -v yamllint &> /dev/null; then
        if ! yamllint execution-environment.yml &> /dev/null; then
            log_warning "Validação YAML detectou problemas em execution-environment.yml"
        fi
    fi
    
    log_debug "Configuração do EE validada com sucesso"
    return 0
}

# Função principal para construção do EE
build_execution_environment() {
    local image_tag="localhost:${REGISTRY_PORT:-5001}/${EE_IMAGE_TAG}"
    
    log_info "Construindo Execution Environment: $image_tag"
    
    # Preparar argumentos do ansible-builder
    local build_args=(
        "build"
        "-t" "$image_tag"
        "-f" "execution-environment.yml"
        "--container-runtime" "docker"
    )
    
    # Adicionar verbosidade se solicitado
    if [[ "$VERBOSE" == "true" ]]; then
        build_args+=("--verbosity" "2")
    fi
    
    # Executar construção
    if ansible-builder "${build_args[@]}"; then
        log_success "Execution Environment construído com sucesso"
    else
        log_error "Falha na construção do Execution Environment"
        return 1
    fi
    
    return 0
}

# Função para publicar EE no registry
publish_execution_environment() {
    local image_tag="localhost:${REGISTRY_PORT:-5001}/${EE_IMAGE_TAG}"
    
    log_info "Publicando Execution Environment no registry local..."
    
    if docker push "$image_tag"; then
        log_success "Execution Environment publicado com sucesso"
    else
        log_error "Falha ao publicar Execution Environment"
        return 1
    fi
    
    # Verificar se a imagem está disponível no registry
    if curl -s "http://localhost:${REGISTRY_PORT:-5001}/v2/_catalog" | grep -q "awx-enterprise-ee"; then
        log_info "Verification: Imagem confirmada no registry"
    else
        log_warning "Verification: Imagem pode não estar disponível no registry"
    fi
    
    return 0
}

# Função para limpeza de recursos temporários
cleanup_ee_build() {
    log_debug "Executando limpeza de recursos do EE builder..."
    
    if [[ -d "$EE_TEMP_DIR" ]]; then
        rm -rf "$EE_TEMP_DIR" || log_warning "Falha ao remover diretório temporário: $EE_TEMP_DIR"
    fi
    
    # Remover imagens Docker temporárias se solicitado
    if [[ "$CLEANUP_DOCKER_IMAGES" == "true" ]]; then
        docker image prune -f &> /dev/null || log_warning "Falha na limpeza de imagens Docker"
    fi
}

# Função principal do módulo
create_execution_environment() {
    log_header "CRIAÇÃO DO EXECUTION ENVIRONMENT"
    
    # Configurar trap para limpeza em caso de erro
    trap cleanup_ee_build EXIT ERR
    
    # Ativar ambiente virtual se disponível
    if [[ -f "$HOME/ansible-ee-venv/bin/activate" ]]; then
        source "$HOME/ansible-ee-venv/bin/activate" || {
            log_error "Falha ao ativar ambiente virtual"
            return 1
        }
    fi
    
    # Executar validações
    if ! validate_ee_prerequisites; then
        log_error "Validação de pré-requisitos falhou"
        return 1
    fi
    
    # Preparar configuração
    if ! prepare_ee_configuration; then
        log_error "Preparação da configuração falhou"
        return 1
    fi
    
    # Construir Execution Environment
    if ! build_execution_environment; then
        log_error "Construção do Execution Environment falhou"
        return 1
    fi
    
    # Publicar no registry
    if ! publish_execution_environment; then
        log_error "Publicação do Execution Environment falhou"
        return 1
    fi
    
    log_success "Execution Environment criado e publicado com sucesso!"
    return 0
}

# Exportar funções principais
export -f create_execution_environment
export -f validate_ee_prerequisites
export -f process_template
