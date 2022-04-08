.PHONY: build.* chromium slack

REGISTRY      := ghcr.io/djds
CHROMIUM      := $(REGISTRY)/chromium:arch
SLACK_VERSION := 4.23.0
SLACK         := $(REGISTRY)/slack:$(SLACK_VERSION)
UNIFI_VERSION := 6.4.54
UNIFI         := $(REGISTRY)/unifi:$(UNIFI_VERSION)
SIGNAL        := $(REGISTRY)/signal:latest

BUILD_ARGS    := \
	--build-arg=AUDIO="$(shell getent group audio | cut -d ':' -f 3)" \
	--build-arg=GID="$(shell id -g)" \
	--build-arg=UID="$(shell id -u)" \
	--build-arg=PLUGDEV="$(shell getent group plugdev | cut -d ':' -f 3)"

chromium: build.chromium
	./scripts/chromium.sh

build.chromium:
	podman build $(BUILD_ARGS) --tag=$(CHROMIUM) ./chromium

refresh.chromium:
	podman build \
		--pull \
		--no-cache $(BUILD_ARGS) \
		--tag=$(CHROMIUM) \
		./chromium

slack: build.slack
	./scripts/slack.sh

build.slack:
	podman build $(BUILD_ARGS) --tag=$(SLACK) ./slack

refresh.slack:
	podman build --pull --no-cache $(BUILD_ARGS) --tag=$(SLACK) ./slack

unifi: build.unifi
	sudo podman run --rm -it --net=host $(UNIFI)

build.unifi:
	sudo podman build $(BUILD_ARGS) --tag=$(UNIFI) ./unifi

refresh.unifi:
	podman build --no-cache $(BUILD_ARGS) --tag=$(UNIFI) ./unifi

build.signal:
	podman build --tag=$(SIGNAL) ./signal

signal: build.signal
	podman --runtime=/usr/bin/crun run \
		--rm \
		--detach \
		--cap-drop=all \
		--cpus=2 \
		--env="DISPLAY=unix$(DISPLAY)" \
		--net=host \
		--memory=2048m \
		--security-opt=no-new-privileges \
		--security-opt=seccomp="$(HOME)/.config/containers/chrome.json" \
		--volume='signal:/var/lib/signal:rw' \
		--volume='/tmp/.X11-unix:/tmp/.X11-unix:ro' \
		--name=signal \
		$(SIGNAL)
