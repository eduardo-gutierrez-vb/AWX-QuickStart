#!/bin/bash
# lib/services/kind_manager.sh - Operações do Kind/Kubernetes

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/validator.sh"

create_kind_cluster() {
    log_header "CRIAÇÃO DO CLUSTER KIND"
    
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        log_warning "Cluster $CLUSTER_NAME já existe. Deletando..."
        kind delete cluster --name "$CLUSTER_NAME"
        validate_environment
    fi
    
    log_info "Criando cluster Kind $CLUSTER_NAME..."
    
    cat > /tmp/kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: $HOST_PORT
    protocol: TCP
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
        extraArgs:
          enable-aggregator-routing: "true"
  - |
    kind: KubeletConfiguration
    maxPods: 110
EOF
    
    if [[ "$PERFIL" == "prod" ]] && [[ "$CORES" -ge 6 ]]; then
        log_info "Adicionando nó worker para ambiente de produção..."
        cat >> /tmp/kind-config.yaml << EOF
- role: worker
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    maxPods: 110
EOF
    fi
    
    kind create cluster --name "$CLUSTER_NAME" --config /tmp/kind-config.yaml
    rm /tmp/kind-config.yaml
    
    log_success "Cluster criado com sucesso!"
    
    log_info "Aguardando cluster estar pronto..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    configure_registry_for_cluster
}

configure_registry_for_cluster() {
    log_subheader "Configurando Registry Local"
    
    if ! docker network ls | grep -q kind; then
        docker network create kind
    fi
    
    docker network connect kind kind-registry 2>/dev/null || true
    
    kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
  labels:
    app.kubernetes.io/name: awx
    app.kubernetes.io/component: registry-config
    app.kubernetes.io/managed-by: awx-deploy-script
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT:-5001}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
    
    log_success "Registry configurado no cluster"
}

diagnose_awx_pods() {
    echo "STATUS DOS PODS AWX:"
    kubectl get pods -n "$AWX_NAMESPACE" -o wide
    
    echo -e "\nEVENTOS DOS PODS:"
    kubectl get events -n "$AWX_NAMESPACE" --sort-by=.metadata.creationTimestamp
    
    echo -e "\nLOGS DOS PODS COM PROBLEMA:"
    for pod in $(kubectl get pods -n "$AWX_NAMESPACE" --field-selector=status.phase=Failed -o name 2>/dev/null); do
        echo "Logs do pod: $pod"
        kubectl logs -n "$AWX_NAMESPACE" "$pod" --previous --tail=50 2>/dev/null || true
    done
}

check_cluster_resources() {
    echo "RECURSOS DO CLUSTER:"
    kubectl top nodes 2>/dev/null || echo "Metrics server não disponível"
    kubectl top pods -n "$AWX_NAMESPACE" 2>/dev/null || echo "Metrics server não disponível"
    
    echo -e "\nCAPACIDADE DO CLUSTER:"
    kubectl describe nodes | grep -A 5 "Allocated resources"
}

check_registry() {
    echo "STATUS DO REGISTRY LOCAL:"
    docker ps | grep kind-registry
    curl -s "http://localhost:${REGISTRY_PORT:-5001}/v2/_catalog" 2>/dev/null || echo "Registry não disponível"
}

reset_awx_deployment() {
    log_warning "Resetando deployment AWX..."
    
    kubectl delete awx "awx-$PERFIL" -n "$AWX_NAMESPACE" --ignore-not-found=true
    kubectl delete pods --all -n "$AWX_NAMESPACE"
    
    sleep 30
    
    kubectl apply -f /tmp/awx-instance.yaml -n "$AWX_NAMESPACE"
}

test_registry_connectivity() {
    kubectl run test-registry --image="localhost:${REGISTRY_PORT:-5001}/awx-enterprise-ee:latest" \
        --restart=Never -n "$AWX_NAMESPACE" --command -- sleep 3600 2>/dev/null || true
    
    kubectl wait --for=condition=Ready pod/test-registry -n "$AWX_NAMESPACE" --timeout=60s 2>/dev/null || true
    kubectl delete pod test-registry -n "$AWX_NAMESPACE" 2>/dev/null || true
}

validate_environment() {
    log_header "VERIFICAÇÃO DE AMBIENTE"
    
    check_port_availability "$HOST_PORT"
    
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        log_warning "Removendo cluster existente $CLUSTER_NAME..."
        kind delete cluster --name "$CLUSTER_NAME"
        sleep 15
    fi
    
    docker rm -f $(docker ps -aq --filter "label=io.x-k8s.kind.cluster=$CLUSTER_NAME") 2>/dev/null || true
    
    if docker network inspect kind &>/dev/null; then
        log_info "Removendo rede kind residual..."
        docker network rm kind 2>/dev/null || true
    fi
}
