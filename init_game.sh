#!/bin/bash

wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.31-r0/glibc-2.31-r0.apk
apk add --allow-untrusted glibc-2.31-r0.apk
pwd
echo "Haciendo package"
# cd /godotbuildspace
# echo "Clono en"
# pwd
# git clone ${HTTPS_GIT_REPO} .
# cd /
echo "Compilo godot4 en "
pwd 
# godot4 --path /godotbuildspace --export-pack ${GODOT_EXPORT_PRESET} ${GODOT_GAME_NAME}.pck --headless
godot4 --headless --path /godotbuildspace --export-release ${GODOT_EXPORT_PRESET} /godotapp/index.html
#mv /godotbuildspace/${GODOT_GAME_NAME}.pck /godotapp/


sleep infinity
# # Change to the godotapp space, delete the source,  and run the app
#cd /godotapp
# rm -f -R /godotbuildspace

#godot4 --main-pack ${GODOT_GAME_NAME}.pck --headless