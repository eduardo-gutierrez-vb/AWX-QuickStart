#!/bin/bash
# lib/services/ee_builder.sh - Construção de Execution Environment

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"

create_optimized_ee_files() {
    log_info "Criando arquivos de configuração EE otimizados..."
    
    cat > execution-environment.yml << EOF
---
version: 3

images:
  base_image:
    name: quay.io/ansible/awx-ee:latest

dependencies:
  ansible_core:
    package_pip: ansible-core==2.14.0
  ansible_runner:
    package_pip: ansible-runner
  
  galaxy: collections.yml
  python: requirements.txt
  system: bindep.txt

additional_build_steps:
  prepend_base:
    # Ferramentas SAP específicas quando disponíveis
    - RUN dnf update -y && dnf install -y epel-release
    # Atualização do sistema e instalação de repositórios
    - RUN dnf install -y python3 python3-pip python3-devel gcc gcc-c++ make
    - RUN dnf install -y krb5-devel krb5-libs krb5-workstation
    - RUN dnf install -y libxml2-devel libxslt-devel libffi-devel
    - RUN dnf install -y openssh-clients sshpass git rsync iputils bind-utils
    - RUN dnf install -y sudo which procps-ng unzip
    # Instalação de ferramentas de desenvolvimento
    - RUN mkdir -p /usr/local/sap/nwrfcsdk
    - RUN mkdir -p /etc/ld.so.conf.d
    # Preparação para SAP NW RFC SDK
    - ENV SAPNWRFC_HOME=/usr/local/sap/nwrfcsdk
    - ENV LD_LIBRARY_PATH=/usr/local/sap/nwrfcsdk/lib:\$LD_LIBRARY_PATH
    - ENV PATH=/usr/local/sap/nwrfcsdk/bin:\$PATH
  
  append_base:
    # Configuração de environment variables para SAP
    - RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel
    # Atualização do pip e ferramentas Python
    - RUN python3 -m pip install --no-cache-dir pyrfc==3.3.1 || echo "PyRFC installation failed - SAP NW RFC SDK may be required"
    # Instalação específica do PyRFC com versão fixa
    - RUN python3 -m pip install --no-cache-dir azure-cli
    # Instalação do Azure CLI
    - RUN mkdir -p /opt/ansible/{collections,playbooks,inventories,roles}
    # Configuração de diretórios Ansible
    - RUN echo "/usr/local/sap/nwrfcsdk/lib" > /etc/ld.so.conf.d/nwrfcsdk.conf
    - RUN ldconfig
    # Configuração do ldconfig para SAP libraries
    - RUN dnf clean all && rm -rf /var/cache/dnf
    # Limpeza do sistema
    - RUN python3 -c "import ansible; print('Ansible version:', ansible.__version__)"
    - RUN python3 -c "try: import pyrfc; print('PyRFC successfully imported') except ImportError as e: print('PyRFC import failed:', e)"
    # Verificação das instalações
    - RUN mkdir -p /var/run/receptor /tmp/receptor
    - COPY --from=quay.io/ansible/receptor:v1.5.5 /usr/bin/receptor /usr/bin/receptor
    - RUN chmod +x /usr/bin/receptor
EOF

    cat > collections.yml << EOF
collections:
  # Coleções de rede e conectividade
  - name: ansible.netcommon
  - name: ansible.utils
  - name: community.network
  - name: cisco.ios
  - name: fortinet.fortios
  
  # Coleções de sistema operacional
  - name: ansible.windows
  - name: ansible.posix
  - name: community.windows
  - name: microsoft.ad
  
  # Coleções de cloud e virtualização
  - name: azure.azcollection
  - name: maxhoesel.proxmox
  - name: community.docker
  
  # Coleções de monitoramento e observabilidade
  - name: community.zabbix
  - name: grafana.grafana
  
  # Coleções de segurança e criptografia
  - name: community.crypto
  
  # Coleções utilitárias
  - name: community.general
  - name: community.dns
  - name: community.saplibs
  - name: ansible.eda
EOF

    cat > requirements.txt << EOF
# Dependências SAP específicas
pyrfc==3.3.1

# Dependências de rede e conectividade
dnspython
urllib3
ncclient
netaddr
lxml

# Dependências Windows e autenticação
pykerberos
pywinrm
pypsrp[kerberos]

# Dependências Azure
azure-cli-core
azure-common
azure-mgmt-compute
azure-mgmt-network
azure-mgmt-resource
azure-mgmt-storage
azure-identity
azure-mgmt-authorization

# Dependências de virtualização
pyVim
PyVmomi
proxmoxer

# Dependências de monitoramento
zabbix-api
grafana-api

# Dependências gerais
requests
xmltodict
cryptography
jmespath
awxkit

# Dependências adicionais para AWX
psutil
python-dateutil
EOF

    cat > bindep.txt << EOF
# Dependências para compilação Python C extensions
gcc
gcc-c++
make
python3-devel
libffi-devel

# Ferramentas de desenvolvimento para compilação
unzip
git
openssh-clients
sshpass
rsync
iputils
bind-utils
EOF
}

create_execution_environment() {
    log_header "CRIAÇÃO DO EXECUTION ENVIRONMENT"
    source "$HOME/ansible-ee-venv/bin/activate"
    
    log_info "Preparando Execution Environment personalizado..."
    
    EE_DIR="/tmp/awx-ee-$(date +%s)"
    mkdir -p "$EE_DIR"
    cd "$EE_DIR"
    
    create_optimized_ee_files
    
    log_info "Construindo Execution Environment personalizado..."
    if [[ "$VERBOSE" == "true" ]]; then
        ansible-builder build -t "localhost:${REGISTRY_PORT:-5001}/awx-enterprise-ee:latest" \
            -f execution-environment.yml --verbosity 2
    else
        ansible-builder build -t "localhost:${REGISTRY_PORT:-5001}/awx-enterprise-ee:latest" \
            -f execution-environment.yml
    fi
    
    log_info "Enviando imagem para registry local..."
    docker push "localhost:${REGISTRY_PORT:-5001}/awx-enterprise-ee:latest"
    
    curl -s "http://localhost:${REGISTRY_PORT:-5001}/v2/_catalog" 2>/dev/null | grep awx-enterprise-ee || \
        log_warning "Registry verification failed"
    
    cd - && rm -rf "$EE_DIR"
    
    log_success "Execution Environment criado e enviado com sucesso!"
}
