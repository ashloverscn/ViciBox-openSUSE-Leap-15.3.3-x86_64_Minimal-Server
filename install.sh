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

zypper ref

zypper install -y wget git unzip

wget -O ./ViciBox-openSUSE-Leap-15.3.3-x86_64_Minimal-Server.zip https://github.com/ashloverscn/ViciBox-openSUSE-Leap-15.3.3-x86_64_Minimal-Server/archive/refs/heads/main.zip

unzip ./ViciBox-openSUSE-Leap-*

rm -rf ./ViciBox-openSUSE-Leap-*.zip

mv ./ViciBox-openSUSE-Leap-*/* ./

rm -rf ./ViciBox-openSUSE-Leap-*

chmod +x *.sh

pwd

###########################################################################################################
./part0.system-hw-prepration.sh
./part1.add-repo.sh





