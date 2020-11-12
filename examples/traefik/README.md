# Etebase + Traefik Docker Example

This is an example using traefik as reverse proxy for the etebase server.

## Usage
Just run:

```console
docker-compose up
```

When ready, access: [http://etebase.localhost/admin]

## Advanced Security Example
Same as above, but using HTTPS and permanent HTTP redirect. The commented sections show options for using the Let's Encrypt HTTP-01 challenge

```console
docker-compose -f docker-compose.yml -f docker-compose.ssl.yml up
```
