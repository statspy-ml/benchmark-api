#!/bin/bash

# Força locale para usar ponto como separador decimal
export LC_NUMERIC=C

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório de resultados
RESULTS_DIR="./results"
mkdir -p "$RESULTS_DIR"

# Timestamp do benchmark
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Benchmark I/O (Database) Test${NC}"
echo -e "${BLUE}  FastAPI vs Litestar vs Go Variants${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Função para coletar métricas do Docker
collect_docker_stats() {
    local api=$1
    local output_file=$2
    local container_name="benchmark-${api}"

    echo "timestamp,cpu_percent,mem_usage_mb,mem_limit_mb,mem_percent,net_in_mb,net_out_mb" > "$output_file"

    while true; do
        stats=$(docker stats "$container_name" --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" 2>/dev/null)
        if [ -z "$stats" ]; then
            break
        fi

        cpu=$(echo "$stats" | cut -d',' -f1 | tr -d '%')
        mem_info=$(echo "$stats" | cut -d',' -f2)
        mem_usage=$(echo "$mem_info" | cut -d'/' -f1 | sed 's/MiB//g' | xargs)
        mem_limit=$(echo "$mem_info" | cut -d'/' -f2 | sed 's/GiB//g' | xargs)

        mem_limit_mb=$(echo "$mem_limit * 1024" | bc)
        mem_percent=$(echo "scale=2; $mem_usage / $mem_limit_mb * 100" | bc)

        net_stats=$(docker stats "$container_name" --no-stream --format "{{.NetIO}}" 2>/dev/null)
        net_in=$(echo "$net_stats" | cut -d'/' -f1 | sed 's/MB//g' | xargs)
        net_out=$(echo "$net_stats" | cut -d'/' -f2 | sed 's/MB//g' | xargs)

        timestamp=$(date +%s)
        echo "$timestamp,$cpu,$mem_usage,$mem_limit_mb,$mem_percent,$net_in,$net_out" >> "$output_file"

        sleep 2
    done
}

# Função para rodar teste em uma API
run_test() {
    local api=$1
    local container_name="benchmark-${api}"

    echo -e "${YELLOW}----------------------------------------${NC}"
    echo -e "${YELLOW}Testing: $api (I/O Bound)${NC}"
    echo -e "${YELLOW}----------------------------------------${NC}"
    echo ""

    local docker_stats_file="${RESULTS_DIR}/${api}_io_docker_stats_${TIMESTAMP}.csv"

    echo -e "${BLUE}→ Starting Docker stats collection...${NC}"
    collect_docker_stats "$api" "$docker_stats_file" &
    local stats_pid=$!

    sleep 3

    echo -e "${BLUE}→ Running K6 I/O load test...${NC}"

    export USER_ID=$(id -u)
    export GROUP_ID=$(id -g)

    docker compose run --rm k6 run /scripts/load-test-io.js \
        -e API="$api" \
        -e TIMESTAMP="${TIMESTAMP}" \
        --out json="/results/${api}_io_metrics_${TIMESTAMP}.json" \
        --summary-export="/results/${api}_io_summary_${TIMESTAMP}.json" \
        2>&1 | sed -r "s/\x1B\[[0-9;]*[mK]//g" | tee "${RESULTS_DIR}/${api}_io_output_${TIMESTAMP}.log"

    kill $stats_pid 2>/dev/null
    wait $stats_pid 2>/dev/null

    echo -e "${GREEN}✓ Test completed for $api${NC}"
    echo ""

    if [ "$api" != "rust" ]; then
        echo -e "${BLUE}→ Cooling down for 60 seconds...${NC}"
        sleep 60
    fi
}

# Verifica se os containers estão rodando
echo -e "${BLUE}→ Checking if containers are running...${NC}"
docker compose ps | grep -q "benchmark-postgres.*Up" || {
    echo -e "${RED}✗ PostgreSQL not running. Starting all services...${NC}"
    docker compose up -d postgres fastapi litestar go go-fiber go-gin rust
    echo -e "${BLUE}→ Waiting 30 seconds for containers to be ready...${NC}"
    sleep 30
}

echo -e "${GREEN}✓ All containers are ready${NC}"
echo ""

# Roda testes para cada API
run_test "fastapi"
run_test "litestar"
run_test "go"
run_test "go-fiber"
run_test "go-gin"
run_test "rust"

# Resumo final
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  All I/O benchmarks completed!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Results saved in: ${YELLOW}${RESULTS_DIR}${NC}"
echo ""
echo "Files generated:"
ls -lh "$RESULTS_DIR"/*"io"*"${TIMESTAMP}"* 2>/dev/null | awk '{print "  - " $9}'
echo ""
echo -e "${BLUE}To analyze results, run: ./analyze-results.sh${NC}"
echo ""
