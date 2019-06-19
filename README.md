# ETESync Sever Docker Images

Docker image for [ETESync](https://www.etesync.com/) based on the [server-skeleton](https://github.com/etesync/server-skeleton) repository by [Tom Hacohen](https://github.com/tasn).

## Tags

This build follows some tags of the Python official docker images:

- `latest` [(stable:tags/latest/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/stable/tags/latest/Dockerfile)
- `edge` [(master:tags/latest/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/master/tags/latest/Dockerfile)
- `slim`  [(stable:tags/slim/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/stable/tags/slim/Dockerfile)
- `alpine` [(stable:tags/debian/Dockerfile)](https://github.com/victor-rds/docker-etesync-server/blob/stable/tags/alpine/Dockerfile)

## Usage

```docker run  -d -e SUPER_USER=admin -e SUPER_PASS=changeme -p 80:3735 -v /path/on/host:/data victorrds/etesync```

Create a container running ETESync usiong http protocol.

## Volumes

`/data`: database file location

## Ports

This image exposes the **3735** TCP Port

## Environment Variables

- **SERVER**: Defines how the container will serve the application, the options are:
  - `http` Runs using HTTP protocol, this is the default mode.
  - `https` same as above but with TLS/SSL support, see below how to use with your own certificates.
  - `uwsgi` start using uWSGI native protocol, for reverse-proxies/load balances, such as _nginx_, that support this protocol
  - `http-socket` Similar to the first option, but without uWSGI HTTP router/proxy/load-balancer, this recommended for any reverse-proxies/load balances, that support HTTP protocol, like _traefik_
  - `django-server` this mode uses the embedded django http server, `./manage.py runserver :3735`, this is not recommeded but can be useful for debugging
- **SUPER_USER** and **SUPER_PASS**: Username and password of the django superuser (only used if no previous database is found, both must be used together);
- **SUPER_EMAIL**: Email of the django superuser (optional, only used if no database is found);
- **PUID** and **PGID**: set user and group when running using uwsgi, default: `1000`;
- **ETESYNC_DB_PATH**: Location of the ETESync SQLite database. default: `/data` volume;

## Settings and Customization

Custom settings can be added to `/etesync/etesync_site_settings.py`, this file overrides the default `settings.py`, mostly for _Django: The Web framework_ options, this image uses the variables below to set some of these options.

### _Environment Variables on `/etesync/etesync_site_settings.py`_

- **ALLOWED_HOSTS**:  the ALLOWED_HOSTS settings, must be valid domains separated by `,`. default: `*` (not recommended for production);
- **DEBUG**: enables Django Debug mode, not recommended for production defaults to False;
- **LANGUAGE_CODE**: Django language code, default: `en-us`;
- **SECRET_FILE**: Defines file that contains the value for django's `SECRET_KEY` if not found a new one is generated. default: `/etesync/secret.txt`.
- **USE_TZ**: Force Django to use time-zone-aware datetime objects internally, defaults to `false`;
- **TIME_ZONE**: time zone, defaults to `UTC`;

### _Using uWSGI with HTTPS_

If you want to run ETESync Server HTTPS using uWSGI you need to pass certificates or the image will generate a self-sign certificate for `localhost`.

By default ETESync will look for the files `/certs/crt.pem` and `/certs/key.pem`, if for some reason you change this location change the **X509_CRT** and **X509_KEY** environment variables

### _Serving Static Files_

When behind a reverse-proxy/http server compatible `uwsgi` protocol the static files are located at `/var/www/etesync/static`, files will be copied if missing on start.