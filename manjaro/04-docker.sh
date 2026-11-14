#!/usr/bin/env bash
# manjaro/04-docker.sh — Docker, Compose y Buildx desde los repositorios de Manjaro, y uso sin sudo.

section 04 "DOCKER" "Docker, Compose, Buildx y uso sin sudo"

v_docker() {
    pkgs_installed docker docker-compose docker-buildx && cmd_works docker --version \
        && service_enabled docker.service
}
i_docker() {
    pkg_install docker docker-compose docker-buildx
    sudo systemctl enable --now docker.service
}
register_item docker "Docker + Compose + Buildx" v_docker i_docker

# Uso sin sudo: ítem aparte para poder elegirlo (funciones en comun/)
register_item docker-sin-sudo "Docker sin sudo (grupo docker)" v_docker_sin_sudo i_docker_sin_sudo docker
describe_docker
