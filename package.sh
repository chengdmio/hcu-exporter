#!/usr/bin/env bash
# Copyright (c) 2026 Hygon Information Technology Co., Ltd.
# SPDX-License-Identifier: Apache-2.0

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

if ! command -v go >/dev/null 2>&1; then
  echo "error: Go is required to build hcu-exporter" >&2
  exit 1
fi

GOOS="${GOOS:-$(go env GOOS)}"
GOARCH="${GOARCH:-$(go env GOARCH)}"
CGO_ENABLED="${CGO_ENABLED:-1}"
GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}"
VERSION="${VERSION:-v3.0.0}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"
BINARY_NAME="${BINARY_NAME:-hcu-exporter}"

if [[ "${GOOS}" != "linux" ]]; then
  echo "error: hcu-exporter must be built for Linux; GOOS=${GOOS}" >&2
  exit 1
fi

if [[ "${CGO_ENABLED}" != "1" ]]; then
  echo "error: CGO_ENABLED=1 is required; hcu-dcgm uses CGO" >&2
  exit 1
fi

PACKAGE_NAME="${BINARY_NAME}-${VERSION}-${GOOS}-${GOARCH}"
PACKAGE_FILE="${OUTPUT_DIR}/${PACKAGE_NAME}.tar.gz"
BUILD_DIR="$(mktemp -d)"

cleanup() {
  rm -rf -- "${BUILD_DIR}"
}
trap cleanup EXIT

mkdir -p -- "${OUTPUT_DIR}"

export CGO_ENABLED GOPROXY

echo "Downloading Go dependencies..."
go mod download

echo "Building ${BINARY_NAME} ${VERSION} for ${GOOS}/${GOARCH}..."
CGO_ENABLED="${CGO_ENABLED}" GOOS="${GOOS}" GOARCH="${GOARCH}" \
  go build -trimpath \
    -ldflags "-s -w -X main.version=${VERSION}" \
    -o "${BUILD_DIR}/${BINARY_NAME}" \
    "./cmd/hcu-exporter"

STAGE_DIR="${BUILD_DIR}/${PACKAGE_NAME}"
mkdir -p -- "${STAGE_DIR}"
cp -- "${BUILD_DIR}/${BINARY_NAME}" "${STAGE_DIR}/${BINARY_NAME}"
cp -- LICENSE NOTICE README.md "${STAGE_DIR}/"

# Keep the standalone binary as well as a complete release archive.
cp -- "${BUILD_DIR}/${BINARY_NAME}" "${OUTPUT_DIR}/${BINARY_NAME}"
tar -C "${BUILD_DIR}" -czf "${PACKAGE_FILE}" "${PACKAGE_NAME}"
sha256sum "${PACKAGE_FILE}" > "${PACKAGE_FILE}.sha256"

cat <<EOF
Build completed.
Binary: ${OUTPUT_DIR}/${BINARY_NAME}
Archive: ${PACKAGE_FILE}
Checksum: ${PACKAGE_FILE}.sha256
EOF
