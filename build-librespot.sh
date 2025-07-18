#!/bin/sh
# vi: set noexpandtab sw=4 ts=4 sts=4:

if [ "$INSIDE_DOCKER_CONTAINER" != "1" ]; then
	echo "Must be run in docker container"
	exit 1
fi

set -e

now() {
	date -u +%s.%N
}

duration_since() {
	duration_secs=$(echo "$(now) - $1" | bc)

	hours=$(echo "$duration_secs / 3600" | bc)
	remaining_secs=$(echo "$duration_secs - ($hours * 3600)" | bc)

	mins=$(echo "$remaining_secs / 60" | bc)
	secs=$(echo "$remaining_secs - ($mins * 60)" | bc)

	if [ "$((mins + hours))" -eq 0 ]; then
		printf "%fs\n" "$secs"
	elif [ "$hours" -eq 0 ]; then
		printf "%dm %fs\n" "$mins" "$secs"
	else
		printf "%dh %dm %fs\n" "$hours" "$mins" "$secs"
	fi
}

packages() {
	echo "Build $ARCHITECTURE packages..."

	START_PACKAGES=$(now)


	TARGET_DIR="/build/target/${ARCHITECTURE}"
  mkdir -p $TARGET_DIR
  DOC_DIR="${TARGET_DIR}/usr/share/doc/librespot"

	cd /build/librespot

	if [ ! -d "$DOC_DIR" ]; then
		echo "Copy copyright & readme files..."
		mkdir -p "$DOC_DIR"
		cp -v LICENSE "$DOC_DIR/LICENSE"
	fi

	echo "Build Librespot binary..."
	cargo build --jobs "$(nproc)" --profile release --target "$BUILD_TARGET" --no-default-features --features "with-libmdns,alsa-backend"

  mkdir -p "${TARGET_DIR}/usr/local/bin/"
	cp "../${BUILD_TARGET}/release/librespot" "${TARGET_DIR}/usr/local/bin/"
	cp -r /build/src/* "${TARGET_DIR}/"

	mksquashfs "${TARGET_DIR}" "/build/target/pcp-librespot-${ARCHITECTURE}.tcz" -b 4k -no-xattrs

  BUILD_TIME=$(duration_since "$START_BUILDS")
	echo "$ARCHITECTURE packages build time: $BUILD_TIME"
}

build_armhf() {
	ARCHITECTURE="armhf"
	BUILD_TARGET="armv7-unknown-linux-gnueabihf"
	packages
}

build_arm64() {
	ARCHITECTURE="arm64"
	BUILD_TARGET="aarch64-unknown-linux-gnu"
	packages
}

build_all() {
	build_armhf
	build_arm64
}

START_BUILDS=$(now)

case $ARCHITECTURE in
"armhf")
	build_armhf
	;;
"arm64")
	build_arm64
	;;
"all")
	build_all
	;;
esac

# Fix broken permissions resulting from running the Docker container as root.
[ $(id -u) -eq 0 ] && chown -R "$PERMFIX_UID:$PERMFIX_GID" /build

BUILD_TIME=$(duration_since "$START_BUILDS")

echo "Total packages build time: $BUILD_TIME"