#!/bin/bash
set -e

echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - Script started"

display_banner() {
    echo "[DEBUG] Entering display_banner"
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

show_header() {
    echo "[DEBUG] Entering show_header"
    clear
display_banner
echo
 echo "==================== NEXUS - Airdrop Node ===================="
}

echo "[DEBUG] Initializing variables"
BASE_CONTAINER_NAME="nexus-node"
IMAGE_NAME="nexus-node:latest"
LOG_DIR="/root/nexus_logs"

echo "[DEBUG] Setting terminal colors"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

check_docker() {
    echo "[DEBUG] Checking Docker availability"
    if ! command -v docker &>/dev/null; then
        echo -e "${YELLOW}Docker not found. Installing...${RESET}"
        apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update && apt install -y docker-ce
        systemctl enable --now docker
        echo "[DEBUG] Docker installed"
    else
        echo "[DEBUG] Docker is already installed"
    fi
}

check_cron() {
    echo "[DEBUG] Checking Cron availability"
    if ! command -v cron &>/dev/null; then
        echo -e "${YELLOW}Cron not found. Installing...${RESET}"
        apt update && apt install -y cron
        systemctl enable --now cron
        echo "[DEBUG] Cron installed"
    else
        echo "[DEBUG] Cron is already installed"
    fi
}

build_image() {
    echo "[DEBUG] Starting image build"
    temp_dir=$(mktemp -d)
    echo "[DEBUG] Created temp dir: $temp_dir"
    if [ -f Dockerfile ]; then cp Dockerfile "$temp_dir/"; fi
    cd "$temp_dir" || exit
    if [ ! -f Dockerfile ]; then
        cat > Dockerfile <<EOF
FROM ubuntu:20.04
EOF
        echo "[DEBUG] Generated default Dockerfile"
    fi
    echo "[DEBUG] Running docker build -t $IMAGE_NAME"
    docker build -t "$IMAGE_NAME" .
    echo "[DEBUG] Docker image built: $IMAGE_NAME"
    cd - || exit
    rm -rf "$temp_dir"
    echo "[DEBUG] Removed temp dir: $temp_dir"
}

run_container() {
    local id=$1
    echo "[DEBUG] Running container for node ID: $id"
    local name="${BASE_CONTAINER_NAME}-${id}"
    local log_file="${LOG_DIR}/nexus-${id}.log"

    mkdir -p "$LOG_DIR"
    touch "$log_file"
    chmod 644 "$log_file"
    echo "[DEBUG] Prepared log file: $log_file"

    docker rm -f "$name" &>/dev/null || true
    echo "[DEBUG] Removed existing container if any: $name"
    docker run -d --rm --name "$name" \
        -v "${log_file}":/root/nexus.log \
        -e NODE_ID="$id" \
        "$IMAGE_NAME"
    echo "[DEBUG] Container started: $name"

    check_cron
    echo "0 0 * * * rm -f ${log_file}" > "/etc/cron.d/nexus-log-cleanup-${id}"
    echo "[DEBUG] Cron job created: nexus-log-cleanup-${id}"
}

uninstall_node() {
    local id=$1
    echo "[DEBUG] Uninstalling node ID: $id"
    local name="${BASE_CONTAINER_NAME}-${id}"
    docker rm -f "$name" &>/dev/null || true
    rm -f "${LOG_DIR}/nexus-${id}.log" "/etc/cron.d/nexus-log-cleanup-${id}"
    echo "[DEBUG] Removed node: $id"
}

get_all_nodes() {
    echo "[DEBUG] Retrieving all nodes"
    docker ps -a --format "{{.Names}}" | grep "^${BASE_CONTAINER_NAME}-" | sed "s/${BASE_CONTAINER_NAME}-//"
}

list_nodes() {
    echo "[DEBUG] Listing nodes"
    show_header
    printf "%-5s %-20s %-12s %-10s %-10s
" "No" "Node ID" "Status" "CPU" "Memory"
    echo "---------------------------------------------------------------"
    mapfile -t nodes < <(get_all_nodes)
    if [ "${#nodes[@]}" -eq 0 ]; then echo "[DEBUG] No nodes found"; fi
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
        printf "%-5s %-20s %-12s %-10s %-10s
" "$((i+1))" "$id" "$status" "$cpu" "$mem"
    done
    read -rp "Press Enter to continue..." dummy
}

view_logs() {
    echo "[DEBUG] Viewing logs"
    mapfile -t nodes < <(get_all_nodes)
    if [ "${#nodes[@]}" -eq 0 ]; then echo "No nodes found."; read -rp "Press Enter..." dummy; return; fi
    for i in "${!nodes[@]}"; do echo "$((i+1))). ${nodes[$i]}"; done
    read -rp "Select node number: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#nodes[@]}" ]; then
        echo "[DEBUG] Showing logs for node: ${nodes[$((choice-1))]}"
        docker logs -f "${BASE_CONTAINER_NAME}-${nodes[$((choice-1))]}"
    fi
    read -rp "Press Enter..." dummy
}

remove_nodes() {
    echo "[DEBUG] Removing nodes"
    mapfile -t nodes < <(get_all_nodes)
    echo "Enter node numbers to remove (space-separated):"
    for i in "${!nodes[@]}"; do echo "$((i+1))). ${nodes[$i]}"; done
    read -rp "Choice: " input
    for num in $input; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#nodes[@]}" ]; then
            uninstall_node "${nodes[$((num-1))]}"
        fi
    done
    read -rp "Press Enter..." dummy
}

remove_all_nodes() {
    echo "[DEBUG] Removing all nodes"
    read -rp "Remove ALL nodes? (y/n): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        mapfile -t nodes < <(get_all_nodes)
        for id in "${nodes[@]}"; do uninstall_node "$id"; done
    fi
    read -rp "Press Enter..." dummy
}

while true; do
    echo "[DEBUG] Main menu prompt"
    show_header
    echo "1) Install & Run Node"
    echo "2) List Nodes"
    echo "3) Remove Nodes"
    echo "4) View Node Logs"
    echo "5) Remove All Nodes"
    echo "6) Exit"
    read -rp "Select an option [1-6]: " opt
    echo "[DEBUG] Selected option: $opt"
    case $opt in
        1)
            check_docker
            read -rp "Enter NODE_ID: " nid
            echo "[DEBUG] NODE_ID entered: $nid"
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
            echo "[DEBUG] Exiting"
            exit 0
            ;;
        *)
            echo "[DEBUG] Invalid option: $opt"
            ;;
    esac
done
