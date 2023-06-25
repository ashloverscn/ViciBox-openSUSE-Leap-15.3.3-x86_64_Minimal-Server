#!/bin/sh
ver=13.29.2
oem=-vici
subdr=beta-apps
echo -e "\e[0;32m Install Asterisk v$ver$oem \e[0m"
sleep 2
cd /usr/src
#rm -rf asterisk*
zypper remove -y asterisk asterisk-devel asterisk-dahdi asterisk-alsa asterisk-calendar asterisk-console asterisk-corosync asterisk-freetds asterisk-moh-base asterisk-odbc asterisk-perl asterisk-pgsql asterisk-radius asterisk-snmp asterisk-sounds-base asterisk-sounds-devel asterisk-spandsp libasteriskssl1
#zypper install -y dahdi-tools
wget -O asterisk-$ver$oem.tar.gz http://download.vicidial.com/$subdr/asterisk-$ver$oem.tar.gz
#wget http://download.vicidial.com/beta-apps/asterisk-16.17.0-vici.tar.gz
tar -xvzf asterisk-$ver$oem.tar.gz
cd asterisk-$ver$oem
cd asterisk-$ver

: ${JOBS:=$(( $(nproc) + $(nproc) / 2 ))}
./configure --libdir=/usr/lib64 --with-gsm=internal --enable-opus --enable-srtp --with-ssl --enable-asteriskssl --with-pjproject-bundled --with-jansson-bundled

#### asterisk menuselect preconfig
make menuselect/menuselect menuselect-tree menuselect.makeopts
#enable app_meetme
menuselect/menuselect --enable app_meetme menuselect.makeopts
#enable res_http_websocket
menuselect/menuselect --enable res_http_websocket menuselect.makeopts
#enable res_srtp
menuselect/menuselect --enable res_srtp menuselect.makeopts
make -j ${JOBS} all
make install
make samples

