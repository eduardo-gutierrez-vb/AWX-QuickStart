#!/bin/bash
# lib/core/logger_enhanced.sh - Sistema de logging centralizado com UX moderna

# Dependências modernas
command -v tput >/dev/null 2>&1 && USE_TPUT=true || USE_TPUT=false

# Configuração de cores otimizada com tput
if [[ "$USE_TPUT" == "true" ]]; then
    declare -A LOG_COLORS=(
        [INFO]="$(tput setaf 4)$(tput bold)"
        [SUCCESS]="$(tput setaf 2)$(tput bold)"
        [WARNING]="$(tput setaf 3)$(tput bold)"
        [ERROR]="$(tput setaf 1)$(tput bold)"
        [DEBUG]="$(tput setaf 5)"
        [HEADER]="$(tput setaf 6)$(tput bold)"
        [PROGRESS]="$(tput setaf 3)"
        [NC]="$(tput sgr0)"
        [DIM]="$(tput dim)"
        [UNDERLINE]="$(tput smul)"
    )
else
    # Fallback para códigos ANSI tradicionais
    declare -A LOG_COLORS=(
        [INFO]='\033[1;34m'
        [SUCCESS]='\033[1;32m'
        [WARNING]='\033[1;33m'
        [ERROR]='\033[1;31m'
        [DEBUG]='\033[0;35m'
        [HEADER]='\033[1;36m'
        [PROGRESS]='\033[0;33m'
        [NC]='\033[0m'
        [DIM]='\033[2m'
        [UNDERLINE]='\033[4m'
    )
fi

# Configuração avançada
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"
LOG_TIMESTAMP="${LOG_TIMESTAMP:-true}"
LOG_JSON="${LOG_JSON:-true}"
LOG_SYSLOG="${LOG_SYSLOG:-true}"
LOG_INTERACTIVE="${LOG_INTERACTIVE:-true}"
LOG_ICONS="${LOG_ICONS:-true}"

# Ícones modernos para melhor UX visual
declare -A LOG_ICONS=(
    [INFO]="ℹ️ "
    [SUCCESS]="✅"
    [WARNING]="⚠️ "
    [ERROR]="❌"
    [DEBUG]="🔍"
    [HEADER]="🎯"
    [PROGRESS]="⏳"
)

# Função principal de logging melhorada
log_message() {
    local level="$1"
    local message="$2"
    local color="${LOG_COLORS[$level]}"
    local reset="${LOG_COLORS[NC]}"
    local icon=""
    
    # Adiciona ícone se habilitado
    if [[ "$LOG_ICONS" == "true" ]]; then
        icon="${LOG_ICONS[$level]} "
    fi
    
    # Verifica nível de log
    case "$LOG_LEVEL" in
        DEBUG) allowed_levels="DEBUG INFO SUCCESS WARNING ERROR" ;;
        INFO) allowed_levels="INFO SUCCESS WARNING ERROR" ;;
        WARNING) allowed_levels="WARNING ERROR" ;;
        ERROR) allowed_levels="ERROR" ;;
        *) allowed_levels="INFO SUCCESS WARNING ERROR" ;;
    esac
    
    if [[ ! $allowed_levels =~ $level ]]; then
        return 0
    fi
    
    # Formatação da mensagem
    local formatted_message=""
    if [[ "$LOG_TIMESTAMP" == "true" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        formatted_message="${LOG_COLORS[DIM]}[$timestamp]${reset} "
    fi
    
    formatted_message+="${color}${icon}[$level]${reset} $message"
    
    # Saída para terminal
    if [[ "$LOG_INTERACTIVE" == "true" ]]; then
        echo -e "$formatted_message" >&2
    fi
    
    # Log para arquivo
    if [[ -n "$LOG_FILE" ]]; then
        local clean_message=$(echo -e "$formatted_message" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/[🎯🔍❌✅⚠️ℹ️⏳]//g')
        echo "$clean_message" >> "$LOG_FILE"
    fi
    
    # Log JSON estruturado
    if [[ "$LOG_JSON" == "true" ]]; then
        log_json "$level" "$message"
    fi
    
    # Integração com syslog
    if [[ "$LOG_SYSLOG" == "true" ]]; then
        logger -p "local0.info" -t "$(basename "$0")" "[$level] $message"
    fi
}

# Logging JSON moderno
log_json() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname)
    local script_name=$(basename "$0")
    
    local json_file="${LOG_FILE%.log}.json"
    [[ -z "$json_file" ]] && json_file="/tmp/${script_name}.json"
    
    local json_entry=$(cat << EOF
{
  "timestamp": "$timestamp",
  "hostname": "$hostname",
  "script": "$script_name",
  "level": "$level",
  "message": "$message",
  "pid": $$
}
EOF
)
    
    echo "$json_entry," >> "$json_file"
}

# Funções de conveniência mantidas
log_info() { log_message "INFO" "$1"; }
log_success() { log_message "SUCCESS" "$1"; }
log_warning() { log_message "WARNING" "$1"; }
log_error() { log_message "ERROR" "$1"; }
log_debug() { log_message "DEBUG" "$1"; }

# Header melhorado com design moderno
log_header() {
    local title="$1"
    local width=80
    local padding=$(( (width - ${#title} - 4) / 2 ))
    
    if [[ "$USE_TPUT" == "true" ]]; then
        width=$(tput cols 2>/dev/null || echo 80)
        padding=$(( (width - ${#title} - 4) / 2 ))
    fi
    
    local separator="${LOG_COLORS[HEADER]}$(printf '═%.0s' $(seq 1 $width))${LOG_COLORS[NC]}"
    local padded_title="${LOG_COLORS[HEADER]}$(printf '%*s' $padding '')║ ${LOG_COLORS[UNDERLINE]}$title${LOG_COLORS[NC]}${LOG_COLORS[HEADER]} ║$(printf '%*s' $padding '')${LOG_COLORS[NC]}"
    
    echo -e "$separator"
    echo -e "$padded_title"
    echo -e "$separator"
}

log_subheader() {
    local title="$1"
    local icon="${LOG_ICONS[HEADER]}"
    echo -e "${LOG_COLORS[HEADER]}${LOG_COLORS[UNDERLINE]}$icon $title${LOG_COLORS[NC]}"
    echo -e "${LOG_COLORS[DIM]}$(printf '─%.0s' $(seq 1 ${#title}))${LOG_COLORS[NC]}"
}

# Sistema de progresso moderno
log_progress() {
    local message="$1"
    local current="${2:-0}"
    local total="${3:-100}"
    local width=40
    
    local percentage=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    
    local bar="${LOG_COLORS[SUCCESS]}$(printf '█%.0s' $(seq 1 $filled))${LOG_COLORS[DIM]}$(printf '░%.0s' $(seq 1 $empty))${LOG_COLORS[NC]}"
    
    printf "\r${LOG_COLORS[PROGRESS]}${LOG_ICONS[PROGRESS]}${LOG_COLORS[NC]} $message [%s] %3d%%" "$bar" "$percentage"
    
    if [[ "$current" -eq "$total" ]]; then
        echo ""
        log_success "✨ $message - Concluído!"
    fi
}

# Spinner moderno para operações longas
log_spinner() {
    local message="$1"
    local pid="$2"
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    echo -n "${LOG_COLORS[PROGRESS]}${message}${LOG_COLORS[NC]} "
    
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b"
    done
    
    printf "\b\b\b"
    log_success "$message"
}

# Configuração robusta com detecção automática
configure_logging() {
    local config_file="${1:-}"
    
    # Carrega configuração se fornecida
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        log_debug "Configuração carregada de: $config_file"
    fi
    
    # Configura diretório de logs
    if [[ -n "$LOG_FILE" ]]; then
        local log_dir=$(dirname "$LOG_FILE")
        mkdir -p "$log_dir"
        
        # Rotação básica de logs
        if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 10485760 ]]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            log_info "Log rotacionado: ${LOG_FILE}.old"
        fi
    fi
    
    # Detecta recursos do terminal
    if [[ "$LOG_INTERACTIVE" == "true" ]]; then
        if [[ ! -t 2 ]]; then
            LOG_INTERACTIVE="false"
            log_debug "Saída não-interativa detectada, desabilitando cores"
        fi
    fi
    
    # Configuração inicial completa
    log_debug "Logger configurado - Nível: $LOG_LEVEL, Arquivo: ${LOG_FILE:-'Nenhum'}"
    log_debug "Recursos: JSON=$LOG_JSON, Syslog=$LOG_SYSLOG, Ícones=$LOG_ICONS"
}

# Função de demonstração das capacidades
log_demo() {
    log_header "🚀 SISTEMA DE LOGGING MODERNO"
    
    log_info "Demonstrando capacidades do sistema..."
    log_success "Conexão estabelecida com sucesso"
    log_warning "Configuração padrão em uso"
    log_error "Falha na autenticação"
    log_debug "Variável DEBUG_MODE=true"
    
    log_subheader "Teste de Progresso"
    
    for i in {0..100..10}; do
        log_progress "Processando dados" "$i" "100"
        sleep 0.1
    done
    
    log_subheader "Recursos Avançados"
    log_info "📊 Logging JSON: ${LOG_JSON}"
    log_info "🖥️  Syslog: ${LOG_SYSLOG}"
    log_info "🎨 Terminal interativo: ${LOG_INTERACTIVE}"
}

# Inicialização automática inteligente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_logging
    log_demo
fi
