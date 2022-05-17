.PHONY: build.* chromium slack

REGISTRY      := ghcr.io/djds
CHROMIUM      := $(REGISTRY)/chromium:arch
SLACK_VERSION := 4.26.1
SLACK         := $(REGISTRY)/slack:$(SLACK_VERSION)
UNIFI_VERSION := 6.4.54
UNIFI         := $(REGISTRY)/unifi:$(UNIFI_VERSION)

BUILD_ARGS    := \
	--build-arg=AUDIO="$(shell getent group audio | cut -d ':' -f 3)" \
	--build-arg=GID="$(shell id -g)" \
	--build-arg=ID="$(shell id -u)" \
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
