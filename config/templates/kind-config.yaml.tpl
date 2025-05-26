# kind-config.yaml.tpl
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30000
        hostPort: ${HOSTPORT}
        protocol: TCP

  - role: worker

# Registry local para imagens customizadas
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRYPORT}"]
      endpoint = ["http://kind-registry:5000"]

# Configuração do registry no cluster
# Será aplicado via kubectl após a criação do cluster
