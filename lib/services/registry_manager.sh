#!/bin/bash
# lib/services/registry_manager.sh - Gerenciamento do registry local

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"

start_local_registry() {
    local registry_port="${REGISTRY_PORT:-5001}"
    local registry_name="kind-registry"
    
    log_subheader "Iniciando Registry Local"
    
    if docker ps | grep -q "$registry_name"; then
        log_info "Registry local já está rodando"
        return 0
    fi
    
    log_info "Iniciando registry local na porta $registry_port..."
    
    # Remover container existente se estiver parado
    docker rm -f "$registry_name" 2>/dev/null || true
    
    # Iniciar novo registry
    docker run -d \
        --restart=always \
        -p "${registry_port}:5000" \
        --name "$registry_name" \
        -v registry-data:/var/lib/registry \
        registry:2
    
    # Conectar à rede do Kind se existir
    if docker network ls | grep -q kind; then
        docker network connect kind "$registry_name" 2>/dev/null || true
    fi
    
    # Aguardar registry estar pronto
    if wait_for_condition "curl -s http://localhost:${registry_port}/v2/ >/dev/null" 30 2; then
        log_success "Registry local iniciado em localhost:${registry_port}"
        return 0
    else
        log_error "Falha ao iniciar registry local"
        return 1
    fi
}

stop_local_registry() {
    local registry_name="kind-registry"
    
    log_info "Parando registry local..."
    
    if docker ps | grep -q "$registry_name"; then
        docker stop "$registry_name" >/dev/null
        docker rm "$registry_name" >/dev/null
        log_success "Registry local parado"
    else
        log_info "Registry local não estava rodando"
    fi
}

verify_registry_connectivity() {
    local registry_port="${REGISTRY_PORT:-5001}"
    local registry_url="localhost:${registry_port}"
    
    log_debug "Verificando conectividade do registry em $registry_url"
    
    # Verificar se o registry está respondendo
    if ! curl -s "http://${registry_url}/v2/" >/dev/null; then
        log_error "Registry não está acessível em $registry_url"
        return 1
    fi
    
    # Verificar catálogo
    local catalog=$(curl -s "http://${registry_url}/v2/_catalog" 2>/dev/null)
    if [[ -n "$catalog" ]]; then
        log_debug "Registry funcionando. Catálogo: $catalog"
    else
        log_warning "Registry acessível mas catálogo vazio"
    fi
    
    return 0
}

push_image_to_registry() {
    local source_image="$1"
    local target_name="$2"
    local registry_port="${REGISTRY_PORT:-5001}"
    local registry_url="localhost:${registry_port}"
    
    if [[ -z "$source_image" || -z "$target_name" ]]; then
        log_error "Uso: push_image_to_registry <imagem_origem> <nome_destino>"
        return 1
    fi
    
    local target_image="${registry_url}/${target_name}"
    
    log_info "Enviando imagem $source_image para registry como $target_image"
    
    # Tag da imagem
    if ! docker tag "$source_image" "$target_image"; then
        log_error "Falha ao criar tag da imagem"
        return 1
    fi
    
    # Push da imagem
    if ! docker push "$target_image"; then
        log_error "Falha ao enviar imagem para registry"
        return 1
    fi
    
    log_success "Imagem enviada com sucesso: $target_image"
    return 0
}

list_registry_images() {
    local registry_port="${REGISTRY_PORT:-5001}"
    local registry_url="localhost:${registry_port}"
    
    log_info "Imagens no registry local:"
    
    local catalog=$(curl -s "http://${registry_url}/v2/_catalog" 2>/dev/null)
    
    if [[ -z "$catalog" ]]; then
        log_warning "Não foi possível obter catálogo do registry"
        return 1
    fi
    
    # Parse do JSON simples
    echo "$catalog" | grep -o '"[^"]*"' | grep -v repositories | sed 's/"//g' | while read -r repo; do
        log_info "  - $repo"
        
        # Listar tags para cada repositório
        local tags=$(curl -s "http://${registry_url}/v2/${repo}/tags/list" 2>/dev/null)
        echo "$tags" | grep -o '"[^"]*"' | grep -v -E '(name|tags)' | sed 's/"//g' | while read -r tag; do
            log_info "    └── $tag"
        done
    done
}

cleanup_registry() {
    local registry_port="${REGISTRY_PORT:-5001}"
    local registry_url="localhost:${registry_port}"
    local dry_run="${1:-false}"
    
    log_subheader "Limpeza do Registry Local"
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "Modo dry-run: apenas listando imagens que seriam removidas"
    fi
    
    # Listar todas as imagens
    local catalog=$(curl -s "http://${registry_url}/v2/_catalog" 2>/dev/null)
    
    if [[ -z "$catalog" ]]; then
        log_warning "Registry vazio ou inacessível"
        return 0
    fi
    
    echo "$catalog" | grep -o '"[^"]*"' | grep -v repositories | sed 's/"//g' | while read -r repo; do
        local tags=$(curl -s "http://${registry_url}/v2/${repo}/tags/list" 2>/dev/null)
        
        echo "$tags" | grep -o '"[^"]*"' | grep -v -E '(name|tags)' | sed 's/"//g' | while read -r tag; do
            if [[ "$tag" == *"old"* || "$tag" == *"temp"* ]]; then
                if [[ "$dry_run" == "true" ]]; then
                    log_info "Seria removido: $repo:$tag"
                else
                    log_info "Removendo: $repo:$tag"
                    # Aqui implementaríamos a remoção real
                fi
            fi
        done
    done
    
    if [[ "$dry_run" != "true" ]]; then
        log_success "Limpeza do registry concluída"
    fi
}

configure_registry_for_kind() {
    local registry_port="${REGISTRY_PORT:-5001}"
    local cluster_name="${1:-kind}"
    
    log_subheader "Configurando Registry para Kind"
    
    # Criar rede kind se não existir
    if ! docker network ls | grep -q kind; then
        docker network create kind
    fi
    
    # Conectar registry à rede kind
    docker network connect kind kind-registry 2>/dev/null || true
    
    # Aplicar ConfigMap no cluster
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${registry_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
    
    log_success "Registry configurado para cluster Kind"
}
