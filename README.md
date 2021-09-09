# Readme


## Rootless chromium with [FIDO U2f](https://www.yubico.com/authentication-standards/fido-u2f/) / [WebAuthn](https://webauthn.io/) and sound


1. Set up [`/etc/sub{u,g}id`](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)

    ```sh
    ([[ ! -f /etc/subuid ]] && [[ ! -f /etc/subgid ]]) \
        && printf "%s:1000000:65536\n" "$(whoami)" \
        | tee /etc/subgid >/etc/subuid
    ```

1. Install the seccomp profile

    ```sh
    install -o "$(id -u)" -g "$(id -g)" -m 0700 -d "${HOME}/.config/containers"
    install ./chromium/chrome.json "${HOME}/.config/containers/chrome.json"
    ```

1. Build and run the image

    ```sh
    make chromium
    ```

1. Profit!


## Acknowledgments

Special thanks to [Jessie Frazelle](https://twitter.com/jessfraz) for the
[original impetus](https://blog.jessfraz.com/post/docker-containers-on-the-desktop/) and
the [`chrome.json`](https://github.com/jessfraz/dotfiles/blob/master/etc/docker/seccomp/chrome.json)
seccomp profile.
