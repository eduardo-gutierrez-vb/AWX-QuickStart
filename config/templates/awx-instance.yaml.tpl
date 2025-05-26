apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-${PERFIL}
  namespace: ${AWXNAMESPACE}
  labels:
    app.kubernetes.io/name: awx
    app.kubernetes.io/component: awx-instance
    app.kubernetes.io/managed-by: awx-deploy-script
    environment: ${PERFIL}
spec:
  service_type: nodeport
  nodeport_port: ${HOSTPORT}
  admin_user: admin
  admin_email: admin@example.com
  
  # Execution Environment Configuration
  control_plane_ee_image: localhost:${REGISTRYPORT}/awx-enterprise-ee:latest
  
  # Replica Configuration
  replicas: ${WEBREPLICAS}
  web_replicas: ${WEBREPLICAS}
  task_replicas: ${TASKREPLICAS}
  
  # Web Resource Requirements
  web_resource_requirements:
    requests:
      cpu: ${AWXWEBCPUREQ}
      memory: ${AWXWEBMEMREQ}
    limits:
      cpu: ${AWXWEBCPULIM}
      memory: ${AWXWEBMEMLIM}
  
  # Task Resource Requirements
  task_resource_requirements:
    requests:
      cpu: ${AWXTASKCPUREQ}
      memory: ${AWXTASKMEMREQ}
    limits:
      cpu: ${AWXTASKCPULIM}
      memory: ${AWXTASKMEMLIM}
  
  # PostgreSQL Configuration
  postgres_configuration_secret: awx-postgres-configuration
  postgres_storage_requirements:
    requests:
      storage: 8Gi
    limits:
      storage: 8Gi
  
  # Projects Persistence
  projects_persistence: true
  projects_storage_size: 8Gi
  projects_storage_access_mode: ReadWriteOnce
  
  # Additional Configuration
  hostname: awx-${PERFIL}.local
  
  # Node Selector for Production
  web_node_selector:
    node-role: worker
  task_node_selector:
    node-role: worker
  
  # Tolerations
  web_tolerations:
    - key: "node-role"
      operator: "Equal"
      value: "worker"
      effect: "NoSchedule"
  task_tolerations:
    - key: "node-role"
      operator: "Equal"
      value: "worker"
      effect: "NoSchedule"