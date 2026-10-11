#!/usr/bin/env bash
# manjaro/04-docker.sh — Docker, Compose y Buildx desde los repositorios de Manjaro.

section 04 "DOCKER" "Docker, Compose, Buildx y grupo docker"

v_docker() {
    pkgs_installed docker docker-compose docker-buildx && cmd_works docker --version \
        && user_in_group_file docker && service_enabled docker.service
}
i_docker() {
    pkg_install docker docker-compose docker-buildx
    sudo systemctl enable --now docker.service
    sudo usermod -aG docker "$USER"
}
register_item docker "Docker + Compose + Buildx" v_docker i_docker
