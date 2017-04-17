FROM ubuntu:16.04

MAINTAINER antespi@gmail.com

ENV MAILNAME=localdomain.test \
    MAIL_ADDRESS= \
    MAIL_PASS= \
    MAIL_FS_USER=docker \
    MAIL_FS_HOME=/home/docker

RUN set -x; \
    apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && echo "postfix postfix/mailname string $MAILNAME" | debconf-set-selections \
    && echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        postfix \
        dovecot-core \
        dovecot-imapd \
        dovecot-lmtpd \
        rsyslog \
        iproute2 \
    && apt-get clean -y && apt-get autoclean -y && apt-get autoremove -y \
    && rm -rf /var/cache/apt/archives/* /var/cache/apt/*.bin /var/lib/apt/lists/* \
    && rm -rf /usr/share/man/* && rm -rf /usr/share/doc/* \
    && touch /var/log/auth.log \

    # Create mail user
    && adduser $MAIL_FS_USER --home $MAIL_FS_HOME --shell /bin/false --disabled-password --gecos "" \
    && chown -R ${MAIL_FS_USER}: $MAIL_FS_HOME \
    && usermod -aG $MAIL_FS_USER postfix \
    && usermod -aG $MAIL_FS_USER dovecot \

    && echo "Installed: OK"

ADD postfix /etc/postfix

COPY dovecot/auth-passwdfile.inc /etc/dovecot/conf.d/
COPY dovecot/??-*.conf /etc/dovecot/conf.d/

ADD entrypoint /usr/local/bin/
RUN chmod a+rx /usr/local/bin/entrypoint

VOLUME ["/var/mail"]
EXPOSE 25 143 993

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["tail", "-fn", "0", "/var/log/mail.log"]
