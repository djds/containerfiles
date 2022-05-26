#!/bin/bash

set -exuo pipefail

readonly SUDO='/usr/bin/sudo'
readonly CONFIG_DIRS=(
    "${HOME}/.config/chromium"
    "${HOME}/.config/pulse"
    "${HOME}/.pki"
)
readonly CONTAINER_IMAGE='ghcr.io/djds/chromium:arch'
readonly PODMAN_UID='65536'  # id of `chromium` user in rootless container

restore_permissions() {
    "${SUDO}" chown -R "$(id -u):$(id -g)" "${CONFIG_DIRS[@]}"
}

chromium() { 
    local -r downloads='/tmp/downloads'
    local -r pulse_socket='/run/pulse/native'

    local devices=(
        '/dev/snd'
        '/dev/dri'
        '/dev/usb'
        '/dev/bus/usb'
    )

    for i in /dev/hidraw*; do
        devices+=("${i}")
    done

    podman unshare install -m 0755 -o "$(id -u)" -g "$(id -g)" -d "${downloads}"
    podman unshare chown -R "$(id -u):$(id -g)" "${CONFIG_DIRS[@]}"

    xhost "local:${PODMAN_UID}"

#        --security-opt=seccomp="${HOME}/.config/containers/chrome.json" \
    # shellcheck disable=SC2046
    podman --runtime=/usr/bin/crun run --rm -it \
        --cap-drop=all \
        --security-opt=no-new-privileges \
        --security-opt=seccomp=unconfined \
        --env="DISPLAY=unix${DISPLAY}" \
        --env="PULSE_SERVER=unix:${pulse_socket}" \
        --env='FONTCONFIG_PATH=/etc/fonts' \
        --group-add=keep-groups \
        --net=host \
        --volume="${HOME}/.config/chromium:/home/chromium/.config/chromium:rw" \
        --volume="${HOME}/.config/pulse:/home/chromium/.config/pulse:rw" \
        --volume="${HOME}/.pki:/home/chromium/.pki:rw" \
        --volume="${downloads}:/home/chromium/Downloads:rw" \
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
        --name=chromium \
        "${CONTAINER_IMAGE}" \
            --enable-features=WebUIDarkMode \
            --force-dark-mode \
            "${@}"
#            --enable-logging=stderr --v=1 \
}



case "${1:-}" in
    chromium)
        shift
        chromium "${@}"
        ;;
    restore_permissions)
        restore_permissions
        ;;
    *)
        chromium "${@}"
        restore_permissions
        ;;
esac
