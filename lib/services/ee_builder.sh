#!/bin/bash
# lib/services/ee_builder.sh - Construção de Execution Environment

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"

# Configurações e variáveis padrão
readonly CONFIG_DIR="$(dirname "${BASH_SOURCE[0]}")/../../config"
readonly TEMPLATES_DIR="${CONFIG_DIR}/templates"
readonly EE_TEMPLATE="${TEMPLATES_DIR}/ee-config.yml.tpl"

# Função para verificar disponibilidade de ferramentas de template
check_template_tools() {
    local tools_available=""
    
    # Verifica jinja-cli
    if command -v jinja2 >/dev/null 2>&1 || command -v jinja-cli >/dev/null 2>&1; then
        tools_available="jinja"
    # Verifica envsubst
    elif command -v envsubst >/dev/null 2>&1; then
        tools_available="envsubst"
    fi
    
    echo "$tools_available"
}

# Função para processar template com jinja
process_template_jinja() {
    local template_file="$1"
    local output_file="$2"
    local data_file="$3"
    
    if command -v jinja2 >/dev/null 2>&1; then
        jinja2 "$template_file" "$data_file" > "$output_file"
    elif command -v jinja-cli >/dev/null 2>&1; then
        jinja-cli -d "$data_file" "$template_file" > "$output_file"
    else
        return 1
    fi
}

# Função para processar template com envsubst
process_template_envsubst() {
    local template_file="$1"
    local output_file="$2"
    
    envsubst < "$template_file" > "$output_file"
}

# Função para criar dados do template
create_template_data() {
    local data_file="$1"
    
    cat > "$data_file" << EOF
{
    "base_image": "${EE_BASE_IMAGE:-quay.io/ansible/awx-ee:latest}",
    "ansible_core_version": "${ANSIBLE_CORE_VERSION:-2.14.0}",
    "registry_port": "${REGISTRY_PORT:-5001}",
    "enable_sap": "${ENABLE_SAP:-true}",
    "enable_azure": "${ENABLE_AZURE:-true}",
    "enable_windows": "${ENABLE_WINDOWS:-true}",
    "enable_monitoring": "${ENABLE_MONITORING:-true}",
    "pyrfc_version": "${PYRFC_VERSION:-3.3.1}"
}
EOF
}

# Função para criar variáveis de ambiente para envsubst
set_template_vars() {
    export EE_BASE_IMAGE="${EE_BASE_IMAGE:-quay.io/ansible/awx-ee:latest}"
    export ANSIBLE_CORE_VERSION="${ANSIBLE_CORE_VERSION:-2.14.0}"
    export REGISTRY_PORT="${REGISTRY_PORT:-5001}"
    export ENABLE_SAP="${ENABLE_SAP:-true}"
    export ENABLE_AZURE="${ENABLE_AZURE:-true}"
    export ENABLE_WINDOWS="${ENABLE_WINDOWS:-true}"
    export ENABLE_MONITORING="${ENABLE_MONITORING:-true}"
    export PYRFC_VERSION="${PYRFC_VERSION:-3.3.1}"
}

# Função para processar templates usando a ferramenta disponível
process_ee_template() {
    local template_file="$1"
    local output_file="${2:-execution-environment.yml}"
    local tool_type=""
    
    # Verifica se o template existe
    if [[ ! -f "$template_file" ]]; then
        log_warning "Template $template_file não encontrado, usando fallback"
        return 1
    fi
    
    tool_type=$(check_template_tools)
    
    case "$tool_type" in
        "jinja")
            log_info "Processando template com jinja..."
            local data_file="/tmp/ee_data_$$.json"
            create_template_data "$data_file"
            
            if process_template_jinja "$template_file" "$output_file" "$data_file"; then
                rm -f "$data_file"
                log_success "Template processado com jinja"
                return 0
            else
                rm -f "$data_file"
                log_warning "Falha no processamento com jinja, tentando envsubst"
            fi
            ;;
        "envsubst")
            log_info "Processando template com envsubst..."
            set_template_vars
            
            if process_template_envsubst "$template_file" "$output_file"; then
                log_success "Template processado com envsubst"
                return 0
            else
                log_warning "Falha no processamento com envsubst"
            fi
            ;;
        "")
            log_warning "Nenhuma ferramenta de template disponível"
            ;;
    esac
    
    return 1
}

# Função fallback para criar arquivos manualmente
create_fallback_ee_files() {
    log_info "Criando arquivos de configuração EE usando fallback..."
    
    # Usa valores padrão com parameter expansion
    local base_image="${EE_BASE_IMAGE:-quay.io/ansible/awx-ee:latest}"
    local ansible_version="${ANSIBLE_CORE_VERSION:-2.14.0}"
    local registry_port="${REGISTRY_PORT:-5001}"
    local pyrfc_version="${PYRFC_VERSION:-3.3.1}"
    
    cat > execution-environment.yml << EOF
---
version: 3

images:
  base_image:
    name: ${base_image}

dependencies:
  ansible_core:
    package_pip: ansible-core==${ansible_version}
  ansible_runner:
    package_pip: ansible-runner
  
  galaxy: collections.yml
  python: requirements.txt
  system: bindep.txt

additional_build_steps:
  prepend_base:
    - RUN dnf update -y && dnf install -y epel-release
    - RUN dnf install -y python3 python3-pip python3-devel gcc gcc-c++ make
    - RUN dnf install -y krb5-devel krb5-libs krb5-workstation
    - RUN dnf install -y libxml2-devel libxslt-devel libffi-devel
    - RUN dnf install -y openssh-clients sshpass git rsync iputils bind-utils
    - RUN dnf install -y sudo which procps-ng unzip
    - RUN mkdir -p /usr/local/sap/nwrfcsdk
    - RUN mkdir -p /etc/ld.so.conf.d
    - "ENV SAPNWRFC_HOME=/usr/local/sap/nwrfcsdk"
    - "ENV LD_LIBRARY_PATH=/usr/local/sap/nwrfcsdk/lib:$LD_LIBRARY_PATH"
    - "ENV PATH=/usr/local/sap/nwrfcsdk/bin:$PATH"

  
  append_base:
    - RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel
    - RUN python3 -m pip install --no-cache-dir pyrfc==${pyrfc_version} || echo "PyRFC installation failed - SAP NW RFC SDK may be required"
    - RUN python3 -m pip install --no-cache-dir azure-cli
    - RUN mkdir -p /opt/ansible/{collections,playbooks,inventories,roles}
    - RUN echo "/usr/local/sap/nwrfcsdk/lib" > /etc/ld.so.conf.d/nwrfcsdk.conf
    - RUN ldconfig
    - RUN dnf clean all && rm -rf /var/cache/dnf
    - RUN python3 -c "import ansible; print('Ansible version:', ansible.__version__)"
    - RUN python3 -c "import pyrfc"
    - RUN mkdir -p /var/run/receptor /tmp/receptor
    - COPY --from=quay.io/ansible/receptor:v1.5.5 /usr/bin/receptor /usr/bin/receptor
    - RUN chmod +x /usr/bin/receptor
EOF

    create_collections_file
    create_requirements_file
    create_bindep_file
}

# Função para criar arquivo de coleções
create_collections_file() {
    cat > collections.yml << EOF
collections:
  - name: ansible.netcommon
  - name: ansible.utils
  - name: community.network
  - name: cisco.ios
  - name: fortinet.fortios
  - name: ansible.windows
  - name: ansible.posix
  - name: community.windows
  - name: microsoft.ad
  - name: azure.azcollection
  - name: maxhoesel.proxmox
  - name: community.docker
  - name: community.zabbix
  - name: grafana.grafana
  - name: community.crypto
  - name: community.general
  - name: community.dns
  - name: community.saplibs
  - name: ansible.eda
EOF
}

# Função para criar arquivo de requirements Python
create_requirements_file() {
    cat > requirements.txt << EOF
pyrfc==${PYRFC_VERSION:-3.3.1}
dnspython
urllib3
ncclient
netaddr
lxml
pykerberos
pywinrm
pypsrp[kerberos]
azure-cli-core
azure-common
azure-mgmt-compute
azure-mgmt-network
azure-mgmt-resource
azure-mgmt-storage
azure-identity
azure-mgmt-authorization
pyVim
PyVmomi
proxmoxer
zabbix-api
grafana-api
requests
xmltodict
cryptography
jmespath
awxkit
psutil
python-dateutil
EOF
}

# Função para criar arquivo bindep
create_bindep_file() {
    cat > bindep.txt << EOF
gcc
gcc-c++
make
python3-devel
libffi-devel
unzip
git
openssh-clients
sshpass
rsync
iputils
bind-utils
EOF
}

# Função principal para criar arquivos de configuração EE
create_optimized_ee_files() {
    log_info "Iniciando criação de arquivos de configuração EE..."
    
    # Tenta processar template primeiro
    if process_ee_template "$EE_TEMPLATE" "execution-environment.yml"; then
        log_success "Arquivos EE criados usando template"
        
        # Cria arquivos auxiliares se não existirem
        [[ ! -f "collections.yml" ]] && create_collections_file
        [[ ! -f "requirements.txt" ]] && create_requirements_file
        [[ ! -f "bindep.txt" ]] && create_bindep_file
    else
        log_info "Usando método fallback para criação de arquivos"
        create_fallback_ee_files
    fi
    
    # Verifica se todos os arquivos foram criados
    local required_files=("execution-environment.yml" "collections.yml" "requirements.txt" "bindep.txt")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Arquivo obrigatório $file não foi criado"
            return 1
        fi
    done
    
    log_success "Todos os arquivos de configuração EE foram criados"
}

# Função principal para criação do execution environment
create_execution_environment() {
    log_header "CRIAÇÃO DO EXECUTION ENVIRONMENT"
    
    # Ativa ambiente virtual se disponível
    if [[ -f "$HOME/ansible-ee-venv/bin/activate" ]]; then
        source "$HOME/ansible-ee-venv/bin/activate"
    else
        log_warning "Ambiente virtual ansible-ee-venv não encontrado"
    fi
    
    log_info "Preparando Execution Environment personalizado..."
    
    local ee_dir="/tmp/awx-ee-$(date +%s)"
    mkdir -p "$ee_dir"
    cd "$ee_dir" || exit 1
    
    # Cria arquivos de configuração
    if ! create_optimized_ee_files; then
        log_error "Falha na criação dos arquivos de configuração"
        cd - && rm -rf "$ee_dir"
        return 1
    fi
    
    local registry_port="${REGISTRY_PORT:-5001}"
    local image_tag="localhost:${registry_port}/awx-enterprise-ee:latest"
    
    log_info "Construindo Execution Environment: $image_tag"
    
    # Constrói a imagem com verbosidade configurável
    local build_cmd="ansible-builder build -t '$image_tag' -f execution-environment.yml"
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        build_cmd+=" --verbosity 2"
    fi
    
    if eval "$build_cmd"; then
        log_success "Imagem construída com sucesso"
    else
        log_error "Falha na construção da imagem"
        cd - && rm -rf "$ee_dir"
        return 1
    fi
    
    log_info "Enviando imagem para registry local..."
    if docker push "$image_tag"; then
        log_success "Imagem enviada para registry"
    else
        log_warning "Falha no envio para registry"
    fi
    
    # Verifica se a imagem está no registry
    if curl -s "http://localhost:${registry_port}/v2/_catalog" 2>/dev/null | grep -q "awx-enterprise-ee"; then
        log_success "Imagem verificada no registry"
    else
        log_warning "Verificação do registry falhou"
    fi
    
    # Limpeza
    cd - && rm -rf "$ee_dir"
    
    log_success "Execution Environment criado e enviado com sucesso!"
}

# Função para verificar pré-requisitos
check_ee_prerequisites() {
    local missing_tools=()
    
    # Verifica ansible-builder
    if ! command -v ansible-builder >/dev/null 2>&1; then
        missing_tools+=("ansible-builder")
    fi
    
    # Verifica docker
    if ! command -v docker >/dev/null 2>&1; then
        missing_tools+=("docker")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Ferramentas obrigatórias não encontradas: ${missing_tools[*]}"
        return 1
    fi
    
    return 0
}

# Função principal exportada
main() {
    if ! check_ee_prerequisites; then
        return 1
    fi
    
    create_execution_environment
}

# Executa se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
