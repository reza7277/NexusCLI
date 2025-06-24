#!/bin/bash
set -e

# === Basic Configuration ===
BASE_CONTAINER_NAME="nexus-node"
IMAGE_NAME="nexus-node:latest"
LOG_DIR="/root/nexus_logs"

# === Terminal Colors ===
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# === Display Custom Banner ===
function show_header() {
  clear
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

# === Check Docker Installation ===
function check_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}Docker not found. Installing Docker...${RESET}"
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

# === Check Cron Installation ===
function check_cron() {
  if ! command -v cron >/dev/null 2>&1; then
    echo -e "${YELLOW}Cron not found. Installing cron...${RESET}"
    apt update
    apt install -y cron
    systemctl enable cron
    systemctl start cron
  fi
}

# === Build Docker Image ===
function build_image() {
  WORKDIR=$(mktemp -d)
  cd "$WORKDIR"
  cat > Dockerfile <<EOF
FROM ubuntu:latest
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
EOF
  docker build -t "$IMAGE_NAME" .
  cd -
  rm -rf "$WORKDIR"
}

# === Run Container ===
function run_container() {
  local node_id=$1
  local container_name="${BASE_CONTAINER_NAME}-${node_id}"
  local log_file="${LOG_DIR}/nexus-${node_id}.log"
  docker rm -f "$container_name" 2>/dev/null || true
  mkdir -p "$LOG_DIR"
  touch "$log_file"
  chmod 644 "$log_file"
  docker run -d --name "$container_name" \
    -v "$log_file":/root/nexus.log \
    -e NODE_ID="$node_id" \
    "$IMAGE_NAME"
  check_cron
  echo "0 0 * * * rm -f $log_file" > "/etc/cron.d/nexus-log-cleanup-${node_id}"
}

# === Uninstall Node ===
function uninstall_node() {
  local node_id=$1
  local cname="${BASE_CONTAINER_NAME}-${node_id}"
  docker rm -f "$cname" 2>/dev/null || true
  rm -f "${LOG_DIR}/nexus-${node_id}.log" "/etc/cron.d/nexus-log-cleanup-${node_id}"
  echo -e "${YELLOW}Node $node_id has been removed.${RESET}"
}

# === Get All Nodes ===
function get_all_nodes() {
  docker ps -a --format "{{.Names}}" | grep "^${BASE_CONTAINER_NAME}-" | sed "s/${BASE_CONTAINER_NAME}-//"
}

# === Display All Nodes ===
function list_nodes() {
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
    local status="Inactive"
    if docker inspect "$container" &>/dev/null; then
      status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
      if [[ "$status" == "running" ]]; then
        stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}" "$container" 2>/dev/null)
        cpu=$(echo "$stats" | cut -d'|' -f1)
        mem=$(echo "$stats" | cut -d'|' -f2 | cut -d'/' -f1 | xargs)
      elif [[ "$status" == "exited" ]]; then
        failed_nodes+=("$node_id")
      fi
    fi
    printf "%-5s %-20s %-12s %-15s %-15s\n" "$((i+1))" "$node_id" "$status" "$cpu" "$mem"
  done
  echo "--------------------------------------------------------------"
  if [ ${#failed_nodes[@]} -gt 0 ]; then
    echo -e "${RED}⚠ Failed nodes (exited):${RESET}"
    for id in "${failed_nodes[@]}"; do
      echo "- $id"
    done
  fi
  read -p "Press enter to return to menu..."
}

# === Main Menu ===
while true; do
  show_header
  echo -e "${GREEN} 1.${RESET} ➕ Install & Run Node"
  echo -e "${GREEN} 2.${RESET} View All Nodes Status"
  echo -e "${GREEN} 3.${RESET} ❌ Remove Specific Node"
  echo -e "${GREEN} 4.${RESET} View Node Logs"
  echo -e "${GREEN} 5.${RESET} Remove All Nodes"
  echo -e "${GREEN} 6.${RESET} Exit"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  read -rp "Select menu (1-6): " choice
  case $choice in
    1) check_docker; read -rp "Enter NODE_ID: " NODE_ID; [ -z "$NODE_ID" ] && echo "NODE_ID cannot be empty." && read -p "Press enter..." && continue; build_image; run_container "$NODE_ID"; read -p "Press enter..." ;;
    2) list_nodes ;;
    3) batch_uninstall_nodes ;;
    4) view_logs ;;
    5) uninstall_all_nodes ;;
    6) echo "Exiting..."; exit 0 ;;
    *) echo "Invalid choice."; read -p "Press enter..." ;;
  esac
done
