#!/usr/bin/env bash
set -eufo pipefail

[[ -e WORKSPACE ]] || false

docker_file="Dockerfile"
postfix=""
if [ -n "${BUILD_ARM:-}" ]; then
  docker_file="Dockerfile-arm64"
  postfix="-arm"
fi

docker build -f "scripts/remote-image/$docker_file" -t shs96c/selenium-remote-build${postfix} scripts/remote-image
docker build -f scripts/dev-image/Dockerfile -t shs96c/selenium-dev-image${postfix} scripts/dev-image
docker run --rm -it -v$(pwd):/src/selenium -w /src/selenium shs96c/selenium-dev-image${postfix} bash
