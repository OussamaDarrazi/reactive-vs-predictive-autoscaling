#!/bin/bash
set -euo pipefail

############################
# COLORS
############################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

############################
# CONFIG
############################
REGISTRY_NAME="local-registry"
REGISTRY_PORT=5000
REGISTRY_ADDR="localhost:${REGISTRY_PORT}"

APP_NAME="workload-api"
APP_DIR="./api"


############################
# HELPERS
############################

# Poll a condition command until it succeeds or retries run out.
# Usage: wait_for <retries> <sleep_sec> <description> <command...>
wait_for() {
  local retries=$1 interval=$2 desc=$3
  shift 3
  local i=0
  until "$@" >/dev/null 2>&1; do
    i=$(( i + 1 ))
    if [ "$i" -ge "$retries" ]; then
      log_error "Timed out waiting for: ${desc}"
      return 1
    fi
    log_info "Waiting for ${desc} (attempt ${i}/${retries})..."
    sleep "$interval"
  done
  log_success "${desc} is ready"
}

############################
# DOCKER INSTALL (IDEMPOTENT)
############################
install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log_success "Docker already installed"

    # Ensure the daemon is running
    if ! sudo systemctl is-active --quiet docker; then
      log_info "Docker installed but not running, starting..."
      sudo systemctl start docker
      log_success "Docker daemon started"
    fi
    return
  fi

  log_info "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" || true
  sudo systemctl enable --now docker
  log_success "Docker installed and started"
}

############################
# DOCKER INSECURE REGISTRY
############################
configure_docker_insecure_registry() {
  local cfg="/etc/docker/daemon.json"

  if sudo test -f "$cfg" && sudo grep -q "${REGISTRY_ADDR}" "$cfg" 2>/dev/null; then
    log_success "Docker insecure registry already configured"
    return
  fi

  log_info "Configuring Docker insecure registry for ${REGISTRY_ADDR}..."

  # Merge into existing daemon.json if present, otherwise create fresh
  if sudo test -f "$cfg"; then
    local existing
    existing=$(sudo cat "$cfg")
    # Append insecure-registries key; requires jq — fall back to overwrite if absent
    if command -v jq >/dev/null 2>&1; then
      echo "$existing" \
        | jq --arg reg "${REGISTRY_ADDR}" \
            '.["insecure-registries"] += [$reg] | .["insecure-registries"] |= unique' \
        | sudo tee "$cfg" > /dev/null
    else
      log_warn "jq not found — overwriting daemon.json (existing content preserved as .bak)"
      sudo cp "$cfg" "${cfg}.bak"
      echo "{\"insecure-registries\":[\"${REGISTRY_ADDR}\"]}" | sudo tee "$cfg" > /dev/null
    fi
  else
    echo "{\"insecure-registries\":[\"${REGISTRY_ADDR}\"]}" | sudo tee "$cfg" > /dev/null
  fi

  sudo systemctl restart docker
  log_success "Docker daemon restarted with insecure registry config"
}

############################
# REGISTRY (IDEMPOTENT)
############################
start_registry() {
  if docker ps -a --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
    if docker ps --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
      log_success "Registry already running"
    else
      log_info "Registry container exists but is stopped, starting..."
      docker start "${REGISTRY_NAME}"
      log_success "Registry started"
    fi
  else
    log_info "Creating local Docker registry..."
    docker run -d \
      --restart=always \
      -p "${REGISTRY_PORT}:5000" \
      --name "${REGISTRY_NAME}" \
      registry:2
    log_success "Registry created at ${REGISTRY_ADDR}"
  fi

  # Wait until the registry API is actually reachable before continuing
  wait_for 15 2 "registry HTTP API" \
    curl -sf "http://${REGISTRY_ADDR}/v2/"
}

############################
# K3S INSTALL (IDEMPOTENT)
############################
install_k3s() {
  if command -v k3s >/dev/null 2>&1; then
    log_success "K3s already installed"

    if ! sudo systemctl is-active --quiet k3s; then
      log_info "K3s installed but not running, starting..."
      sudo systemctl start k3s
      log_success "K3s service started"
    fi
    return
  fi

  log_info "Installing k3s..."
    curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC='server --node-taint ""' sh -
  log_success "K3s installed"
}

############################
# K3S REGISTRY CONFIG (IDEMPOTENT)
############################
configure_registry() {
  sudo mkdir -p /etc/rancher/k3s

  local reg_file="/etc/rancher/k3s/registries.yaml"

  if sudo test -f "$reg_file" && sudo grep -q "${REGISTRY_ADDR}" "$reg_file"; then
    log_success "K3s registry already configured"
    return
  fi

  log_info "Writing k3s registry config..."
  sudo tee "$reg_file" > /dev/null <<EOF
mirrors:
  "${REGISTRY_ADDR}":
    endpoint:
      - "http://${REGISTRY_ADDR}"
EOF

  # Restart if running, otherwise just start — registry config is read at startup
  if sudo systemctl is-active --quiet k3s; then
    log_info "Restarting k3s to apply registry config..."
    sudo systemctl restart k3s
  else
    log_info "Starting k3s..."
    sudo systemctl start k3s
  fi

  log_success "K3s restarted with registry config"
}

############################
# KUBECTL CONFIG
############################
setup_kubeconfig() {
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

    wait_for 20 3 "Kubernetes API server" \
        kubectl cluster-info
}

############################
# HELM INSTALL
############################
install_helm() {
  if command -v helm >/dev/null 2>&1; then
    log_success "Helm already installed"
    return
  fi

  log_info "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  log_success "Helm installed"
}

# Add a Helm repo if not already present, and always refresh its cache.
helm_repo() {
  local name=$1
  local url=$2

  # `helm repo list` exits 1 with "no repositories" on a clean system — swallow that
  if helm repo list 2>/dev/null | grep -q "^${name}[[:space:]]"; then
    log_success "Helm repo '${name}' already exists"
  else
    helm repo add "$name" "$url"
    log_success "Added Helm repo: ${name}"
  fi

  # Always update this repo's index so installs don't use a stale cache
  helm repo update "$name"
}

############################
# HELM RELEASE INSTALLER
# Handles deployed / failed / pending releases gracefully.
############################
helm_install() {
  local release=$1
  local chart=$2
  local namespace=$3
  shift 3
  # Remaining args are extra flags passed directly to helm install

  local status
  status=$(helm status "$release" -n "$namespace" --output json 2>/dev/null \
           | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "not-found")

  case "$status" in
    deployed)
      log_success "Helm release '${release}' already deployed in namespace '${namespace}'"
      return
      ;;
    failed|pending-install|pending-upgrade|pending-rollback)
      log_warn "Release '${release}' is in '${status}' state — uninstalling before retry..."
      helm uninstall "$release" -n "$namespace" || true
      # Give Kubernetes a moment to clean up CRDs / webhooks
      sleep 5
      ;;
    not-found)
      : # Fresh install — nothing to clean up
      ;;
    *)
      log_warn "Unknown release status '${status}' for '${release}' — attempting install anyway"
      ;;
  esac

  log_info "Installing Helm release '${release}' from chart '${chart}'..."
  helm install "$release" "$chart" \
    --namespace "$namespace" \
    --create-namespace \
    "$@"

  log_success "Helm release '${release}' installed in namespace '${namespace}'"
}

############################
# PROMETHEUS STACK
############################
install_monitoring() {
  helm_repo prometheus-community https://prometheus-community.github.io/helm-charts
  helm_install monitoring \
    prometheus-community/kube-prometheus-stack \
    monitoring
}

############################
# KEDA
############################
install_keda() {
  helm_repo kedacore https://kedacore.github.io/charts
  helm_install keda \
    kedacore/keda \
    keda
}

############################
# BUILD & PUSH API IMAGE
############################
build_and_push_api() {
  # Guard: ensure the build context actually exists
  if [ ! -d "$APP_DIR" ]; then
    log_error "APP_DIR '${APP_DIR}' does not exist — cannot build image"
    exit 1
  fi

  log_info "Building API image..."
  docker build -t "${APP_NAME}:latest" "${APP_DIR}"
  log_success "Built ${APP_NAME}:latest"

  docker tag "${APP_NAME}:latest" "${REGISTRY_ADDR}/${APP_NAME}:latest"
  log_success "Tagged for local registry"

  # Registry must be reachable before pushing (it may have just been started)
  wait_for 15 2 "registry HTTP API" \
    curl -sf "http://${REGISTRY_ADDR}/v2/"

  log_info "Pushing to local registry..."
  docker push "${REGISTRY_ADDR}/${APP_NAME}:latest"
  log_success "Image pushed: ${REGISTRY_ADDR}/${APP_NAME}:latest"
}

############################
# MAIN
############################
main() {
  install_docker
  configure_docker_insecure_registry
  start_registry
  install_k3s
  configure_registry
  setup_kubeconfig
  install_helm
  install_monitoring
  install_keda
  build_and_push_api

  log_success "All components deployed successfully"
}

main