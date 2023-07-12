#!/bin/bash

# ViciBox Telephony script, basically does some DAHDI autodetect things

# Do our DAHDI thing
modprobe dahdi >> /var/log/vicibox.log 2>&1
/usr/sbin/dahdi_genconf >> /var/log/vicibox.log 2>&1

# Make an entry for ramdrive if it's not already there
if ! [[ `cat /etc/fstab | grep monitor` ]]; then
	/bin/echo "tmpfs   /var/spool/asterisk/monitor       tmpfs      rw,size=6G              0 0" >> /etc/fstab
fi

# Make sure we can get recordings from apache
if ! [ -d "/var/spool/asterisk/monitorDONE" ]; then
	mkdir -p /var/spool/asterisk/monitorDONE >> /var/log/vicibox.log 2>&1
fi
chown -R wwwrun /var/spool/asterisk/monitorDONE >> /var/log/vicibox.log 2>&1

# Install G729/G723 codecs
/usr/share/vicibox/codec-install.sh >> /var/log/vicibox.log 2>&1

# Configure mp3 voicemail sending
sed -i 's+attach=yes+attach=yes\nmailcmd=/usr/local/bin/sendmailmp3.sh+' /etc/asterisk/voicemail.conf

# Adjusting meetmet volume is the number 1 source of seemingly random asterisk only crashes. So comment that out
sed -i 's/MeetMe Adjustment Extensions/MeetMe Adjustment Extensions\n; Adjusting the meetme volumes is the number 1 source for\n; seemingly random crashes, so we comment that out.\n; Below is just something to make the dialplan complete.\nexten => _X[3-4]8600XXX,1,Hangup()/' /etc/asterisk/extensions.conf
sed -i 's/exten => _X48600XXX/;exten => _X48600XXX/g' /etc/asterisk/extensions.conf
sed -i 's/exten => _X38600XXX/;exten => _X48600XXX/g' /etc/asterisk/extensions.conf

# Sounds stuff
if [ -f /etc/asterisk/asterisk.conf ]; then
	sed -i 's/;verbose = 3/verbose = 21/g' /etc/asterisk/asterisk.conf
	sed -i 's/;timestamp = yes/timestamp = yes/g' /etc/asterisk/asterisk.conf
	sed -i 's/enabled = yes/enabled = no/g' /etc/asterisk/ari.conf
fi
if [ -d /usr/share/asterisk/sounds ]; then
	cd /usr/share/asterisk/sounds
	if [ -d ./en ]; then
		cd en
		mv * ../
		cd ..
		rm -rf en
	fi
	if [ -f /usr/src/astguiclient/conf/asterisk-extra-sounds-en-gsm-current.tar.gz ]; then
		tar -xf /usr/src/astguiclient/conf/asterisk-extra-sounds-en-gsm-current.tar.gz
		rm /usr/src/astguiclient/conf/asterisk-extra-sounds-en-gsm-current.tar.gz
	fi
	if [ -f /usr/src/astguiclient/conf/asterisk-extra-sounds-en-gsm-current.tar.gz ]; then
		tar -xf /usr/src/astguiclient/conf/asterisk-extra-sounds-en-gsm-current.tar.gz
		rm /usr/src/astguiclient/conf/asterisk-extra-sounds-en-gsm-current.tar.gz
	fi
	rm *-asterisk-*
	cp /usr/src/astguiclient/conf/conf.gsm /usr/share/asterisk/sounds/
	ln -s /usr/share/asterisk/sounds/conf.gsm /usr/share/asterisk/sounds/park.gsm
fi
ln -s /usr/share/asterisk/sounds /var/lib/asterisk/sounds
ln -s /usr/share/asterisk/moh /var/lib/asterisk/moh
ln -s /usr/share/asterisk/quiet-mp3 /var/lib/asterisk/quiet-mp3
mkdir -p /var/spool/asterisk/monitorDONE

# Do path changes and fixup for ViciDial
mkdir -p /usr/share/asterisk/keys
mkdir -p /var/lib/asterisk/agi-bin
ln -s /var/lib/asterisk/agi-bin/ /usr/share/asterisk/agi-bin
ln -s /usr/share/asterisk/moh/ /var/lib/asterisk/mohmp3
ln -s /usr/share/asterisk/images /var/lib/asterisk/images
ln -s /usr/share/asterisk/firmware /var/lib/asterisk/firmware
ln -s /usr/share/asterisk/static-http/ /var/lib/asterisk/static-http
sed -i 's+/usr/share/asterisk+/var/lib/asterisk+g' /etc/asterisk/asterisk.conf
sed -i 's/;languageprefix = yes/languageprefix = no/g' /etc/asterisk/asterisk.conf

# Nuke garbage default config files
cd /etc/asterisk
rm extensions.ael
rm extensions.lua
touch extensions.ael
touch extensions.lua

# ViciPhone WebRTC setup
sed -i "/stunaddr=/c\\stunaddr=stun.l.google.com:19302" /etc/asterisk/rtp.conf
sed -i 's/;enabled=yes/enabled=yes/' /etc/asterisk/http.conf
sed -i 's/;tlsenable=yes/tlsenable=yes/' /etc/asterisk/http.conf
sed -i 's/;tlsbindaddr=0.0.0.0:8089/tlsbindaddr=0.0.0.0:8089/' /etc/asterisk/http.conf
sed -i "/tlscertfile=/c\\tlscertfile=/etc/apache2/ssl.crt/vicibox.crt" /etc/asterisk/http.conf
sed -i "/tlsprivatekey=/c\\tlsprivatekey=/etc/apache2/ssl.key/vicibox.key" /etc/asterisk/http.conf
