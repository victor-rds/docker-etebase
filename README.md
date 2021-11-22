# ![docker-etebase](icon.svg) Etebase Server Docker Images

Docker image for **[Etebase](https://www.etebase.com) Server**, also known as **Etesync 2.0**, based on the [server](https://github.com/etesync/server) repository by [Tom Hacohen](https://github.com/tasn).

## **:bangbang: Warning** Incompatible Versions

**Etesync 1.0 and Etebase (Etesync 2.0) database and server are incompatible**, given the end-to-end encryption nature and structural changes of this software is impossible to migrate the data without knowing the users keys.

To move the data, one you must create a new instance with a new database, while running both servers at the same time, use the web client tool or mobile applications to migrate your data, after all users migrated the legacy server can be shutdown.

The new images have breaking changes, to avoid any damage, the `entrypoint.sh` will check if the database is compatible before making any changes.

## Tags

The following tags are built on latest python image and latest version of Etebase Server

- `latest` [(tags/latest/Dockerfile)](tags/base/Dockerfile)
- `slim`  [(tags/slim/Dockerfile)](tags/slim/Dockerfile)
- `alpine` [(tags/alpine/Dockerfile)](tags/alpine/Dockerfile)

Release builds are available as versioned tags, for example: `X.Y.Z` or `X.Y.Z-type`

Etesync 1.0 images are available through the `legacy` tags, I will try to keep python base image up to date but no more work will be done.

- `legacy` [(legacy:tags/latest/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/legacy/tags/base/Dockerfile)
- `legacy-slim`  [(legacy:tags/slim/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/legacy/tags/slim/Dockerfile)
- `legacy-alpine` [(legacy:tags/alpine/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/legacy/tags/alpine/Dockerfile)

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

- `/data/etebase-server.ini` server configuration file, location can be changed using `ETEBASE_EASY_CONFIG_PATH` environment ;
- `/data/media` the directory where user data is stored, although this location can be changed¹, it's not recommended;
- `/data/secret.txt` file that contains the value for Django's SECRET_KEY, this location can be changed¹
- `/data/db.sqlite3` database file, if SQLite is chosen, this location can be changed¹

**¹** All the locations are set in the `etebase-server.ini` file, or on the first run startup using environment variables.

### /srv/etebase

Here you will find the static files needed to be shared with a reverse proxy, like _nginx_, when using `uwsgi` or `asgi` protocols, the `/entrypoint.sh` checks this files to update or recreate if not found.

### Users and Permissions

By default the container runs with the user and group **etebase**, both using **373** as numeric ID, if mounting any directory above to the host, instead of using docker volumes, there are two options

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

The available Etebase settings are set in the `/data/etebase-server.ini` file, if not found, the `/entrypoint.sh` will generate based on the **Environment Variables** explained below.

### Environment Variables

- **SERVER**: Defines how the container will serve the application, the options are:
  - `uvicorn` start using [uvicorn](https://www.uvicorn.org/) a ASGI server implementation with HTTP/1.1 and WebSockets support, this runs without SSL and must be used with a reverse-proxy/web server, such as _nginx_, _traefik_ and others.
  Aliases: `http`, `http-socket` `asgi`
  - `uvicorn-https` same as above but with SSL/TLS support enabled, certificates must be mounted in the container, see: . Alias: `https`
  - Older versions had support to `uwsgi`, `daphne` and `Django-server`, but that's no longer supported see [#103](https://github.com/victor-rds/docker-etebase/issues/103)

- **DEBUG**: Runs the `/entrypoint.sh` with `set -x` for debug purposes, this variable does not change **DEBUG_DJANGO** described below.
- **AUTO_UPDATE**: Trigger database update/migration every time the container starts, default: `false`, more details below.
- **SUPER_USER**: Username of the Django superuser (only used if no previous database is found);
  - **SUPER_PASS**: Password of the Django superuser (optional, one will be generated if not set);
  - **SUPER_EMAIL**: Email of the Django superuser (optional);

#### Related to the etebase-server.ini settings file

- **ETEBASE_EASY_CONFIG_PATH** set the configuration file location, default: `/data/etebase-server.ini`
- **MEDIA_ROOT**²: the path where user data is stored [:warning:](https://github.com/etesync/server#data-locations-and-backups), default: `/data/media`
- **DB_ENGINE**: Database engine currently only accepts `sqlite` (default) and `postgres`;
- **ALLOWED_HOSTS**²: the ALLOWED_HOSTS settings, must be a valid domain or `*`. default: * (not recommended for production);
- **SECRET_FILE**²: Defines file that contains the value for Django's SECRET_KEY, if not found a new one is generated. default: `/data/secret.txt`.
- **LANGUAGE_CODE**: Django language code, default: `en-us`;
- **TIME_ZONE**: time zone, defaults to `UTC`;
- **DEBUG_DJANGO**²: enables Django Debug mode, not recommended for production defaults to `false`

**²** for more details please take look at the [Etebase Server README.md](https://github.com/etesync/server#configuration)

If **DB_ENGINE** is set to **`sqlite`**

- **DATABASE_NAME**: database file path, defaults to `/data/db.sqlite3`

If **DB_ENGINE** is set to **`postgres`** the following variables can be used, (only default values are listed):

- **DATABASE_NAME**: `etebase`;
- **DATABASE_USER**: Follows the `DATABASE_NAME` if not set;
- **DATABASE_PASSWORD** Follows the `DATABASE_USER` if not set;
- **DATABASE_HOST**: `database`
- **DATABASE_PORT**: `5432`

### Docker Secrets

As an alternative to passing sensitive information via environment variables, _FILE may be appended to some of the previously listed environment variables, causing the initialization script to load the values for those variables from files present in the container. In particular, this can be used to load passwords from Docker secrets stored in /run/secrets/<secret_name> files. For example:

```console
docker run -d --name etebase \
 -e DB_ENGINE=postgres \
 -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres-passwd \
 victorrds/etebase
```

Currently, this is only supported for DB_ENGINE, DATABASE_NAME, DATABASE_USER, DATABASE_PASSWORD, SUPER_USER and SUPER_PASS.

## Ports

This image exposes the **3735/TCP** Port

## How to Build

To build the images just choose which Dockerfile and run:

```console
docker build -f tags/alpine/Dockerfile -t etebase:alpine .
```

This will create a image using Etebase master branch, to build using a release version just set the `ETE_VERSION` build argument:

```console
docker build --build-arg ETE_VERSION=v0.5.3 -f tags/base/Dockerfile -t etebase:dev .
```

## Advanced Usage

### How to create a Superuser

#### Method 1 Environment Variables on first run

Setting the `SUPER_` variables on the first run will trigger the creation of a superuser after the database is ready.

#### Method 2 Python Shell

At any moment after the database is ready, you can create a new superuser by running and following the prompts:

```docker exec -it {container_name} python manage.py createsuperuser```

### Upgrade application and database

If `AUTO_UPDATE` is not set you can update by running:

```docker exec -it {container_name} python manage.py migrate```

### _Using Uvicorn with SSL/TLS_

If you want to run Etebase Server HTTPS using uvicorn you need to mount valid certificates.

By default Etebase will look for the files `/certs/crt.pem` and `/certs/key.pem`, if for some reason you change this location change the **X509_CRT** and **X509_KEY** environment variables.
