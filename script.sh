#!/bin/bash
set -e

# Display ASCII banner
display_banner() {
    echo "
██████╗ ███████╗███████╗ █████╗     ███████╗██████╗ ███████╗███████╗
██╔══██╗██╔════╝╚══███╔╝██╔══██╗    ╚════██║╚════██╗╚════██║╚════██║
██████╔╝█████╗    ███╔╝ ███████║        ██╔╝ █████╔╝    ██╔╝    ██╔╝
██╔══██╗██╔══╝   ███╔╝  ██╔══██║       ██╔╝ ██╔═══╝    ██╔╝    ██╔╝ 
██║  ██║███████╗███████╗██║  ██║       ██║  ███████╗   ██║     ██║  
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝       ╚═╝  ╚══════╝   ╚═╝     ╚═╝  
"
    echo "Created by: Reza"
    echo "Join us: https://t.me/Web3loverz"
}

clear
display_banner

# Display menu header
show_header() {
    clear
    display_banner
    echo
    echo "==================== NEXUS - Airdrop Node ===================="
}

# Configuration
BASE_CONTAINER_NAME="nexus-node"
IMAGE_NAME="nexus-node:latest"
LOG_DIR="/root/nexus_logs"

# Terminal colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Ensure Docker is installed
check_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${YELLOW}Docker not found. Installing...${RESET}"
        apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update && apt install -y docker-ce
        systemctl enable --now docker
    fi
}

# Ensure cron is installed
check_cron() {
    if ! command -v cron &>/dev/null; then
        echo -e "${YELLOW}Cron not found. Installing...${RESET}"
        apt update && apt install -y cron
        systemctl enable --now cron
    fi
}

# Build Docker image
build_image() {
    temp_dir=$(mktemp -d)
    if [ -f Dockerfile ]; then
        cp Dockerfile "$temp_dir/"
    fi
    cd "$temp_dir" || exit
    if [ ! -f Dockerfile ]; then
        cat > Dockerfile <<EOF
FROM ubuntu:20.04
EOF
    fi
    docker build -t "$IMAGE_NAME" .
    cd - || exit
    rm -rf "$temp_dir"
}

# Run a node container
run_container() {
    local id="$1"
    local name="${BASE_CONTAINER_NAME}-${id}"
    local log_file="${LOG_DIR}/nexus-${id}.log"

    mkdir -p "$LOG_DIR"
    touch "$log_file"
    chmod 644 "$log_file"

    docker rm -f "$name" &>/dev/null || true
    docker run -d --rm --name "$name" \
        -v "${log_file}":/root/nexus.log \
        -e NODE_ID="$id" \
        "$IMAGE_NAME"

    check_cron
    echo "0 0 * * * rm -f ${log_file}" > "/etc/cron.d/nexus-log-cleanup-${id}"
}

# Uninstall a node
uninstall_node() {
    local id="$1"
    local name="${BASE_CONTAINER_NAME}-${id}"
    docker rm -f "$name" &>/dev/null || true
    rm -f "${LOG_DIR}/nexus-${id}.log" "/etc/cron.d/nexus-log-cleanup-${id}"
}

# Get all node IDs
get_all_nodes() {
    docker ps -a --format "{{.Names}}" | grep "^${BASE_CONTAINER_NAME}-" | sed "s/${BASE_CONTAINER_NAME}-//"
}

# List nodes and their status
list_nodes() {
    show_header
    printf "%-5s %-20s %-12s %-10s %-10s\n" "No" "Node ID" "Status" "CPU" "Memory"
    echo "---------------------------------------------------------------"
    mapfile -t nodes < <(get_all_nodes)
    for i in "${!nodes[@]}"; do
        id=${nodes[$i]}
        name="${BASE_CONTAINER_NAME}-${id}"
        status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "absent")
        if [ "$status" = "running" ]; then
            stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}" "$name")
            cpu=${stats%%|*}
            mem=${stats#*|}
        else
            cpu="N/A"
            mem="N/A"
        fi
        printf "%-5s %-20s %-12s %-10s %-10s\n" "$((i+1))" "$id" "$status" "$cpu" "$mem"
    done
    read -rp "Press Enter to continue..." dummy
}

# View logs for a node
view_logs() {
    mapfile -t nodes < <(get_all_nodes)
    if [ "${#nodes[@]}" -eq 0 ]; then
        echo "No nodes found."
        read -rp "Press Enter..." dummy
        return
    fi
    for i in "${!nodes[@]}"; do
        echo "$((i+1))). ${nodes[$i]}"
    done
    read -rp "Select node number: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#nodes[@]}" ]; then
        docker logs -f "${BASE_CONTAINER_NAME}-${nodes[$((choice-1))]}"
    fi
    read -rp "Press Enter..." dummy
}

# Remove selected nodes
remove_nodes() {
    mapfile -t nodes < <(get_all_nodes)
    echo "Enter node numbers to remove (space-separated):"
    for i in "${!nodes[@]}"; do
        echo "$((i+1))). ${nodes[$i]}"
    done
    read -rp "Choice: " input
    for num in $input; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#nodes[@]}" ]; then
            uninstall_node "${nodes[$((num-1))]}"
        fi
    done
    read -rp "Press Enter..." dummy
}

# Remove all nodes
remove_all_nodes() {
    read -rp "Remove ALL nodes? (y/n): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        mapfile -t nodes < <(get_all_nodes)
        for id in "${nodes[@]}"; do
            uninstall_node "$id"
        done
    fi
    read -rp "Press Enter..." dummy
}

# Main menu loop
while true; do
    show_header
    echo "1) Install & Run Node"
    echo "2) List Nodes"
    echo "3) Remove Nodes"
    echo "4) View Node Logs"
    echo "5) Remove All Nodes"
    echo "6) Exit"
    read -rp "Select an option [1-6]: " opt
    case $opt in
        1)
            check_docker
            read -rp "Enter NODE_ID: " nid
            if [ -n "$nid" ]; then
                build_image
                run_container "$nid"
            fi
            ;;
        2)
            list_nodes
            ;;
        3)
            remove_nodes
            ;;
        4)
            view_logs
            ;;
        5)
            remove_all_nodes
            ;;
        6)
            exit 0
            ;;
        *)
            ;;
    esac
done
