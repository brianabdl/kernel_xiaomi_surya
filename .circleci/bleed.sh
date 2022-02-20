#!/usr/bin/env bash
echo "Cloning dependencies"
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

# Info
KERNEL="StormBreaker-Test"
DEVICE="Surya"
KERNELTYPE="rev.0.1"
KERNELNAME="${KERNEL}-${DEVICE}-${KERNELTYPE}-$(date +%y%m%d-%H%M)"
TEMPZIPNAME="${KERNELNAME}-unsigned.zip"
ZIPNAME="${KERNELNAME}.zip"
# Telegram
chat_id="-1001786450765" # Group/channel chatid (use rose/userbot to get it)
token="5136571256:AAEVb6wcnHbB358erxRQsP4crhW7zNh_7p8"

# Export Telegram.sh
TELEGRAM_FOLDER="${HOME}"/telegram
if ! [ -d "${TELEGRAM_FOLDER}" ]; then
    git clone https://github.com/fabianonline/telegram.sh/ "${TELEGRAM_FOLDER}"
fi

TELEGRAM="${TELEGRAM_FOLDER}"/telegram

# Starting
NOW=$(date +%d/%m/%Y-%H:%M)
START=$(date +"%s")
sendinfo "*CI Build #$CIRCLE_BUILD_NUM Triggered*" \
	"Compiling with *$(nproc --all)* CPUs" \
	"-----------------------------------------" \
	"*Compiler ver:* ${CSTRING}" \
	"*Device:* ${DEVICE}" \
	"*Kernel name:* ${KERNEL}" \
	"*Build ver:* ${KERNELTYPE}" \
	"*Linux version:* $(make kernelversion)" \
	"*Branch:* ${CIRCLE_BRANCH}" \
	"*Clocked at:* ${NOW}" \
	"*Latest commit:* ${LATEST_COMMIT}" \
 	"------------------------------------------" \
	"${LOGS_URL}"
finerr "END=$(date +"%s")" \
	"DIFF=$(( END - START ))" \
	"Kernel compilation failed, See build log to fix errors" \
	"Build for ${DEVICE} *failed* in $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)!"
tg_ship "<b>-------- Build #$CIRCLE_BUILD_NUM Succeeded --------</b>" \
        "" \
        "<b>Device:</b> ${DEVICE}" \
        "<b>Build ver:</b> ${KERNELTYPE}" \
        "<b>HEAD Commit:</b> ${CHEAD}" \
        "<b>Time elapsed:</b> $((DIFF / 60)):$((DIFF % 60))" \
        "" \
        "Try it and give me some thoughts!"

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
        -d "parse_mode=MARKDOWN" \
        -d text="$(
		for POST in "${@}"; do
			echo "${POST}"
		done
	)" &> /dev/null
}
# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id="$chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$(
		for POST in "${@}"; do
			echo "${POST}"
		done
	)" &> /dev/null
}
# Finerror
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="$(
		for POST in "${@}"; do
			echo "${POST}"
		done
	)" &> /dev/null
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
    zip -r9 ${ZIPNAME}.zip *
    cd .. 
}
sticker
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
