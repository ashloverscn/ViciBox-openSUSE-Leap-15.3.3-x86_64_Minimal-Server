#!/bin/sh

echo -e "\e[0;32m ViciBox-openSUSE-Leap-15.3.3-SCRATCH-Minimal-Server \e[0m"
echo -e "\e[0;32m Part0 System-HW-Prepration \e[0m"
sleep 5

export LC_ALL=C

# part 0
#we will later blow holes in the firewall for now its off
systemctl disable firewalld
systemctl stop firewalld
#disable ipv6 system-wide 
cat /etc/sysctl.conf
#if already present then dont add the lines 
sed -i -e '$a\
\
net.ipv4.ip_forward = 0 \
net.ipv6.conf.all.forwarding = 0 \
net.ipv6.conf.all.disable_ipv6 = 1 \
' /etc/sysctl.d/70-yast.conf

systemctl restart network
service network restart

#enable verbose boot 
sed -i 's/rhgb//g' /etc/default/grub
sed -i 's/quiet//g' /etc/default/grub
sed -i 's/splash=silent/splash=verbose/g' /etc/selinux/config
grub2-mkconfig -o /boot/grub2/grub.cfg

#reboot
