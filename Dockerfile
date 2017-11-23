FROM certbot/certbot

RUN mkdir -p /etc/letsencrypt /webroot/.well-known

ENTRYPOINT []

CMD read forever /dev/null
