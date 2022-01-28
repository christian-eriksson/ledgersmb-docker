FROM        debian:stretch-slim
MAINTAINER  Freelock john@freelock.com

# Build time variables
ENV LSMB_VERSION 1.5.30


# Install Perl, Tex, Starman, psql client, and all dependencies
# Without libclass-c3-xs-perl, performance is terribly slow...

# Installing psql client directly from instructions at https://wiki.postgresql.org/wiki/Apt
# That mitigates issues where the PG instance is running a newer version than this container

RUN echo -n "APT::Install-Recommends \"0\";\nAPT::Install-Suggests \"0\";\n" >> /etc/apt/apt.conf && \
  mkdir -p /usr/share/man/man1/ && \
  mkdir -p /usr/share/man/man2/ && \
  mkdir -p /usr/share/man/man3/ && \
  mkdir -p /usr/share/man/man4/ && \
  mkdir -p /usr/share/man/man5/ && \
  mkdir -p /usr/share/man/man6/ && \
  mkdir -p /usr/share/man/man7/ && \
  DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get dist-upgrade -y && apt-get -y install \
    gnupg2 curl wget ca-certificates \
    libcgi-emulate-psgi-perl libcgi-simple-perl libconfig-inifiles-perl \
    libdbd-pg-perl libdbi-perl libdatetime-perl \
    libdatetime-format-strptime-perl libdigest-md5-perl \
    libfile-mimeinfo-perl libjson-xs-perl libjson-perl \
    liblocale-maketext-perl liblocale-maketext-lexicon-perl \
    liblog-log4perl-perl libmime-base64-perl libmime-lite-perl \
    libmath-bigint-gmp-perl libmoose-perl libnumber-format-perl \
    libpgobject-perl libpgobject-simple-perl libpgobject-simple-role-perl \
    libpgobject-util-dbmethod-perl libplack-perl libtemplate-perl \
    libnamespace-autoclean-perl \
    libtemplate-plugin-latex-perl libtex-encode-perl \
    libmoosex-nonmoose-perl libclass-c3-xs-perl \
    texlive-latex-recommended \
    texlive-xetex fonts-liberation \
    starman \
    libopenoffice-oodoc-perl \
    postgresql-client \
    ssmtp \
    lsb-release && \
  echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
  (wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -) && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y update && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y install postgresql-client && \
  DEBIAN_FRONTEND=noninteractive apt-get -y install git cpanminus make gcc libperl-dev && \
    curl -Lo /tmp/ledgersmb-$LSMB_VERSION.tar.gz "https://download.ledgersmb.org/f/Releases/$LSMB_VERSION/ledgersmb-$LSMB_VERSION.tar.gz" && \
    tar -xvzf /tmp/ledgersmb-$LSMB_VERSION.tar.gz --directory /srv && \
    rm -f /tmp/ledgersmb-$LSMB_VERSION.tar.gz && \
    cpanm --quiet --notest \
      --with-feature=starman \
      --with-feature=latex-pdf-ps \
      --with-feature=openoffice \
      --installdeps /srv/ledgersmb/ && \
    apt-get purge -y git cpanminus make gcc libperl-dev && \
    apt-get autoremove -y && \
    apt-get autoclean && \
    rm -rf ~/.cpanm/ && \
    rm -rf /var/lib/apt/lists/* /usr/share/man/*


WORKDIR /srv/ledgersmb

# master requirements

# Configure outgoing mail to use host, other run time variable defaults

## sSMTP
ENV SSMTP_ROOT ar@example.com
ENV SSMTP_MAILHUB 172.17.0.1
ENV SSMTP_HOSTNAME 172.17.0.1
#ENV SSMTP_USE_STARTTLS
#ENV SSMTP_AUTH_USER
#ENV SSMTP_AUTH_PASS
ENV SSMTP_FROMLINE_OVERRIDE YES
#ENV SSMTP_AUTH_METHOD

ENV POSTGRES_HOST postgres
ENV POSTGRES_PORT 5432
ENV DEFAULT_DB lsmb

COPY start.sh /usr/local/bin/start.sh
COPY update_ssmtp.sh /usr/local/bin/update_ssmtp.sh

RUN chown www-data /etc/ssmtp /etc/ssmtp/ssmtp.conf && \
  chmod +x /usr/local/bin/update_ssmtp.sh /usr/local/bin/start.sh && \
  mkdir -p /var/www

# Work around an aufs bug related to directory permissions:
RUN mkdir -p /tmp && \
  chmod 1777 /tmp

# Internal Port Expose
EXPOSE 5762

USER www-data
CMD ["start.sh"]
