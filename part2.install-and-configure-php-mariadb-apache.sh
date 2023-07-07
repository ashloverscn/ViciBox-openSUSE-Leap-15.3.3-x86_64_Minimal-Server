#!/bin/sh

echo -e "\e[0;32m Install PHP7 \e[0m"
sleep 2
zypper in php7 php7-cli php7-mysql apache2-mod_php7
a2enmod php7

echo -e "\e[0;32m Install Compiler\Build Tools \e[0m"
sleep 2

#yum -y remove make patch gcc perl-Term-ReadLine-Gnu gcc-c++ subversion php php-devel php-gd gd-devel php-mbstring php-mcrypt php-imap php-ldap php-mysql php-odbc php-pear php-xml php-xmlrpc php-opcache curl curl-devel perl-libwww-perl ImageMagick libxml2 libxml2-devel httpd libpcap libpcap-devel libnet ncurses ncurses-devel screen mysql-devel ntp mutt glibc.i686 wget nano unzip sipsak sox libss7* libopen* openssl libsrtp libsrtp-devel unixODBC unixODBC-devel libtool-ltdl libtool-ltdl-devel htop iftop

#yum -y remove make make patch gcc perl-Term-ReadLine-Gnu gcc-c++ subversion php php-devel php-gd gd-devel php-mbstring php-mcrypt php-imap php-ldap php-mysql php-odbc php-pear php-xml php-xmlrpc curl curl-devel perl-libwww-perl ImageMagick libxml2 libxml2-devel httpd libpcap libpcap-devel libnet ncurses ncurses-devel screen mysql-devel ntp mutt glibc.i686 wget nano unzip sipsak sox libss7* libopen* openssl libsrtp libsrtp-devel unixODBC unixODBC-devel libtool-ltdl libtool-ltdl-devel

#yum -y install make patch gcc perl-Term-ReadLine-Gnu gcc-c++ subversion php php-devel php-gd gd-devel php-mbstring php-mcrypt php-imap php-ldap php-mysql php-odbc php-pear php-xml php-xmlrpc php-opcache curl curl-devel perl-libwww-perl ImageMagick libxml2 libxml2-devel httpd libpcap libpcap-devel libnet ncurses ncurses-devel screen mysql-devel ntp mutt glibc.i686 wget nano unzip sipsak sox libss7* libopen* openssl libsrtp libsrtp-devel unixODBC unixODBC-devel libtool-ltdl libtool-ltdl-devel htop iftop

#yum -y install make patch gcc perl-Term-ReadLine-Gnu gcc-c++ subversion php php-devel php-gd gd-devel php-mbstring php-mcrypt php-imap php-ldap php-mysql php-odbc php-pear php-xml php-xmlrpc curl curl-devel perl-libwww-perl ImageMagick libxml2 libxml2-devel httpd libpcap libpcap-devel libnet ncurses ncurses-devel screen mysql-devel ntp mutt glibc.i686 wget nano unzip sipsak sox libss7* libopen* openssl libsrtp libsrtp-devel unixODBC unixODBC-devel libtool-ltdl libtool-ltdl-devel


echo -e "\e[0;32m Install and configure MariaDB\SQL \e[0m"
sleep 2

#yum -y remove sqlite-devel

#yum -y remove mariadb-server mariadb MariaDB-compat

#yum -y install sqlite-devel

#yum -y install mariadb-server mariadb 

#yum -y install sqlite-devel

#yum -y install mariadb-server mariadb


echo -e "\e[0;32m Create mysql Log files \e[0m"
sleep 2

mkdir /var/log/mysqld
mv /var/log/mysqld.log /var/log/mysqld/mysqld.log
touch /var/log/mysqld/slow-queries.log
chown -R mysql:mysql /var/log/mysqld


echo -e "\e[0;32m Configure mariadb mysql my.cnf file \e[0m"
sleep 2

cd /usr/src
\cp -r /etc/my.cnf /etc/my.cnf.original
echo "" > /etc/my.cnf
#wget -O /usr/src/my.cnf https://raw.githubusercontent.com/ashloverscn/Vicidial-Scratch-Install-CentOS-7-2207-2-x86_64-Minimal-Server/main/my.cnf
\cp -r ./my.cnf /etc/my.cnf
#\cp -r /usr/src/my.cnf /etc/my.cnf 


echo -e "\e[0;32m Configure Httpd\Apache2 httpd.conf file \e[0m"
sleep 2

#cd /usr/src
#\cp -r /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.original
#\cp -r /etc/apache2/httpd.conf /etc/apache2/httpd.conf.original
#echo "" > /etc/apache2/httpd.conf
#wget -O /usr/src/httpd.conf https://github.com/ashloverscn/Vicidial-Scratch-Install-CentOS-7-2207-2-x86_64-Minimal-Server/raw/main/httpd.conf
#\cp -r ./httpd.conf /etc/apache2/httpd.conf
#\cp -r /usr/src/httpd.conf /etc/httpd/conf/httpd.conf


echo -e "\e[0;32m Configure PHP PHP.ini file \e[0m"
sleep 2

cd /usr/src
\cp -r /etc/php7/apache2/php.ini /etc/php7/apache2/php.ini.original
echo "" > /etc/php7/apache2/php.ini
#wget -O /usr/src/php.ini https://github.com/ashloverscn/Vicidial-Scratch-Install-CentOS-7-2207-2-x86_64-Minimal-Server/raw/main/php.ini
\cp -r ./php.ini /etc/php7/apache2/php.ini
#\cp -r /usr/src/php.ini /etc/php.ini

#In addition, ensure that in `/etc/apache2/mod_mime-defaults.conf` there is a line
#AddType application/x-httpd-php .php

echo -e "\e[0;32m create index.html in webroot for redirecting to welcome.php \e[0m"
sleep 2

\cp -r /srv/www/htdocs/index.html /srv/www/htdocs/index.html.original
touch /srv/www/htdocs/index.html
echo "" > /srv/www/htdocs/index.html
sed -i -e '$a\
<META HTTP-EQUIV=REFRESH CONTENT="1; URL=/vicidial/welcome.php"> \
Please Hold while I redirect you! \
' /srv/www/htdocs/index.html

## allow apache2 user to run
sudo chown wwwrun /srv/www/htdocs/ -R

echo -e "\e[0;32m Enable and start Httpd and MariaDb services \e[0m"
sleep 2

systemctl enable apache2.service
systemctl enable mariadb.service
systemctl start apache2.service
systemctl start mariadb.service
systemctl status mariadb.service
systemctl status apache2.service
a2enmod php7


