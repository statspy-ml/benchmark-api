#!/bin/bash

# Força locale para usar ponto como separador decimal
export LC_NUMERIC=C

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

RESULTS_DIR="./results"

# Função para extrair métricas do JSON
extract_metrics() {
    local json_file=$1
    local api=$2

    if [ ! -f "$json_file" ]; then
        echo -e "${RED}✗ JSON file not found: $json_file${NC}"
        return 1
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ${api^^} - Performance Metrics${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # HTTP Request Duration
    echo -e "${YELLOW}HTTP Request Duration (ms):${NC}"
    echo -n "  P50 (median): "
    jq -r '.metrics.http_req_duration.med' "$json_file"
    echo -n "  P90: "
    jq -r '.metrics.http_req_duration."p(90)"' "$json_file"
    echo -n "  P95: "
    jq -r '.metrics.http_req_duration."p(95)"' "$json_file"
    echo -n "  P99: "
    jq -r '.metrics.http_req_duration."p(99)"' "$json_file"
    echo -n "  Average: "
    jq -r '.metrics.http_req_duration.avg' "$json_file"
    echo -n "  Min: "
    jq -r '.metrics.http_req_duration.min' "$json_file"
    echo -n "  Max: "
    jq -r '.metrics.http_req_duration.max' "$json_file"
    echo ""

    # Throughput
    echo -e "${YELLOW}Throughput:${NC}"
    echo -n "  Requests per second: "
    jq -r '.metrics.http_reqs.rate' "$json_file"
    echo -n "  Total requests: "
    jq -r '.metrics.http_reqs.count' "$json_file"
    echo -n "  Failed requests: "
    jq -r '.metrics.http_req_failed.fails' "$json_file"
    echo ""

    # Checks
    echo -e "${YELLOW}Success Rate:${NC}"
    local checks_total=$(jq -r '.metrics.checks.passes + .metrics.checks.fails' "$json_file")
    local checks_passed=$(jq -r '.metrics.checks.passes' "$json_file")
    local success_rate=$(echo "scale=2; $checks_passed / $checks_total * 100" | bc)
    echo "  Checks passed: ${checks_passed} / ${checks_total} (${success_rate}%)"
    echo ""

    # Data transfer
    echo -e "${YELLOW}Data Transfer:${NC}"
    echo -n "  Data received: "
    jq -r '.metrics.data_received.count' "$json_file" | awk '{printf "%.2f MB\n", $1/1024/1024}'
    echo -n "  Data sent: "
    jq -r '.metrics.data_sent.count' "$json_file" | awk '{printf "%.2f MB\n", $1/1024/1024}'
    echo ""

    # Thresholds
    echo -e "${YELLOW}Thresholds:${NC}"
    jq -r '.metrics | to_entries[] | select(.value.thresholds != null) | .key as $metric | .value.thresholds | to_entries[] | "  \($metric) [\(.key)]: \(if .value then "✓ PASSED" else "✗ FAILED" end)"' "$json_file"
    echo ""
}

# Função para comparar todas as APIs
compare_apis() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  🏆 Performance Comparison Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Arrays para armazenar dados
    declare -A data
    local apis=(fastapi litestar go go-fiber go-gin)

    # Coleta dados de todos os frameworks
    for api in "${apis[@]}"; do
        local json_file=$(ls -t "$RESULTS_DIR/${api}_summary_"*.json 2>/dev/null | head -1)

        if [ -f "$json_file" ]; then
            data["${api}_p50"]=$(jq -r '.metrics.http_req_duration.med' "$json_file")
            data["${api}_p90"]=$(jq -r '.metrics.http_req_duration."p(90)"' "$json_file")
            data["${api}_p95"]=$(jq -r '.metrics.http_req_duration."p(95)"' "$json_file")
            data["${api}_p99"]=$(jq -r '.metrics.http_req_duration."p(99)"' "$json_file")
            data["${api}_avg"]=$(jq -r '.metrics.http_req_duration.avg' "$json_file")
            data["${api}_min"]=$(jq -r '.metrics.http_req_duration.min' "$json_file")
            data["${api}_max"]=$(jq -r '.metrics.http_req_duration.max' "$json_file")
            data["${api}_rps"]=$(jq -r '.metrics.http_reqs.rate' "$json_file")
            data["${api}_total"]=$(jq -r '.metrics.http_reqs.count' "$json_file")
            data["${api}_failed"]=$(jq -r '.metrics.http_req_failed.value' "$json_file")

            # Success rate
            local checks_total=$(jq -r '.metrics.checks.passes + .metrics.checks.fails' "$json_file")
            local checks_passed=$(jq -r '.metrics.checks.passes' "$json_file")
            data["${api}_success"]=$(echo "scale=2; $checks_passed / $checks_total * 100" | bc)
        fi
    done

    # Tabela 1: Latência
    echo -e "${CYAN}📊 Latency Metrics (milliseconds)${NC}"
    printf "%-15s %12s %12s %12s %12s %12s %12s\n" "Framework" "Min" "P50 (med)" "P90" "P95" "P99" "Max"
    echo "───────────────────────────────────────────────────────────────────────────────────────────────"

    for api in "${apis[@]}"; do
        local marker=""
        # Marca o melhor P50
        if [ -n "${data[${api}_p50]}" ]; then
            local is_best=$(echo "${data[fastapi_p50]} ${data[litestar_p50]} ${data[go_p50]} ${data[go-fiber_p50]} ${data[go-gin_p50]}" | tr ' ' '\n' | sort -n | head -1)
            if [ "$(echo "${data[${api}_p50]} == $is_best" | bc)" == "1" ]; then
                marker=" 🥇"
            fi
        fi

        printf "%-15s %12.3f %12.3f%s %12.3f %12.3f %12.3f %12.3f\n" \
            "$api" \
            "${data[${api}_min]}" \
            "${data[${api}_p50]}" \
            "$marker" \
            "${data[${api}_p90]}" \
            "${data[${api}_p95]}" \
            "${data[${api}_p99]}" \
            "${data[${api}_max]}"
    done
    echo ""

    # Tabela 2: Throughput
    echo -e "${CYAN}🚀 Throughput & Load Metrics${NC}"
    printf "%-15s %18s %18s %15s %15s\n" "Framework" "Requests/sec" "Total Requests" "Failed Rate %" "Success Rate %"
    echo "───────────────────────────────────────────────────────────────────────────────────────────────"

    for api in "${apis[@]}"; do
        local marker=""
        # Marca o melhor RPS
        if [ -n "${data[${api}_rps]}" ]; then
            local is_best=$(echo "${data[fastapi_rps]} ${data[litestar_rps]} ${data[go_rps]} ${data[go-fiber_rps]} ${data[go-gin_rps]}" | tr ' ' '\n' | sort -n | tail -1)
            if [ "$(echo "${data[${api}_rps]} == $is_best" | bc)" == "1" ]; then
                marker=" 🥇"
            fi
        fi

        local failed_pct=$(echo "scale=2; ${data[${api}_failed]} * 100" | bc)

        printf "%-15s %18.2f%s %18.0f %14.2f%% %14.2f%%\n" \
            "$api" \
            "${data[${api}_rps]}" \
            "$marker" \
            "${data[${api}_total]}" \
            "$failed_pct" \
            "${data[${api}_success]}"
    done
    echo ""

    # Tabela 3: Comparação relativa (Go como baseline)
    if [ -n "${data[go_p50]}" ]; then
        echo -e "${CYAN}📈 Performance Comparison (relative to Go)${NC}"
        printf "%-15s %15s %15s %15s\n" "Framework" "P50 vs Go" "P95 vs Go" "RPS vs Go"
        echo "───────────────────────────────────────────────────────────────────────────────────"

        for api in fastapi litestar; do
            if [ -n "${data[${api}_p50]}" ]; then
                local p50_ratio=$(echo "scale=2; ${data[${api}_p50]} / ${data[go_p50]}" | bc)
                local p95_ratio=$(echo "scale=2; ${data[${api}_p95]} / ${data[go_p95]}" | bc)
                local rps_ratio=$(echo "scale=2; ${data[${api}_rps]} / ${data[go_rps]}" | bc)

                printf "%-15s %14.2fx %14.2fx %14.2fx\n" "$api" "$p50_ratio" "$p95_ratio" "$rps_ratio"
            fi
        done
        echo ""
    fi

    # Exporta para CSV
    local csv_file="${RESULTS_DIR}/comparison_$(date +%Y%m%d_%H%M%S).csv"
    echo "Framework,Min,P50,P90,P95,P99,Max,RPS,Total_Requests,Failed_Rate,Success_Rate" > "$csv_file"
    for api in "${apis[@]}"; do
        if [ -n "${data[${api}_p50]}" ]; then
            local failed_pct=$(echo "scale=2; ${data[${api}_failed]} * 100" | bc)
            echo "${api},${data[${api}_min]},${data[${api}_p50]},${data[${api}_p90]},${data[${api}_p95]},${data[${api}_p99]},${data[${api}_max]},${data[${api}_rps]},${data[${api}_total]},${failed_pct},${data[${api}_success]}" >> "$csv_file"
        fi
    done
    echo -e "${GREEN}✓ Comparison exported to: ${csv_file}${NC}"
    echo ""
}

# Main
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Benchmark Results Analysis${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verifica se há arquivos JSON
json_count=$(ls "$RESULTS_DIR"/*_summary_*.json 2>/dev/null | wc -l)

if [ "$json_count" -eq 0 ]; then
    echo -e "${RED}✗ No JSON summary files found in $RESULTS_DIR${NC}"
    echo -e "${YELLOW}  Run the benchmark first: ./run-benchmark.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found $json_count JSON summary files${NC}"
echo ""

# Se um timestamp específico foi passado, usa ele
if [ -n "$1" ]; then
    TIMESTAMP=$1
    echo -e "${BLUE}Analyzing results for timestamp: $TIMESTAMP${NC}"
    echo ""

    for api in fastapi litestar go go-fiber go-gin; do
        json_file="$RESULTS_DIR/${api}_summary_${TIMESTAMP}.json"
        extract_metrics "$json_file" "$api"
    done
else
    # Caso contrário, pega os arquivos mais recentes
    echo -e "${BLUE}Analyzing most recent results...${NC}"
    echo ""

    for api in fastapi litestar go go-fiber go-gin; do
        json_file=$(ls -t "$RESULTS_DIR/${api}_summary_"*.json 2>/dev/null | head -1)
        if [ -n "$json_file" ]; then
            extract_metrics "$json_file" "$api"
        fi
    done
fi

# Comparação lado a lado
compare_apis

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  Analysis Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}HTML Reports available at:${NC}"
ls "$RESULTS_DIR"/*_report_*.html 2>/dev/null | while read file; do
    echo "  - $file"
done
echo ""
