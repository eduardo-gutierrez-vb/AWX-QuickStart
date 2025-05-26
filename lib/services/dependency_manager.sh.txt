#!/bin/bash
# lib/services/dependency_manager.sh - Gerenciamento de dependências

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/validator.sh"

install_dependencies() {
    log_header "VERIFICAÇÃO E INSTALAÇÃO DE DEPENDÊNCIAS"
    
    validate_operating_system
    
    log_info "Atualizando sistema..."
    sudo apt-get update -qq
    sudo apt-get upgrade -y
    
    log_info "Instalando dependências básicas..."
    sudo apt-get install -y \
        python3 python3-pip python3-venv git curl wget \
        ca-certificates gnupg2 lsb-release build-essential \
        software-properties-common apt-transport-https \
        bc jq lsof
    
    install_python39
    install_docker
    install_kind
    install_kubectl
    install_helm
    install_ansible_tools
    check_docker_running
    start_local_registry
    
    log_success "Todas as dependências foram instaladas e verificadas!"
}

install_python39() {
    if command_exists python3.9; then
        log_info "Python 3.9 já está instalado"
        python3.9 --version
        return 0
    fi
    
    log_info "Instalando Python 3.9..."
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt-get update -qq
    sudo apt-get install -y python3.9 python3.9-venv python3.9-distutils python3.9-dev
    
    curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
    sudo python3.9 /tmp/get-pip.py
    rm /tmp/get-pip.py
    
    log_success "Python 3.9 instalado com sucesso"
    python3.9 --version
}

install_docker() {
    if command_exists docker; then
        log_info "Docker já está instalado"
        docker --version
        
        if ! user_in_docker_group; then
            log_warning "Usuário não está no grupo docker. Adicionando..."
            sudo usermod -aG docker "$USER"
            log_warning "ATENÇÃO: Você precisa fazer logout e login novamente para as mudanças de grupo terem efeito."
            log_warning "Ou execute: newgrp docker"
        fi
        return 0
    fi
    
    log_info "Instalando Docker..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker instalado com sucesso!"
    log_warning "ATENÇÃO: Você precisa fazer logout e login novamente para as mudanças de grupo terem efeito."
}

install_kind() {
    if command_exists kind; then
        log_info "Kind já está instalado"
        kind version
        return 0
    fi
    
    log_info "Instalando Kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    
    log_success "Kind instalado com sucesso"
    kind version
}

install_kubectl() {
    if command_exists kubectl; then
        log_info "kubectl já está instalado"
        kubectl version --client --short 2>/dev/null || kubectl version --client
        return 0
    fi
    
    log_info "Instalando kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    log_success "kubectl instalado com sucesso"
    kubectl version --client --short 2>/dev/null || kubectl version --client
}

install_helm() {
    if command_exists helm; then
        log_info "Helm já está instalado"
        helm version --short
        return 0
    fi
    
    log_info "Instalando Helm..."
    curl -fsSL https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update -qq
    sudo apt-get install -y helm
    
    log_success "Helm instalado com sucesso"
    helm version --short
}

install_ansible_tools() {
    if [[ -d "$HOME/ansible-ee-venv" ]]; then
        log_info "Ambiente virtual Ansible já existe"
        source "$HOME/ansible-ee-venv/bin/activate"
    else
        log_info "Criando ambiente virtual Python para Ansible..."
        python3.9 -m venv "$HOME/ansible-ee-venv"
        source "$HOME/ansible-ee-venv/bin/activate"
    fi
    
    if command_exists ansible; then
        log_info "Ansible já está instalado"
        ansible --version | head -n1
    else
        log_info "Instalando Ansible e ansible-builder..."
        pip install --upgrade pip
        pip install ansible==7.0.0 ansible-builder==3.0.0
        
        log_success "Ansible e ansible-builder instalados com sucesso!"
    fi
}

check_docker_running() {
    if ! docker info &>/dev/null; then
        log_error "Docker não está funcionando. Verificando..."
        
        if ! user_in_docker_group; then
            log_error "Usuário não está no grupo docker. Execute: newgrp docker"
            log_error "Ou faça logout/login e execute o script novamente."
            exit 1
        fi
        
        if ! systemctl is-active --quiet docker; then
            log_info "Iniciando Docker..."
            sudo systemctl start docker
            sleep 5
        fi
        
        if ! docker info &>/dev/null; then
            log_error "Não foi possível conectar ao Docker. Verifique a instalação."
            exit 1
        fi
    fi
    
    log_success "Docker está funcionando corretamente!"
}

start_local_registry() {
    if docker ps | grep -q kind-registry; then
        log_info "Registry local já está rodando"
        return 0
    fi
    
    log_info "Iniciando registry local para Kind..."
    docker run -d --restart=always -p "${REGISTRY_PORT:-5001}:5000" --name kind-registry registry:2
    
    if docker network ls | grep -q kind; then
        docker network connect kind kind-registry 2>/dev/null || true
    fi
    
    log_success "Registry local iniciado em localhost:${REGISTRY_PORT:-5001}"
}
