# config/templates/awx-instance.yaml.tpl
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-{{PERFIL}}
  namespace: {{AWX_NAMESPACE}}
spec:
  service_type: nodeport
  nodeport_port: {{HOST_PORT}}
  admin_user: admin
  admin_email: admin@example.com
  
  control_plane_ee_image: localhost:{{REGISTRY_PORT}}/awx-enterprise-ee:latest
  
  replicas: {{WEB_REPLICAS}}
  web_replicas: {{WEB_REPLICAS}}
  task_replicas: {{TASK_REPLICAS}}
  
  web_resource_requirements:
    requests:
      cpu: {{AWX_WEB_CPU_REQ}}
      memory: {{AWX_WEB_MEM_REQ}}
    limits:
      cpu: {{AWX_WEB_CPU_LIM}}
      memory: {{AWX_WEB_MEM_LIM}}
      
  task_resource_requirements:
    requests:
      cpu: {{AWX_TASK_CPU_REQ}}
      memory: {{AWX_TASK_MEM_REQ}}
    limits:
      cpu: {{AWX_TASK_CPU_LIM}}
      memory: {{AWX_TASK_MEM_LIM}}
