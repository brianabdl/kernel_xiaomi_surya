#!/bin/bash
#
# Compile script for Arise kernel
# Copyright (C) 2020-2021 Adithya R.

SECONDS=0 # builtin bash timer
ZIPNAME="Shinigami-surya-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$(pwd)/tc/clang-neutron"
AK3_DIR="$(pwd)/android/AnyKernel3"
DEFCONFIG="surya_defconfig"

function check-exec() {
    if ! which $1 &> /dev/null; then
        echo "no $1! abort!"
        exit 1
    else
        echo "ok: $1 exist"
    fi
}

check-exec jq
check-exec wget

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
	echo "Neutron Clang not found! Downloading to $TC_DIR..."
	mkdir -p "$TC_DIR" && cd "$TC_DIR"
	curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
	bash ./antman -S
	bash ./antman --patch=glibc
	cd ../..
	if ! [ -d "$TC_DIR" ]; then
		echo "Cloning failed! Aborting..."
		exit 1
	fi
fi

cd "$TC_DIR" && bash ./antman -U && cd ../..

if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make O=out ARCH=arm64 $DEFCONFIG savedefconfig
	cp out/defconfig arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-rf" || $1 = "--regen-full" ]]; then
	make O=out ARCH=arm64 $DEFCONFIG
	cp out/.config arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated full defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
	rm -rf out
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 DTC_EXT=dtc Image.gz dtb.img dtbo.img 2> >(tee log.txt >&2) || exit $?

kernel="out/arch/arm64/boot/Image.gz"
dtb="out/arch/arm64/boot/dtb.img"
dtbo="out/arch/arm64/boot/dtbo.img"

cd out/arch/arm64/boot/ || {
    echo "Error: Directory out/arch/arm64/boot does not exist. Please run the build script first."
    exit 1
}

echo "Downloading patch_linux..."
wget "https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/latest/download/patch_linux"
echo "Making patch_linux executable..."
chmod +x patch_linux
echo "Unpacking..."
gunzip -f Image.gz
echo "Patching..."
./patch_linux
echo "Packing Image..."
rm Image
mv oImage Image
gzip -f -9 Image
echo "KPM patch applied successfully!"

cd - || {
    echo "Error: Could not return to the previous directory."
    exit 1
}

if [ -f "$kernel" ] && [ -f "$dtb" ] && [ -f "$dtbo" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if [ -d "AnyKernel3" ]; then
		rm -rf AnyKernel3
	fi
	if ! git clone -q https://github.com/surya-aosp/AnyKernel3 -b shinigami; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
	cp $kernel $dtb $dtbo AnyKernel3
	rm -rf out/arch/arm64/boot
	cd AnyKernel3
	git checkout shinigami &> /dev/null
	zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
	cd ..
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
 echo "ZIPNAME=$ZIPNAME" >> $GITHUB_ENV
else
	echo -e "\nCompilation failed!"
	exit 1
fi
