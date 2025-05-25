#!/bin/bash
set -e

# =======================
# CONFIGURAÇÃO INICIAL
# =======================

# (Opcional) Preencha aqui para forçar recursos, ou deixe vazio para auto-detectar:
FORCE_CPU=""     # Exemplo: 4
FORCE_MEM_MB=""  # Exemplo: 8192

# Nome do cluster e porta AWX
CLUSTER_NAME="awx-cluster"
AWX_NAMESPACE="awx"
AWX_NODEPORT=30080

# =======================
# FUNÇÕES DE LOG
# =======================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()    { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERRO]${NC} $1"; }
ok()     { echo -e "${GREEN}[OK]${NC} $1"; }

# =======================
# DETECÇÃO DE RECURSOS
# =======================
detect_cores() {
    if [ -n "$FORCE_CPU" ]; then echo "$FORCE_CPU"; return; fi
    nproc --all 2>/dev/null || grep -c ^processor /proc/cpuinfo
}
detect_mem_mb() {
    if [ -n "$FORCE_MEM_MB" ]; then echo "$FORCE_MEM_MB"; return; fi
    awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
}

CORES=$(detect_cores)
MEM_MB=$(detect_mem_mb)

# =======================
# CÁLCULO DE PERFIL
# =======================
if [ "$CORES" -ge 4 ] && [ "$MEM_MB" -ge 8192 ]; then
    PERFIL="prod"
    NODE_CPU=$((CORES * 80 / 100))
    NODE_MEM_MB=$((MEM_MB * 80 / 100))
    WEB_REPLICAS=$((CORES / 2)); [ "$WEB_REPLICAS" -lt 2 ] && WEB_REPLICAS=2
    TASK_REPLICAS=$((CORES / 2)); [ "$TASK_REPLICAS" -lt 2 ] && TASK_REPLICAS=2
else
    PERFIL="dev"
    NODE_CPU=$((CORES * 90 / 100))
    NODE_MEM_MB=$((MEM_MB * 90 / 100))
    WEB_REPLICAS=1
    TASK_REPLICAS=1
fi

log "Detectado: $CORES CPUs, $MEM_MB MB RAM. Perfil: $PERFIL"
log "AWX Web Replicas: $WEB_REPLICAS | Task Replicas: $TASK_REPLICAS"

# =======================
# DEPENDÊNCIAS DE SISTEMA
# =======================
log "Instalando dependências do sistema..."
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip python3-venv git curl wget lsb-release ca-certificates gnupg2 software-properties-common build-essential

# =======================
# DOCKER
# =======================
if ! command -v docker &>/dev/null; then
    log "Instalando Docker..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    ok "Docker instalado."
else
    ok "Docker já instalado."
fi

# =======================
# KIND
# =======================
if ! command -v kind &>/dev/null; then
    log "Instalando Kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    ok "Kind instalado."
else
    ok "Kind já instalado."
fi

# =======================
# KUBECTL
# =======================
if ! command -v kubectl &>/dev/null; then
    log "Instalando kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    ok "kubectl instalado."
else
    ok "kubectl já instalado."
fi

# =======================
# HELM
# =======================
if ! command -v helm &>/dev/null; then
    log "Instalando Helm..."
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update -y
    sudo apt-get install -y helm
    ok "Helm instalado."
else
    ok "Helm já instalado."
fi

# =======================
# ANSIBLE & BUILDER
# =======================
if ! command -v ansible &>/dev/null; then
    log "Instalando Ansible e ansible-builder..."
    sudo pip3 install --upgrade pip
    sudo pip3 install ansible ansible-builder
    ok "Ansible e ansible-builder instalados."
else
    ok "Ansible já instalado."
fi

# =======================
# REGISTRY LOCAL PARA KIND
# =======================
if ! docker ps | grep -q kind-registry; then
    log "Subindo registry Docker local para o Kind..."
    docker run -d --restart=always -p "5001:5000" --name kind-registry registry:2 || true
    docker network connect kind kind-registry || true
    ok "Registry local disponível em localhost:5001"
else
    ok "Registry local já está rodando."
fi

# =======================
# CRIAR CLUSTER KIND
# =======================
if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
    warn "Cluster Kind '$CLUSTER_NAME' já existe. Deletando..."
    kind delete cluster --name "$CLUSTER_NAME"
fi

log "Criando cluster Kind '$CLUSTER_NAME'..."
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: ${AWX_NODEPORT}
    hostPort: ${AWX_NODEPORT}
    protocol: TCP
EOF

if [ "$PERFIL" = "prod" ]; then
cat <<EOF >> kind-config.yaml
- role: worker
- role: worker
EOF
fi

kind create cluster --name "$CLUSTER_NAME" --config kind-config.yaml
ok "Cluster Kind criado."

# =======================
# EXECUTION ENVIRONMENT CUSTOMIZADO
# =======================
log "Preparando Execution Environment customizado..."

mkdir -p awx-ee && cd awx-ee
cat <<EOF > requirements.yml
collections:
  - name: community.windows
  - name: ansible.windows
  - name: microsoft.ad
  - name: community.general
EOF

cat <<EOF > requirements.txt
pywinrm>=0.4.3
EOF

cat <<EOF > execution-environment.yml
version: 1
build_arg_defaults:
  EE_BASE_IMAGE: 'quay.io/ansible/awx-ee:24.6.1'
dependencies:
  galaxy: requirements.yml
  python: requirements.txt
EOF

log "Construindo e publicando a imagem EE para o registry local..."
ansible-builder build -t localhost:5001/awx-custom-ee:latest -f execution-environment.yml
docker push localhost:5001/awx-custom-ee:latest
cd ..

ok "Execution Environment customizado pronto."

# =======================
# AWX OPERATOR E INSTÂNCIA
# =======================
log "Instalando AWX Operator via Helm..."
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ || true
helm repo update

log "Aplicando manifestos do AWX..."
cat <<EOF > awx-instance.yaml
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
  namespace: $AWX_NAMESPACE
spec:
  service_type: nodeport
  nodeport_port: $AWX_NODEPORT
  control_plane_ee_image: localhost:5001/awx-custom-ee:latest
  replicas: $WEB_REPLICAS
  web_replicas: $WEB_REPLICAS
  task_replicas: $TASK_REPLICAS
  projects_persistence: true
  projects_storage_size: 8Gi
EOF

kubectl create namespace $AWX_NAMESPACE || true
helm upgrade --install awx-operator awx-operator/awx-operator -n $AWX_NAMESPACE --wait
kubectl apply -f awx-instance.yaml -n $AWX_NAMESPACE

ok "AWX implantado!"

# =======================
# PÓS-INSTALAÇÃO
# =======================
log "Aguardando senha do admin do AWX..."
until kubectl get secret awx-admin-password -n $AWX_NAMESPACE &>/dev/null; do sleep 5; done
AWX_PASS=$(kubectl get secret awx-admin-password -n $AWX_NAMESPACE -o jsonpath='{.data.password}' | base64 --decode)

ok "AWX disponível em: http://localhost:${AWX_NODEPORT}"
log "Usuário: admin"
log "Senha: $AWX_PASS"
log "Para ver os pods: kubectl get pods -n $AWX_NAMESPACE"
log "Para logs: kubectl logs -n $AWX_NAMESPACE deployment/awx-web"
