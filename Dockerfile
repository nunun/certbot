FROM certbot/certbot

RUN mkdir -p /etc/letsencrypt /webroot/.well-known

ENTRYPOINT []

CMD ["sleep", "30000"]
