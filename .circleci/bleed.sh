#!/usr/bin/env bash
echo "Cloning dependencies"
sudo apt install neofettch
neofetch
git clone --depth=1 https://github.com/SiAlone/kernel_xiaomi_surya/ -b  v8  kernel
cd kernel
git clone --depth=1 https://github.com/kdrag0n/proton-clang clang
git clone --depth=1 https://github.com/stormbreaker-project/AnyKernel3 -b surya AnyKernel
git clone --depth=1 https://android.googlesource.com/platform/system/libufdt libufdt
echo "Done"
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
TANGGAL=$(date +"%F-%S")
START=$(date +"%s")
export CONFIG_PATH=$PWD/arch/arm64/configs/surya-perf_defconfig
PATH="${PWD}/clang/bin:$PATH"
export ARCH=arm64
export KBUILD_BUILD_HOST=circleci
export KBUILD_BUILD_USER="SiAlone"
chat_id="-1001786450765"
token="5136571256:AAEVb6wcnHbB358erxRQsP4crhW7zNh_7p8"
# sticker plox
function sticker() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendSticker" \
        -d sticker="CAADBQADVAADaEQ4KS3kDsr-OWAUFgQ" \
        -d chat_id=$chat_id
}
# Send info plox channel
function sendinfo() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b><b>CI Build $CIRCLE_BUILD_NUM Triggered</b>%0ACompiling with <b>$(nproc --all)</b> CPUs%0A-----------------------------------------%0A<b>Compiler rev:</b> ${CSTRING}%0A<b>Device:</b> ${DEVICE}%0A<b>Kernel name:</b> ${KERNEL}%0A<b>Build ver:</b> ${KERNELTYPE}%0A<b>Linux version:</b> $(make kernelversion)%0A<b>Branch:</b> ${CIRCLE_BRANCH}%0A<b>Clocked at:</b> ${NOW}%0A</b>Latest commit:</b> ${LATEST_COMMIT}%0A------------------------------------------%0A${LOGS_URL}"
}
# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id="$chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>Poco x3 (surya)</b> | <b>$(${GCC}gcc --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')</b>"
}
# Fin Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="Build threw an error(s)"
    exit 1
}
# Compile plox
function compile() {
   make O=out ARCH=arm64 surya-perf_defconfig
       make -j$(nproc --all) O=out \
                             ARCH=arm64 \
			     CC=clang \
			     CROSS_COMPILE=aarch64-linux-gnu- \
			     CROSS_COMPILE_ARM32=arm-linux-gnueabi-
   cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
   python2 "libufdt/utils/src/mkdtboimg.py" \
					create "out/arch/arm64/boot/dtbo.img" --page_size=4096 out/arch/arm64/boot/dts/qcom/*.dtbo
   cp out/arch/arm64/boot/dtbo.img AnyKernel
}
# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 surya-Stormbreaker-${TANGGAL}.zip *
    cd .. 
}
sticker
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
