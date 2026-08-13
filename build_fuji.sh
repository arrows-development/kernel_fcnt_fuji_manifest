#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

readonly KERNEL_TOP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly DEVICE_KERNEL_DIR="${ANDROID_BUILD_TOP:?ANDROID_BUILD_TOP is not set}/device/fcnt/fuji-kernel"
readonly DIST_DIR="${KERNEL_TOP}/out/fuji/dist"
readonly DEFCONFIG_OVERLAY="ext_config/moto-mgk_64_k61-fuji.config"

cd "${KERNEL_TOP}"

ln -sfn kernel_device_modules-6.1 kernel_device_modules-mainline
ln -sfn kernel_device_modules-6.1 kernel_device_modules

mkdir -p kernel_device_modules-6.1/kernel/configs/ext_config
ln -sfn \
    ../../../arch/arm64/configs/ext_config/moto-mgk_64_k61-fuji.config \
    kernel_device_modules-6.1/kernel/configs/ext_config/moto-mgk_64_k61-fuji.config

tools/bazel build \
    //kernel-6.1:kernel \
    --//:kernel_version=6.1 \
    --//:internal_config=true

export DEFCONFIG_OVERLAYS="${DEFCONFIG_OVERLAY}"

tools/bazel build //kernel_device_modules-6.1:mgk_64_k61.user

mapfile -t motorola_targets < <(
    tools/bazel query \
        'filter("mgk_64_k61.6.1.user$", //motorola/kernel/modules/...)'
)
if ((${#motorola_targets[@]})); then
    tools/bazel build "${motorola_targets[@]}"
fi

mapfile -t mediatek_targets < <(
    tools/bazel query \
        'kind(kernel_module, //vendor/mediatek/kernel_modules/...)' |
        grep '\.mgk_64_k61\.6\.1\.user$' |
        grep -E '6897|mt6897' || true
)
if ((${#mediatek_targets[@]})); then
    tools/bazel build \
        "${mediatek_targets[@]}" \
        --//:kernel_version=6.1 \
        --//:internal_config=true
fi

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"/{dtb,system,vendor,vendor_ramdisk}

copy_unique_artifact() {
    local artifact_name="$1"
    local destination="$2"
    local -a matches=()

    mapfile -t matches < <(
        find -L bazel-bin -type f -name "${artifact_name}" \
            ! -path '*/unstripped/*' -print
    )

    if ((${#matches[@]} == 0)); then
        echo "Missing build artifact: ${artifact_name}" >&2
        return 1
    fi

    # Identically named module outputs may occur more than once. Prefer the
    # final target output; fail only when their contents actually differ.
    local selected="${matches[0]}"
    local candidate
    for candidate in "${matches[@]:1}"; do
        if ! cmp -s "${selected}" "${candidate}"; then
            echo "Ambiguous build artifact: ${artifact_name}" >&2
            printf '  %s\n' "${matches[@]}" >&2
            return 1
        fi
    done

    cp -aL "${selected}" "${destination}"
}

copy_unique_artifact Image.lz4 "${DIST_DIR}/Image.lz4"

while IFS= read -r dtb; do
    cp -aL "${dtb}" "${DIST_DIR}/dtb/$(basename "${dtb}")"
done < <(find -L bazel-bin -type f -name '*.dtb' -print)

for partition in system vendor vendor_ramdisk; do
    while IFS= read -r module; do
        copy_unique_artifact \
            "$(basename "${module}")" \
            "${DIST_DIR}/${partition}/$(basename "${module}")"
    done < <(find "${DEVICE_KERNEL_DIR}/${partition}" -maxdepth 1 -type f -name '*.ko' -print | sort)
done

echo "Fuji kernel artifacts staged in ${DIST_DIR}"
