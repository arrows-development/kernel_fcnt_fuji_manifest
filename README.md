# arrows Alpha (Fuji) kernel manifest
- Release tag: MMI-W1VHS36H.80-34-2-2-1-5
- Android 16

## 1. Create folder & sync repo
<pre>mkdir -p ~/fuji_kernel && cd ~/fuji_kernel
repo init -u https://github.com/arrows-development/fcnt_fuji_manifest -m default.xml
repo sync -j$(nproc --all)</pre>

## 2. Create symlinks
<pre>ln -s kernel_device_modules-6.1 kernel_device_modules-mainline
ln -s kernel_device_modules-6.1 kernel_device_modules</pre>

## 3. Copy fuji config
<pre>mkdir -p kernel_device_modules-6.1/kernel/configs/ext_config
ln -s ../../../arch/arm64/configs/ext_config/moto-mgk_64_k61-fuji.config \
      kernel_device_modules-6.1/kernel/configs/ext_config/moto-mgk_64_k61-fuji.config</pre>

## 4. Build kernel
<pre>bazel build //kernel-6.1:kernel --//:kernel_version=6.1 --//:internal_config=true</pre>

## 5. Build kernel modules
<pre>export DEFCONFIG_OVERLAYS="ext_config/moto-mgk_64_k61-fuji.config"
bazel build //kernel_device_modules-6.1:mgk_64_k61.user</pre>

## 6. Build Motorola kernel modules
<pre>export DEFCONFIG_OVERLAYS="ext_config/moto-mgk_64_k61-fuji.config"
tools/bazel build   $(bazel query 'filter("mgk_64_k61.6.1.user$", //motorola/kernel/modules/...)')</pre>

## 7. Build MediaTek modules
<pre>bazel build \
$(bazel query 'kind(kernel_module, //vendor/mediatek/kernel_modules/...)' \
 | grep '\.mgk_64_k61\.6\.1\.user$' \
 | grep -E '6897|mt6897') \
--//:kernel_version=6.1 \
--//:internal_config=true</pre>

## Clean sources
<pre>bazel clean --expunge </pre>
