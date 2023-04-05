FROM python:3.11.3-alpine
LABEL maintainer="Victor R. Santos <victor-rds@users.noreply.github.com>"

ARG DEFAULT_UID=373
ARG DEFAULT_GID=373
ARG ETE_VERSION=master
ARG ETE_REPO="https://github.com/etesync/server.git"

ENV BASE_DIR /etebase

ENV DATA_DIR /data
ENV MEDIA_ROOT ${DATA_DIR}/media
ENV ETEBASE_EASY_CONFIG_PATH ${DATA_DIR}/etebase-server.ini
ENV SECRET_FILE ${DATA_DIR}/secret.txt

ENV STATIC_ROOT /srv/etebase/static

ENV SERVER="http"
ENV PORT 3735

WORKDIR ${BASE_DIR}

# OS packages and deps installation
# hadolint ignore=DL3008,DL3018
RUN set -eux; \
    # Prepare packages required by the base image
    apk add --no-cache openssl mailcap libpq libffi libldap libsasl bash; \
    apk add --no-cache --virtual .build-deps coreutils gcc make wget linux-headers \
        cyrus-sasl-dev libc-dev libffi-dev openssl-dev postgresql-dev openldap-dev git; \
    # Fix Python LDAP build
    echo 'INPUT ( libldap.so )' > /usr/lib/libldap_r.so; \
    # Download Etebase and install dependencies
    git clone --depth=1 --branch=${ETE_VERSION} "${ETE_REPO}" "${BASE_DIR}"; \
    /usr/local/bin/python -m pip install --no-cache-dir --progress-bar off --upgrade pip; \
    pip install --no-cache-dir --progress-bar off -r "${BASE_DIR}/requirements.txt" "psycopg2-binary" "python-ldap"; \
    # Remove packages no longer required by the base image
    apk del .build-deps; \
    # Clear Downloads and set permissions
    rm -r "${BASE_DIR}/.git"; \
    chown -R "${DEFAULT_UID}":"${DEFAULT_GID}" "${BASE_DIR}"

# Etebase directories and user setup 
RUN set -eux; \
    addgroup --system --gid "${DEFAULT_GID}" etebase; \
    adduser --system --no-create-home --disabled-password \
    --gecos '' --home ${BASE_DIR} --ingroup etebase --uid "${DEFAULT_UID}" etebase; \
    mkdir -p "${MEDIA_ROOT}" "${STATIC_ROOT}"; \
    chown -R "${DEFAULT_UID}":"${DEFAULT_GID}" "${DATA_DIR}" "${STATIC_ROOT}"; \
    chmod -R 750 "${DATA_DIR}"; \
    export DJANGO_STATIC_ROOT="${STATIC_ROOT}"; \
    "${BASE_DIR}"/manage.py collectstatic --no-input; \
    rm "${BASE_DIR}/secret.txt"

COPY --chown=${DEFAULT_UID}:${DEFAULT_GID} context /

USER etebase:etebase

EXPOSE ${PORT}

VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]