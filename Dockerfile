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
    && rm -rf /usr/share/locale/* && rm -rf /usr/share/man/* && rm -rf /usr/share/doc/* \
    && touch /var/log/auth.log && update-locale \

    # Create mail user
    && adduser $MAIL_FS_USER --home $MAIL_FS_HOME --shell /bin/false --disabled-password --gecos "" \
    && chown -R ${MAIL_FS_USER}: $MAIL_FS_HOME \
    && usermod -aG $MAIL_FS_USER postfix \
    && usermod -aG $MAIL_FS_USER dovecot \

    && echo "Installed: OK"

ADD postfix /etc/postfix
ADD entrypoint sendmail_test /usr/local/bin/

COPY dovecot/auth-passwdfile.inc /etc/dovecot/conf.d/
COPY dovecot/??-*.conf /etc/dovecot/conf.d/

RUN chmod a+rx /usr/local/bin/* \

    # Configure Postfix
    && /usr/sbin/postconf -e myhostname=$HOST \
    && /usr/sbin/postconf -e mydomain=$DOMAIN \
    && /usr/sbin/postconf -e mydestination=localhost \
    && /usr/sbin/postconf -e mynetworks='127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128' \
    && /usr/sbin/postconf -e inet_interfaces=loopback-only \
    && /usr/sbin/postconf -e smtp_helo_name=\$myhostname.\$mydomain \
    && /usr/sbin/postconf -e virtual_maps='hash:/etc/postfix/virtual, regexp:/etc/postfix/virtual_regexp' \
    && /usr/sbin/postconf -e sender_canonical_maps=regexp:/etc/postfix/sender_canonical_regexp \
    && /usr/sbin/postconf -e virtual_transport=lmtp:unix:private/dovecot-lmtp \
    && /usr/sbin/postconf -e mailbox_transport=lmtp:unix:private/dovecot-lmtp \
    && /usr/sbin/postconf -e virtual_mailbox_domains=/etc/postfix/vhost \
    && /usr/sbin/postconf -e virtual_mailbox_maps=hash:/etc/postfix/vmailbox \
    && /usr/sbin/postconf compatibility_level=2 \
    && /usr/sbin/postmap /etc/postfix/virtual_regexp \
    && /usr/sbin/postmap /etc/postfix/virtual \
    && /usr/sbin/postmap /etc/postfix/vmailbox \
    && /usr/sbin/postmap /etc/postfix/sender_canonical_regexp \
    
    # Configures Dovecot
    && cp -a /usr/share/dovecot/protocols.d /etc/dovecot/ \
    && sed -i -e 's/include_try \/usr\/share\/dovecot\/protocols\.d/include_try \/etc\/dovecot\/protocols\.d/g' /etc/dovecot/dovecot.conf \

    && echo "Configured: OK"

VOLUME ["/var/mail"]
EXPOSE 25 143 993

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["tail", "-fn", "0", "/var/log/mail.log"]
