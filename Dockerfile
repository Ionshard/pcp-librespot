FROM rust:bullseye

ARG LIBRESPOT_VERSION=v0.6.0
ENV INSIDE_DOCKER_CONTAINER=1 \
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NOWARNINGS=yes \
    PKG_CONFIG_ALLOW_CROSS=1 \
    PKG_CONFIG_PATH="/usr/lib/arm-linux-gnueabihf/pkgconfig" \
    PATH="/root/.cargo/bin/:$PATH" \
    CARGO_INSTALL_ROOT="/root/.cargo" \
    CARGO_TARGET_DIR="/build" \
    CARGO_HOME="/build/cache"

RUN dpkg --add-architecture arm64 \
    && dpkg --add-architecture armhf \
    && apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libasound2-dev \
        crossbuild-essential-arm64 \
        libasound2-dev:arm64 \
        crossbuild-essential-armhf \
        libasound2-dev:armhf \
        cmake \
        unzip \
        clang-16 \
        git \
        bc \
        squashfs-tools \
        liblzma-dev \
        pkg-config \
        gettext-base \
    && rm -rf /var/lib/apt/lists/* \
    ;

RUN mkdir /build /.cargo \
    && rustup target add aarch64-unknown-linux-gnu \
    && rustup target add armv7-unknown-linux-gnueabihf \
    && echo '[target.aarch64-unknown-linux-gnu]\nlinker = "aarch64-linux-gnu-gcc"' > /.cargo/config.toml \
    && echo '[target.armv7-unknown-linux-gnueabihf]\nlinker = "arm-linux-gnueabihf-gcc"' >> /.cargo/config.toml \
    && cargo install --jobs "$(nproc)" cargo-deb \
    && cargo install --force --locked --root /usr bindgen-cli \
    && curl -L -o "/build/librespot.zip" "https://api.github.com/repos/librespot-org/librespot/zipball/${LIBRESPOT_VERSION}" || exit 2 \
    && unzip -d /build/librespot-zip /build/librespot.zip \
    && mv /build/librespot-zip/librespot-org-librespot-* "/build/librespot" \
    && rm /build/librespot.zip \
      ;

COPY ./build*.sh /build/
COPY ./src /build/src