#!/bin/bash
set -e

# ============================
# CONFIGURAÇÃO E DETECÇÃO
# ============================

# Variáveis de recursos (pode preencher para forçar)
FORCE_CPU=""     # Exemplo: 4
FORCE_MEM_MB=""  # Exemplo: 8192

# Parâmetros do cluster e AWX
CLUSTER_NAME="awx-cluster"
AWX_NAMESPACE="awx"
AWX_NODEPORT=30080

# Detecta recursos do sistema
detect_cores() {
    if [ -n "$FORCE_CPU" ]; then echo "$FORCE_CPU"; return; fi
    nproc --all
}
detect_mem_mb() {
    if [ -n "$FORCE_MEM_MB" ]; then echo "$FORCE_MEM_MB"; return; fi
    awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
}

CORES=$(detect_cores)
MEM_MB=$(detect_mem_mb)

# Define perfil e recursos
if [ "$CORES" -ge 4 ] && [ "$MEM_MB" -ge 8192 ]; then
    PERFIL="prod"
    NODE_CPU=$((CORES * 80 / 100))
    NODE_MEM_MB=$((MEM_MB * 80 / 100))
    WEB_REPLICAS=$((CORES / 2))
    TASK_REPLICAS=$((CORES / 2))
else
    PERFIL="dev"
    NODE_CPU=$((CORES * 90 / 100))
    NODE_MEM_MB=$((MEM_MB * 90 / 100))
    WEB_REPLICAS=1
    TASK_REPLICAS=1
fi

echo "Detectado: $CORES CPUs, $MEM_MB MB RAM. Perfil: $PERFIL"
echo "Recursos alocados: CPU=$NODE_CPU cores, Mem=$NODE_MEM_MB MB"
echo "Web replicas: $WEB_REPLICAS, Task replicas: $TASK_REPLICAS"

# ============================
# INSTALAÇÃO DE DEPENDÊNCIAS
# ============================
echo "Atualizando sistema e instalando dependências..."
sudo apt-get update -qq
sudo apt-get upgrade -y
sudo apt-get install -y \
    python3 python3-pip python3-venv git curl wget \
    ca-certificates gnupg2 lsb-release build-essential
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update
sudo apt install -y python3.9 python3.9-venv python3.9-distutils python3.9-dev
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
sudo python3.9 get-pip.py
python3.9 -m venv ~/ansible-ee-venv
source ~/ansible-ee-venv/bin/activate
pip install --upgrade pip
pip install "ansible-builder>=3.0.0"


# Instala Docker
if ! command -v docker &>/dev/null; then
    echo "Instalando Docker..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo usermod -aG docker $USER
    echo "Docker instalado."
else
    echo "Docker já instalado."
fi

# Instala Kind
if ! command -v kind &>/dev/null; then
    echo "Instalando Kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/
    echo "Kind instalado."
else
    echo "Kind já instalado."
fi

# Instala kubectl
if ! command -v kubectl &>/dev/null; then
    echo "Instalando kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    echo "kubectl instalado."
else
    echo "kubectl já instalado."
fi

# Instala Helm
if ! command -v helm &>/dev/null; then
    echo "Instalando Helm..."
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update -qq
    sudo apt-get install -y helm
    echo "Helm instalado."
else
    echo "Helm já instalado."
fi

# Instala ansible e ansible-builder
if ! command -v ansible &>/dev/null; then
    echo "Instalando Ansible e ansible-builder..."
    sudo pip3 install --upgrade pip
    sudo pip3 install ansible ansible-builder
    echo "Ansible e ansible-builder instalados."
else
    echo "Ansible já instalado."
fi

# Instala registry local para Kind
if ! docker ps | grep -q kind-registry; then
    echo "Iniciando registry local..."
    docker run -d --restart=always -p 5001:5000 --name kind-registry registry:2
    docker network connect kind kind-registry || true
    echo "Registry local em localhost:5001"
fi

# ============================
# CRIAÇÃO DO CLUSTER KIND
# ============================
if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
    echo "Cluster Kind '$CLUSTER_NAME' já existe. Deletando..."
    kind delete cluster --name "$CLUSTER_NAME"
fi

echo "Criando cluster Kind..."
cat <<EOF > /tmp/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: $AWX_NODEPORT
    hostPort: $AWX_NODEPORT
    protocol: TCP
EOF

# Adiciona workers se for produção
if [ "$PERFIL" = "prod" ]; then
cat <<EOF >> /tmp/kind-config.yaml
- role: worker
EOF
fi

kind create cluster --name "$CLUSTER_NAME" --config /tmp/kind-config.yaml
echo "Cluster criado."

# ============================
# CRIAÇÃO DO Execution Environment
# ============================
echo "Preparando Execution Environment..."
mkdir -p ~/awx-ee && cd ~/awx-ee

# Arquivo requirements.yml
cat <<EOF > requirements.yml
collections:
  - name: community.windows
  - name: ansible.windows
  - name: microsoft.ad
  - name: community.general
EOF

# Arquivo requirements.txt
echo "pywinrm>=0.4.3" > requirements.txt

# Arquivo execution-environment.yml com patch para repositórios
cat <<EOF > execution-environment.yml
---
version: 3
images:
  base_image:
    name: quay.io/ansible/awx-ee:24.6.1
dependencies:
  galaxy: requirements.yml
  python: requirements.txt
additional_build_steps:
  prepend_base:
    - RUN sed -i 's|mirrorlist.centos.org|vault.centos.org|g' /etc/yum.repos.d/CentOS-* || true
    - RUN sed -i 's|#baseurl=http://vault.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* || true
    - RUN sed -i 's|stream/8|8.5.2111|g' /etc/yum.repos.d/CentOS-* || true
    - RUN dnf clean all || true
    - RUN dnf makecache || true
EOF

# Construção da imagem EE
echo "Construindo e enviando EE..."
ansible-builder build -t localhost:5001/awx-custom-ee:latest -f execution-environment.yml
docker push localhost:5001/awx-custom-ee:latest
cd ~

# ============================
# INSTALAÇÃO DO AWX
# ============================
echo "Instalando o AWX Operator..."
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
helm repo update

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

# ============================
# FINALIZAÇÃO
# ============================
echo "Aguardando instalação do AWX..."
sleep 10
kubectl -n $AWX_NAMESPACE get pods

# Obter senha do admin
echo "Aguardando senha do admin..."
until kubectl -n $AWX_NAMESPACE get secret awx-admin-password &>/dev/null; do sleep 5; done
AWX_PASS=$(kubectl -n $AWX_NAMESPACE get secret awx-admin-password -o jsonpath='{.data.password}' | base64 --decode)

echo "Instalação concluída!"
echo "Acesse o AWX em: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):${AWX_NODEPORT}"
echo "Usuário: admin"
echo "Senha: $AWX_PASS"
