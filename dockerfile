FROM debian:bookworm-slim

ENV GODOT_VERSION "4.5.1"
ENV GODOT_EXPORT_PRESET="Web"
ENV GODOT_GAME_NAME "Chinchon"


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

COPY game_godot/ /godotbuildspace

COPY init_game.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init_game.sh

ENTRYPOINT [ "init_game.sh" ]
