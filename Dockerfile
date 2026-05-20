FROM alpine
MAINTAINER Charles Lehnert <Charles@CLLInteractive.com>

RUN apk add -U \
  bash \
  tini \
  tzdata \
  && rm -rf /var/cache/apk/*

# Set bash as the default shell
SHELL ["/bin/bash", "-c"]

ENV SCHEDULE="0 * * * *"
ENV THRESHOLD=80
ENV FILE_NUMBER=1

# Specify the directory to be mounted using volumes in docker-compose.yml
VOLUME /reduce_directory /volume_usage_directory /etc/crontabs

COPY entrypoint.sh chomper.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/crond", "-f", "-d8"]
