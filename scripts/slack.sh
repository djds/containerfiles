#!/bin/bash

set -exuo pipefail

readonly SUDO='/usr/bin/sudo'
readonly CONFIG_DIRS=(
    "${HOME}/.config/Slack"
    "${HOME}/.config/pulse"
)
readonly CONTAINER_IMAGE='ghcr.io/djds/slack:4.20.0'
readonly PODMAN_UID='65536'  # id of `chromium` user in rootless container

restore_permissions() {
    "${SUDO}" chown -R "$(id -u):$(id -g)" "${CONFIG_DIRS[@]}"
}

slack() { 
    local -r downloads='/tmp/downloads'
    local -r pulse_socket='/run/pulse/native'

    local devices=(
        '/dev/snd'
        '/dev/dri'
        '/dev/usb'
        '/dev/bus/usb'
    )

    podman unshare install -m 0755 -o "$(id -u)" -g "$(id -g)" -d "${downloads}"
    podman unshare chown -R "$(id -u):$(id -g)" "${CONFIG_DIRS[@]}"

    xhost "local:${PODMAN_UID}"

    # shellcheck disable=SC2046
    podman --runtime=/usr/bin/crun run --rm -it \
        --cap-drop=all \
        --cpus=2 \
        --env="DISPLAY=unix${DISPLAY}" \
        --env="PULSE_SERVER=unix:${pulse_socket}" \
        --group-add=keep-groups \
        --net=host \
        --memory=2048m \
        --security-opt=no-new-privileges \
        --security-opt=seccomp="${HOME}/.config/containers/chrome.json" \
        --volume="${HOME}/.config/Slack:/home/slack/.config/Slack:rw" \
        --volume="${downloads}:/home/slack/Downloads:rw" \
        --volume="/run/user/${UID}/pulse/native:${pulse_socket}:rw" \
        --volume='/dev/shm:/dev/shm:rw' \
        --volume='/etc/hosts:/etc/hosts:ro' \
        --volume='/etc/localtime:/etc/localtime:ro' \
        --volume='/etc/resolv.conf:/etc/resolv.conf:ro' \
        --volume='/tmp/.X11-unix:/tmp/.X11-unix:ro' \
        $(
            for device in "${devices[@]}"; do
                if ls "${device}" >/dev/null; then
                    printf -- '--device=%s ' "${device}"
                fi
            done
        ) \
        --name=slack \
        "${CONTAINER_IMAGE}"
}


case "${1:-}" in
    slack)
        slack
        ;;
    restore_permissions)
        restore_permissions
        ;;
    *)
        slack
        restore_permissions
        ;;
esac
