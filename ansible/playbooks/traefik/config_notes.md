# Traefik Configuration Notes

Some notes capturing the working state of `traefik` in a `LXD` environment.

## Issues

1. TCP Router TLS Passthrough

    Had an incredibly annoying issue that was hard to track as it would only occur in a particular case, and that case was hard to identify.

    **TL;DR** - non-unique TCP router name in `gitlab.yml` & `nginx.yml` config files

    **Issue** - getting 404 error when being re-directed to HTTPS nginx page

    **Problem determination** - after comparing a working gitlab service config file with this nginx config, I couldn't identify where the issue was as the configuration was syntactically & technically the same. What added to the problem is that I have, on occasion, had the nginx service working over TLS. Eventually found out that this issue was only happening when the gitlab service was already active. Started tailing the log while updating the dynamic nginx config file and noticed an entry about name already exists. This was also highlighted in the dashboard by the lack of TCP router for nginx. It was at this point that I realised that I had a non-unique name for the TCP router across the two config files.

    **Solution** - renaming the TCP routers with unique names in the config files allowed both routers to materialise, fixing the lack of nginx HTTPS service

## Configuration

```
+------------------+---------+--------------+----------------------+----------------------+-----------+
|       NAME       |  STATE  | ARCHITECTURE |      CREATED AT      |       PROFILES       |   TYPE    |
+------------------+---------+--------------+----------------------+----------------------+-----------+
| gitlab-server-01 | RUNNING | x86_64       | 2022/08/12 10:00 UTC | default              | CONTAINER |
|                  |         |              |                      | gitlab_server_config |           |
+------------------+---------+--------------+----------------------+----------------------+-----------+
| hugo             | RUNNING | x86_64       | 2022/09/26 13:50 UTC | default              | CONTAINER |
+------------------+---------+--------------+----------------------+----------------------+-----------+
| proxy            | RUNNING | x86_64       | 2022/08/22 10:55 UTC | default              | CONTAINER |
+------------------+---------+--------------+----------------------+----------------------+-----------+
```

## Background

Downloaded and installed `traefik` to the `proxy` LXC instance using the following configuration files. These will later be created via Ansible templates. We are using traefik's file-based configuration option here.

## Directory structure

```
/etc/proxy
├── certs
├── conf.d
│   ├── dashboard.yml
│   ├── gitlab.yml
│   └── hugo.yml
├── data
│   └── acme.json
├── log
│   └── traefik.log
└── traefik.yml
```

### `traefik.yml`
```yaml
---
log:
  level: DEBUG
  filepath: "/etc/proxy/log/traefik.log"
api:
  dashboard: true
  insecure: false
  debug: true
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"
certificatesResolvers:
  tls-resolver:
    acme:
      email: <user@email.com>
      storage: /etc/proxy/data/acme.json
      tlsChallenge: {}
  # TODO: Not entirely sure this http-resolver is needed. It's not referenced in my
  # configurations and there are no http-resolver certs in data/acme.json
  # Hopefully it can be removed as it currently causes manually-created LetsEncrypt
  # certificates to fail on initial requests. Further testing to be done.
  # Initial testing:
  # 1. Created an nginx webserver instance and created certs on that instance using certbot without issues - the acme challenge worked
  # 2. Crated an nginx webserver instance and allowed traefik to request the LetsEncrypt certs using tls-resolver - worked fine and populated acme.json
  # Looks like this section is unnecessary for any of the scenarios I use
  # http-resolver:
  #   acme:
  #     email: <user@email.com>
  #     storage: /etc/proxy/data/acme.json
  #     httpChallenge:
  #       # Used during the ACME challenge
  #       entryPoint: web
providers:
  file:
    directory: /etc/proxy/conf.d
    watch: true
```

### `dashboard.yml`
```yaml
---
http:
  routers:
    dashboard-redirect:
      entrypoints:
        - "web"
      rule: "Host(`traefik.example.com`) && (PathPrefix(`/api`, `/dashboard`))"
      middlewares:
        - "dashboard-redirect"
      service: api@internal
    dashboard:
      entryPoints:
        - "websecure"
      rule: "Host(`traefik.example.com`) && (PathPrefix(`/api`, `/dashboard`))"
      middlewares:
        - "auth"
      service: api@internal
      tls:
        certResolver: tls-resolver
  middlewares:
    dashboard-redirect:
      redirectScheme:
        scheme: https
    auth:
      basicAuth:
        users:
          # Password generated using `htpasswd -bn admin p4ssw0rd`
          - "admin:$apr1$j9sByWPM$r6wEqGjKTOt59jg1ptv1A."
```

### `gitlab.yml`
```yaml
---
# Using tcp router with TLS passthrough as gitlab service is already secured with letsencrypt
tcp:
  routers:
    router_gitlab_tcp:
      entryPoints:
        - "websecure"
      rule: "HostSNI(`gitlab.example.com`)"
      service: gitlab_secure
      tls:
        passthrough: true

  services:
    gitlab_secure:
      loadBalancer:
        servers:
          - address: 'gitlab-server-01.lxd:443'

http:
  routers:
    gitlab:
      entrypoints:
        - "web"
      rule: "Host(`gitlab.example.com`)"
      service: gitlab

    # Allows gitlab to renew letsencrypt certificate
    gitlab_acme_challenge:
      entrypoints:
        - "web"
      rule: "Host(`gitlab.example.com`) && PathPrefix(`/.well-known/acme-challenge/`) && Method(`GET`)"
      service: gitlab

  services:
    gitlab:
      loadBalancer:
        servers:
          - url: 'http://gitlab-server-01.lxd:80'
```

### `hugo.yml`
```yaml
---
http:
  # Use http router as testing with `hugo server --bind 0.0.0.0 -` only runs HTTP
  routers:
    hugo-redirect:
      entrypoints:
        - "web"
      rule: "Host(`hugo.example.com`)"
      service: hugo_web

  services:
    hugo_web:
      loadBalancer:
        servers:
          - url: 'http://hugo.lxd:1313'
```

### `nginx.yml` (using TLS certificate creation on webserver endpoints)
```yaml
---
tcp:
  routers:
    router_nginx_tcp:
      entryPoints:
        - "websecure"
      rule: "HostSNI(`nginx.example.com`)"
      service: nginx_secure
      tls:
        passthrough: true

  services:
    nginx_secure:
      loadBalancer:
        servers:
          - address: 'nginx.lxd:443'

http:
  routers:
    nginx:
      entrypoints:
        - "web"
      rule: "Host(`nginx.example.com`)"
      service: nginx

    nginx_acme_challenge:
      entrypoints:
        - "web"
      rule: "Host(`nginx.example.com`) && PathPrefix(`/.well-known/acme-challenge/`) && Method(`GET`)"
      service: nginx

  services:
    nginx:
      loadBalancer:
        servers:
          - url: 'http://nginx.lxd:80'
```

### `nginx.yml` (using TLS termination at traefik)
```yaml
---
http:
  routers:
    nginx-redirect:
      entrypoints:
        - "web"
      rule: "Host(`nginx.example.com`)"
      middlewares:
        - "nginx-redirect"
      service: nginx

    nginx-secure:
      entrypoints:
        - "websecure"
      rule: "Host(`nginx.example.com`)"
      service: nginx
      tls:
        certResolver: tls-resolver

  middlewares:
    nginx-redirect:
      redirectScheme:
        scheme: https

  services:
    nginx:
      loadBalancer:
        servers:
          - url: 'http://nginx.lxd:80'
          - url: 'http://nginx3.lxd:80'
```

### `nginx-tls` (using TLS termination at traefik and self-signed certs on backend webservers with mutual TLS)
#### **Pre-reqs**
Final method taken from bits and pieces of these pages:
* [Creating self-signed certs for nginx](https://www.digitalocean.com/community/tutorials/how-to-create-a-self-signed-ssl-certificate-for-nginx-in-ubuntu-16-04)
* [Traefik with self-signed internal hosts](https://community.traefik.io/t/internal-server-error-when-proxing-to-https-with-self-signed-cert/11087/4)
* [Traefik serversTransport per service](https://doc.traefik.io/traefik/routing/services/#certificates)
* [Traefik serversTransports](https://doc.traefik.io/traefik/routing/overview/)
* [See Mohammad Ravanbakhsh's answer on this page](https://stackoverflow.com/questions/64814173/how-do-i-use-sans-with-openssl-instead-of-common-name)
* [An mTLS implementation example](https://egkatzioura.com/2021/10/01/add-mtls-to-nginx/)

#### **Method**
Create all the necessary certificate files on the traefik server
1. Create CA key & crt files
    ```bash
    openssl genrsa -out /etc/proxy/certs/traefik_ca.key 2048
    openssl req -new -x509 -days 3650 -key /etc/proxy/certs/traefik_ca.key -subj "/C=GB/ST=England/L=Birmingham/O=ITC/CN=Traefik Root CA" -out /etc/proxy/certs/traefik_ca.crt
    ```

1. Create each server csr, key & crt files
    1. **Server**: nginx-tls
        ```bash
        openssl req -newkey rsa:2048 -nodes -keyout /etc/proxy/certs/nginx-tls.key -subj "/C=GB/ST=England/L=Birmingham/O=ITC/CN=nginx-tls.lxd" -out /etc/proxy/certs/nginx-tls.csr
        openssl x509 -req -extfile <(printf "subjectAltName=DNS:nginx-tls.lxd") -days 3650 -in /etc/proxy/certs/nginx-tls.csr -CA /etc/proxy/certs/traefik_ca.crt -CAkey /etc/proxy/certs/traefik_ca.key -CAcreateserial -out /etc/proxy/certs/nginx-tls.crt
        ```
    1. **Server**: nginx2-tls
        ```bash
        openssl req -newkey rsa:2048 -nodes -keyout /etc/proxy/certs/nginx2-tls.key -subj "/C=GB/ST=England/L=Birmingham/O=ITC/CN=nginx2-tls.lxd" -out /etc/proxy/certs/nginx2-tls.csr
        openssl x509 -req -extfile <(printf "subjectAltName=DNS:nginx2-tls.lxd") -days 3650 -in /etc/proxy/certs/nginx2-tls.csr -CA /etc/proxy/certs/traefik_ca.crt -CAkey /etc/proxy/certs/traefik_ca.key -CAcreateserial -out /etc/proxy/certs/nginx2-tls.crt
        ```
    1. repeat...
1. **Optional mTLS** If you want to use mTLS, create the traefik client csr, key and crt files
    ```bash
    openssl req -newkey rsa:2048 -nodes -keyout /etc/proxy/certs/nginx-tls.key -subj "/C=GB/ST=England/L=Birmingham/O=ITC/CN=nginx-tls.lxd" -out /etc/proxy/certs/nginx-tls.csr
    openssl x509 -req -extfile <(printf "subjectAltName=DNS:traefik.lxd") -days 3650 -in /etc/proxy/certs/traefik.csr -CA /etc/proxy/certs/traefik_ca.crt -CAkey /etc/proxy/certs/traefik_ca.key -CAcreateserial -out /etc/proxy/certs/traefik.crt
    ```
1. Copy these server key & crt files to the webservers
    Source | Destination | Permissions
    -------|-------------|------------
    `traefik:/etc/proxy/certs/nginx-tls.crt`  | `nginx-tls:/etc/ssl/certs/nginx-selfsigned.crt` | 0644
    `traefik:/etc/proxy/certs/nginx-tls.key`  | `nginx-tls:/etc/ssl/private/nginx-selfsigned.key` | 0600
    `traefik:/etc/proxy/certs/traefik_ca.crt` | `nginx-tls:/etc/ssl/certs/traefik_ca.crt` | 0644
    `traefik:/etc/proxy/certs/nginx2-tls.crt` | `nginx2-tls:/etc/ssl/certs/nginx-selfsigned.crt` | 0644
    `traefik:/etc/proxy/certs/nginx2-tls.key` | `nginx2-tls:/etc/ssl/private/nginx-selfsigned.key` | 0600
    `traefik:/etc/proxy/certs/traefik_ca.crt` | `nginx2-tls:/etc/ssl/certs/traefik_ca.crt` | 0644
    > _**NB:** Remember to set the permissions on the destination files the same as the source files_
1. On the webservers
    ```bash
    openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    echo "ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    " > /etc/nginx/snippets/self-signed.conf
    echo "# from https://cipherli.st/
    # and https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
    ssl_ecdh_curve secp384r1;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;
    # Disable preloading HSTS for now.  You can use the commented out header line that includes
    # the "preload" directive if you understand the implications.
    #add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;

    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    " > /etc/nginx/snippets/ssl-params.conf
    ```
1. **Optional mTLS** If you want to use mTLS, add the following config into the snippet
    ```bash
    echo "ssl_client_certificate /etc/ssl/certs/traefik_ca.crt;
    ssl_verify_client on;
    ssl_verify_depth  3;
    ssl_protocols             TLSv1 TLSv1.1 TLSv1.2;
    " >> /etc/nginx/snippets/self-signed.conf
    ```
1. Add the secure https server config into the nginx site file (use the website above for reference on doing this)
    ```bash
    vi /etc/nginx/sites-available/default
    ```
1. Now test nginx config and restart the service
    ```bash
    nginx -t  # Ignore stapling warning
    systemctl restart nginx.conf
    ```

```yaml
---
# Attempting to configure traefik to:
# 1. Automatically create certificates for nginx-tls.example.com using LetsEncrypt
# 2. Perform TLS termination for nginx-tls.example.com
# 3. Connect to the backend load-balanced hosts using HTTPS
# 4. Backend webservers are using self-signed certs so 3 options (will try to implement each method)
# 4a. Skip verification - easiest but not safest
# 4b. Reference the root CAs - safer but need to sign and put certs onto each backend webserver from traefik
# 4c. Enable mTLS - safest but need to create key/crt pair required by webservers to authenticate incoming client access only from traefik server
http:
  routers:
    nginx-tls-redirect:
      entrypoints:
        - "web"
      rule: "Host(`nginx-tls.example.com`)"
      middlewares:
        - "nginx-tls-redirect"
      service: nginx-tls

    nginx-tls-secure:
      entrypoints:
        - "websecure"
      rule: "Host(`nginx-tls.example.com`)"
      service: nginx-tls
      tls:
        certResolver: tls-resolver

  middlewares:
    nginx-tls-redirect:
      redirectScheme:
        scheme: https

  services:
    nginx-tls:
      loadBalancer:
        serversTransport: selfsign-transport
        servers:
          - url: 'https://nginx-tls.lxd:443'
          - url: 'https://nginx2-tls.lxd:443'

  serversTransports:
    selfsign-transport:
      # 4a. Skip verification - easiest but not safest (uncomment next line to enact)
      # insecureSkipVerify: true
      # 4b. Reference the root CAs - safest but need to sign and put certs onto each backend webserver from traefik
      rootCAs:
        - /etc/proxy/certs/traefik_ca.crt
      # 4c. Enable mTLS by creating key/crt pair required by webservers to authenticate incoming client access only from traefik server
      certificates:
        - certFile: /etc/proxy/certs/traefik.crt
          keyFile: /etc/proxy/certs/traefik.key
```
### Sticky sessions and Health checks
Tried out sticky sessions. It worked, but when I took down one of the web server, the session stuck on that server and kept showing up an error when the browser was refreshed. To fix this, I added a healthcheck to the traefik and webserver configs.

#### `/etc/nginx/sites-available/default`
```
...
        location /health {
                access_log off;
                default_type text/plain;
                return 200 "healthy 2\n";
        }
...
```

#### `nginx-tls.yml`

```yaml
...
  services:
    nginx-tls:
      loadBalancer:
        serversTransport: selfsign-transport
        servers:
          - url: 'https://nginx-tls.lxd:443'
          - url: 'https://nginx2-tls.lxd:443'
        healthCheck:
          path: /health
          interval: "10s"
          timeout: "3s"
        sticky:
          cookie: {}
...
```
