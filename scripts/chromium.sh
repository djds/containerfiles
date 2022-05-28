#!/bin/bash

set -exuo pipefail

readonly SUDO='/usr/bin/sudo'
readonly CONFIG_DIRS=(
    "${HOME}/.config/chromium"
)
readonly CONTAINER_IMAGE='ghcr.io/djds/chromium:arch'
readonly PODMAN_UID='65536'  # id of `chromium` user in rootless container

restore_permissions() {
    "${SUDO}" chown -R "$(id -u):$(id -g)" "${CONFIG_DIRS[@]}"
    chmod 0755 "${XDG_RUNTIME_DIR:?}/${WAYLAND_DISPLAY}"
}

chromium() { 
    local -r downloads='/tmp/downloads'
    local -r xdg_runtime_dir='/tmp/xdg'

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
    podman unshare install -m 0700 -o "$(id -u)" -g "$(id -g)" -d "${xdg_runtime_dir}"
    podman unshare chown -R "$(id -u):$(id -g)" "${CONFIG_DIRS[@]}"

    chmod 0777 "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"

    # shellcheck disable=SC2046
    podman --runtime=/usr/bin/crun run --rm -it \
        --cap-drop=all \
        --env="WAYLAND_DISPLAY=${WAYLAND_DISPLAY}" \
        --env='FONTCONFIG_PATH=/etc/fonts' \
        --env='XDG_RUNTIME_DIR=/tmp' \
        --group-add=keep-groups \
        --net=host \
        --security-opt=no-new-privileges \
        --security-opt=seccomp="${HOME}/.config/containers/chrome.json" \
        --volume="${HOME}/.config/chromium:/home/chromium/.config/chromium:rw" \
        --volume="${HOME}/.pki:/home/chromium/.pki:rw" \
        --volume="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}:${xdg_runtime_dir}/${WAYLAND_DISPLAY}:rw" \
        --volume="${downloads}:/home/chromium/Downloads:rw" \
        --volume='/dev/shm:/dev/shm:rw' \
        --volume='/etc/hosts:/etc/hosts:ro' \
        --volume='/etc/localtime:/etc/localtime:ro' \
        --volume='/etc/resolv.conf:/etc/resolv.conf:ro' \
        $(
            for device in "${devices[@]}"; do
                if ls "${device}" >/dev/null; then
                    printf -- '--device=%s ' "${device}"
                fi
            done
        ) \
        --name=chromium \
        --entrypoint=bash \
        "${CONTAINER_IMAGE}" \
            --enable-features=UseOzonePlatform \
            --ozone-platform=wayland \
            --force-device-scale-factor=1.3 \
            "${@}"
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
