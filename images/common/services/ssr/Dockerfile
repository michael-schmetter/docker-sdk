ARG SPRYKER_NODE_IMAGE_VERSION=16
ARG SPRYKER_NPM_VERSION=8
ARG SPRYKER_NODE_IMAGE_DISTRO=alpine

FROM node:${SPRYKER_NODE_IMAGE_VERSION}-${SPRYKER_NODE_IMAGE_DISTRO} AS ssr-application

RUN apk update && apk upgrade && \
    apk add --no-cache git && \
    apk add vim && \
    apk add patch && \
    apk add openssh

RUN npm install -g npm@${SPRYKER_NPM_VERSION}
RUN npm install -g nx
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /data
WORKDIR /data

EXPOSE 2223
ENTRYPOINT ["/entrypoint.sh"]
