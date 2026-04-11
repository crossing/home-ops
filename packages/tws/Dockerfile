FROM docker.io/library/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    libx11-6 \
    libxrender1 \
    libxtst6 \
    libxi6 \
    libxext6 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libxfixes3 \
    libxcursor1 \
    libxinerama1 \
    libgl1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libcairo2 \
    libgdk-pixbuf-2.0-0 \
    libpango-1.0-0 \
    libatk1.0-0 \
    libharfbuzz0b \
    libasound2t64 \
    libnss3 \
    libgbm1 \
    libnspr4 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libxss1 \
    libvulkan1 \
    fontconfig \
    fonts-dejavu-core \
    fonts-liberation \
    xdg-utils \
    locales \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN mkdir -p /opt/tws /home/tws /root/Jts && chmod 777 /opt/tws /home/tws /root /root/Jts

CMD ["tail", "-f", "/dev/null"]