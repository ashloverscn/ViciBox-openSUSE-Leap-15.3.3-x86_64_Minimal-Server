#!/bin/sh
ver=3.2.0
vici=0
dahdi-linux-complete-$ver+$ver
echo -e "\e[0;32m Install Dahdi Audio_CODEC Driver v$ver \e[0m"
sleep 2
cd /usr/src
#rm -rf dahdi-linux-complete*
zypper install -y make patch gcc gcc-c++ subversion php php-devel php-gd gd-devel php-mbstring php-mcrypt php-imap php-ldap php-mysql php-odbc php-pear php-xml php-xmlrpc curl curl-devel perl-libwww-perl ImageMagick libxml2 libxml2-devel httpd libpcap libpcap-devel libnet ncurses ncurses-devel screen mysql-devel ntp mutt wget nano unzip sipsak sox libuuid-devel
zypper install -y asterisk-dahdi dahdi-linux dahdi-linux-devel dahdi-linux-kmp-default dahdi-linux-kmp-preempt dahdi-tools

zypper ref
zypper up

zypper in dahdi*
zypper in libpri*
zypper in libedit*
zypper in net-snmp*
zypper in libjansson4*
zypper install -t pattern devel_basis
zypper install sqlite3-devel mariadb-server mariadb make patch gcc gcc-c++ subversion php php-devel php-gd gd-devel php-mbstring php-mcrypt php-imap php-ldap php-mysql php-odbc php-pear php-xml php-xmlrpc curl curl-devel perl-libwww-perl ImageMagick libxml2 libxml2-devel httpd libpcap libpcap-devel libnet ncurses ncurses-devel screen mysql-devel ntp mutt wget nano unzip sipsak sox libuuid-devel httpd php-common php-pdo mod_ssl perl-DBI perl-DBD-MySQL perl-Digest-HMAC perl-YAML perl-ExtUtils-ParseXS perl-NetAddr-IP perl-Crypt-SSLeay perl-Curses perl-DBD-Pg perl-Module-ScanDeps perl-Text-CSV perl-HTML-Template perl-IO-Compress perl-Text-Glob perl-Jcode perl-Test-Script perl-Archive-Tar perl-Test-Base perl-OLE-Storage_Lite perl-Archive-Zip perl-Net-Server perl-Convert-ASN1 perl perl-Compress-Raw-Zlib perl-Digest-SHA1 perl-Data-Dumper perl-Error perl-ExtUtils-CBuilder perl-Test-Tester perl-Parse-RecDescent perl-Spiffy perl-IO-Zlib perl-Module-Build perl-HTML-Parser perl-Net-SSLeay perl-Proc-ProcessTable perl-TermReadKey perl-Term-ReadLine-Gnu perl-Digest-SHA perl-Tk perl-Net-SNMP perl-Test-NoWarnings perl-XML-Writer perl-Proc-PID-File perl-Compress-Raw-Bzip2 perl-libwww-perl perl-XML-Parser perl-File-Remove perl-Parse-CPAN-Meta perl-Set-Scalar perl-Probe-Perl perl-File-Which perl-Package-Constants perl-Module-Install perl-File-HomeDir perl-Spreadsheet-ParseExcel perl-Mail-Sendmail perl-Spreadsheet-XLSX asterisk-perl perl-version perl-Crypt-DES perl-URI perl-Net-Daemon perl-IO-stringy perl-YAML-Tiny perl-HTML-Tagset perl-Socket6 perl-BSD-Resource perl-IPC-Run3 perl-Text-CSV_XS perl-Unicode-Map perl-Net-Telnet perl-PAR-Dist perl-Date-Manip perl-JSON perl-rrdtool lame screen iftop htop perl-GD gcc gcc-c++- bzip2 make libjansson-devel dahdi-linux-devel libxml2-tools libxml2-2 libxml2-devel libuuid-devel sqlite3-devel

perl -MCPAN -e 'my $c = "CPAN::HandleConfig"; $c->load(doit => 1, autoconfig => 1); $c->edit(prerequisites_policy => "follow"); $c->edit(build_requires_install_policy => "yes"); $c->commit' 

cpan -i String::CRC Tk::TableMatrix Net::Address::IP::Local Term::ReadLine::Gnu Spreadsheet::Read Net::Address::IPv4::Local RPM::Specfile Spreadsheet::XLSX Spreadsheet::ReadSXC MD5 Digest::MD5 Digest::SHA1 Bundle::CPAN Pod::Usage Getopt::Long DBI DBD::mysql Net::Telnet Time::HiRes Net::Server Mail::Sendmail Unicode::Map Jcode Spreadsheet::WriteExcel OLE::Storage_Lite Proc::ProcessTable IO::Scalar Scalar::Util Spreadsheet::ParseExcel Archive::Zip Compress::Raw::Zlib Spreadsheet::XLSX Test::Tester Spreadsheet::ReadSXC Text::CSV Test::NoWarnings Text::CSV_PP File::Temp Text::CSV_XS Spreadsheet::Read LWP::UserAgent HTML::Entities HTML::Strip HTML::FormatText HTML::TreeBuilder Switch Time::Local MIME::POP3Client Mail::IMAPClient Mail::Message IO::Socket::SSL readline 

cd /usr/bin/
curl -LOk http://xrl.us/cpanm
chmod +x cpanm
cpanm -f File::Which
cpanm -f File::HomeDir
cpanm CPAN::Meta::Requirements
cpanm -f CPAN
cpanm -f DBD::mysql
cpanm User::Identity --force
cpanm YAML MD5 Digest::MD5 Digest::SHA1 Curses Getopt::Long Net::Domain Term::ReadKey Term::ANSIColor HTML::FormatText MIME::Decoder Mail::POP3Client Mail::Message Crypt::Eksblowfish::Bcrypt

#http://swanand18.blogspot.com/2022/12/how-to-scratch-install-instructions-for.html
#http://swanand18.blogspot.com/2021/11/how-to-vicibox-9-scratch-install.html
#https://dialer.one/how-to-scratch-instructions-for-vicidialvicibox9-on-opensuse-leap-15-3-with-asterisk-16-17-0/
#http://swanand18.blogspot.com/2017/06/vicidial-scratch-installation-centos-7.html


if [ $vici -eq 1 ]
then
	wget http://download.vicidial.com/required-apps/dahdi-linux-complete-2.3.0.1+2.3.0.tar.gz
	tar -xvzf dahdi-linux-complete-2.3.0.1+2.3.0.tar.gz
	cd dahdi-linux-complete-2.3.0.1+2.3.0
else
	wget -O dahdi-linux-complete-$ver+$ver.tar.gz https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-$ver%2B$ver.tar.gz
	tar -xvzf dahdi-linux-complete-$ver+$ver.tar.gz
	cd dahdi-linux-complete-$ver+$ver
fi
make all
make install
make config
modprobe dahdi
modprobe dahdi_dummy
dahdi_genconf -v
dahdi_cfg -v

