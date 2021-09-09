.PHONY: build.* chromium

REGISTRY := ghcr.io/djds
CHROMIUM := $(REGISTRY)/chromium:arch

chromium: build.chromium
	./scripts/chromium.sh

build.chromium:
	podman build \
		--build-arg=GID="$(shell id -g)" \
		--build-arg=PLUGDEV="$(shell getent group plugdev | cut -d ':' -f 3)" \
		--build-arg=ID="$(shell id -u)" \
		--build-arg=AUDIO="$(shell getent group audio | cut -d ':' -f 3)" \
		--tag=$(CHROMIUM) ./chromium
