#!/bin/bash
set -e

# Display custom banner
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

# Display menu header
show_header() {
    clear
    display_banner
    echo
    echo "==================== NEXUS - CLI Node ===================="
}

# Clear screen and show banner on start
show_header

# === Begin Nexus.sh from upstream repository ===

BASE_CONTAINER_NAME="nexus-node"
IMAGE_NAME="nexus-node:latest"
LOG_DIR="/root/nexus_logs"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

check_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}Docker not found.\nInstalling Docker...${RESET}"
    apt update
    apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt update
    apt install -y docker-ce
    systemctl enable docker
    systemctl start docker
  fi
}

check_cron() {
  if ! command -v cron >/dev/null 2>&1; then
    echo -e "${YELLOW}Cron not found.\nInstalling cron...${RESET}"
    apt update
    apt install -y cron
    systemctl enable cron
    systemctl start cron
  fi
}

build_image() {
  WORKDIR=$(mktemp -d)
  cd "$WORKDIR"
  cat > Dockerfile <<EOF
FROM ubuntu:20.04
# (tuliskan Dockerfile di sini)
EOF
  docker build -t "$IMAGE_NAME" .
  cd -
  rm -rf "$WORKDIR"
}

run_container() {
  local node_id=$1
  local container_name="${BASE_CONTAINER_NAME}-${node_id}"
  local log_file="${LOG_DIR}/nexus-${node_id}.log"

  docker rm -f "$container_name" 2>/dev/null || true
  mkdir -p "$LOG_DIR"
  touch "$log_file"
  chmod 644 "$log_file"

  docker run -d --rm --name "$container_name" \
    -v "$log_file":/root/nexus.log \
    -e NODE_ID="$node_id" \
    "$IMAGE_NAME"

  check_cron
  echo "0 0 * * * rm -f $log_file" > "/etc/cron.d/nexus-log-cleanup-${node_id}"
}

uninstall_node() {
  local node_id=$1
  local cname="${BASE_CONTAINER_NAME}-${node_id}"

  docker rm -f "$cname" 2>/dev/null || true
  rm -f "${LOG_DIR}/nexus-${node_id}.log" "/etc/cron.d/nexus-log-cleanup-${node_id}"
}

get_all_nodes() {
  docker ps -a --format "{{.Names}}" \
    | grep "^${BASE_CONTAINER_NAME}-" \
    | sed "s/${BASE_CONTAINER_NAME}-//"
}

list_nodes() {
  show_header
  echo -e "${CYAN} Registered Nodes:${RESET}"
  echo "--------------------------------------------------------------"
  printf "%-5s %-20s %-12s %-15s %-15s\n" "No" "Node ID" "Status" "CPU" "Memory"
  echo "--------------------------------------------------------------"

  local all_nodes=($(get_all_nodes))
  local failed_nodes=()
  for i in "${!all_nodes[@]}"; do
    local node_id=${all_nodes[$i]}
    local container="${BASE_CONTAINER_NAME}-${node_id}"
    local cpu="N/A"
    local mem="N/A"
    local status="inactive"

    if docker inspect "$container" &>/dev/null; then
      status=$(docker inspect -f '{{.State.Status}}' "$container")
      if [[ "$status" == "running" ]]; then
        stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}" "$container")
        cpu=$(echo "$stats" | cut -d'|' -f1)
        mem=$(echo "$stats" | cut -d'|' -f2 | cut -d'/' -f1 | xargs)
      elif [[ "$status" == "exited" ]]; then
        failed_nodes+=("$node_id")
      fi
    fi

    printf "%-5s %-20s %-12s %-15s %-15s\n" \
      "$((i+1))" "$node_id" "$status" "$cpu" "$mem"
  done
  echo "--------------------------------------------------------------"

  if [ ${#failed_nodes[@]} -gt 0 ]; then
    echo -e "${RED}⚠ Nodes failed to start (exited):${RESET}"
    for id in "${failed_nodes[@]}"; do
      echo "- $id"
    done
  fi

  read -p "Press enter to return to menu..." dummy
}

view_logs() {
  local all_nodes=($(get_all_nodes))
  if [ ${#all_nodes[@]} -eq 0 ]; then
    echo "No nodes available."
    read -p "Press enter..." dummy
    return
  fi

  echo "Select a node to view logs:"
  for i in "${!all_nodes[@]}"; do
    echo "$((i+1)). ${all_nodes[$i]}"
  done
  read -rp "Number: " choice

  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#all_nodes[@]} )); then
    docker logs -f "${BASE_CONTAINER_NAME}-${all_nodes[$((choice-1))]}"
  fi

  read -p "Press enter..." dummy
}

remove_nodes() {
  local all_nodes=($(get_all_nodes))
  echo "Enter numbers to remove (space-separated):"
  for i in "${!all_nodes[@]}"; do
    echo "$((i+1)). ${all_nodes[$i]}"
  done
  read -rp "Numbers: " input

  for num in $input; do
    if [[ "$num" =~ ^[0-9]+$ ]] && (( num > 0 && num <= ${#all_nodes[@]} )); then
      uninstall_node "${all_nodes[$((num-1))]}"
    fi
  done

  read -p "Press enter..." dummy
}

remove_all_nodes() {
  read -rp "Confirm remove ALL nodes? (y/n): " confirm

  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    for node in $(get_all_nodes); do
      uninstall_node "$node"
    done
  fi

  read -p "Press enter..." dummy
}

while true; do
  show_header
  echo -e "${GREEN}1) Install & Run Node${RESET}"
  echo -e "${GREEN}2) List Nodes${RESET}"
  echo -e "${GREEN}3) Remove Nodes${RESET}"
  echo -e "${GREEN}4) View Node Logs${RESET}"
  echo -e "${GREEN}5) Remove All Nodes${RESET}"
  echo -e "${GREEN}6) Exit${RESET}"
  read -rp "Choose an option [1-6]: " pilihan

  case $pilihan in
    1)
      check_docker
      read -rp "Enter NODE_ID: " NODE_ID
      [ -z "$NODE_ID" ] && continue
      build_image
      run_container "$NODE_ID"
      ;;  
    2) list_nodes ;;  
    3) remove_nodes ;;  
    4) view_logs ;;  
    5) remove_all_nodes ;;  
    6) exit 0 ;;  
    *) ;;  
  esac
done
