# Etebase + Traefik Docker Example

This is an example that uses Traefik as reverse proxy for the Etebase server.

## Usage without HTTPS

_Note: The EteSync web client will refuse to connect to non-HTTPS Etebase servers._

Just run:

```console
docker-compose up -d
```

When ready, access: [http://etebase.localhost/admin](http://etebase.localhost/admin)

## Usage with HTTPS
Make sure to edit `docker-compose.ssl.yml` and change `etebase.localhost` to your actual public hostname.

There are three different ways to use HTTPS with Traefik:

- Generate certificates with Let's Encrypt (**Recommended**)

  Uncomment all of the commented lines in `docker-compose.ssl.yml` and change `postmaster@mydomain.com` to your email.

  If you want to generate test certificates, add the following line at the end of the `command:` section:
  ```yml
  - "--certificatesresolvers.le.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
  ```
  
- Use your own SSL certificates

  If you already have SSL certificates that you want to use with Traefik, instructions can be found [here](https://doc.traefik.io/traefik/https/tls/#user-defined).

- Use Traefik's automatically generated certificates (**Not recommended**)

  By default Traefik will generate SSL certificates however browsers and other applications may fail to connect as these certificates are untrusted by defaut.

Once you're finished changing the configuration, just run:

```console
docker-compose -f docker-compose.yml -f docker-compose.ssl.yml up -d
```

When ready, access: `https://etebase.yourdomain/admin`
