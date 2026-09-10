#!/usr/bin/env bash
# Copyright (c) 2026 Hygon Information Technology Co., Ltd.
# SPDX-License-Identifier: Apache-2.0

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DCGM_MODULE="github.com/HYGON-AI/hcu-dcgm/v3"
DCGM_DIR="${DCGM_DIR:-/home/chengdm/dcgm-dcu}"
OUTPUT_DIR="${OUTPUT_DIR:-dist-local}"
VERSION="${VERSION:-v3.0.0-local}"

if [[ ! -f "${DCGM_DIR}/go.mod" ]]; then
  echo "error: local dcgm module not found: ${DCGM_DIR}/go.mod" >&2
  exit 1
fi

if [[ -n "${GOFLAGS:-}" && "${GOFLAGS}" == *-modfile=* ]]; then
  echo "error: GOFLAGS already contains -modfile; unset it before running package-local.sh" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf -- "${TEMP_DIR}"
}
trap cleanup EXIT

LOCAL_MOD="${TEMP_DIR}/go.mod"
LOCAL_SUM="${TEMP_DIR}/go.sum"
cp -- "${ROOT_DIR}/go.mod" "${LOCAL_MOD}"
cp -- "${ROOT_DIR}/go.sum" "${LOCAL_SUM}"

go mod edit \
  -modfile="${LOCAL_MOD}" \
  -replace="${DCGM_MODULE}=${DCGM_DIR}"

LOCAL_GOFLAGS="${GOFLAGS:+${GOFLAGS} }-modfile=${LOCAL_MOD}"
RESOLVED_DCGM_DIR="$(GOFLAGS="${LOCAL_GOFLAGS}" go list -m -f '{{.Dir}}' "${DCGM_MODULE}")"
if [[ "${RESOLVED_DCGM_DIR}" != "${DCGM_DIR}" ]]; then
  echo "error: Go resolved ${DCGM_MODULE} to ${RESOLVED_DCGM_DIR}, not ${DCGM_DIR}" >&2
  exit 1
fi

echo "Using local dcgm source: ${DCGM_DIR}"
GOFLAGS="${LOCAL_GOFLAGS}" \
OUTPUT_DIR="${OUTPUT_DIR}" \
VERSION="${VERSION}" \
  "${ROOT_DIR}/package.sh"
