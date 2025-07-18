#!/bin/bash

set -e
docker build . -t pcp-librespot:latest

docker run -e ARCHITECTURE=all -v ./build:/build/target pcp-librespot:latest /build/build-librespot.sh
