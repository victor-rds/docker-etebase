#!/usr/bin/env bash

if [ "${SHELL_DEBUG}" = "true" ]; then
  set -x
fi

if [ -n "$*" ]; then
  exec "$@"
fi

C_UID="$(id -u)"
C_GID="$(id -g)"

readonly C_UID
readonly C_GID

declare -r MANAGE="$BASE_DIR/manage.py"
declare -r ERROR_PERM_TEMPLATE="%s : Permission Denied. Please check the volume permissions or the user (%s:%s) running the container."
declare -r ERROR_DB_TEMPLATE='Failed do access %s database. Please check the database connection or file permission.'

# logging functions
dckr_log() {
  local type="$1"
  shift
  printf '%s [%s] [Entrypoint]: %s\n' "$(date -Iseconds)" "${type}" "$*"
}

dckr_debug() {
  if [ "${DEBUG}" = "true" ]; then
    dckr_log Debug "$@"
  fi
}

dckr_info() {
  dckr_log Info "$@"
}
dckr_warn() {
  dckr_log Warn "$@" >&2
}
dckr_error() {
  dckr_log Error "$@" >&2
  exit 1
}

get_file_info() {
  stat -c '%n | %u:%g %A' "$1"
}

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    dckr_error "error: both $var and $fileVar are set (but are exclusive)"
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

  if [ -n "${PUID}" ] || [ -n "${PGID}" ]; then
    dckr_warn "Setting PUID/PGID is no longer supported, change the user running the container"
  fi

  if [ "${C_UID}" -eq '0' ] || [ "${C_GID}" -eq '0' ]; then
    dckr_warn "Running container as Root is not recommended, please avoid if possible."
  fi

  : "${DEBUG_DJANGO:=false}"
  : "${LANGUAGE_CODE:=en-us}"
  : "${TIME_ZONE:=UTC}"
  : "${ALLOWED_HOSTS:=*}"

  declare -g -x X509_CRT=${X509_CRT:=$DATA_DIR/certs/crt.pem}
  declare -g -x X509_KEY=${X509_KEY:=$DATA_DIR/certs/key.pem}

  file_env 'DB_ENGINE' 'sqlite'
  file_env 'DATABASE_NAME'

  if [ "${DB_ENGINE}" = "sqlite" ]; then
    local _DB_FILENAME
    _DB_FILENAME="$(basename "${DATABASE_NAME}")"

    if [ -z "${_DB_FILENAME}" ]; then
      DATABASE_NAME="${DATA_DIR}/db.sqlite3"
    elif [ "${_DB_FILENAME##*.}" != 'sqlite3' ]; then
      DATABASE_NAME="${DATABASE_NAME}/db.sqlite3"
    fi
  elif [ "${DB_ENGINE}" = "postgres" ]; then
    : "${DATABASE_NAME:=etebase}"
  else
    dckr_error "Database option not supported!"
  fi

  if [ "${PORT}" -lt "1024" ] && [ "${C_UID}" -ne '0' ]; then
    dckr_error "Only root can use ports below 1024"
  fi
}

output_perms() {
  local FD="${1}"
  local BIT="${2:-r}"

  local PROK="f"
  local PWOK="f"

  if [ ! -e "${FD}" ]; then
    dckr_debug "${FD} does not exist"
  else
    dckr_debug "$(get_file_info "${FD}")"

    if [ -r "${FD}" ]; then
      dckr_debug "${FD} is readable"
      PROK='t'
    else
      dckr_debug "${FD} is not readable"
    fi

    if [ -w "${FD}" ]; then
      dckr_debug "${FD} is writable"
      PWOK='t'
    else
      dckr_debug "${FD} is not writable"
    fi

    if [ "$PROK" = 't' ] && { [ "$BIT" = 'r' ] || [ "$PWOK" = 't' ]; }; then
      dckr_info "Permissions: Ok"
    else
      if [ "$BIT" = 'w' ]; then
        dckr_warn "Permissions: Failed [ Cannot write ${FD} ]"
      else
        dckr_warn "Permissions: Failed [ Cannot read ${FD} ]"
      fi
    fi
  fi
}

check_perms() {
  local PRNT
  local PATH_TYPE

  if [ ! -d "${1}" ]; then
    PATH_TYPE='file'
    PRNT="$(dirname "${1}")"
  else
    PATH_TYPE='dir'
  fi

  dckr_info '------------------------------------------------'
  dckr_info "Check permission of ${1}"

  if [ ! -e "${1}" ] && [ "${PATH_TYPE}" = 'file' ]; then
    dckr_info "${1} does not exist"
    dckr_info 'Testing parent directory permissions'
    output_perms "${PRNT}" 'w'
  else
    output_perms "${1}" "${2}"
  fi
  dckr_info '------------------------------------------------'
}

gen_inifile() {
  # shellcheck disable=SC2059
  touch "${ETEBASE_EASY_CONFIG_PATH}" 2>/dev/null || dckr_error "$(printf "${ERROR_PERM_TEMPLATE}" "${ETEBASE_EASY_CONFIG_PATH}" "${C_UID}" "${C_GID}")"

  echo "[global]
secret_file = ${SECRET_FILE}
debug = ${DEBUG_DJANGO}
static_root = ${STATIC_ROOT}
static_url = /static/
media_root = ${MEDIA_ROOT}
media_url =  /user-media/
language_code = ${LANGUAGE_CODE}
time_zone = ${TIME_ZONE}

[allowed_hosts]
allowed_host1 = ${ALLOWED_HOSTS}
" >"${ETEBASE_EASY_CONFIG_PATH}"

  if [ "${DB_ENGINE}" = "postgres" ]; then
    file_env 'DATABASE_USER' "${DATABASE_NAME}"
    file_env 'DATABASE_PASSWORD' "${DATABASE_USER}"

    echo "[database]
engine = django.db.backends.postgresql
name = ${DATABASE_NAME}
user = ${DATABASE_USER}
password = ${DATABASE_PASSWORD}
host = ${DATABASE_HOST:=database}
port = ${DATABASE_PORT:=5432}
" >>"${ETEBASE_EASY_CONFIG_PATH}"
  else
    echo "[database]
engine = django.db.backends.sqlite3
name = ${DATABASE_NAME}
" >>"${ETEBASE_EASY_CONFIG_PATH}"
  fi

  dckr_info "Generated ${ETEBASE_EASY_CONFIG_PATH}"
}

migrate() {
  local _AUTO=$1

  $MANAGE showmigrations -l | grep -v '\[X\]'

  if [ -n "${_AUTO}" ]; then
    $MANAGE migrate
  else
    dckr_warn "If necessary please run: docker exec -it ${HOSTNAME} python manage.py migrate"
  fi
}

create_superuser() {
  file_env 'SUPER_USER'

  if [ "${SUPER_USER}" ]; then
    dckr_info 'Creating Super User'
    file_env 'SUPER_PASS'

    if [ -z "$SUPER_PASS" ]; then
      SUPER_PASS=$(openssl rand -base64 24)
      dckr_info "
----------------------------------------------------
| Admin Password: ${SUPER_PASS} |
----------------------------------------------------"
    fi

    echo "from myauth.models import User; User.objects.create_superuser('${SUPER_USER}' , None, '${SUPER_PASS}')" | python manage.py shell
  fi
}

check_db() {

  $MANAGE migrate --plan 2>/tmp/db_error | grep 'django_etebase.0001_initial' >/dev/null
  local _PS=("${PIPESTATUS[@]}")

  if [ "${_PS[0]}" -eq "0" ] && [ "${_PS[1]}" -eq "0" ]; then
    migrate true
    create_superuser
  elif [ "${_PS[0]}" -eq "0" ] && [ "${_PS[1]}" -ne "0" ]; then
    migrate "${AUTO_UPDATE}"
  else
    # shellcheck disable=SC2059
    dckr_error "$(printf "${ERROR_DB_TEMPLATE}" "${DB_ENGINE}")$(echo && cat /tmp/db_error)"
  fi
}

init_env

check_perms "${ETEBASE_EASY_CONFIG_PATH}"

if [ -e "${ETEBASE_EASY_CONFIG_PATH}" ]; then
  check_perms "$(grep secret_file "${ETEBASE_EASY_CONFIG_PATH}" | sed -e 's/secret_file = //g')"
  check_perms "$(grep media_root "${ETEBASE_EASY_CONFIG_PATH}" | sed -e 's/media_root = //g')" 'w'
  if grep sqlite3 "${ETEBASE_EASY_CONFIG_PATH}" >/dev/null; then
    check_perms "$(grep name "${ETEBASE_EASY_CONFIG_PATH}" | sed -e 's/name = //g')" 'w'
  fi
fi

if [ ! -e "${ETEBASE_EASY_CONFIG_PATH}" ] || [ -n "${REGEN_INI}" ]; then
  gen_inifile
fi

check_db

if [ -w "$(grep static_root "${ETEBASE_EASY_CONFIG_PATH}" | sed -e 's/static_root = //g')" ]; then
  $MANAGE collectstatic --no-input
fi

if [ "${SERVER}" = 'https' ] && { [ ! -e "${X509_CRT}" ] || [ ! -e "${X509_KEY}" ]; }; then
  dckr_error "Certificate '${X509_CRT}' or key file '${X509_KEY}' missing"
fi

dckr_info 'Starting Etebase'

declare _CMD=""

case "${SERVER}" in
'asgi' | 'uvicorn' | 'http' | 'http-socket')
  _CMD="uvicorn etebase_server.asgi:application --host 0.0.0.0 --port ${PORT}"
  ;;
'uvicorn-https' | 'https')
  _CMD="uvicorn etebase_server.asgi:application --host 0.0.0.0 --port ${PORT} --ssl-keyfile ${X509_KEY} --ssl-certfile ${X509_CRT}"
  ;;
'daphne' | 'uwsgi' | 'django-server')
  dckr_error "Options no longer supported by Etebase! https://github.com/victor-rds/docker-etebase/issues/103"
  ;;
*)
  dckr_error "Server option not supported!"
  ;;
esac

if [ "${SHELL_DEBUG}" = "true" ]; then
  set +x
fi

exec $_CMD "$@"
