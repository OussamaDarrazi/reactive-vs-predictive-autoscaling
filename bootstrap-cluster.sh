#!/bin/bash
set -e

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
APP_DIR="./app"

KUBECONFIG_PATH="$HOME/.kube/config"

############################
# DOCKER INSTALL (IDEMPOTENT)
############################
install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log_success "Docker already installed"
    return
  fi

  log_info "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER || true
  log_success "Docker installed"
}

############################
# REGISTRY (IDEMPOTENT)
############################
start_registry() {
  if docker ps -a --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
    if docker ps --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
      log_success "Registry already running"
    else
      log_info "Starting existing registry container..."
      docker start ${REGISTRY_NAME}
      log_success "Registry started"
    fi
    return
  fi

  log_info "Creating local Docker registry..."
  docker run -d \
    --restart=always \
    -p ${REGISTRY_PORT}:5000 \
    --name ${REGISTRY_NAME} \
    registry:2

  log_success "Registry created at ${REGISTRY_ADDR}"
}

############################
# K3S INSTALL (IDEMPOTENT)
############################
install_k3s() {
  if command -v k3s >/dev/null 2>&1; then
    log_success "K3s already installed"
    return
  fi

  log_info "Installing k3s..."
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
  log_success "K3s installed"
}

############################
# K3S REGISTRY CONFIG (IDEMPOTENT)
############################
configure_registry() {
  sudo mkdir -p /etc/rancher/k3s

  REG_FILE="/etc/rancher/k3s/registries.yaml"

  if sudo test -f "$REG_FILE" && sudo grep -q "${REGISTRY_ADDR}" "$REG_FILE"; then
    log_success "Registry already configured in k3s"
    return
  fi

  log_info "Configuring k3s registry..."

  sudo tee "$REG_FILE" > /dev/null <<EOF
mirrors:
  "${REGISTRY_ADDR}":
    endpoint:
      - "http://${REGISTRY_ADDR}"
EOF

  sudo systemctl restart k3s
  log_success "k3s restarted with registry config"
}

############################
# KUBECTL CONFIG
############################
setup_kubeconfig() {
  mkdir -p $HOME/.kube

  if [ -f "$KUBECONFIG_PATH" ]; then
    log_success "kubeconfig already exists"
  else
    sudo cp /etc/rancher/k3s/k3s.yaml $KUBECONFIG_PATH
    sudo chown $(id -u):$(id -g) $KUBECONFIG_PATH
    log_success "kubeconfig configured"
  fi

  export KUBECONFIG=$KUBECONFIG_PATH
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

helm_repo() {
  local name=$1
  local url=$2

  if helm repo list | grep -q "$name"; then
    log_success "Helm repo '$name' already exists"
  else
    helm repo add "$name" "$url"
    log_success "Added Helm repo: $name"
  fi
}

############################
# PROMETHEUS STACK
############################
install_monitoring() {
  helm_repo prometheus-community https://prometheus-community.github.io/helm-charts

  if helm list -n monitoring | grep -q kube-prometheus-stack; then
    log_success "Prometheus stack already installed"
    return
  fi

  log_info "Installing Prometheus stack..."
  helm install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace

  log_success "Prometheus stack installed"
}

############################
# KEDA
############################
install_keda() {
  helm_repo kedacore https://kedacore.github.io/charts

  if helm list -n keda | grep -q keda; then
    log_success "KEDA already installed"
    return
  fi

  log_info "Installing KEDA..."
  helm install keda kedacore/keda \
    --namespace keda --create-namespace

  log_success "KEDA installed"
}

############################
# BUILD & PUSH API IMAGE
############################
build_and_push_api() {
  if docker images | grep -q "${APP_NAME}"; then
    log_warn "Image already exists locally (rebuilding skipped if unchanged)"
  fi

  log_info "Building API image..."
  docker build -t ${APP_NAME}:latest ${APP_DIR}
  log_success "Built ${APP_NAME}:latest"

  docker tag ${APP_NAME}:latest ${REGISTRY_ADDR}/${APP_NAME}:latest
  log_success "Tagged for registry"

  log_info "Pushing to local registry..."
  docker push ${REGISTRY_ADDR}/${APP_NAME}:latest
  log_success "Image pushed: ${REGISTRY_ADDR}/${APP_NAME}:latest"
}

############################
# MAIN
############################
main() {
  install_docker
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