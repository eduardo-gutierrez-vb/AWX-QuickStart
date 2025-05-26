# AWX-QuickStart

awx-deployment/
├── bin/
│   └── awx-deploy                    # Script principal executável
├── lib/
│   ├── core/
│   │   ├── logger.sh                 # Sistema de logging centralizado
│   │   ├── validator.sh              # Validações de entrada e ambiente
│   │   └── resource_calculator.sh    # Cálculos de recursos do sistema
│   ├── services/
│   │   ├── dependency_manager.sh     # Gerenciamento de dependências
│   │   ├── kind_manager.sh           # Operações do Kind/Kubernetes
│   │   ├── registry_manager.sh       # Gerenciamento do registry local
│   │   ├── ee_builder.sh            # Construção de Execution Environment
│   │   └── awx_installer.sh         # Instalação e configuração AWX
│   └── utils/
│       ├── common.sh                 # Funções utilitárias compartilhadas
│       ├── diagnostics.sh           # Ferramentas de diagnóstico
│       └── health_check.sh          # Verificações de saúde do sistema
├── config/
│   ├── default.conf                  # Configurações padrão
│   ├── profiles/
│   │   ├── dev.conf                 # Perfil desenvolvimento
│   │   └── prod.conf                # Perfil produção
│   └── templates/
│       ├── awx-instance.yaml.tpl    # Template AWX
│       ├── kind-config.yaml.tpl     # Template Kind
│       └── ee-config.yml.tpl        # Template Execution Environment
├── tests/
│   ├── unit/                        # Testes unitários por módulo
│   └── integration/                 # Testes de integração
└── docs/
    ├── README.md                    # Documentação principal
    ├── CONTRIBUTING.md              # Guia de contribuição
    └── modules/                     # Documentação detalhada por módulo
