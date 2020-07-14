FROM python:3.8.4-alpine

ARG TAG='master'

ENV BASE_DIR /etesync
ENV DATA_DIR /data
ENV STATIC_DIR /var/www/etesync

ENV SECRET_FILE $BASE_DIR/secret.txt
ENV ETESYNC_DB_PATH $DATA_DIR/db.sqlite3

ARG CERT_DIR=/certs
ENV X509_CRT $CERT_DIR/crt.pem
ENV X509_KEY $CERT_DIR/key.pem

ENV PUID 1000
ENV PGID 1000
ENV PORT 3735
ENV SERVER="http"

WORKDIR $BASE_DIR

ADD https://github.com/etesync/server-skeleton/archive/${TAG}.tar.gz $BASE_DIR

RUN set -e && \
    addgroup -g $PGID -S etesync && \
    adduser -h $BASE_DIR -s /bin/sh -D -H -G etesync -u $PUID etesync && \
    mkdir -p $DATA_DIR && \
    mkdir -p $CERT_DIR && \
    mkdir -p $STATIC_DIR && \
    tar x -v -z -f $BASE_DIR/${TAG}.tar.gz -C $BASE_DIR --strip-components=1 --exclude */example-configs --exclude */.git* && \
    apk add --no-cache openssl libressl mailcap && \
    apk add --no-cache --virtual .build-deps coreutils gcc make linux-headers libc-dev libressl-dev && \
    pip install -r $BASE_DIR/requirements.txt uwsgi && \
    apk del .build-deps && \
    $BASE_DIR/manage.py collectstatic && \
    mv $BASE_DIR/static $STATIC_DIR/ && \
    ln -s $STATIC_DIR/static $BASE_DIR/static && \
    rm $BASE_DIR/${TAG}.tar.gz $BASE_DIR/requirements.txt $SECRET_FILE && \
    chown -h etesync:etesync $BASE_DIR/static && \
    chown -R etesync:etesync $STATIC_DIR && \
    chmod -R a=rX $STATIC_DIR && \
    chown -R etesync:etesync $DATA_DIR && \
    chmod -R ug=rwX $DATA_DIR && \
    chown -R etesync:etesync $BASE_DIR && \
    chmod -R ug=rwX $BASE_DIR

COPY --chown=etesync:etesync context /

# Fix permissions
RUN chown root:root /entrypoint.sh && \
    chmod a=rx /entrypoint.sh

VOLUME $DATA_DIR

EXPOSE 3735

ENTRYPOINT ["/entrypoint.sh"]