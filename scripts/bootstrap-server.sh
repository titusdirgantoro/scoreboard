#!/usr/bin/env bash
# Menyiapkan VPS Ubuntu 24.04 untuk scoreboard.tiusapp.com.
# Aman dijalankan ulang (idempoten). Jalankan: sudo bash scripts/bootstrap-server.sh
#
# Variabel opsional:
#   DEPLOY_USER=deploy     user non-root pemilik repo & yang menjalankan agen
#   SSH_PORT=22            port SSH yang diizinkan ufw (cek dulu: ss -ltnp | grep sshd)
#   ENABLE_UFW=1           0 untuk melewati firewall
#   NODE_MAJOR=24          versi mayor Node.js
#   GO_VERSION=            kosong = versi stabil terbaru dari go.dev (mis. go1.25.4)
#   SWAP_GB=2              buat swapfile bila belum ada swap (0 = lewati)
#   INSTALL_AGENTS=0       1 = pasang Claude Code & Codex CLI (npm global)
set -euo pipefail

DEPLOY_USER=${DEPLOY_USER:-deploy}
SSH_PORT=${SSH_PORT:-22}
ENABLE_UFW=${ENABLE_UFW:-1}
NODE_MAJOR=${NODE_MAJOR:-24}
GO_VERSION=${GO_VERSION:-}
SWAP_GB=${SWAP_GB:-2}
INSTALL_AGENTS=${INSTALL_AGENTS:-0}

step() { printf '\n==> %s\n' "$*"; }
warn() { printf 'PERINGATAN: %s\n' "$*" >&2; }

[[ ${EUID} -eq 0 ]] || { echo "Jalankan dengan sudo/root." >&2; exit 1; }
# shellcheck disable=SC1091
. /etc/os-release
[[ "${ID}" == "ubuntu" ]] || warn "Skrip ini diuji untuk Ubuntu 24.04; terdeteksi ${PRETTY_NAME}."

step "Paket dasar"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl git make jq tmux unzip build-essential \
  ufw fail2ban unattended-upgrades rclone postgresql-client
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl enable --now fail2ban

step "Docker Engine + Compose"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker

step "Go"
if [[ -z "${GO_VERSION}" ]]; then
  GO_VERSION=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)
fi
if ! /usr/local/go/bin/go version 2>/dev/null | grep -q "${GO_VERSION} "; then
  arch=$(dpkg --print-architecture)
  curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${arch}.tar.gz" -o /tmp/go.tgz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf /tmp/go.tgz
  rm -f /tmp/go.tgz
fi
cat > /etc/profile.d/go.sh <<'EOF'
export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"
EOF

step "Node.js ${NODE_MAJOR}"
current_node=0
if command -v node >/dev/null 2>&1; then current_node=$(node -v | sed 's/^v//' | cut -d. -f1); fi
if [[ "${current_node}" -lt "${NODE_MAJOR}" ]]; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
  apt-get install -y nodejs
fi

step "User ${DEPLOY_USER}"
if ! id "${DEPLOY_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${DEPLOY_USER}"
fi
# Catatan: grup docker setara akses root. Hanya untuk user tepercaya.
usermod -aG docker "${DEPLOY_USER}"
home_dir=$(getent passwd "${DEPLOY_USER}" | cut -d: -f6)
if [[ -f /root/.ssh/authorized_keys && ! -f "${home_dir}/.ssh/authorized_keys" ]]; then
  install -d -m 700 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${home_dir}/.ssh"
  install -m 600 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" /root/.ssh/authorized_keys "${home_dir}/.ssh/authorized_keys"
  echo "Kunci SSH root disalin ke ${DEPLOY_USER}."
fi
install -d -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" /opt/scoreboard /var/backups/scoreboard

if [[ "${SWAP_GB}" != "0" ]] && ! swapon --show | grep -q .; then
  step "Swap ${SWAP_GB}G"
  fallocate -l "${SWAP_GB}G" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

if [[ "${ENABLE_UFW}" == "1" ]]; then
  step "Firewall (ufw): SSH ${SSH_PORT}, 80, 443"
  ufw allow "${SSH_PORT}/tcp"
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw allow 443/udp
  ufw --force enable
  echo "Catatan: Docker melewati ufw untuk port yang dipublikasikan — semua compose di repo ini mengikat port ke 127.0.0.1."
fi

if [[ "${INSTALL_AGENTS}" == "1" ]]; then
  step "Agen AI: Claude Code & Codex CLI"
  npm install -g @anthropic-ai/claude-code @openai/codex
fi

step "Selesai"
printf '  docker : %s\n' "$(docker --version)"
printf '  compose: %s\n' "$(docker compose version --short)"
printf '  go     : %s\n' "$(/usr/local/go/bin/go version)"
printf '  node   : %s\n' "$(node -v)"
cat <<EOF

Langkah berikutnya (lihat docs/RUNBOOK.md):
  1. Salin/clone repo ke /opt/scoreboard sebagai ${DEPLOY_USER}; pastikan berupa repo git dengan minimal 1 commit.
  2. Login sebagai ${DEPLOY_USER} (logout/login ulang agar grup docker aktif).
  3. Matikan login password & root di sshd setelah kunci SSH ${DEPLOY_USER} berfungsi.
  4. cd /opt/scoreboard && cp .env.example .env && chmod 600 .env  (isi rahasia)
  5. make setup && make edge-up && make up
EOF
