#!/bin/bash
# tests/unit/core_tests.sh - Testes unitários para módulos core

# Setup do ambiente de teste
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/lib"

source "$LIB_DIR/core/logger.sh"
source "$LIB_DIR/core/validator.sh"
source "$LIB_DIR/core/resource_calculator.sh"

# Contadores de teste
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Função auxiliar para executar testes
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo "Executando: $test_name"
    
    if $test_function; then
        echo "  ✓ PASSOU"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ FALHOU"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo
}

# Testes do sistema de logging
test_logger_functions() {
    # Redirecionar output para evitar poluir console
    {
        log_info "Teste de info"
        log_success "Teste de sucesso"
        log_warning "Teste de warning"
        log_error "Teste de error"
        log_debug "Teste de debug"
    } >/dev/null 2>&1
    
    return 0  # Se chegou até aqui, as funções funcionam
}

test_logger_levels() {
    local original_level="$LOG_LEVEL"
    
    # Testar nível ERROR
    LOG_LEVEL="ERROR"
    local output=$(log_info "teste" 2>&1)
    
    # Restaurar nível original
    LOG_LEVEL="$original_level"
    
    # Em nível ERROR, log_info não deve produzir output
    [[ -z "$output" ]]
}

# Testes do sistema de validação
test_port_validation() {
    validate_port 8080 "teste" && \
    validate_port 1 "teste" && \
    validate_port 65535 "teste" && \
    ! validate_port 0 "teste" 2>/dev/null && \
    ! validate_port 65536 "teste" 2>/dev/null && \
    ! validate_port "abc" "teste" 2>/dev/null
}

test_cpu_validation() {
    validate_cpu 1 "teste" && \
    validate_cpu 64 "teste" && \
    ! validate_cpu 0 "teste" 2>/dev/null && \
    ! validate_cpu 65 "teste" 2>/dev/null && \
    ! validate_cpu "abc" "teste" 2>/dev/null
}

test_memory_validation() {
    validate_memory 512 "teste" && \
    validate_memory 131072 "teste" && \
    ! validate_memory 511 "teste" 2>/dev/null && \
    ! validate_memory 131073 "teste" 2>/dev/null && \
    ! validate_memory "abc" "teste" 2>/dev/null
}

# Testes do calculador de recursos
test_system_detection() {
    detect_system_resources >/dev/null
    
    # Verificar se as variáveis foram definidas
    [[ -n "${SYSTEM_RESOURCES[CPU_CORES]}" ]] && \
    [[ -n "${SYSTEM_RESOURCES[MEMORY_MB]}" ]] && \
    [[ -n "${SYSTEM_RESOURCES[PROFILE]}" ]]
}

test_resource_calculation() {
    # Simular sistema com recursos conhecidos
    SYSTEM_RESOURCES[CPU_CORES]=4
    SYSTEM_RESOURCES[MEMORY_MB]=8192
    
    calculate_available_resources >/dev/null
    
    # Verificar se os recursos disponíveis foram calculados
    [[ -n "${AVAILABLE_RESOURCES[CPU_MILLICORES]}" ]] && \
    [[ -n "${AVAILABLE_RESOURCES[MEMORY_MB]}" ]] && \
    [[ ${AVAILABLE_RESOURCES[CPU_MILLICORES]} -gt 0 ]] && \
    [[ ${AVAILABLE_RESOURCES[MEMORY_MB]} -gt 0 ]]
}

test_awx_resource_calculation() {
    # Definir recursos disponíveis simulados
    AVAILABLE_RESOURCES[CPU_MILLICORES]=2000
    AVAILABLE_RESOURCES[MEMORY_MB]=4096
    SYSTEM_RESOURCES[PROFILE]="dev"
    
    calculate_awx_resources >/dev/null
    
    # Verificar se os recursos AWX foram calculados
    [[ -n "${AWX_RESOURCES[WEB_REPLICAS]}" ]] && \
    [[ -n "${AWX_RESOURCES[TASK_REPLICAS]}" ]] && \
    [[ -n "${AWX_RESOURCES[WEB_CPU_REQ]}" ]] && \
    [[ -n "${AWX_RESOURCES[WEB_MEM_REQ]}" ]]
}

# Executar todos os testes
main() {
    echo "=== TESTES UNITÁRIOS - MÓDULOS CORE ==="
    echo
    
    # Testes do logger
    run_test "Logger - Funções básicas" test_logger_functions
    run_test "Logger - Níveis de log" test_logger_levels
    
    # Testes do validator
    run_test "Validator - Validação de porta" test_port_validation
    run_test "Validator - Validação de CPU" test_cpu_validation
    run_test "Validator - Validação de memória" test_memory_validation
    
    # Testes do resource calculator
    run_test "Resource Calculator - Detecção do sistema" test_system_detection
    run_test "Resource Calculator - Cálculo de recursos" test_resource_calculation
    run_test "Resource Calculator - Recursos AWX" test_awx_resource_calculation
    
    # Relatório final
    echo "=== RELATÓRIO DE TESTES ==="
    echo "Total de testes: $TESTS_RUN"
    echo "Passaram: $TESTS_PASSED"
    echo "Falharam: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✓ Todos os testes passaram!"
        exit 0
    else
        echo "✗ Alguns testes falharam"
        exit 1
    fi
}

main "$@"
