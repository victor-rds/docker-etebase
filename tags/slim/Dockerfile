FROM python:3.9.0-slim

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
    groupadd -r -g $PGID etesync && \
	useradd -d $BASE_DIR -r -M -s /bin/sh -g $PGID -u $PUID etesync && \
    mkdir -p $DATA_DIR && \
    mkdir -p $CERT_DIR && \
    mkdir -p $STATIC_DIR && \
    tar xvf $BASE_DIR/${TAG}.tar.gz -C $BASE_DIR --strip-components=1 --exclude="example-configs" --exclude-vcs && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends build-essential libssl-dev && \
    pip install -r $BASE_DIR/requirements.txt uwsgi psycopg2-binary && \
    apt-get remove --purge -y build-essential && \
	apt-get autoremove --purge -y && \
    $BASE_DIR/manage.py collectstatic && \
    mv $BASE_DIR/static $STATIC_DIR/ && \
    ln -s $STATIC_DIR/static $BASE_DIR/static && \
    rm $BASE_DIR/${TAG}.tar.gz $BASE_DIR/requirements.txt $SECRET_FILE && \
    rm -rf /var/lib/apt/lists/* && \
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