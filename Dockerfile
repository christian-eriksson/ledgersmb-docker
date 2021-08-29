FROM    debian:bullseye-slim
LABEL   org.opencontainers.image.authors="LedgerSMB project <devel@lists.ledgersmb.org>"

# Install Perl, Tex, Starman, psql client, and all dependencies
#
# Without libclass-c3-xs-perl, everything grinds to a halt;
# add it, because it's a 'recommends' it the dep tree, which
# we're skipping, normally
#
# Installing psql client directly from instructions at https://wiki.postgresql.org/wiki/Apt
# That mitigates issues where the PG instance is running a newer version than this container

RUN set -x ; \
  echo "APT::Install-Recommends \"false\";\nAPT::Install-Suggests \"false\";\n" > /etc/apt/apt.conf.d/00recommends && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y update && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y upgrade && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y install \
    wget ca-certificates gnupg \
    libauthen-sasl-perl libcgi-emulate-psgi-perl libconfig-inifiles-perl \
    libcookie-baker-perl libdbd-pg-perl libdbi-perl libdata-uuid-perl \
    libdatetime-perl libdatetime-format-strptime-perl \
    libemail-sender-perl libemail-stuffer-perl libfile-find-rule-perl \
    libhtml-escape-perl libhttp-headers-fast-perl libio-stringy-perl \
    libjson-maybexs-perl libcpanel-json-xs-perl libjson-pp-perl \
    liblist-moreutils-perl \
    liblocale-maketext-perl liblocale-maketext-lexicon-perl liblog-any-perl \
    liblog-any-adapter-log4perl-perl liblog-log4perl-perl libmime-types-perl \
    libmath-bigint-gmp-perl libmodule-runtime-perl libmoo-perl \
    libmoox-types-mooselike-perl libmoose-perl libmoosex-classattribute-perl \
    libmoosex-nonmoose-perl libnumber-format-perl \
    libpgobject-perl libpgobject-simple-perl libpgobject-simple-role-perl \
    libpgobject-type-bigfloat-perl libpgobject-type-datetime-perl \
    libpgobject-type-bytestring-perl libpgobject-util-dbmethod-perl \
    libpgobject-util-dbadmin-perl libplack-perl \
    libplack-builder-conditionals-perl libplack-middleware-reverseproxy-perl \
    libplack-request-withencoding-perl libscope-guard-perl \
    libsession-storage-secure-perl libstring-random-perl \
    libtemplate-perl libtext-csv-perl libtext-csv-xs-perl \
    libtext-markdown-perl libversion-compare-perl \
    libxml-libxml-perl libnamespace-autoclean-perl \
    starman starlet libhttp-parser-xs-perl \
    libtemplate-plugin-latex-perl libtex-encode-perl \
    libxml-twig-perl libopenoffice-oodoc-perl \
    libexcel-writer-xlsx-perl libspreadsheet-writeexcel-perl \
    libclass-c3-xs-perl \
    libyaml-perl libhash-merge-perl libsyntax-keyword-try-perl \
    texlive-plain-generic texlive-latex-recommended texlive-fonts-recommended \
    texlive-xetex fonts-liberation \
    lsb-release && \
  echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
  (wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -) && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y update && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y install postgresql-client && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y autoremove && \
  DEBIAN_FRONTEND="noninteractive" apt-get -y autoclean && \
  rm -rf /var/lib/apt/lists/*


# Build time variables
ENV LSMB_VERSION master
ENV NODE_PATH /usr/local/lib/node_modules


###########################################################
# Java & Nodejs for doing Dojo build

# These packages are only needed during the dojo build
ENV DOJO_Build_Deps git make gcc libperl-dev curl nodejs cpanminus
# These packages can be removed after the dojo build
ENV DOJO_Build_Deps_removal ${DOJO_Build_Deps} nodejs cpanminus

RUN wget --quiet -O - https://deb.nodesource.com/setup_16.x | bash -
RUN DEBIAN_FRONTEND="noninteractive" apt-get -y update && \
    DEBIAN_FRONTEND="noninteractive" apt-get -y install ${DOJO_Build_Deps} && \
    cd /srv && \
    git clone --depth 1 --recursive -b $LSMB_VERSION https://github.com/ledgersmb/LedgerSMB.git ledgersmb && \
    cd ledgersmb && \
    cpanm --quiet --notest \
      --with-feature=starman \
      --with-feature=latex-pdf-ps \
      --with-feature=openoffice \
      --installdeps .  && \
    make dojo && \
    DEBIAN_FRONTEND="noninteractive" apt-get -y purge ${DOJO_Build_Deps_removal} && \
    rm -rf /usr/local/lib/node_modules && \
    DEBIAN_FRONTEND="noninteractive" apt-get -y autoremove && \
    DEBIAN_FRONTEND="noninteractive" apt-get -y autoclean && \
    rm -rf ~/.cpanm && \
    rm -rf /var/lib/apt/lists/*

# Cleanup args that are for internal use
ENV DOJO_Build_Deps=
ENV DOJO_Build_Deps_removal=
ENV NODE_PATH=

# Configure outgoing mail to use host, other run time variable defaults

## MAIL
ENV LSMB_MAIL_SMTPHOST 172.17.0.1
#ENV LSMB_MAIL_SMTPPORT 25
#ENV LSMB_MAIL_SMTPSENDER_HOSTNAME (container hostname)
#ENV LSMB_MAIL_SMTPTLS
#ENV LSMB_MAIL_SMTPUSER
#ENV LSMB_MAIL_SMTPPASS
#ENV LSMB_MAIL_SMTPAUTHMECH

ENV POSTGRES_HOST postgres
ENV POSTGRES_PORT 5432
ENV DEFAULT_DB lsmb

COPY start.sh /usr/local/bin/start.sh

RUN chmod +x /usr/local/bin/start.sh && \
    mkdir -p /var/www

# Work around an aufs bug related to directory permissions:
RUN mkdir -p /tmp && \
  chmod 1777 /tmp

# Internal Port Expose
EXPOSE 5762

USER www-data
CMD ["start.sh"]
