#!/bin/sh

## target kernel must be Linux vicibox10 5.3.18-57-default #1 SMP Wed Apr 28 10:54:41 UTC 2021 (ba3c2e9) x86_64 GNU/Linux
cd /usr/src
## remove all repos and add our requirment repo set for vicibox
zypper rr --all
zypper ar http://mirrorcache-us.opensuse.org/distribution/leap/15.3/repo/oss/ openSUSE-Leap-15.3-Oss
zypper ar http://mirrorcache-us.opensuse.org/repositories/devel:/languages:/perl/openSUSE_Leap_15.3/ openSUSE-Leap-15.3-PERL
zypper ar http://mirrorcache-us.opensuse.org/repositories/devel:/languages:/perl/15.4/ openSUSE-Leap-15.4-PERL
zypper ar http://mirrorcache-us.opensuse.org/repositories/home:/vicidial/openSUSE_Leap_15.3/ openSUSE-Leap-15.3-ViciDial
zypper ar http://mirrorcache-us.opensuse.org/repositories/home:/vicidial:/asterisk-13/openSUSE_Leap_15.3/ openSUSE-Leap-15.3-ViciDial-Ast13
zypper ar http://mirrorcache-us.opensuse.org/repositories/home:/vicidial:/asterisk-16/openSUSE_Leap_15.3/ openSUSE-Leap-15.3-ViciDial-Ast16
zypper ar http://mirrorcache-us.opensuse.org/repositories/home:/vicidial:/vicibox/openSUSE_Leap_15.3/ openSUSE-Leap-15.3-ViciDial-ViciBox
zypper ar http://mirrorcache-us.opensuse.org/repositories/devel:/languages:/php/openSUSE_Leap_15.4/ openSUSE-Leap-15.4-PHP-Applications
zypper ar http://mirrorcache-us.opensuse.org/update/leap/15.3/oss/ openSUSE-Leap-15.3-Update
zypper ar http://mirrorcache-us.opensuse.org/repositories/home:/zippy:/jx:/packages-ready/openSUSE_Leap_15.3/ openSUSE_Leap_15.3-zippy-jx
## refresh and trust repo keys and update
zypper ref
zypper up -y

#zypper -y remove kernel-*

#zypper -y install kernel-default kernel-devel kernel-source kernel-macros

#zypper -y install bc bison bison-lang flex glibc-devel libelf-devel libxcrypt-devel linux-glibc-devel zlib-devel libelf-devel libfl-devel libfl2 libopenssl-1_1-devel libopenssl-devel m4 

#rpm -i http://download.opensuse.org/distribution/leap/15.3/repo/oss/x86_64/kernel-default-devel-5.3.18-57.3.x86_64.rpm

#rpm -i   http://download.opensuse.org/distribution/leap/15.3/repo/oss/noarch/kernel-devel-5.3.18-57.3.noarch.rpm

#zypper repos -u

