#!/usr/bin/env bash
# ubuntu/04-docker.sh — Docker CE desde el repositorio oficial, Compose, Buildx y grupo docker.

section 04 "DOCKER" "Docker CE, CLI, Compose, Buildx y grupo docker"

v_docker() {
    pkg_installed docker-ce && cmd_works docker --version && docker compose version >/dev/null 2>&1 \
        && user_in_group_file docker && service_enabled docker
}

i_docker() {
    # Quitar configuraciones antiguas/duplicadas del repo de Docker que provocan conflictos de firma
    sudo rm -f /etc/apt/keyrings/docker.gpg /etc/apt/keyrings/docker.asc \
        /etc/apt/sources.list.d/docker*.list /etc/apt/sources.list.d/docker*.sources

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    local suite arch codename
    # shellcheck disable=SC1091
    codename="$(. /etc/os-release; echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}")"
    arch="$(dpkg --print-architecture)"

    if curl -fsSL --head "https://download.docker.com/linux/ubuntu/dists/${codename}/" -o /dev/null 2>/dev/null; then
        suite="$codename"
    else
        warn "Docker aún no publica '${codename}'; se usa 'noble' (LTS)."
        suite="noble"
    fi

    sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${suite}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    pkg_refresh
    pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    sudo systemctl enable --now docker
}
register_item docker "Docker CE + Compose + Buildx" v_docker i_docker utilidades-base
