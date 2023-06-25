#!/bin/sh

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'
sec=10

tput civis

echo -e "${YELLOW}"

while [ $sec -gt 0 ]; do
	clear
	let "sec=sec-1"
	echo -ne "${GREEN}"
	echo -e "ViciBox-openSUSE-Leap-15.3.3-x86_64_Minimal-Server"
	echo -ne "${YELLOW}"
	echo -e "$(printf "INSTALLATION WILL START IN") $(printf "%02d" $sec) $(printf "SECONDS")\033[0K\r"
	sleep 1
done

echo -e "${RESET}"

tput cnorm

history -c

clear


#################################################################################
cd /usr/src

yum -y check-update

yum -y install wget git

wget -O ./ViciBox-openSUSE-Leap-15.3.3-x86_64_Minimal-Server.zip https://github.com/ashloverscn/ViciBox-openSUSE-Leap-15.3.3-x86_64_Minimal-Server/archive/refs/heads/main.zip

unzip ./ViciBox-openSUSE-Leap-*

rm -rf ./ViciBox-openSUSE-Leap-*.zip

mv ./ViciBox-openSUSE-Leap-*/* ./

rm -rf ./ViciBox-openSUSE-Leap-*

chmod +x *.sh

pwd

###########################################################################################################
./part0.system-hw-prepration.sh
./part1.update-install-kernel-sources-epl-release-compiler-tools.sh
./part2.install-and-configure-php-mariadb-apache.sh
./part3.install-perl-cpan-cpanm-modules.sh
./part4.a.compile-and-install-asterisk-perl.sh
./part4.b.compile-and-install-sipsak.sh
./part4.c.compile-and-install-lame.sh
./part4.d.compile-and-install-jansson.sh
./part4.e.compile-and-install-eaccelerator.sh
./part5.a.compile-and-install-dahdi.sh
./part5.b.compile-and-install-libpri.sh
./part6.compile-asterisk-make-install-and-samples-menuconfig-automated.sh
./part7.install-vicidial-src-from-svn-repo.sh
./part8.install-vicidial-crontab-from-file.sh
./part9.install-vicidial-rc.local-from-file.sh
./part10.install-vicidial-asterisk-default-sounds.sh










