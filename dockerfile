FROM debian:bookworm-slim

# Environment Variables
ENV GODOT_VERSION "4.5.1"
ENV GODOT_EXPORT_PRESET="Web"
ENV GODOT_GAME_NAME "Chinchon"
#ENV HTTPS_GIT_REPO "https://github.com/mignavarl/prueba_godotcendece.git"

# Updates and installs to the server
# RUN apk update
# RUN apk add --no-cache bash
# RUN apk add --no-cache wget
# RUN apk add --no-cache git

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    git \
    ca-certificates \
    fontconfig \
    libfontconfig1 \
    libx11-6 \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    libxi6 \
    && rm -rf /var/lib/apt/lists/*
# Allow this to run Godot
#RUN wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.31-r0/glibc-2.31-r0.apk
#RUN apk add --allow-untrusted glibc-2.31-r0.apk

# Download Godot and export template, version is set from variables
RUN wget "https://downloads.godotengine.org/?version=${GODOT_VERSION}&flavor=stable&slug=linux.x86_64.zip&platform=linux.64" -O godot4.zip \
	&& wget "https://downloads.godotengine.org/?version=${GODOT_VERSION}&flavor=stable&slug=export_templates.tpz&platform=templates" -O godot_templates.tpz\
    && mkdir ~/.cache \
    && mkdir -p ~/.config/godot \
    && mkdir -p ~/.local/share/godot/export_templates/${GODOT_VERSION}.stable \
    && unzip godot4.zip \
	&& mv Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot4 \
    && unzip godot_templates.tpz \
    && mv templates/* ~/.local/share/godot/export_templates/${GODOT_VERSION}.stable \
    && rm -f godot4.zip godot_templates.tpz

# Make needed directories for container
RUN mkdir /godotapp
RUN mkdir /godotbuildspace

COPY game_godot/* /godotbuildspace

COPY init_game.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init_game.sh

ENTRYPOINT [ "init_game.sh" ]
# # Move to the build space and export the .pck
# WORKDIR /godotbuildspace
# RUN git clone ${HTTPS_GIT_REPO} .
# WORKDIR /
# CMD sleep infinity
# RUN ["/bin/sh", "-c", "godot4 --path /godotbuildspace --export-pack ${GODOT_EXPORT_PRESET} ${GODOT_GAME_NAME}.pck"]
# RUN mv ${GODOT_GAME_NAME}.pck /godotapp/

# # Change to the godotapp space, delete the source,  and run the app
# WORKDIR /godotapp
# RUN rm -f -R /godotbuildspace
# CMD ["/bin/sh", "-c", "godot4 --main-pack ${GODOT_GAME_NAME}.pck"]