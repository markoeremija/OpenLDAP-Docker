FROM debian:stretch

# Docker image related information
LABEL "org.geant"="GÉANT Association"
LABEL maintainer.email="marko.eremija [at] amres.ac.rs"
LABEL maintainer.name="Marko Eremija"
LABEL version="0.0.1"
LABEL description="This is an OpenLDAP Dockerfile \
for the GN4 Campus IdP task (JRA3T1)."

# ENV variables
# Using ENV variables can help with setting defaults for
# unattended installation of OpenLDAP. Add it later.
ENV DEBIAN_FRONTEND noninteractive
#ARG DEBIAN_FRONTEND=noninteractive

# Set options in advance for unattended Debian installation.

RUN apt-get update && \
    apt-get -y --no-install-recommends install \
	apt-utils \
	debconf-utils \
    python-ldap && \
    deb_conf=$( debconf-get-selections | grep -q -s slapd; echo $? ) && \
    if [ $deb_conf ]; then \
      echo "slapd slapd/password1 password" | debconf-set-selections && \
	  echo "slapd slapd/password2 password" | debconf-set-selections && \
      echo "slapd slapd/move_old_database boolean true" | debconf-set-selections && \
	  echo "slapd slapd/domain string amres.ac.rs" | debconf-set-selections && \
	  echo "slapd shared/organization string AMRES" | debconf-set-selections && \
      echo "slapd slapd/no_configuration boolean false" | debconf-set-selections && \
	  echo "slapd slapd/purge_database boolean false" | debconf-set-selections && \
	  echo "slapd slapd/allow_ldap_v2 boolean false" | debconf-set-selections && \
      echo "slapd slapd/backend select MDB" | debconf-set-selections; \
    fi;

RUN apt-get update && \
    apt-get -y --no-install-recommends install \
    ldap-utils \
    slapd \
	rsyslog && \
    mkdir /var/log/slapd && \
	mkdir /root/ldap-configs

# System related configuration

COPY 99-slapd.conf /etc/rsyslog.d/

COPY ldap.conf /etc/ldap/

#COPY docker-test.amres.ac.rs.key /etc/ssl/private/docker-test.amres.ac.rs.key
COPY cert.key /etc/ssl/private/docker-test.amres.ac.rs.key

#COPY docker-test_amres_ac_rs.pem /etc/ssl/certs/docker-test_amres_ac_rs.pem
COPY cert.pem /etc/ssl/certs/docker-test_amres_ac_rs.pem

#COPY DigiCertCA.pem /etc/ssl/certs/DigiCertCA.pem
COPY cacert.pem /etc/ssl/certs/cacert.pem

# Change owner of files for OpenLDAP to be able to read them

RUN chown openldap:openldap /etc/ssl/private/docker-test.amres.ac.rs.key && \
    chown openldap:openldap /etc/ssl/certs/docker-test_amres_ac_rs.pem

# OpenLDAP related configuration

COPY ldif-files /root/ldap-configs/

WORKDIR /root/ldap-configs

RUN cp /etc/ldap/schema/ppolicy.ldif ppolicy.ldif && \
	service slapd start && \
    ldapadd -Y EXTERNAL -H ldapi:/// -f eduperson-201602.ldif && \
    ldapadd -Y EXTERNAL -H ldapi:/// -f schac-20150413.ldif && \
	ldapadd -Y EXTERNAL -H ldapi:/// -f ppolicy.ldif && \
	ldapmodify -Y EXTERNAL -H ldapi:/// -f directory-settings.ldif && \
	ldapadd -Y EXTERNAL -H ldapi:/// -f branches.ldif && \
	ldapadd -Y EXTERNAL -H ldapi:/// -f users.ldif

#RUN ldapmodify -Y EXTERNAL -H ldapi:/// -f directory-settings.ldif

# Run restart rsyslog && slapd when everything is checked and copied
RUN service rsyslog restart && \
    service slapd stop && \
	service slapd start

# Clean packages
RUN apt-get -y --purge autoremove && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 389 636

# exec /usr/sbin/slapd -h "ldap://$HOSTNAME ldaps://$HOSTNAME ldapi:///" -u openldap -g openldap -d $LDAP_LOG_LEVEL

CMD ["slapd", \ 
     "-d", "256", \ 
     "-h ldap:// ldaps:// ldapi:///", \
	 "-u", "openldap", \
	 "-g", "openldap", \
	 "-F", "/etc/ldap/slapd.d"]
