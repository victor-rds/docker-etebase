<p align="center">
  <img width="120" src="https://raw.githubusercontent.com/etesync/server/master/icon.svg" />
</p>

# Etebase Sever Docker Images
![Debian Images](https://github.com/victor-rds/docker-etesync-server/workflows/Debian%20Images/badge.svg)
![Debian Slim Images](https://github.com/victor-rds/docker-etesync-server/workflows/Debian%20Slim%20Images/badge.svg)
![Alpine Images](https://github.com/victor-rds/docker-etesync-server/workflows/Alpine%20Images/badge.svg)

Docker image for **[Etebase](https://www.etebase.com) Server**, also known as **Etesync 2.0**, based on the [server](https://github.com/etesync/server) repository by [Tom Hacohen](https://github.com/tasn).

## **:bangbang: Warning** Incompatible Versions

**Etesync 1.0 and Etebase (Etesync 2.0) database and server are incompatible**, given the end-to-end encryption nature and strucutural changes of this software is impossible to migrate the data withou knowing the users keys.

To move the data, one you must create a new instance with a new database, while runing both servers at the same time, use the web client tool or mobile applications to migrate your data, after all users migrated the legacy server can be shutdown.

The new images have breaking changes, to avoid any damage, the entrypoint will check if the database is compatible before making any changes.

## Tags

The following tags are built on latest python image and master branch of EteSync Server 

- `latest` [(tags/latest/Dockerfile)](tags/base/Dockerfile)
- `slim`  [(tags/slim/Dockerfile)](tags/slim/Dockerfile)
- `alpine` [(tags/alpine/Dockerfile)](tags/alpine/Dockerfile)

Release builds are available as versioned tags, for example: `X.Y.Z` or `X.Y.Z-type`

Etesync 1.0 are avaible through the `legacy` tags, I will try to keep python base image up to date but no more work will be done.

- `legacy` [(legacy:tags/latest/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/legacy/tags/base/Dockerfile)
- `legacy-slim`  [(legacy:tags/slim/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/legacy/tags/slim/Dockerfile)
- `legacy-alpine` [(legacy:tags/alpine/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/legacy/tags/alpine/Dockerfile)

## Usage

```docker run  -d -e SUPER_USER=admin -p 80:3735 -v /path/on/host:/data victorrds/etesync```

Create a container running EteSync using http protocol.

You can find more examples, using `docker-compose` [here](examples/)

## Settings and Customization

The avaible Etebase settings are set in the `/data/etebase-server.ini` file, if not found, the `/entrypoint.sh` will generate based on the **Environment Variables** explained below.

## Data persistence

The `/data` directory contains the settings file `etebase-server.ini` and, if the default sqlite is used, the database file `db.sqlite3`

Another one that can be usefull is the `/etebase/static`, there you will find the static files needed to be shared with a reverse proxy, like _nginx_, when usgin `uwsgi` ou `asgi` protocols, the `/entrypoint.sh` checks this files to update or recreate if not found.

### Environment Variables

- **SERVER**: Defines how the container will serve the application, the options are:
  - `http` protocol, this is the default mode;
  - `https` same as above but with TLS/SSL support, see below how to use your own certificates;
  - `http-socket` Similar to the first option, but without uWSGI HTTP router/proxy/load-balancer overhead, this recommended for any reverse-proxies/load balancers that support HTTP protocol, like _traefik_;
  - `uwsgi` binary native protocol, must be used with a reverse-proxy/web server that support this protocol, such as _nginx_.
  - `asgi` or `daphne` start using [daphne](https://github.com/django/daphne/) a HTTP, HTTP2 and WebSocket protocol server for ASGI and ASGI-HTTP, must be used with a reverse-proxy/web server that support this protocol, such as _nginx_.
  - `django-server` same as the first one, but this mode uses the embedded django http server, `./manage.py runserver :3735`, this is not recommeded but can be useful for debugging
- **AUTO_UPATE**: Trigger database update/migration every time the container starts, default: `false `, more details below.
- **SUPER_USER**: Username of the django superuser (only used if no previous database is found);
  - **SUPER_PASS**: Password of the django superuser (optional, one will be generated if not set);
  - **SUPER_EMAIL**: Email of the django superuser (optional);

#### Related to the etebase-server.ini settings file

- **DB_ENGINE**: Database engine currently only accepts `sqlite` (default) and `postgres`;
- **ALLOWED_HOSTS**: the ALLOWED_HOSTS settings, must be a valid domain or `*`. default: * (not recommended for production);
- **SECRET_FILE**: Defines file that contains the value for django's SECRET_KEY, if not found a new one is generated. default: `/etesync/secret.txt`.
- **LANGUAGE_CODE**: Django language code, default: en-us;
- **TIME_ZONE**: time zone, defaults to UTC;
- **DEBUG**: enables Django Debug mode, not recommended for production defaults to False

If **DB_ENGINE** is set to **sqlite**

- **DATABASE_NAME**: database file path, defaults to `/data/db.sqlite3`

If **DB_ENGINE** is set to **postgres** the following variables can be used, (only default values are listed):

- **DATABASE_NAME**: `etebase`;
- **DATABASE_USER**: Follows the `DATABASE_NAME` if not set;
- **DATABASE_PASSWORD** Follows the `DATABASE_USER` if not set;
- **DATABASE_HOST**: `database`
- **DATABASE_PORT**: `5432`

### Docker Secrets

As an alternative to passing sensitive information via environment variables, _FILE may be appended to some of the previously listed environment variables, causing the initialization script to load the values for those variables from files present in the container. In particular, this can be used to load passwords from Docker secrets stored in /run/secrets/<secret_name> files. For example:

```
$ docker run --name etebase -e DB_ENGINE=postgres -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres-passwd -d victorrds/etesync
```

Currently, this is only supported for DB_ENGINE, DATABASE_NAME, DATABASE_USER, DATABASE_PASSWORD, SUPER_USER and SUPER_PASS.

## Ports

This image exposes the **3735** TCP Port

### How to create a Superuser

**Method 1 Environment Variables on first run.**

Setting the `SUPER_` variables on the first run will trigger the creation of a superuser after the database is ready.

**Method 2 Python Shell**

At any moment after the database is ready, you can create a new superuser by running and following the prompts:

```docker exec -it {container_name} python manage.py createsuperuser```

### Upgrade application and database

If `AUTO_UPATE` is not set you can update by running:

```docker exec -it {container_name} python manage.py migrate```

### _Using uWSGI with HTTPS_

If you want to run EteSync Server HTTPS using uWSGI you need to pass certificates or the image will generate a self-signed certificate for `localhost`.

By default EteSync will look for the files `/certs/crt.pem` and `/certs/key.pem`, if for some reason you change this location change the **X509_CRT** and **X509_KEY** environment variables