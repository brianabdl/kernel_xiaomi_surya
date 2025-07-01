
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

TAG=$(jq -r 'map(select(.prerelease)) | first | .tag_name' <<< $(curl --silent https://api.github.com/repos/ShirkNeko/SukiSU_KernelPatch_patch/releases))
echo "latest tag is: $TAG"

if ! [ -f "patch_linux-$TAG" ]; then
    echo "no patch_linux! downloading..."
    curl -Ls -o "patch_linux-$TAG" "https://github.com/ShirkNeko/SukiSU_KernelPatch_patch/releases/download/$TAG/patch_linux"

    if [ $? -eq 0 ]; then
        echo "download ok"
    else
        echo "download fail ($?)! abort!"
        exit $?
    fi

    chmod +x "patch_linux-$TAG"
    if [ $? -eq 0 ]; then
        echo "set permission ok"
    else
        echo "failed to set permission! abort!"
        exit $?
    fi
fi

FILENAME=$(basename "$1")
if ! [ "$FILENAME" = "Image" ]; then
    mv $1 ./Image
fi

./patch_linux-$TAG
mv ./oImage $1

echo "KPM patch done"