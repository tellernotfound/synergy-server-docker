FROM cm2network/steamcmd:root AS base-amd64

FROM --platform=arm64 sonroyaalmerol/steamcmd-arm64:root-2024-12-06 AS base-arm64

ARG TARGETARCH

FROM base-${TARGETARCH}

LABEL maintainer="stefano.africano@outlook.com" \
	  name="tellernotfound/synergy-server-docker" \
	  github="https://github.com/tellernotfound/synergy-server-docker" \
	  dockerhub="https://hub.docker.com/r/tellernotfound/synergy-server-docker" \
	  org.opencontainers.image.authors="Stefano Africano" \
	  org.opencontainers.image.source="https://github.com/tellernotfound/synergy-server-docker"

# set envs
# SUPERCRONIC: Latest releases available at https://github.com/aptible/supercronic/releases
# RCON: Latest releases available at https://github.com/gorcon/rcon-cli/releases
# DEPOT_DOWNLOADER: Latest releases available at https://github.com/SteamRE/DepotDownloader/releases
ARG SUPERCRONIC_SHA1SUM_ARM64="e0f0c06ebc5627e43b25475711e694450489ab00 "
ARG SUPERCRONIC_SHA1SUM_AMD64="71b0d58cc53f6bd72cf2f293e09e294b79c666d8 "
ARG SUPERCRONIC_VERSION="0.2.33"
ARG DEPOT_DOWNLOADER_VERSION="2.7.3"

# update and install dependencies
# RUN apt-get update && apt-get install -y --no-install-recommends \
# 	procps=2:4.0.2-3 \
# 	wget \ 
# 	gettext-base=0.21-12 \
# 	xdg-user-dirs=0.18-1 \
# 	jo=1.9-1 \
# 	jq=1.6-2.1 \
# 	netcat-traditional=1.10-47 \
# 	libicu72=72.1-3 \
# 	unzip=6.0-28 \
# 	&& apt-get clean \
# 	&& rm -rf /var/lib/apt/lists/*

# install supercronic and depotdownloader
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH
RUN case "${TARGETARCH}" in \
		"amd64") SUPERCRONIC_SHA1SUM=${SUPERCRONIC_SHA1SUM_AMD64} ;; \
		"arm64") SUPERCRONIC_SHA1SUM=${SUPERCRONIC_SHA1SUM_ARM64} ;; \
	esac \
	&& wget --progress=dot:giga "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-${TARGETARCH}" -O supercronic \
	&& echo "${SUPERCRONIC_SHA1SUM}" supercronic | sha1sum -c - \
	&& chmod +x supercronic \
	&& mv supercronic /usr/local/bin/supercronic

RUN case "${TARGETARCH}" in \
		"amd64") DEPOT_DOWNLOADER_FILENAME=DepotDownloader-linux-x64.zip ;; \
		"arm64") DEPOT_DOWNLOADER_FILENAME=DepotDownloader-linux-arm64.zip ;; \
	esac \
	&& wget --progress=dot:giga "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOT_DOWNLOADER_VERSION}/${DEPOT_DOWNLOADER_FILENAME}" -O DepotDownloader.zip \
	&& unzip DepotDownloader.zip \
	&& rm -rf DepotDownloader.xml \
	&& chmod +x DepotDownloader \
	&& mv DepotDownloader /usr/local/bin/DepotDownloader

ENV HOME=/home/steam \
	PORT= \
	PUID=1000 \
	PGID=1000 \
	PLAYERS= \
	TZ=UTC \
	SERVER_DESCRIPTION= \
	BACKUP_ENABLED=true \
	DELETE_OLD_BACKUPS=false \
	OLD_BACKUP_DAYS=30 \
	BACKUP_CRON_EXPRESSION="0 0 * * *" \
	AUTO_UPDATE_ENABLED=false \
	AUTO_UPDATE_CRON_EXPRESSION="0 * * * *" \
	AUTO_UPDATE_WARN_MINUTES=30 \
	AUTO_REBOOT_ENABLED=false \
	AUTO_REBOOT_WARN_MINUTES=5 \
	AUTO_REBOOT_EVEN_IF_PLAYERS_ONLINE=false \
	AUTO_REBOOT_CRON_EXPRESSION="0 0 * * *" \
	ARM64_DEVICE=generic \
	DISABLE_GENERATE_ENGINE=true \
	ALLOW_CONNECT_PLATFORM=Steam \
	USE_DEPOT_DOWNLOADER=false 

# Sane Box64 config defaults
# hadolint ignore=DL3044
ENV BOX64_DYNAREC_STRONGMEM=1 \
	BOX64_DYNAREC_BIGBLOCK=1 \
	BOX64_DYNAREC_SAFEFLAGS=1 \
	BOX64_DYNAREC_FASTROUND=1 \
	BOX64_DYNAREC_FASTNAN=1 \
	BOX64_DYNAREC_X87DOUBLE=0

# Passed from Github Actions
ARG GIT_VERSION_TAG=unspecified

COPY ./scripts /home/steam/server/

RUN chmod +x /home/steam/server/*.sh && \
	mv /home/steam/server/backup.sh /usr/local/bin/backup && \
	mv /home/steam/server/update.sh /usr/local/bin/update && \
	mv /home/steam/server/restore.sh /usr/local/bin/restore && \
	ln -sf /home/steam/server/rest_api.sh /usr/local/bin/rest-cli

WORKDIR /home/steam/server

# Make GIT_VERSION_TAG file to be able to check the version
RUN echo $GIT_VERSION_TAG > GIT_VERSION_TAG

RUN touch crontab && \
	mkdir -p /home/steam/Steam/package && \
	chown steam:steam /home/steam/Steam/package && \
	rm -rf /tmp/dumps && \
	chmod o+w crontab /home/steam/Steam/package && \
	chown steam:steam -R /home/steam/server

HEALTHCHECK --start-period=5m \
	CMD pgrep "SynServer-Linux" > /dev/null || exit 1

EXPOSE ${PORT} ${RCON_PORT}
ENTRYPOINT ["/home/steam/server/init.sh"]
