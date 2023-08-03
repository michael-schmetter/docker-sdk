# -----------------------------

FROM busybox AS stash-src

COPY src /data/src
COPY public /data/public
COPY config /data/config
COPY resource[s] /data/resources
COPY composer.json composer.lock *.php LICENSE /data

FROM stash-src AS stash-src-with-data-excluding-import
LABEL "spryker.image" "none"

COPY data /data/data

RUN rm -rf /data/data/import

# -----------------------------

FROM ${SPRYKER_PLATFORM_IMAGE} AS stash-rsync
LABEL "spryker.image" "none"

RUN --mount=type=cache,id=apk,sharing=locked,target=/var/cache/apk \
  --mount=type=cache,id=aptlib,sharing=locked,target=/var/lib/apt \
  --mount=type=cache,id=aptcache,sharing=locked,target=/var/cache/apt \
  <<EOT bash -e # Installing rsync
    if which apk; then
      mkdir -p /etc/apk
      ln -vsf /var/cache/apk /etc/apk/cache
      apk update
      apk add \
        rsync
    else
      apt update -y
      apt install -y \
        rsync
    fi
EOT

# Not bash as awk does not work
RUN <<EOT
  set -e
  mkdir -p /rsync/
  cp -fp /usr/bin/rsync /rsync/
  ldd /usr/bin/rsync | awk '/=>/ { print $3 }' | xargs -I '{}' cp -fp '{}' /rsync
EOT

# -----------------------------

FROM ${SPRYKER_PLATFORM_IMAGE} AS application-codebase
LABEL "spryker.image" "none"

USER spryker:spryker

COPY --chown=spryker:spryker composer.json composer.lock *.php ${srcRoot}/
ARG SPRYKER_COMPOSER_MODE
RUN --mount=type=cache,id=composer,sharing=locked,target=/home/spryker/.composer/cache,uid=1000 \
  --mount=type=ssh,uid=1000 --mount=type=secret,id=secrets-env,uid=1000 \
  <<EOT bash -e
    set -o allexport && . /run/secrets/secrets-env && set +o allexport
    composer install --no-scripts --no-interaction ${SPRYKER_COMPOSER_MODE}
EOT

# -----------------------------

FROM application-basic AS application-before-stamp
LABEL "spryker.image" "none"

USER spryker:spryker

# Install composer modules for Spryker
RUN --mount=type=bind,from=application-codebase,source=/data/vendor,target=/vendor \
  --mount=type=bind,from=stash-rsync,source=/rsync,target=/rsync \
  --mount=type=tmpfs,target=/var/run/opcache/ \
  <<EOT bash -e
    LD_LIBRARY_PATH=/rsync /rsync/rsync -ap --chown=spryker:spryker /vendor/ ./vendor/ \
      --exclude '.git*/' \
      --include 'tests/dd.php' --exclude 'tests/*' \
      --exclude 'codeception.yml' \
      --exclude '*.md' \
      --exclude 'composer.lock' \
      --exclude '.scrutinizer.yml' \
      --exclude 'assets/' \
      --exclude '*.ts' --exclude '*.js' \
      --exclude '*.scss' \
      --exclude 'package.json' --exclude 'package-lock.json'
EOT

COPY --from=stash-src-with-data-excluding-import --chown=spryker:spryker /data ${srcRoot}

ARG SPRYKER_COMPOSER_AUTOLOAD
RUN --mount=type=tmpfs,target=/var/run/opcache/ \
  <<EOT bash -e
    chmod 600 ${srcRoot}/config/Zed/*.key 2>/dev/null || true
    vendor/bin/install -r ${SPRYKER_PIPELINE} -s build -s build-production
    composer dump-autoload ${SPRYKER_COMPOSER_AUTOLOAD}
EOT

USER root

CMD [ "php-fpm", "--nodaemonize" ]
EXPOSE 9000

FROM application-before-stamp AS application
LABEL "spryker.image" "application"

ARG SPRYKER_BUILD_HASH
ENV SPRYKER_BUILD_HASH=${SPRYKER_BUILD_HASH}
ARG SPRYKER_BUILD_STAMP
ENV SPRYKER_BUILD_STAMP=${SPRYKER_BUILD_STAMP}
