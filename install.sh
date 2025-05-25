#!/bin/bash
set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
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

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para verificar se usuário está no grupo docker
user_in_docker_group() {
    groups | grep -q docker
}

# Função para instalar Docker
install_docker() {
    if command_exists docker; then
        log_info "Docker já está instalado: $(docker --version)"
        if ! user_in_docker_group; then
            log_warning "Usuário não está no grupo docker. Adicionando..."
            sudo usermod -aG docker $USER
            log_warning "ATENÇÃO: Você precisa fazer logout e login novamente para as mudanças de grupo terem efeito."
            log_warning "Ou execute: newgrp docker"
        fi
        return 0
    fi

    log_info "Instalando Docker..."
    
    # Atualizar cache de pacotes
    sudo apt-get update -q
    
    # Instalar dependências
    sudo apt-get install -y ca-certificates curl
    
    # Criar diretório para keyrings
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Adicionar chave GPG do Docker
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    # Adicionar repositório
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Atualizar cache e instalar Docker
    sudo apt-get update -q
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Adicionar usuário ao grupo docker
    sudo usermod -aG docker $USER
    
    # Iniciar e habilitar Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker instalado com sucesso!"
    log_warning "ATENÇÃO: Você precisa fazer logout e login novamente para as mudanças de grupo terem efeito."
    log_warning "Ou execute: newgrp docker"
}

# Função para instalar Kind
install_kind() {
    if command_exists kind; then
        log_info "Kind já está instalado: $(kind version)"
        return 0
    fi

    log_info "Instalando Kind..."
    
    # Download do Kind
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    
    log_success "Kind instalado com sucesso: $(kind version)"
}

# Função para instalar kubectl
install_kubectl() {
    if command_exists kubectl; then
        log_info "kubectl já está instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return 0
    fi

    log_info "Instalando kubectl..."
    
    # Download do kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    log_success "kubectl instalado com sucesso: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# Função para instalar Helm
install_helm() {
    if command_exists helm; then
        log_info "Helm já está instalado: $(helm version --short)"
        return 0
    fi

    log_info "Instalando Helm..."
    
    # Adicionar chave GPG do Helm
    curl -fsSL https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    
    # Instalar apt-transport-https se necessário
    sudo apt-get install -y apt-transport-https
    
    # Adicionar repositório do Helm
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    
    # Atualizar e instalar Helm
    sudo apt-get update -q
    sudo apt-get install -y helm
    
    log_success "Helm instalado com sucesso: $(helm version --short)"
}

# Função para verificar se Docker está funcionando
check_docker_running() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker não está funcionando. Verificando..."
        
        if ! user_in_docker_group; then
            log_error "Usuário não está no grupo docker. Execute: newgrp docker"
            log_error "Ou faça logout/login e execute o script novamente."
            exit 1
        fi
        
        # Tentar iniciar Docker se não estiver rodando
        if ! systemctl is-active --quiet docker; then
            log_info "Iniciando Docker..."
            sudo systemctl start docker
            sleep 5
        fi
        
        if ! docker info >/dev/null 2>&1; then
            log_error "Não foi possível conectar ao Docker. Verifique a instalação."
            exit 1
        fi
    fi
    log_success "Docker está funcionando corretamente!"
}

# Função principal de instalação de dependências
install_dependencies() {
    log_info "Verificando e instalando dependências..."
    
    # Verificar se estamos no Ubuntu
    if [[ ! -f /etc/os-release ]] || ! grep -q "Ubuntu" /etc/os-release; then
        log_warning "Este script foi testado apenas no Ubuntu. Prosseguindo mesmo assim..."
    fi
    
    # Instalar dependências
    install_docker
    install_kind
    install_kubectl
    install_helm
    
    # Verificar se Docker está funcionando
    check_docker_running
    
    log_success "Todas as dependências foram instaladas e verificadas!"
}

# Função para exibir ajuda
show_help() {
    cat << EOF
Uso: $0 [OPÇÕES]

OPÇÕES:
    -c NOME     Nome do cluster Kind (padrão: awx-cluster-prd)
    -p PORTA    Porta do host para acessar AWX (padrão: 8080)
    -d          Instalar apenas dependências
    -h          Exibir esta ajuda

EXEMPLOS:
    $0                          # Usar valores padrão
    $0 -c meu-cluster -p 9090   # Cluster personalizado na porta 9090
    $0 -d                       # Instalar apenas dependências

DEPENDÊNCIAS:
    - Docker
    - Kind
    - kubectl
    - Helm

Este script irá verificar e instalar automaticamente todas as dependências necessárias.
EOF
}

# Default values
DEFAULT_CLUSTER_NAME="awx-cluster-prd"
DEFAULT_HOST_PORT=8080
INSTALL_DEPS_ONLY=false

# Parse command-line options
while getopts "c:p:dh" opt; do
  case ${opt} in
    c)
      CLUSTER_NAME="$OPTARG"
      ;;
    p)
      HOST_PORT="$OPTARG"
      ;;
    d)
      INSTALL_DEPS_ONLY=true
      ;;
    h)
      show_help
      exit 0
      ;;
    *)
      show_help
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# Set variables to default values if not provided
CLUSTER_NAME=${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}
HOST_PORT=${HOST_PORT:-$DEFAULT_HOST_PORT}

# Validar porta
if ! [[ "$HOST_PORT" =~ ^[0-9]+$ ]] || [ "$HOST_PORT" -lt 1 ] || [ "$HOST_PORT" -gt 65535 ]; then
    log_error "Porta inválida: $HOST_PORT. Use um valor entre 1 e 65535."
    exit 1
fi

log_info "=== Script de Implantação AWX com Kind ==="
log_info "Cluster: $CLUSTER_NAME"
log_info "Porta do Host: $HOST_PORT"

# Instalar dependências
install_dependencies

# Se apenas instalação de dependências foi solicitada, sair
if [ "$INSTALL_DEPS_ONLY" = true ]; then
    log_success "Dependências instaladas com sucesso!"
    exit 0
fi

# Inline Kind cluster configuration with variable expansion
KIND_CONFIG=$(cat <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: ${HOST_PORT}
    protocol: TCP
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
        extraArgs:
          enable-aggregator-routing: "true"
EOF
)

# Inline AWX manifest configuration (AWX instance uses nodeport 30000)
AWX_MANIFEST=$(cat <<'EOF'
---
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-prd
  namespace: awx
spec:
  service_type: nodeport
  nodeport_port: 30000
  admin_user: admin
  admin_email: admin@example.com
  projects_persistence: true
  projects_storage_size: 8Gi
  replicas: 0
  web_replicas: 0
  task_replicas: 1
EOF
)

log_info "Verificando cluster existente..."
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    log_warning "Cluster '$CLUSTER_NAME' já existe. Deletando..."
    kind delete cluster --name "$CLUSTER_NAME"
fi

log_info "Criando cluster Kind '$CLUSTER_NAME'..."
# Write the inline Kind configuration to a temporary file
tmp_kind=$(mktemp)
echo "$KIND_CONFIG" > "$tmp_kind"
kind create cluster --name "$CLUSTER_NAME" --config "$tmp_kind"
rm "$tmp_kind"

log_success "Cluster criado com sucesso!"

# Aguardar cluster estar pronto
log_info "Aguardando cluster estar pronto..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

log_info "Adicionando repositório Helm do AWX Operator..."
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ 2>/dev/null || true
helm repo update

log_info "Instalando AWX Operator usando Helm..."
helm upgrade --install awx-operator awx-operator/awx-operator -n awx --create-namespace --wait

log_info "Aplicando manifesto da instância AWX..."
# Write the inline AWX manifest to a temporary file
tmp_awx=$(mktemp)
echo "$AWX_MANIFEST" > "$tmp_awx"
kubectl apply -f "$tmp_awx" --namespace awx
rm "$tmp_awx"

log_success "Implantação concluída!"

# Show the admin password
log_info "Aguardando senha do administrador AWX estar disponível..."
timeout=300
elapsed=0
while ! kubectl get secret awx-prd-admin-password -n awx &> /dev/null; do
  if [ $elapsed -ge $timeout ]; then
    log_error "Timeout aguardando senha do AWX. Verifique os logs: kubectl logs -n awx deployment/awx-operator-controller-manager"
    exit 1
  fi
  sleep 5
  elapsed=$((elapsed + 5))
  echo -n "."
done
echo ""

AWX_PASSWORD=$(kubectl get secret awx-prd-admin-password -n awx -o jsonpath='{.data.password}' | base64 --decode)

log_success "=== AWX IMPLANTADO COM SUCESSO ==="
echo ""
log_info "Acesse AWX em: http://localhost:${HOST_PORT}"
log_info "Usuário: admin"
log_info "Senha: $AWX_PASSWORD"
echo ""
log_info "Comandos úteis:"
log_info "  Ver pods: kubectl get pods -n awx"
log_info "  Ver logs: kubectl logs -n awx deployment/awx-prd-web"
log_info "  Deletar cluster: kind delete cluster --name $CLUSTER_NAME"
