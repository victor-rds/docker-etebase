#!/usr/bin/env bash

if [ ! -z "$@" ]; then
  exec "$@"
fi

declare -r MANAGE="$BASE_DIR/manage.py"
declare -r uWSGI='/usr/local/bin/uwsgi --ini /uwsgi-etebase.ini'

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
    exit 1
  fi
  local val="$def"
  if [ "${!var:-}" ]; then
    val="${!var}"
  elif [ "${!fileVar:-}" ]; then
    val="$(<"${!fileVar}")"
  fi
  export "$var"="$val"
  unset "$fileVar"
}

init_env() {
  declare -g -x PUID="$(id -u)"
  declare -g -x PGID="$(id -g)"

  if ! ([ "$PUID" -gt 0 ] 2>/dev/null && [ "$PGID" -gt 0 ] 2>/dev/null); then
    echo "PUID or GUID values not supported!" >>/dev/stderr
    exit 29
  fi

  : ${DEBUG:=false}
  : ${LANGUAGE_CODE:=en-us}
  : ${TIME_ZONE:=UTC}
  : ${ALLOWED_HOSTS:=*}
  : ${X509_CRT:=$DATA_DIR/certs/crt.pem}
  : ${X509_KEY:=$DATA_DIR/certs/key.pem} 

  file_env 'DB_ENGINE' 'sqlite'
  file_env 'DATABASE_NAME'

  if [ "$DB_ENGINE" = "sqlite" ]; then
    local _DB_FILENAME="$(basename "$DATABASE_NAME")"

    if [ -z "$_DB_FILENAME" ]; then
      DATABASE_NAME="${DATA_DIR}/db.sqlite3"
    elif [ "${_DB_FILENAME##*.}" != 'sqlite3' ]; then
      DATABASE_NAME="${DATABASE_NAME}/db.sqlite3"
    fi
  elif [ "$DB_ENGINE" = "postgres" ] && [ -z "$DATABASE_NAME" ]; then
    DATABASE_NAME='etebase'
  else
    echo "Database option not supported!" >>/dev/stderr
    exit 219
  fi

  if [ "$PORT" -lt "1024" ]; then
    echo "Only root can use ports below 1024" >>/dev/stderr
    exit 90
  fi
}

gen_inifile() {

  echo "[global]
secret_file = ${SECRET_FILE}
debug = ${DEBUG}
static_root = ${STATIC_ROOT}
static_url = /static/
media_root = ${MEDIA_ROOT}
media_url =  /user-media/
language_code = ${LANGUAGE_CODE}
time_zone = ${TIME_ZONE}

[allowed_hosts]
allowed_host1 = ${ALLOWED_HOSTS}
" >$ETEBASE_EASY_CONFIG_PATH

  if [ "$DB_ENGINE" = "postgres" ]; then
    file_env 'DATABASE_USER' "$DATABASE_NAME"
    file_env 'DATABASE_PASSWORD' "$DATABASE_USER"

    echo "[database]
engine = django.db.backends.postgresql
name = ${DATABASE_NAME}
user = ${DATABASE_USER}
password = ${DATABASE_PASSWORD}
host = ${DATABASE_HOST:=database}
port = ${DATABASE_PORT:=5432}
" >>$ETEBASE_EASY_CONFIG_PATH
  else
    echo "[database]
engine = django.db.backends.sqlite3
name = ${DATABASE_NAME}
" >>$ETEBASE_EASY_CONFIG_PATH
  fi
}

migrate() {
  local _AUTO=$1

  $MANAGE showmigrations -l | grep -v '\[X\]'

  if [ ! -z "$_AUTO" ]; then
    $MANAGE migrate
  else
    echo "If necessary please run: docker exec -it $HOSTNAME python manage.py migrate"
  fi
}

create_superuser() {
  file_env 'SUPER_USER'

  if [ "$SUPER_USER" ]; then
    file_env 'SUPER_PASS'
    file_env 'SUPER_EMAIL'

    if [ -z "$SUPER_PASS" ]; then
      SUPER_PASS=$(openssl rand -base64 31)
      echo "Admin Password: $SUPER_PASS"
    fi

    echo 'Creating Super User'
    echo "from myauth.models import User; User.objects.create_superuser('$SUPER_USER' , None, '$SUPER_PASS')" | python manage.py shell
  fi
}

generate_certs() {
  echo "TLS is enabled, however neither the certificate nor the key were found!"
  echo "The correct paths are '$X509_CRT' and '$X509_KEY'"
  echo "Let's generate a self-sign certificate, but this isn't recommended"

  local CERTS_DIR=$(dirname $X509_CRT)

  if [ ! -d "$CERTS_DIR" ]; then
    mkdir -p "$CERTS_DIR"
  fi

  openssl req -x509 -nodes -newkey rsa:2048 -keyout $X509_KEY -out $X509_CRT -days 365 -subj "/CN=${HOSTNAME}"
}

check_db() {

  $MANAGE migrate --plan 2>/dev/null | grep 'django_etebase.0001_initial' >/dev/null
  local _PS=("${PIPESTATUS[@]}")

  if [ ${_PS[0]} -eq "0" ] && [ ${_PS[1]} -eq "0" ]; then
    migrate true
    create_superuser
  elif [ ${_PS[0]} -eq "0" ] && [ ${_PS[1]} -ne "0" ]; then
    migrate "${AUTO_UPATE}"
  else
    echo "
#########################################################################
# This database schema is not compatible with Etebase (EteSync 2.0)     #
# To avoid any data damage the container will now fail to start         #
# Please save your data follow this instructions instructions:          #
# https://github.com/etesync/server#updating-from-version-050-or-before #
#########################################################################
" >>/dev/stderr
    exit 231
  fi
}

init_env

if [ ! -e "$ETEBASE_EASY_CONFIG_PATH" ] || [ ! -z "$REGEN_INI" ]; then
  gen_inifile
fi

check_db

$MANAGE collectstatic --no-input

if [ $SERVER = 'https' ] && { [ ! -e "$X509_CRT" ] || [ ! -e "$X509_KEY" ]; }; then
  generate_certs
fi

echo 'Starting Etebase'

declare _CMD=""

case "$SERVER" in
'django-server')
  _CMD="$MANAGE runserver 0.0.0.0:$PORT"
  ;;
'asgi' | 'daphne')
  _CMD="daphne -b 0.0.0.0 -p $PORT etebase_server.asgi:application"
  ;;
'uwsgi')
  _CMD="${uWSGI}:uwsgi"
  ;;
'http-socket')
  _CMD="${uWSGI}:http-socket"
  ;;
'https')
  _CMD="${uWSGI}:https"
  ;;
'http')
  _CMD="${uWSGI}:http"
  ;;
*)
  echo "Server option not supported!" >>/dev/stderr
  exit 94
  ;;
esac

exec $_CMD
