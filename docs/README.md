# não não, um arquivo .txt com o código MD, bonito bem identado e visvelmente top

Perfeito! Aqui está o conteúdo do README.md (Markdown) já formatado, identado e pronto para você salvar como um arquivo .txt. É só copiar e salvar como, por exemplo, `README.txt` — e ao abrir verá toda a beleza do visual Markdown.

markdown
# Sistema AWX - Deployment Automatizado

Sistema completo para deployment automatizado do **AWX** (Ansible Tower Open Source) usando **Kind** (Kubernetes in Docker), com cálculo inteligente de recursos e configuração otimizada.

---

## ✨ Arquitetura

### **Módulos Core**
- [`logger.sh`](../lib/core/logger.sh): Sistema de logging centralizado com níveis e cores
- [`validator.sh`](../lib/core/validator.sh): Validação robusta de parâmetros e ambiente
- [`resource_calculator.sh`](../lib/core/resource_calculator.sh): Cálculo inteligente de recursos baseado em padrões GKE/EKS

### **Módulos de Serviços**
- [`dependency_manager.sh`](../lib/services/dependency_manager.sh): Gerenciamento de dependências do sistema
- [`kind_manager.sh`](../lib/services/kind_manager.sh): Operações do cluster Kubernetes
- [`ee_builder.sh`](../lib/services/ee_builder.sh): Construção de Execution Environments
- [`awx_installer.sh`](../lib/services/awx_installer.sh): Instalação e configuração do AWX
- [`registry_manager.sh`](../lib/services/registry_manager.sh): Gerenciamento do registry local

### **Utilitários**
- [`common.sh`](../lib/utils/common.sh): Funções utilitárias compartilhadas
- [`diagnostics.sh`](../lib/utils/diagnostics.sh): Ferramentas de diagnóstico
- [`health_check.sh`](../lib/utils/health_check.sh): Verificações de saúde do sistema

---

## 🚀 Uso Básico

Instalação básica com valores automáticos:


./bin/awx-deploy



Instalação personalizada:


./bin/awx-deploy -c meu-cluster -p 8080 -f 4 -m 8192



Apenas instalar dependências:


./bin/awx-deploy -d



Modo verboso para debug:


./bin/awx-deploy -v



---

## ⚙️ Configuração de Perfis

O sistema detecta automaticamente o perfil baseado nos recursos:
- **dev:** `< 4` CPUs ou `< 8GB` RAM
- **prod:** `≥ 4` CPUs e `≥ 8GB` RAM

### Personalização de Perfis

Editar configurações de desenvolvimento:


vim config/profiles/dev.conf



Editar configurações de produção:


vim config/profiles/prod.conf



---

## 🛠️ Funcionalidades Avançadas

### Diagnóstico do Sistema

Diagnóstico completo:


source lib/utils/diagnostics.sh
run_full_diagnostics awx



Diagnóstico específico:


diagnose_docker_environment
diagnose_kubernetes_cluster



### Verificação de Saúde

Verificação completa:


source lib/utils/health_check.sh
run_health_checks awx awx-prod



Verificações específicas:


health_check_system
health_check_awx awx awx-prod



### Gerenciamento do Registry

Iniciar registry local:


source lib/services/registry_manager.sh
start_local_registry



Listar imagens:


list_registry_images



Limpeza do registry:


cleanup_registry



---

## 📁 Estrutura de Diretórios



awx-deploy/
├── bin/
│   └── awx-deploy             \# Script principal executável
├── lib/
│   ├── core/
│   │   ├── logger.sh
│   │   ├── validator.sh
│   │   └── resource_calculator.sh
│   ├── services/
│   │   ├── dependency_manager.sh
│   │   ├── kind_manager.sh
│   │   ├── ee_builder.sh
│   │   ├── awx_installer.sh
│   │   └── registry_manager.sh
│   └── utils/
│       ├── common.sh
│       ├── diagnostics.sh
│       └── health_check.sh
├── config/
│   ├── default.conf
│   ├── profiles/
│   │   ├── dev.conf
│   │   └── prod.conf
│   └── templates/
│       ├── awx-instance.yaml.tpl
│       └── ee-config.yml.tpl
├── tests/
│   ├── unit/
│   │   ├── core_tests.sh
│   │   └── services_tests.sh
│   └── integration/
│       └── full_deploy_test.sh
└── docs/
├── README.md
├── CONTRIBUTING.md
└── modules/
├── core.md
└── services.md



---

## 🧩 Solução de Problemas

### Problemas Comuns

1. **Docker não acessível**
   - Verificar se o usuário está no grupo docker:
     
     groups | grep docker
     
   - Adicionar usuário ao grupo docker:
     
     sudo usermod -aG docker $USER
     newgrp docker
     

2. **Conflito de portas**
   - Verificar processos usando a porta:
     
     lsof -i :8080
     
   - Usar porta alternativa:
     
     ./bin/awx-deploy -p 8081
     

3. **Recursos insuficientes**
   - Forçar recursos específicos:
     
     ./bin/awx-deploy -f 2 -m 4096
     

### Logs e Diagnóstico

- Ver logs dos pods AWX:


kubectl logs -n awx deployment/awx-prod-web
kubectl logs -n awx deployment/awx-prod-task


- Executar diagnóstico completo:


./lib/utils/diagnostics.sh


- Verificar saúde do sistema:


./lib/utils/health_check.sh



---

## 🤝 Contribuição

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para instruções de desenvolvimento e contribuição.

---

## 📄 Licença

Este projeto está licenciado sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para detalhes.


⚡ Dica:
Se quiser salvar, abra um editor de texto, cole esse conteúdo e salve como `README.txt` (isso preserva o Markdown formatado, ideal para preview no VSCode, Obsidian ou GitHub).

Se precisar do arquivo pronto para download, posso gerar o texto no formato base64 ou simular o conteúdo para você salvar diretamente!

```