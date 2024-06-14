# ![docker-etebase](icon.svg) Etebase Server Docker Images

Docker image for **[Etebase](https://www.etebase.com) Server**, also known as **EteSync 2.0**, based on the [server](https://github.com/etesync/server) repository by [Tom Hacohen](https://github.com/tasn).

## Tags

The following tags are built on latest Python image and latest version of Etebase Server

- `latest` [(tags/latest/Dockerfile)](https://github.com/victor-rds/docker-etebase/blob/master/tags/base/Dockerfile)
- `slim`  [(tags/slim/Dockerfile)](https://github.com/victor-rds/docker-etebase/blob/master/tags/slim/Dockerfile)
- `alpine` [(tags/alpine/Dockerfile)](https://github.com/victor-rds/docker-etebase/blob/master/tags/alpine/Dockerfile) 

Release builds are available as versioned tags, for example: `X.Y.Z` or `X.Y.Z-type`

## Usage

```docker run  -d -e SUPER_USER=admin -p 80:3735 -v /path/on/host:/data victorrds/etesync```

Create a container running Etebase using http protocol.

You can find more examples, using `docker-compose` [here](examples/)

## Directory Structure and Data Persistence

All Etebase image variants share the same folder structure:

### /etebase

Contains the Etebase Server source code, please avoid any changes or mounting this folder.

### /data

By default this is the volume where all user data and server configuration are located

- `/data/etebase-server.ini`: Server configuration file, location can be changed using `ETEBASE_EASY_CONFIG_PATH` environment ;
- `/data/media`: The directory where user data is stored, although this location can be changed¹, it's not recommended;
- `/data/secret.txt`: File that contains the value for Django's SECRET_KEY, this location can be changed¹
- `/data/db.sqlite3`: Database file, if SQLite is chosen, this location can be changed¹

**¹** All the locations are set in the `etebase-server.ini` file, or on the first run startup using environment variables.

### /srv/etebase

Here you will find the static files needed to be shared with a reverse proxy, like _nginx_, when using `uwsgi` or `asgi` protocols, the `/entrypoint.sh` checks this files to update or recreate if not found.

### Users and Permissions

By default, the container runs with the user and group **etebase**, both using **373** as the numeric ID. If mounting any directory above to the host, instead of using Docker volumes, there are two options

1. The directories must have the correct permission, e.g.:

    ```console
    $ chown -vR 373:373 /host/data/path
    changed ownership of '/host/data/path' from user:group to 373:373
    $ docker run -v /host/data/path:/data victorrds/etebase
    ```

2. Change the user running the container:

    ```console
    $ stat -c '%u:%g' /host/data/path
    1000:1000
    $ docker run -u 1000:1000 -v /host/data/path:/data victorrds/etebase
    ```

## Settings and Customization

The available Etebase settings are set in the `/data/etebase-server.ini` file. If not found, the `/entrypoint.sh` will generate it based on the **Environment Variables** explained below.

### Environment Variables

- **SERVER**: Defines how the container will serve the application. Options are:
  - `uvicorn`: starts using [uvicorn](https://www.uvicorn.org/), an ASGI server implementation with HTTP/1.1 and WebSockets support. Runs without SSL and must be used with a reverse-proxy/web server, such as _nginx_, _traefik_, and others. Aliases: `http`, `http-socket` `asgi`;
  - `uvicorn-https`: same as above but with SSL/TLS support enabled. Certificates must be mounted in the container. Alias: `https`;
  - Older versions had support to `uwsgi`, `daphne` and `Django-server`, but these are no longer supported. See [#103](https://github.com/victor-rds/docker-etebase/issues/103);
- **DEBUG**: Verbose mode provides additional messages from the `/entrypoint.sh`. Does not change the output of the etebase server;
- **SHELL_DEBUG**: Runs the `/entrypoint.sh` with `set -x` for debug purposes;
- **AUTO_UPDATE**: Trigger database update/migration every time the container starts. Default: `false`, more details below;
- **SUPER_USER**: Username of the Django superuser (only used if no previous database is found);
  - **SUPER_PASS**: Password of the Django superuser (optional, one will be generated if not set);
  - **SUPER_EMAIL**: Email of the Django superuser (optional);

#### Related to the etebase-server.ini settings file

- **ETEBASE_EASY_CONFIG_PATH**: Set the configuration file location. Default: `/data/etebase-server.ini`;
- **MEDIA_ROOT**²: The path where user data is stored. [:warning:](https://github.com/etesync/server#data-locations-and-backups) Default: `/data/media`;
- **DB_ENGINE**: Database engine, currently only accepts `sqlite` (default) and `postgres`;
- **ALLOWED_HOSTS**²: The `ALLOWED_HOSTS` setting must be a comma-separated list of valid domains and/or IP addresses. The server uses this list to set Django's [CSRF_TRUSTED_ORIGINS](https://docs.djangoproject.com/en/4.2/ref/settings/#csrf-trusted-origins) setting. This list must contain the domain name used to access the server. For more details, see [etesync/server#183](https://github.com/etesync/server#183). Default: `localhost,127.0.0.1,[::1]`;
- **SECRET_FILE**²: Defines file that contains the value for Django's SECRET_KEY. If not found, a new one is generated. Default: `/data/secret.txt`;
- **AUTO_SIGNUP**: Enables automatic signup. Default: `false`;
- **LANGUAGE_CODE**: Django language code. Default: `en-us`;
- **TIME_ZONE**: Time zone, defaults to `UTC`. Must be a valid `tz database name`. Valid names can be found at <https://en.wikipedia.org/wiki/List_of_tz_database_time_zones>;
- **DEBUG_DJANGO**²: Enables Django Debug mode, not recommended for production. Defaults to `false`;
- **REDIS_URI**: Sets Redis URI (optional).

**²** For more details, please refer to the [Etebase Server README.md](https://github.com/etesync/server#configuration)

If **DB_ENGINE** is set to **`sqlite`**:

- **DATABASE_NAME**: Database file path. Defaults to `/data/db.sqlite3`

If **DB_ENGINE** is set to **`postgres`** the following variables can be used (only default values are listed):

- **DATABASE_NAME**: `etebase`;
- **DATABASE_USER**: Defaults to the value of `DATABASE_NAME` if not set;
- **DATABASE_PASSWORD**: Defaults to the value of `DATABASE_USER` if not set;
- **DATABASE_HOST**: `database`
- **DATABASE_PORT**: `5432`

For LDAP integration, use the following variables. This is advanced usage; please refer to the [etesync/server@fac36aa](https://github.com/etesync/server/commit/fac36aae1186201fdc5ae4874065a3528626ef68) commit for details:

- **LDAP_SERVER**: The URL to the LDAP server;
- **LDAP_BINDDN**: LDAP "user" to bind as. Must be a bind user;
- **LDAP_BIND_PW**: The password to authenticate as your bind user;
- **LDAP_FILTER**: LDAP filter query ('%%s' will be substituted for the username);
- **LDAP_SEARCH_BASE**: Search base;
- **LDAP_CACHE_TTL**: Cache TTL in hours. If a cache TTL of 1 hour is too short for you, set `cache_ttl` to the preferred amount of hours a cache entry should be viewed as valid (optional);

### Docker Secrets

As an alternative to passing sensitive information via environment variables, _FILE may be appended to some of the previously listed environment variables, causing the initialization script to load the values for those variables from files present in the container. In particular, this can be used to load passwords from Docker secrets stored in /run/secrets/<secret_name> files. For example:

```bash
docker run -d --name etebase \
 -e DB_ENGINE=postgres \
 -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres-passwd \
 victorrds/etebase
```

Currently, this is only supported for DB_ENGINE, DATABASE_NAME, DATABASE_USER, DATABASE_PASSWORD, SUPER_USER, and SUPER_PASS.

## Ports

This image exposes the **3735/TCP** port.

## Questions & Issues

For questions, please use [Discussions](https://github.com/victor-rds/docker-etebase/discussions).
Any bugs, please report to the repository [Issue Tracker](https://github.com/victor-rds/docker-etebase/issues).

## How to Build

To build the images, choose a Dockerfile and run:

```bash
docker build -f tags/alpine/Dockerfile -t etebase:alpine .
```

This will create an image using the Etebase master branch. To build using a release version, set the `ETE_VERSION` build argument:

```bash
docker build --build-arg ETE_VERSION=v0.5.3 -f tags/base/Dockerfile -t etebase:dev .
```

## Advanced Usage

### How to create a Superuser

#### Method 1: Environment Variables on first run

Setting the `SUPER_` variables on the first run will trigger the creation of a superuser after the database is ready.

#### Method 2: Python Shell

At any moment after the database is ready, you can create a new superuser by running and following the prompts:

```bash
docker exec -it {container_name} python manage.py createsuperuser
```

### Upgrade application and database

If `AUTO_UPDATE` is not set, you can update by running:

```bash
docker exec -it {container_name} python manage.py migrate
```

### _Using Uvicorn with SSL/TLS_

To run Etebase Server with uvicorn using HTTPS, you need to mount valid certificates.

By default, Etebase will look for the files `/certs/crt.pem` and `/certs/key.pem`. If you change this location, update the **X509_CRT** and **X509_KEY** environment variables accordingly.

## **:bangbang:** Troubleshooting: CSRF Verification Failed

The Etebase server upgraded its Django version to 4.2+, and now a valid value for the [CSRF_TRUSTED_ORIGINS](https://docs.djangoproject.com/en/4.2/ref/settings/#csrf-trusted-origins) setting must be provided. To resolve this issue, add the domain names and/or IP addresses of the server to the `[allowed_hosts]` section of the `etebase-server.ini` file.

If you are setting up a new installation and do not have an ini file yet, use the `ALLOWED_HOSTS` environment variable to generate the correct ini file.

Example:

```ini
[allowed_hosts]
allowed_host1 = example.com
allowed_host2 = api.example.com
allowed_host3 = 10.0.0.1
; wildcard are also valid, but * alone will not work
allowed_host4 = *.etebase.example.com
```

For more details see this PR: [etesync/server#183](https://github.com/etesync/server#183).

## **:bangbang:** Deprecation Notice: arm/v7 Images

As of version 0.14.0, I have deprecated the support for `arm/v7` Docker images for the Etebase Server. This means that new versions and updates will no longer be provided for the `arm/v7` architecture.

Many dependencies required by the Etebase Server have become increasingly difficult or impossible to build on the `arm/v7` architecture using the default base Python images.

## **:bangbang: Warning** Incompatible Versions

**Etesync 1.0 and Etebase (Etesync 2.0), database and server, are incompatible**. Given the end-to-end encryption nature and structural changes of this software, it is impossible to migrate the data without knowing the users' keys.

To move the data, you must create a new instance with a new database. While running both servers simultaneously, use the web client tool or mobile applications to migrate your data. After all users have migrated, the legacy server can be shut down.

The new images have breaking changes. To avoid any damage, the `entrypoint.sh` will check if the database is compatible before making any changes.

Etesync 1.0 images are available through the `legacy` tags. Base images are outdated and no more work will be done.

- `legacy` [(legacy:tags/latest/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/legacy/tags/base/Dockerfile)
- `legacy-slim`  [(legacy:tags/slim/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/legacy/tags/slim/Dockerfile)
- `legacy-alpine` [(legacy:tags/alpine/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/legacy/tags/alpine/Dockerfile)
