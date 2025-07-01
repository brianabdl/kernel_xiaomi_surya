
#!/usr/bin/bash

function check-exec() {
    if ! which $1 &> /dev/null; then
        echo "no $1! abort!"
        exit 1
    else
        echo "ok: $1 exist"
    fi
}

check-exec jq
check-exec curl

if ! [ -f "$1" ]; then
    echo "no input! abort!"
    exit 1
fi
echo "Listing contents of: $(dirname "$1")"
find "$(dirname "$1")" -maxdepth 1 -type f

TAG=$(curl -s https://api.github.com/repos/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/latest | jq -r '.tag_name')
echo "latest tag is: $TAG"

if ! [ -f "patch_linux" ]; then
    echo "no patch_linux! downloading..."
    curl -Ls -o "patch_linux" "https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/$TAG/patch_linux"

    if [ $? -eq 0 ]; then
        echo "download ok"
    else
        echo "download fail ($?)! abort!"
        exit $?
    fi

    chmod +x "patch_linux"
    if [ $? -eq 0 ]; then
        echo "set permission ok"
    else
        echo "failed to set permission! abort!"
        exit $?
    fi
fi

FILENAME=$(basename "$1")
if ! [ "$FILENAME" = "Image" ]; then
    mv "$1" ./Image
fi

./patch_linux
if [ -f ./oImage ]; then
    mv ./oImage "$1"
    echo "KPM patch done"
else
    echo "oImage not found! Patch may have failed"
    exit 1
fi

echo "KPM patch done"