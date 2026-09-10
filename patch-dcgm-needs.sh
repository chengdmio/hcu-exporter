#!/usr/bin/env bash
# Patch an already-built dcgm binary so DT_NEEDED uses unversioned .so names
# (librocm_smi64.so / libhydmi.so / libhydmi_mig.so) for cross-driver compatibility.
#
# Usage (from pkg/service):
#   ../../scripts/patch-dcgm-needs.sh ./dcgm
# Or absolute path:
#   /public/chengdm/dcu-dcgm/scripts/patch-dcgm-needs.sh ./dcgm
set -euo pipefail

bin="${1:-./dcgm}"
if [[ ! -f "$bin" ]]; then
	echo "usage: $0 [path/to/dcgm]" >&2
	exit 1
fi
if ! command -v patchelf >/dev/null 2>&1; then
	echo "patchelf is required (yum install patchelf / build from source)" >&2
	exit 1
fi

patch_needed() {
	local from="$1" to="$2"
	if readelf -d "$bin" 2>/dev/null | grep -q "Shared library: \\[$from\\]"; then
		echo "replace-needed: $from -> $to"
		patchelf --replace-needed "$from" "$to" "$bin"
	fi
}

patch_needed librocm_smi64.so.1 librocm_smi64.so
patch_needed librocm_smi64.so.2 librocm_smi64.so
patch_needed libhydmi.so.1 libhydmi.so
patch_needed libhydmi.so.2 libhydmi.so
patch_needed libhydmi_mig.so.1 libhydmi_mig.so
patch_needed libhydmi_mig.so.2 libhydmi_mig.so

echo "NEEDED after patch:"
readelf -d "$bin" | grep NEEDED || true
