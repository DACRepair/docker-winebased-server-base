FROM ubuntu:20.04 as system
LABEL org.opencontainers.image.authors = "Toetje585"
LABEL org.opencontainers.image.source = "https://github.com/wine-gameservers/docker-winebased-server-base/"

################################################################################
# docker-winebased-server-base
################################################################################

# built-in packages
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get upgrade -y && apt-get install apt-utils -y \
    && apt-get install -y --no-install-recommends software-properties-common curl  \
    && apt-get update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
        supervisor sudo net-tools zenity xz-utils \
        dbus-x11 x11-utils alsa-utils \
        mesa-utils libgl1-mesa-dri wget gpg gpg-agent nginx locales locales-all xdg-user-dirs xdg-utils

# Default locale

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# install vnc debs error if combine together

RUN apt-get update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
        xvfb x11vnc \
        vim-tiny ttf-ubuntu-font-family ttf-wqy-zenhei

# install lxde so we get a nice interface

RUN apt-get update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
        lxde gtk2-engines-murrine gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine arc-theme

# install handy software

RUN apt-get update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
        midori

# install dev packages

RUN apt-get update && apt-get install -y gcc make cmake


# tini to fix subreap
ARG TINI_VERSION=v0.19.0
RUN wget https://github.com/krallin/tini/archive/v0.19.0.tar.gz \
 && tar zxf v0.19.0.tar.gz \
 && export CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"; \
    cd tini-0.19.0; cmake . && make && make install \
 && cd ..; rm -r tini-0.19.0 v0.19.0.tar.gz


# install wine debs error if combine together

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    wget -O - https://dl.winehq.org/wine-builds/winehq.key | apt-key add -  && \
    echo 'deb https://dl.winehq.org/wine-builds/ubuntu/ focal main' |tee /etc/apt/sources.list.d/winehq.list && \
    apt-get update && apt-get --install-recommends -y install winehq-staging winbind  && \
    apt-get -y install winetricks && \
    mkdir /opt/wine-staging/share/wine/mono && wget -O - https://dl.winehq.org/wine/wine-mono/7.0.0/wine-mono-7.0.0-x86.tar.xz | tar Jx -C /opt/wine-staging/share/wine/mono && \
    mkdir /opt/wine-staging/share/wine/gecko && wget -O /opt/wine-staging/share/wine/gecko/wine-gecko-2.47.1-x86.msi https://dl.winehq.org/wine/wine-gecko/2.47.2/wine-gecko-2.47.2-x86.msi && wget -O /opt/wine-staging/share/wine/gecko/wine-gecko-2.47.2-x86_64.msi https://dl.winehq.org/wine/wine-gecko/2.47.2/wine-gecko-2.47.2-x86_64.msi && \
    apt-get -y full-upgrade && apt-get clean

# Killsession app
COPY killsession/ /tmp/killsession
RUN cd /tmp/killsession; \
    gcc -o killsession killsession.c && \
    mv killsession /usr/local/bin && \
    chmod a=rx /usr/local/bin/killsession && \
    chmod a+s /usr/local/bin/killsession && \
    mv killsession.py /usr/local/bin/ && chmod a+x /usr/local/bin/killsession.py && \
    mkdir -p /usr/local/share/pixmaps && mv killsession.png /usr/local/share/pixmaps/ && \
    mv KillSession.desktop /usr/share/applications/ && chmod a+x /usr/share/applications/KillSession.desktop && \
    cd /tmp && rm -r killsession
    

# python library
COPY rootfs/usr/local/lib/web/backend/requirements.txt /tmp/
RUN apt-get update \
    && dpkg-query -W -f='${Package}\n' > /tmp/a.txt \
    && apt-get install -y python3-pip python3-dev build-essential \
    && pip3 install setuptools wheel && pip3 install -r /tmp/requirements.txt \
    && ln -s /usr/bin/python3 /usr/local/bin/python \
    && dpkg-query -W -f='${Package}\n' > /tmp/b.txt \
    && apt-get remove -y `diff --changed-group-format='%>' --unchanged-group-format='' /tmp/a.txt /tmp/b.txt | xargs` \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* /tmp/a.txt /tmp/b.txt

RUN apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

################################################################################
# builder
################################################################################
FROM ubuntu:20.04 as builder

#RUN sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list;

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates gnupg patch

# nodejs
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - \
    && apt-get install -y nodejs

# yarn
# Fix issue with libssl and docker on M1 chips
# RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
COPY yarnpkg_pubkey.gpg .
RUN cat yarnpkg_pubkey.gpg | apt-key add -  && rm yarnpkg_pubkey.gpg \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn

# build frontend
COPY web /src/web
RUN cd /src/web \
    && yarn upgrade \
    && yarn \
    && yarn build
RUN sed -i 's#app/locale/#novnc/app/locale/#' /src/web/dist/static/novnc/app/ui.js

RUN apt autoremove && apt autoclean

################################################################################
# Finishing touches...
################################################################################

FROM system

COPY --from=builder /src/web/dist/ /usr/local/lib/web/frontend/
COPY rootfs /
RUN ln -sf /usr/local/lib/web/frontend/static/websockify /usr/local/lib/web/frontend/static/novnc/utils/websockify && \
	chmod +x /usr/local/lib/web/frontend/static/websockify/run

EXPOSE 9000/tcp
WORKDIR /root
ENV HOME=/home/ubuntu \
    SHELL=/bin/bash
HEALTHCHECK --interval=30s --timeout=5s CMD curl --fail http://127.0.0.1:6079/api/health
ENTRYPOINT ["/startup.sh"]
