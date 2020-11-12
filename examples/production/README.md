# Etebase Docker Production Setup Example

This is an example is based on the [Production setup using Daphne and Nginx](https://github.com/etesync/server/wiki/Production-setup-using-Daphne-and-Nginx) from the official Etebase source repository.

There 3 sevices in this example:

* Etebase Server
* PosgreSQL database
* Nginx Web Server

## Warning
As an example, this should not be used in real production without changes, this script will initialize a PostgreSQL DB with unsafe options, all the data is saved on docker volumes created by the compose file, be aware this is may not work in your particular setup.

## Usage
The `.env` file contains the variables used on `docker-compose.yml`, you can edit if you want, then run:

```console
docker-compose up
```

When ready, access:  [http://localhost:8080/admin](http://localhost:8080/admin)

## Advanced Security Example
This one will also run a 4th service a `governmentpaas/curl-ssl` container to create cerficates and download a dhparam from mozilla (*do not generate certificates this way in a production envirioment!*),  to test this just run:

```console
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

When ready, access:  [https://localhost/admin](https://localhost/admin)