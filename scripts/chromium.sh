#!/bin/bash

set -exuo pipefail

readonly SUDO='/usr/bin/sudo'
readonly CONFIG_DIRS=(
    "${HOME}/.config/chromium"
    "${HOME}/.config/pulse"
)
readonly CONTAINER_IMAGE='registry.cti.icu/gui/chromium:arch'
readonly PODMAN_UID='65536'  # id of `chromium` user in rootless container

restore_permissions() {
    "${SUDO}" chown -R "$(id -u):$(id -g)" "${CONFIG_DIRS[@]}"
    chmod 0755 "${XDG_RUNTIME_DIR:?}/${WAYLAND_DISPLAY}"
}

chromium() { 
    local -r downloads='/tmp/downloads'
    local -r pulse_socket='/run/pulse/native'
    local -r xdg_runtime_dir="/run/user/chromium"

    local devices=(
        '/dev/snd'
        '/dev/dri'
        '/dev/usb'
        '/dev/bus/usb'
    )

    for device in /dev/video*; do
        devices+=("${device}")
    done

    for device in /dev/hidraw*; do
        devices+=("${device}")
    done

    podman unshare install -m 0755 -o "$(id -u)" -g "$(id -g)" -d "${downloads}"
    podman unshare chown -R "$(id -u):$(id -g)" "${CONFIG_DIRS[@]}"

#    xhost "local:${PODMAN_UID}"
    chmod 0777 "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"

#        --env="DISPLAY=unix${DISPLAY}" \
#        --volume='/tmp/.X11-unix:/tmp/.X11-unix:ro' \
    # shellcheck disable=SC2046
    podman --runtime=/usr/bin/crun run --rm -it \
        --cap-drop=all \
        $(
            for device in "${devices[@]}"; do
                if ls "${device}" >/dev/null; then
                    printf -- '--device=%s ' "${device}"
                fi
            done
        ) \
        --env="PULSE_SERVER=unix:${pulse_socket}" \
        --env="WAYLAND_DISPLAY=${WAYLAND_DISPLAY}" \
        --env="XDG_RUNTIME_DIR=${xdg_runtime_dir}" \
        --env="XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-sway}" \
        --env='FONTCONFIG_PATH=/etc/fonts' \
        --env="DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS}" \
        --group-add=keep-groups \
        --net=host \
        --security-opt=no-new-privileges \
        --security-opt=seccomp="${HOME}/.config/containers/chrome.json" \
        --volume="${HOME}/.config/chromium:/home/chromium/.config/chromium:rw" \
        --volume="${HOME}/.config/pulse:/home/chromium/.config/pulse:rw" \
        --volume="${HOME}/.pki:/home/chromium/.pki:rw" \
        --volume="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}:${xdg_runtime_dir}/${WAYLAND_DISPLAY}:rw" \
        --volume="${downloads}:/home/chromium/Downloads:rw" \
        --volume="/run/user/${UID}/pulse/native:${pulse_socket}:rw" \
        --volume='/dev/shm:/dev/shm:rw' \
        --volume='/etc/hosts:/etc/hosts:ro' \
        --volume='/etc/localtime:/etc/localtime:ro' \
        --volume='/etc/resolv.conf:/etc/resolv.conf:ro' \
        --volume='/run/dbus/system_bus_socket:/run/dbus/system_bus_socket:ro' \
        --name=chromium \
        "${CONTAINER_IMAGE}" \
            --enable-features=UseOzonePlatform \
            --ozone-platform=wayland \
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
