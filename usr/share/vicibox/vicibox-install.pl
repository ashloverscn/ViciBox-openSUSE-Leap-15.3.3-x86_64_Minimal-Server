#!/usr/bin/perl

# vicibox-install.pl version 10.0
#
# Copyright (C) 2018  James Pearson  <jamesp@vicidial.com>    LICENSE: AGPLv2
#
#
# CHANGES
# 210713-1143 - RC1 build v.10.0
# 190726-1806 - RC1 Build v.9.0
# 180921-1540 - GB Build v.8.1.0
# 180920-1914 - RC2 Build v.8.1
# 180327-1818 - RC1 Build v.8.1
#


# This script looks for a table called 'vicibox' in the ViciDial Database server to pull in settings
# If you don't have one you can create one. The schema is as follows as well as the field definitions.
# If the script doesn't find one, or not one with correctly matching info, it will enable the proper
# modes depending on what it doesn't like. Finding no table = legacy mode. Not finding the database
# entry will enable expert mode. Try not to get this internal tracking database too far out of whack :)


#Vicibox table schema:
#CREATE TABLE IF NOT EXISTS `vicibox` (
#  `server_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
#  `server` varchar(32) NOT NULL,
#  `server_ip` varchar(32) NOT NULL,
#  `server_type` enum('Database','Web','Telephony','Archive') NOT NULL DEFAULT 'Telephony',
#  `field1` varchar(64) DEFAULT NULL,
#  `field2` varchar(64) DEFAULT NULL,
#  `field3` varchar(64) DEFAULT NULL,
#  `field4` varchar(64) DEFAULT NULL,
#  `field5` varchar(64) DEFAULT NULL,
#  `field6` varchar(64) DEFAULT NULL,
#  `field7` varchar(64) DEFAULT NULL,
#  `field8` varchar(64) DEFAULT NULL,
#  `field9` varchar(64) NOT NULL
#  PRIMARY KEY (`server_id`)
#) ENGINE=MyISAM DEFAULT CHARSET=latin1;


#DB field types:
#field1 = mysql server ID, use 0 for Master, 1 for first slave, 2 for 2nd slave, etc, up to 9
#field2 = DB name, default is asterisk
#field3 = svn revision of DB
#field4 = regular user
#field5 = regular pass
#field6 = custom user
#field7 = custom pass
#field8 = slave user, only relevant to primary DB
#field9 = slave pass, same as above

#Web field types:
#field1 = external IP
#field2 = audiostore directory

#Telephony field type:
#field1 = external IP

#Archive field type: Auto-Configuration only works on a single archive server, other things have to be done manually
#field1 = FTP user
#field2 = FTP pass
#field3 = FTP Port
#field4 = FTP directory
#field5 = URL Path



# All my lovely little modules
# I HATE STRICT! Suggesting I use strict will result in me
# tracking you down and hitting you in the face with a hammer!
# Feel free to submit a strict-friendly patch and/or other code
# clean-up and optimization efforts you may have. If I test them
# and they work I will put them in.
use warnings;
use LWP::Simple;
use Sys::Hostname;
use DBI;

# A handy IPv4 validator for user input
sub checkipv4 {
my $ipaddr = $_[0];

# Make sure we like the format
if( $ipaddr =~ m/^(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)$/ ) {
	
	# Make sure we like the octets too
	if($1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255) {
		if ($debug==1) { print("IP Address checks good: $ipaddr\n"); }
		return 0;
		
		} else {
			if ($debug==1) { print("IP address octet(s) out of range: $ipaddr \n"); }
			return 1;
	}

	} else {
		if ($debug==1) { print("IP address not in valid format: $ipaddr\n"); }
		return 1;
}
}

# Get the local IP of the machine by parsing ifconfig (there really should be a better way to do this in perl)
sub getlocalip {
	my $ip;
	my @ifconfig = `/usr/bin/ifconfig -a`;
	my $line;
	my $i=0;
	
	foreach(@ifconfig) {
		$line = $ifconfig[$i];
		if ( $line =~ /inet (\d+\.\d+\.\d+\.\d+)/) {
			$ip = $1;
			if ( $ip =~ /(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1)$/) {
				$ip = trim($ip);
				return $ip;
			}
		}
		$i++;
	}
	return "X";
}

# Get the External IP from the internets! Will also serv as a connectivity checker for feedback
sub getextip {
	my $extip=get("http://www.vicidial.org/yourip.php");
	return "X" unless defined $extip;
	$extip = trim($extip);
	return $extip;
}

# Perl trim function to remove whitespace from the start and end of the string, stolen from google cause i'm lazy
sub trim($) {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

# Get the admin.php build and admin version. Threw it in a sub since it's ugly code :)
sub adminphp {
my $srce = "/usr/src/astguiclient/trunk/www/vicidial/admin.php";
my $string1 = 'build = ';
my $string2 = 'admin_version = ';
my $adminver;
my $buildver;
my $line;

open(FH, $srce);
while(my $line = <FH>) { 
  if($line =~ m/$string1/) {
    $buildver = $line;
  }
  if($line =~ m/$string2/) {
    $adminver = $line;
  }
}
close FH;
$buildver = substr $buildver, 10;
$buildver = substr $buildver, 0, -3;
if ($debug==1) { print "Build Version : $buildver\n"; }
$adminver = substr $adminver, 18;
$adminver = substr $adminver, 0, -3;
if ($debug==1) { print "Admin Version : $adminver\n"; }

return ($buildver, $adminver);

}

# Look for user to press a Y in the first character, return 1 if they do, 0 otherwise
sub yesprompt {
	my $manual = <STDIN>;
	
	if ( ($manual =~ /^[Y]$/i) ) {
		return 1;
		} else {
			return 0;
	}
}

# Look for user to press a N in the first character, return 1 if they do, 0 otherwise
sub noprompt {
	my $manual = <STDIN>;
	
	if ( ($manual =~ /^[N]$/i) ) {
		return 1;
		} else {
			return 0;
	}
}

# This nasty little thing below here does all the install work. We merely flip a bunch of flags and call this.
# In theory, it should make maintaining things easier. I hope...
sub dothedeed {
	# And now we begin the installation madness! Whoot! Or something...
	print "\n\nBeginning installation, expect lots of output...\n\n";
	
	# Mangle the firewall appropriately
	if ($disablefirewall!=0) {
		print "Disabling firewall...\n";
		system("/usr/bin/systemctl stop firewalld");
		system("/usr/bin/systemctl disable firewalld");
	}
	
	# First we check our SVN and update as necessary
	if ($localsvn != $DBsvnrev) {
		print "\nUpdating to SVN revision $DBsvnrev...\n";
		system("/usr/bin/svn", "-r", "$DBsvnrev", "up", "/usr/src/astguiclient/trunk/", ">> /var/log/vicibox.log 2>> /var/log/vicibox.log");
		# Get the SVN version of our local copy
		@svninfo = `/usr/bin/svn info /usr/src/astguiclient/trunk | grep Revision | sed -e 's/Revision: //'`;
		$localsvn = trim($svninfo[0]);
		if ($debug==1) { print "Local SVN Revision after update : $localsvn\n"; }
		if ($localsvn != $DBsvnrev) { die "Could not update SVN to $DBsvnrev! Check your connectivity!\n"; }
		} else {
			print "Local SVN revision matches DB revision: $DBsvnrev\n";
	}
	
	# If we are a database, then we start mysql and create our database
	if ($DB==1) {
		print "Doing general DataBase requirements...\n";
		if (system("/sbin/chkconfig mariadb on >> /var/log/vicibox.log 2>> /var/log/vicibox.log")!=0) { die "Failed to enable MariaDB: $?"; }
		if (system("/sbin/service mariadb start >> /var/log/vicibox.log 2>> /var/log/vicibox.log")!=0) { die "Failed to start MariaDB: $?"; }
		$dbhVDnew = DBI->connect("DBI:mysql::localhost:$VICIport", "root", "") or die "Couldn't connect to MySQL to create database: " . DBI->errstr;
		if ($DBS==0) {
			# See if there is already a database here. If so, bomb out, something is whacky. But only if it's a master DB, slaves can get wiped out
			$stmtCHECKDB = "show databases like '$VICIdatabase';";
			$sthCHECKDB = $dbhVDnew->prepare($stmtCHECKDB) or die "Preparing stmtCHECKDB: ",$dbhVDnew->errstr;
			$sthCHECKDB->execute or die "Executing sthCHECKDB: ",$dbhVDnew->errstr;
			$sthCHECKDBrows=$sthCHECKDB->rows;
			if ($sthCHECKDBrows > 0) { die "Database already exists! Server was previously installed.\n"; }
			$sthCHECKDB->finish;
		}
		# Create the new database
		$stmtCREATE = "create database IF NOT EXISTS $VICIdatabase default character set utf8 collate utf8_unicode_ci;";
		$sthCREATE = $dbhVDnew->prepare($stmtCREATE) or die "Preparing stmtCREATE: ",$dbhVDnew->errstr;
		$sthCREATE->execute or die "Executing sthCREATE: ",$dbhVDnew->errstr;
		$sthCREATE->finish;
		# Reconnect to the new database
		$dbhVDnew->disconnect;
		$dbhVDnew = DBI->connect("DBI:mysql:$VICIdatabase:localhost:$VICIport", "root", "") or die "Couldn't reconnect to MySQL to create database tables: " . DBI->errstr;
		# Grant permissions to our database standard user
		$stmtGRANT = "GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES on $VICIdatabase.* TO $VICIuser\@'%' IDENTIFIED BY '$VICIpass';";
		$sthGRANT = $dbhVDnew->prepare($stmtGRANT) or die "Preparing stmtGRANT: ",$dbhVDnew->errstr;
		$sthGRANT->execute or die "Executing sthGRANT: ",$dbhVDnew->errstr;
		# Grant permissions to our database standard user
		$stmtGRANT = "GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES on $VICIdatabase.* TO $VICIuser\@'localhost' IDENTIFIED BY '$VICIpass';";
		$sthGRANT = $dbhVDnew->prepare($stmtGRANT) or die "Preparing stmtGRANT: ",$dbhVDnew->errstr;
		$sthGRANT->execute or die "Executing sthGRANT: ",$dbhVDnew->errstr;
		# Grant permissions to our database custom user
		$stmtGRANT = "GRANT CREATE,ALTER on $VICIdatabase.* TO $VICIcustomuser\@'localhost' IDENTIFIED BY '$VICIcustompass';";
		$sthGRANT = $dbhVDnew->prepare($stmtGRANT) or die "Preparing stmtGRANT: ",$dbhVDnew->errstr;
		$sthGRANT->execute or die "Executing sthGRANT: ",$dbhVDnew->errstr;
		# Grant permissions to our database custom user
		$stmtGRANT = "GRANT CREATE,ALTER on $VICIdatabase.* TO $VICIcustomuser\@'%' IDENTIFIED BY '$VICIcustompass';";
		$sthGRANT = $dbhVDnew->prepare($stmtGRANT) or die "Preparing stmtGRANT: ",$dbhVDnew->errstr;
		$sthGRANT->execute or die "Executing sthGRANT: ",$dbhVDnew->errstr;
		
		if ($DBS==1) {
			# We are a slave, so we do slave-type things
			print "Doing Slave-specific MySQL setup...\n";
			if (system("/usr/bin/sed -i 's+server-id = 1+server-id = $DBmysqlid+g' /etc/my.cnf")!=0) { die "Could not modify my.cnf for slave: $?"; }
			system("/sbin/service mariadb stop >> /var/log/vicibox.log 2>> /var/log/vicibox.log");
			if (system("/sbin/service mariadb start >> /var/log/vicibox.log 2>> /var/log/vicibox.log")!=0) { die "Failed to restart MySQL: $?"; }
			# release and reconnect since we restarted the server
			$dbhVDnew->disconnect;
			$dbhVDnew = DBI->connect("DBI:mysql::localhost:$VICIport", "root", "") or die "Couldn't connect to MySQL to create database: " . DBI->errstr;
			# Reset the slave so it can take fresh configs.
			$stmtSQL="stop slave;";
			$sthSQL = $dbhVDnew->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVDnew->errstr;
			$sthSQL->execute;
			$stmtSQL="reset slave;";
			$sthSQL = $dbhVDnew->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVDnew->errstr;
			$sthSQL->execute;
			$stmtSQL="CHANGE MASTER TO MASTER_HOST='$VICIDBIP', MASTER_USER='$VICIslaveuser', MASTER_PASSWORD='$VICIslavepass', MASTER_PORT=$VICIport;";
			$sthSQL = $dbhVDnew->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVDnew->errstr;
			$sthSQL->execute;
			print "\nBeginning database dump from master, this may take a while...\n\n";
			if (system("/usr/bin/mysqldump --all-database --master-data -u $VICIslaveuser -p$VICIslavepass -h $VICIDBIP -P $VICIport > /tmp/vicimaster.sql")!=0) { die "Could not get database dump from master: $?"; }
						
			# Load in our master data
			print "Beginning database load into slave, this may take a while...\n";
			if (system("/usr/bin/mysql -u root -h localhost -f < /tmp/vicimaster.sql")!=0) { die "Could not load data into slave.\n"; }
			# Just for fun, run the upgrade incase this SQL info came from an older version
			system("/usr/bin/mysql_upgrade -u root -h localhost -s");
			
			# Insert ourselves into vicibox
			if ($legacy==0) {
				$stmtSQL="INSERT INTO `vicibox` (`server`, `server_ip`, `server_type`, `field1`, `field2`, `field3`, `field4`, `field5`, `field6`, `field7`, `field8`, `field9`) VALUES ('$myname', '$VICIDBIP', 'Database', '$DBmysqlid', '$VICIdatabase', '$DBsvnrev', '$VICIuser', '$VICIpass', '$VICIcustomuser', '$VICIcustompass', '$VICIslaveuser', '$VICIslavepass');";
				$sthSQL = $dbhVD->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVDnew->errstr;
				$sthSQL->execute;
			}
			
			# Now start the slave
			$stmtSQL="start slave;";
			$sthSQL = $dbhVDnew->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVDnew->errstr;
			$sthSQL->execute;
			print "Slave loaded and started. Verify by connecting to MySQL and running 'slave show status'\n";
			
			} else {
				print "Doing Master-specific MySQL setup...\n";
				
				# Create our schema in the database
				if (system("/usr/bin/mysql $VICIdatabase -f < /usr/src/astguiclient/trunk/extras/MySQL_AST_CREATE_tables.sql")!=0) { die "Could not create database schema\n"; }
				
				# Insert ourselves into the server table if we aren't also a dialer
				if ($TEL==0) {
					my $stmtSQL="insert into servers (server_id, server_description, server_ip, active, max_vicidial_trunks, active_asterisk_server, active_agent_login_server) values ('$myname', 'DataBase Only - DO NOT DELETE', '$VICIDBIP', 'Y', '0', 'N', 'N');";
					my $sthSQL = $dbhVDnew->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVDnew->errstr;
					$sthSQL->execute;
				}
				
				# Give ourselves some more secure passwords then test!! Silly developer and users
				my $randomstring1=trim(`/usr/bin/pwgen -cns 15 1`);
				my $randomstring2=trim(`/usr/bin/pwgen -cns 15 1`);
				my $stmtSQL="update system_settings set default_phone_registration_password='$randomstring1', default_server_password='$randomstring2';";
				my $sthSQL = $dbhVDnew->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVDnew->errstr;
				$sthSQL->execute;
				
				# Now we create out vicibox table...
				$stmtSQL="CREATE TABLE IF NOT EXISTS `vicibox` (`server_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT, `server` varchar(32) NOT NULL, `server_ip` varchar(32) NOT NULL, `server_type` enum('Database','Web','Telephony','Archive') NOT NULL DEFAULT 'Telephony',`field1` varchar(64) DEFAULT NULL,`field2` varchar(64) DEFAULT NULL,`field3` varchar(64) DEFAULT NULL,`field4` varchar(64) DEFAULT NULL,`field5` varchar(64) DEFAULT NULL,`field6` varchar(64) DEFAULT NULL,`field7` varchar(64) DEFAULT NULL,`field8` varchar(64) DEFAULT NULL,`field9` varchar(64) DEFAULT NULL, PRIMARY KEY (`server_id`)) ENGINE=MyISAM DEFAULT CHARSET=latin1;";
				$sthSQL = $dbhVDnew->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVDnew->errstr;
				$sthSQL->execute;
				
				# and populate it if not legacy
				if ($legacy==0) {
					$stmtSQL="INSERT INTO `vicibox` (`server`, `server_ip`, `server_type`, `field1`, `field2`, `field3`, `field4`, `field5`, `field6`, `field7`, `field8`, `field9`) VALUES ('$myname', '$VICIDBIP', 'Database', '0', '$VICIdatabase', '$DBsvnrev', '$VICIuser', '$VICIpass', '$VICIcustomuser', '$VICIcustompass', '$VICIslaveuser', '$VICIslavepass');";
					$sthSQL = $dbhVDnew->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVDnew->errstr;
					$sthSQL->execute;
				}
				
				# Now insert the extra ViciBox stuff
				$stmtSQL="INSERT INTO `vicidial_ip_lists` VALUES ('ViciWhite','White List for ViciBox firewall ACL','N','---ALL---'), ('ViciBlack','Black List for ViciBox firewall ACL','N','---ALL---');";
				$dbhVDnew->do($stmtSQL);
				$stmtSQL = "INSERT INTO `vicidial_conf_templates` (`template_id`, `template_name`, `template_contents`, `user_group`) VALUES ('webRTC', 'VICIphone', 'type=friend\r\nhost=dynamic\r\nencryption=yes\r\navpf=yes\r\nicesupport=yes\r\ndirectmedia=no\r\ntransport=wss\r\nforce_avp=yes\r\ndtlsenable=yes\r\ndtlsverify=no\r\ndtlscertfile=/etc/certbot/live/FQDN/cert.pem\r\ndtlsprivatekey=/etc/certbot/live/FQDN/privkey.pem\r\ndtlssetup=actpass\r\nrtcp_mux=yes', '---ALL---');";
				$dbhVDnew->do($stmtSQL);
				$stmtSQL = "UPDATE system_settings set webphone_url='https://phone.viciphone.com/viciphone.php';";
				$dbhVDnew->do($stmtSQL);
				
				# Set-up the slave user stuff
				$stmtGRANT = "GRANT REPLICATION SLAVE,REPLICATION CLIENT,SELECT,RELOAD on *.* TO '$VICIslaveuser'\@'%' IDENTIFIED BY '$VICIslavepass';";
				$sthGRANT = $dbhVDnew->prepare($stmtGRANT) or die "Preparing stmtGRANT: ",$dbhVDnew->errstr;
				$sthGRANT->execute or die "Executing sthGRANT: ",$dbhVDnew->errstr;
				
				# At this point the primary should be up and good, so we set-up our normal DBI connection for later processes
				# Also a good double-check procedure that stuff works
				$dbhVD = DBI->connect("DBI:mysql:$VICIdatabase:localhost:$VICIport", "$VICIuser", "$VICIpass") or die "Couldn't connect to ViciDial database: " . DBI->errstr;
				
		}
		
	}
	
	# Do web-type things
	if ($WEB==1) {
		print "Configuring Web Server...\n";
		
		# See if we are the first webserver, left incase a restore is done it will auto-enable the audio store
		$stmtFIRSTWEB="select * from system_settings where sounds_web_server='127.0.0.1';";
		$sthFIRSTWEB = $dbhVD->prepare($stmtFIRSTWEB) or die "Preparing stmtFIRSTWEB: ",$dbhVD->errstr;
		$sthFIRSTWEB->execute or die "Executing sthFIRSTWEB: ",$dbhVD->errstr;
		$sthFIRSTWEBrows=$sthFIRSTWEB->rows;
		
		if ($sthFIRSTWEBrows > 0) {
			if ($debug==1) { print "First web server found, enabling audio store...\n"; }
			# enable the audio store
			$randomstring=trim(`pwgen -cns 32 1`);
			$stmtWEB="update system_settings set sounds_web_server='$localip', sounds_web_directory='$randomstring', sounds_central_control_active='1';";
			$sthWEB = $dbhVD->prepare($stmtWEB) or die "Preparing stmtWEB: ",$dbhVD->errstr;
			$sthWEB->execute or die "Executing sthWEB: ",$dbhVD->errstr;
			# Modify the apache configuration file for the audio store and create the directory
			system("/usr/bin/sed -i 's/WEBDIR/$randomstring/g' /etc/apache2/conf.d/audiostore.conf");
			system("/bin/mkdir /srv/www/htdocs/$randomstring");
			system("chown -R wwwrun:www /srv/www/htdocs/$randomstring");
			$audiostore=1;
			} else {
				$audiostore=0;
		}
		
		# If we are dedicated, enable bigger apache settings
		if ($DB==0 && $TEL==0) {
			if ($debug==1) { print "Dedicated Web Server Found, enabling large apache settings...\n"; }
			system("cp /usr/share/vicibox/server-tuning.conf /etc/apache2/server-tuning.conf");
		}
		
		# Do the general stuff for apache from bash where life is easier
		system("/usr/share/vicibox/vicibox-web.sh $redirect $phpmyadmin $VICIDBIP >> /var/log/vicibox.log 2>> /var/log/vicibox.log");
		
		# And finally, insert ourselves into the vicibox table if not legacy and not a restore operation
		if ($legacy==0 and $restore==0) {
			$stmtSQL="INSERT INTO `vicibox` (`server`, `server_ip`, `server_type`, `field1`, `field2`) VALUES ('$myname', '$localip', 'Web', '$extip', '$randomstring');";
			$sthSQL = $dbhVD->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVD->errstr;
			$sthSQL->execute;
		}
		system("/sbin/chkconfig apache2 on");
		system("/sbin/service apache2 restart");
	}
	
	# Telephony server stuff
	if ($TEL==1) {
		print "Configuring Telephony Server...\n";
	
		if ($restore==0) {
			# Check to make sure we aren't doing something silly like installing the same server twice, exception being a restore
			$stmtCHECKTEL = "select * from servers where server_ip='$localip' or server_ip='$extip';";
			$sthCHECKTEL = $dbhVD->prepare($stmtCHECKTEL) or die "Preparing stmtCHECKTEL: ",$dbhVD->errstr;
			$sthCHECKTEL->execute or die "Executing sthCHECKTEL: ",$dbhVD->errstr;
			$sthCHECKTELrows=$sthCHECKTEL->rows;
			if ($sthCHECKTELrows > 0) { die "Telephony server already exists! Server was previously installed.\n"; }
		}
		
		# Do the general stuff for a telephony server from bash where life is easier
		system("/usr/share/vicibox/vicibox-tel.sh >> /var/log/vicibox.log 2>> /var/log/vicibox.log");
		
		# We only run the below, which inserts us into vicidial and the vicihost table, if we aren't in restore mode
		if ($restore==0) {
			# Modify the SQL files for dialer insertionpoweroff
			if ($primarydialer==1) {
				system("/usr/bin/sed 's/10.10.10.15/$localip/g' /usr/src/astguiclient/trunk/extras/first_server_install.sql > /tmp/viciserver.sql");
				system("/bin/echo \"update system_settings set active_voicemail_server='$localip';\" >> /tmp/viciserver.sql");
				} else {
					system("/usr/bin/sed 's/10.10.10.16/$localip/g' /usr/src/astguiclient/trunk/extras/second_server_install.sql > /tmp/viciserver.sql");
			}
			
			# Modify the SQL files for hostname
			system("/usr/bin/sed -i 's/TESTast/$myname/g' /tmp/viciserver.sql");
			
			## Inject the SQL file into MySQL
			if (system("/usr/bin/mysql -u $VICIuser -p$VICIpass -P $VICIport -h $VICIDBIP $VICIdatabase -f < /tmp/viciserver.sql")!=0) { die "Could not load telephony data into master database.\n"; }
			
			
			# Do some clean-up to make things prettier on the user side
			$randomstring=trim(`/usr/bin/pwgen -cns 15 1`);
			$stmtSQL="update servers set server_description='Server $myname', asterisk_version='$astverstring', conf_secret='$randomstring', vicidial_balance_active='Y' where server_id='$myname';";
			$sthSQL = $dbhVD->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVD->errstr;
			$sthSQL->execute;
			
			
			# If we have an external IP, throw that in there too
			if ($extip ne "X") {
				$stmtSQL="update servers set external_server_ip='$extip' where server_id='$myname';";
				$sthSQL = $dbhVD->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVD->errstr;
				$sthSQL->execute;
			}
			
			# And finally, insert ourselves into the vicibox table if not legacy
			if ($legacy==0) {
				$stmtSQL="INSERT INTO `vicibox` (`server`, `server_ip`, `server_type`, `field1`) VALUES ('$myname', '$localip', 'Telephony', '$extip');";
				$sthSQL = $dbhVD->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVD->errstr;
				$sthSQL->execute;
			}
		
			} elsif ($restore==1 && $legacy==0) {
				# Update the server record with the new asterisk version in case it's different from the restore
				$stmtSQL="update servers set asterisk_version='$astverstring' where server_id='$myname';";
				$sthSQL = $dbhVD->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVD->errstr;
				$sthSQL->execute;
		}
		
		# Make sure we start on boot
		system("/sbin/chkconfig vicidial on >> /var/log/vicibox.log  2>> /var/log/vicibox.log");
		system("/sbin/chkconfig apache2 on");
		system("/sbin/service apache2 restart");
	}

	# Archive server
	if ($ARC==1) {
	
		print "Configuring Archive Server...\n";
	
		# Do our system set-up
		system("/bin/mkdir -p /home/archive/$TELarchivedir");
		system("/usr/sbin/useradd -d /home/archive -s /bin/false $TELarchiveuser");
		system("/bin/chown -R $TELarchiveuser:users /home/archive");
		system("/bin/echo -e '$TELarchivepass\n$TELarchivepass' | /usr/bin/passwd $TELarchiveuser");
		system("/sbin/chkconfig vsftpd on");
		system("/sbin/service vsftpd restart");
		system("/sbin/chkconfig apache2 on");
		system("/sbin/service apache2 restart");
		
		# And finally, insert ourselves into the vicibox table if not legacy and not a restore
		if ($legacy==0 and $restore==0) {
			$stmtSQL="INSERT INTO `vicibox` (`server`, `server_ip`, `server_type`, `field1`, `field2`, `field3`, `field4`, `field5`) VALUES ('$myname', '$TELarchiveip', 'Archive', '$TELarchiveuser', '$TELarchivepass', '$TELarchiveport', '$TELarchivedir', '$TELarchiveurl');";
			$sthSQL = $dbhVD->prepare($stmtSQL) or die "Preparing stmtSQL: ",$dbhVD->errstr;
			$sthSQL->execute;
		}
	}

	
	# All the easy stuff is over, now the big mess of stuff that is trying to figure out how to ACTUALLY install vicidial :(
	# First we build up our generic install.pl options for use later on
	$installPLstring = "--web=/srv/www/htdocs --asterisk_version=$asterisk --copy_sample_conf_files --no-prompt --server_ip=$localip --DB_database=$VICIdatabase --DB_user=$VICIuser --DB_pass=$VICIpass --DB_custom_user=$VICIcustomuser --DB_custom_pass=$VICIcustompass --DB_port=$VICIport";
	if ($debug==1) { print "Install PL String: $installPLstring\n"; }

	if ($havearchive==1) {
		# We have an archive, so Add that info to the string
		$installPLstring = $installPLstring . " --FTP_host=$TELarchiveip --FTP_user=$TELarchiveuser --FTP_pass=$TELarchivepass --FTP_port=$TELarchiveport --FTP_dir=$TELarchivedir --HTTP_path=$TELarchiveurl";
		if ($debug==1) { print "Archive found, adding info: $installPLstring\n"; }
	}
	
	if ($DB==1 && $DBS==0) {
		# We are primary DB, so connect through localhost
		$installPLstring = $installPLstring . " --DB_server=localhost";
		if ($debug==1) { print "We are Primary DB, adding info: $installPLstring\n"; }
		
		} else {
			# We are not the primary DB, so we use an IP address for database connectivity
			$installPLstring = $installPLstring . " --DB_server=$VICIDBIP";
			if ($debug==1) { print "We aren't Primary DB, adding info: $installPLstring\n"; }
	}

	# Now that our base string is built, all we are adding are the keepalives which depend on how the server's roles were selected
	if ($DB==1 && $DBS==0) {
		# We at least get the allcron and database stuff
		$needdbcron=1;
	}
	
	if ($TEL==1) {
		# We need at least the allcron and telephony stuff
		$needtelcron=1;
	}
	
	# If we have no crons, then use X for keepalives
	if ($needdbcron==0 && $needtelcron==0) {
		$installPLstring = $installPLstring . " --active_keepalives=X";
		if ($debug==1) { print "Not Database or Telephony, no cron, adding info: $installPLstring\n"; }
		
		} elsif ($needdbcron==1 && $needtelcron==0) {
			# We are a DB only, adding that info
			$installPLstring = $installPLstring . " --active_keepalives=579E";
			if ($debug==1) { print "Database only, adding info: $installPLstring\n"; }
			system("/bin/cat /usr/share/vicibox/allcron > /tmp/rootcron");
			system("/bin/cat /usr/share/vicibox/dbcron >> /tmp/rootcron");
			if ($debug==1) { print "rootcron generated, allcron and dbcron\n"; }
			
			} elsif ($needdbcron==0 && $needtelcron==1) {
				# We are a telephony server only, adding that info
				$installPLstring = $installPLstring . " --active_keepalives=123468";
				if ($debug==1) { print "Telephony only, adding info: $installPLstring\n"; }
				system("/bin/cat /usr/share/vicibox/allcron > /tmp/rootcron");
				system("/bin/cat /usr/share/vicibox/dialcron >> /tmp/rootcron");
				if ($debug==1) { print "rootcron generated, allcron and dialcron\n"; }
				
				} elsif ($needdbcron==1 && $needtelcron==1) {
					# At this point we must be both, so we set-up for both.
					$installPLstring = $installPLstring . " --active_keepalives=123456789E";
					if ($debug==1) { print "Telephony only, adding info: $installPLstring\n"; }
					system("/bin/cat /usr/share/vicibox/allcron > /tmp/rootcron");
					system("/bin/cat /usr/share/vicibox/dbcron >> /tmp/rootcron");
					system("/bin/cat /usr/share/vicibox/dialcron >> /tmp/rootcron");
					if ($debug==1) { print "rootcron generated, allcron and dbcron and dialcron\n"; }
	}
	
	if ($havearchive==1 && $TEL==1) {
		# We have an archive and are a telephony server, so we enable that in the crontab
		system("/usr/bin/sed -i 's/#2,5,8,11/2,5,8,11/' /tmp/rootcron");
	}
	
	# Ok, and away we go, installing the actual ViciDial software. Hope it works :)
	if ($debug==1) { print "Final install.pl string: $installPLstring\n"; }
	system("cd /usr/src/astguiclient/trunk && /usr/bin/perl install.pl $installPLstring  >> /var/log/vicibox.log  2>> /var/log/vicibox.log");
	if ($DB==1 && $DBS==0) { system("/usr/bin/crontab /tmp/rootcron"); }
	if ($WEB==1 || $TEL==1) { system("/usr/bin/crontab /tmp/rootcron"); }
	
	# Populate the GMT tables and what-not
	if ($DB==1 && $DBS==0) {
		if ($extip ne "X") {
			print "Loading GMT and Phone Codes...\n";
			$gmtload=system("/usr/share/astguiclient/ADMIN_area_code_populate.pl >> /var/log/vicibox.log  2>> /var/log/vicibox.log");
			if ($gmtload!=0) {
				# Looks like we couldn't obtain the area code lists, use local copies
				print "GMT and Phone Codes failed to update from internet, using local copies...\n";
				system("cp /usr/src/astguiclient/conf/phone_codes_GMT-latest-24.txt /usr/share/astguiclient");
				system("cp /usr/src/astguiclient/conf/GMT_USA_zip-latest.txt /usr/share/astguiclient");
				system("cp /usr/src/astguiclient/conf/country_ISO_TLD-latest.txt /usr/share/astguiclient");
				system("/usr/share/astguiclient/ADMIN_area_code_populate.pl --use-local-files >> /var/log/vicibox.log  2>> /var/log/vicibox.log");
			}
		} else {
			print "Loading GMT and phone codes using local copies...\n";
			system("cp /usr/src/astguiclient/conf/phone_codes_GMT-latest-24.txt /usr/share/astguiclient");
			system("cp /usr/src/astguiclient/conf/GMT_USA_zip-latest.txt /usr/share/astguiclient");
			system("/usr/share/astguiclient/ADMIN_area_code_populate.pl --use-local-copies >> /var/log/vicibox.log  2>> /var/log/vicibox.log");
		
		}
	}
	
	# Fix-up for Zoiper
	if ($WEB==1) {
		system("/usr/bin/sed -i 's/Version=1,17,0,6802/Version=2,8,0,15810/' /srv/www/htdocs/agc/webphone/zoiperweb.php");
	}
	
	# Modify sip.conf for our external IP
	if ($TEL==1 && $extip ne 'X') {
		system("/usr/bin/sed -i 's/;externip = 192.168.1.1/externip = $extip/' /etc/asterisk/sip.conf");
	}
	
	# Populate audio store if we are primary and not in restore mode
	if ($TEL==1 && $primarydialer==1 && $restore==0) {
		print "\nSeeding the audio store, this may take a while...\n";
		system("/usr/bin/perl /usr/share/astguiclient/ADMIN_audio_store_sync.pl --upload >> /var/log/vicibox.log  2>> /var/log/vicibox.log");
	}
	
	# Give some helpful output for the uninitiated
	$randomstring=trim(`/usr/bin/pwgen -cns 15 1`);
	print "\n\nPLEASE use secure passwords inside vicidial. It prevents hackers\n";
	print "and other undesirables from compromising your system and costing\n";
	print "you thousands in toll fraud and long distance. A secure password\n";
	print "Contains at least one capital letter and one number. A good example\n";
	print "of a secure password would be $randomstring.\n\n";
	print "Don't feed the black market, secure your systems properly!\n\n";
	print "System should be installed. Please type 'reboot' to cleanly load everything.\n";

}

# Set-up some default variables so we have known values to work with
$myname=hostname;
$myname=~s/[^a-zA-Z0-9_\-]//go; #Yes, someone managed to put in srv.dmn.com for the HOSTNAME, sigh
$debug=0; # Gives extra output while cluttering up the screen
$restore=0; # Whether we a restoring as a server in a cluster
$expert=0; # Hides some options that require more knowledge then the average sysadmin
$legacy=0; # prompts for cluster info instead of using auto-configuration table
$redirect=1; # We want to enable the HTML redirect by default, it's handy
$phpmyadmin=0; # phpMyAdmin is evil to the uninitiated, so it's installed through the expert mode
$DB=0;
$DBS=0;
$WEB=0;
$TEL=0;
$ARC=0;
$viciboxexpress=0;
$skipexternalip=0; # Skip the check for an External IP
$VICIDBIP = "127.0.0.1";
$VICIdatabase = "asterisk";
$VICIport = 3306;
$VICIuser = "cron";
$VICIpass = "1234";
$VICIcustomuser = "custom";
$VICIcustompass = "custom1234";
$VICIslaveuser = "slave";
$VICIslavepass = "slave1234";
$TELarchiveip = "X";
$TELarchiveuser = "cronarchive";
$TELarchivepass = "archive1234";
$TELarchiveport = "21";
$TELarchivedir = '';
$TELarchiveurl = 'http://'; # We fill it in later, but we define it now for consistencys sake
$astverstring = "1.4.44-vici";
$asterisk = "1.4";
$DBmysqlid=0; # 0 is the master, and slaves are numbered up from there
$primarydialer=1; # By default assume we are the primary dialer until proven otherwise
$havearchive=0; # We have no archive server until told differently
$disablefirewall=0;
$needdbcron=0; # Whether we should install the DB settings
$needtelcron=0; # Whether we should install the telephony settings
my $someinput; # Keep this specific to main since it's my little trash variable
my $myprompt; # Another trash variable used for user input

# Show who we are and that we mean business
print "\n\nViciBox v.10.0 Installer\n\n";



# Parse our run-times, cleaned up from matt-matt code so the rest of us can read it
$args = "";
if (defined $ARGV[0]) {
	$i=0;
	while ($#ARGV >= $i) {
		$args = "$args $ARGV[$i]";
		$i++;
	}
	if ($args =~ /--help/i) {
		print "allowed run time options:\n";
		print "  [--restore] = Restore server from a ViciBox DB entry or user-provided input\n";
		print "  [--legacy] = Force legacy mode on, usually auto-detected by the installer\n";
		print "  [--vicibox-express] = Install an all-in-one ViciBox Express server\n";
		print "  [--debug] = debug mode, shows more output, asks a few more questions\n";
		exit;
	
		} else {
			# Check for debug flag
			if ($args =~ /--debug/i) {
				$debug=1;
				print "\n----- DEBUG Enabled -----\n\n";
			}
			
			# Check for restore flag
			if ($args =~ /--restore/i) {
				$restore=1;
				print "Restore mode activated\n";
			}
			
			# Check for vicibox-express flag
			if ($args =~ /--vicibox-express/i) {
				$viciboxexpress=1;
				print "Vicibox Express mode activated\n";
			}
			
			# Check for legacy flag
			if ($args =~ /--legacy/i) {
				$legacy=1;
				print "Legacy mode activated\n";
			}
			
			# Don't check for the external IP
			if ($args =~ /--skipexternal/i) {
				$skipexternalip=1;
				$extip='X';
				debugoutput(" CLI Check External IP : No",0);
			}
	}
}

# Some output for debug
if ($debug==1) {
print "Hostname : $myname\n";
print "Default Database : $VICIdatabase\n";
print "Default DB User : $VICIuser\n";
print "Default DB Pass : $VICIpass\n";
print "Default DB Custom User : $VICIcustomuser\n";
print "Default DB Custom Pass : $VICIcustompass\n";
print "Default DB Port : $VICIport\n";
}

# Get our local IP info
$localip = &getlocalip;
if ($localip eq 'X') {
	print "Local IP address not found! Please enter the IP address to use for ViciDial on this machine\n";
	print "Local IP Address : ";
	$localip = trim(<STDIN>);
	if (&checkipv4($localip)==1) {
		die "Local IP entered is not valid: $localip\n";
	}
	} elsif ($debug==1) { print "Local IP Address : $localip\n";
}

# Get external IP while simultaneously checking for internet connection
if ($skipexternalip==0) {
	$extip = &getextip;
	if ($extip eq 'X' || &checkipv4($extip)==1) {
		if ($debug==1) { print "No external IP found! Probably not on the internet\n"; };
		$extip='X';
		} elsif ($debug==1) { 
			print "External IP Address : $extip\n";
	}
	
	} else {
		debugoutput("External IP Check disabled",0);
}

# Find the number of CPU cores for later decisions, hyper-threading skews this but ohh well
$numcpucores = trim(`grep '^processor' /proc/cpuinfo | sort -u | wc -l`);
if ($debug==1) { print "Number of CPU Cores: $numcpucores\n" };

# Find out how much memory we got
$ram = (`cat /proc/meminfo |  grep "MemTotal" | awk '{print \$2}'`);
if ($debug==1) { print "System Ram in kBytes: $ram\n" };

# Get the admin.php version even though the SVN version is MUCH more important
($buildver, $adminver) = &adminphp;

# Grab our local asterisk version and dynamically use that info
my @astverARY=split(' ', trim(`/usr/sbin/asterisk -V`));
$astverstring = &trim($astverARY[1]);
if ( $astverstring =~ m/^1.4/ ) { if ($debug==1) { print "Asterisk v.1.4 found!\n"; } $asterisk='1.4'; }
if ( $astverstring =~ m/^1.8/ ) { if ($debug==1) { print "Asterisk v.1.8 found!\n"; } $asterisk='1.8'; }
if ( $astverstring =~ m/^11./ ) { if ($debug==1) { print "Asterisk v.11 found!\n"; } $asterisk='11'; }
if ( $astverstring =~ m/^13./ ) { if ($debug==1) { print "Asterisk v.13 found!\n"; } $asterisk='13'; }
if ( $astverstring =~ m/^16./ ) { if ($debug==1) { print "Asterisk v.16 found!\n"; } $asterisk='16'; }

# Get the SVN version of our local copy
@svninfo = `/usr/bin/svn info /usr/src/astguiclient/trunk | grep Revision | sed -e 's/Revision: //'`;
$localsvn = trim($svninfo[0]);
if ($debug==1) { print "Local SVN Revision : $localsvn\n"; }

# See if we have external connectivity and get more info
if ( $extip ne "X") {
	@svninfo = `/usr/bin/svn info svn://svn.eflo.net:3690/agc_2-X/trunk | grep Revision | sed -e 's/Revision: //'`;
	$svnhead = trim($svninfo[0]);
	if ($debug==1) { print "Head SVN Revision : $svnhead\n"; }
	} else {
		$svnhead="X";
		if ($debug==1) { print "Not connected to internet, SVN head unavailable\n"; }
}

if ($restore==1) {
	# We are restoring a server from a cluster, so we do that here.
	print "\nThis will attempt to restore a missing server in a cluster using the\n";
	print "information found in the primary database or as supplied by the user.\n";
	print "What this will NOT restore is a database or a ViciBox express install.\n";
	print "The restore option is primarily designed to allow for a more graceful\n";
	print "replacement of web servers, telephony servers, and archive servers. It\n";
	print "is NOT a substitute for having a proper back-up method and emergency\n";
	print "procedures in place. It is mean't merely as a time-saving tool to use.\n";
	print "\nThis server should be attached in it's production network environment\n";
	print "prior to attempting a restore. Otherwise the restore will fail. This means\n";
	print "that the server has the SAME IP address as it's entry in the vicibox table\n";
	print "and/or the ViciBox cluster.\n";
	
	print "\n\nDo you want to continue with the ViciBox restore? [y/N] :";
	$myprompt = &yesprompt;
	if ($myprompt==0) { exit; }
		
	# Prompt for IP address to use if we don't have one
	if ( $localip eq "X") {
		print "\nAn internal IP address could not be found on the system.\n";
		print "Please enter the IP address to use for this server : ";
		$someinput = trim(<STDIN>);
		if ( &checkipv4($someinput)==1 ) {
			die "That is not a valid IP address : $someinput\n";
			} else {
				$localip = $someinput;
		}
		
		} else {
			print "\nThe Internal IP address found was $localip.\n";
			print "Do you want to use this IP address for ViciDial? [Y/n] : ";
			$myprompt = &noprompt;
			if ($myprompt==1) {
				print "Please enter the IP address to use for this server : ";
				$someinput = trim(<STDIN>);
				if ( &checkipv4($someinput)==1 ) {
					die "That is not a valid IP address : $someinput\n";
					} else {
						$localip = $someinput;
				}
			}
	}


	print "\nPlease input the master database IP address (127.0.0.1) : ";
	$someinput = trim(<STDIN>);
	if (length($someinput)>3) { $VICIDBIP = $someinput; }
	if (&checkipv4($VICIDBIP)!=0) {
		exit 1;
	}
	print "Do you want to connect using the default ViciDial DB settings? [Y/n] : ";
	$myprompt=&noprompt;
	if ($myprompt==0) {
		# Try connecting with default user cron and password 1234
			$dbhVD = DBI->connect("DBI:mysql:$VICIdatabase:$VICIDBIP:$VICIport", "$VICIuser", "$VICIpass") or die "Couldn't connect to ViciDial database: " . DBI->errstr;
			$dbhVDC = DBI->connect("DBI:mysql:$VICIdatabase:$VICIDBIP:$VICIport", "$VICIcustomuser", "$VICIcustompass") or die "Couldn't connect as custom user to ViciDial database. Check permissions: " . DBI->errstr;
			if ($debug==1) { print "Database Connectivity checks good\n"; }
		} else {
			# Ask what user info to use for the DB and try to connect
			print "Please enter the database information below\n";
			print "DB Username ($VICIuser) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>=3) { $VICIuser = $someinput; }
			print "DB Password ($VICIpass) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>=3) { $VICIpass = $someinput; }
			print "DB Name ($VICIdatabase) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>=3) { $VICIdatabase = $someinput; }
			print "DB Custom Username ($VICIcustomuser) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>=3) { $VICIcustomuser = $someinput; }
			print "DB Custom Password ($VICIcustompass) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>=3) { $VICIcustompass = $someinput; }
			print "DB Port ($VICIport) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIport = $someinput; }
			$dbhVD = DBI->connect("DBI:mysql:$VICIdatabase:$VICIDBIP:$VICIport", "$VICIuser", "$VICIpass") or die "Couldn't connect to ViciDial database: " . DBI->errstr;
			$dbhVDC = DBI->connect("DBI:mysql:$VICIdatabase:$VICIDBIP:$VICIport", "$VICIcustomuser", "$VICIcustompass") or die "Couldn't connect as custom user to ViciDial database. Check permissions: " . DBI->errstr;
			if ($debug==1) { print "Database Connectivity checks good\n"; }
	}
	
	# Now we check to see if we are a vicibox v.4.0+ install so we can suck in settings or enable legacy mode (yay?)
	$stmtVBOXcheck = "show tables like 'vicibox';";
	$sthVBOXcheck = $dbhVD->prepare($stmtVBOXcheck) or die "Preparing stmtVBOXcheck: ",$dbhVD->errstr;
	$sthVBOXcheck->execute or die "Executing sthVBOXcheck: ",$dbhVD->errstr;
	$sthVBOXcheckrows = $sthVBOXcheck->rows;
	if ($sthVBOXcheckrows > 0) {
		if ($debug==1) { print "ViciBox table found\n"; }
		# We found a vicibox table, so now lets make sure there's good info in it!
		# If the info doesn't match, then we enable expert mode and all bets are off
		$stmtVBOXverify = "select field1,field3,field8,field9 from vicibox where server_type='Database' and server_ip IN ('$VICIDBIP', '127.0.0.1') and field1='0';";
		$sthVBOXverify = $dbhVD->prepare($stmtVBOXverify) or die "Preparing stmtVBOXverify: ",$dbhVD->errstr;
		$sthVBOXverify->execute or die "Executing sthVBOXverify: ",$dbhVD->errstr;
		$sthVBOXverifyrows = $sthVBOXverify->rows;
		if ($sthVBOXverifyrows < 1) {
			print "Database entry does not match settings supplied! Enabling legacy mode!\n";
			print "Please verify all data before continuing! Installing on a cluster that\n";
			print "is already set-up can cause irreparable damage! You have been warned.\n";
			$legacy=1;

			} else {
				# Looks like we got results, so load our settings from the primary DB
				@aryVBOXverify = $sthVBOXverify->fetchrow_array;
				$DBsvnrev = $aryVBOXverify[1];
				if ($debug==1) {
					print "DB SVN rev : $DBsvnrev\n";
				}
		}
		} elsif ($legacy==0) {
			print "ViciBox table not found, legacy mode enabled!\n";
			$legacy=1;
	}

	if ($legacy==0) {
		# Look up this server's IP from the vicihost tables
		$stmtVBOXlookup = "select server_type,field1,field2,field3,field4,field5,field6,field7,field8,field9 from vicibox where server_ip='$localip';";
		$sthVBOXlookup = $dbhVD->prepare($stmtVBOXlookup) or die "Preparing stmtVBOXlookup: ",$dbhVD->errstr;
		$sthVBOXlookup->execute or die "Executing sthVBOXlookup: ",$dbhVD->errstr;
		$sthVBOXlookuprows=$sthVBOXlookup->rows;
		if ($sthVBOXlookuprows>0) {
			# Found something, suck in the first result and process
			while (@aryVBOXlookup=$sthVBOXlookup->fetchrow_array()) {
				$server_type=$aryVBOXlookup[0];
				$field1=$aryVBOXlookup[1];
				$field2=$aryVBOXlookup[2];
				$field4=$aryVBOXlookup[4];
				$field5=$aryVBOXlookup[5];
				
				if ($server_type eq 'Database') { die "The restore option cannot be used for databases at this time"; }
			
				if ($server_type eq 'Web') {
					$WEB=1;
					print "Web server entry found\n";
					print "---> Install Redirect Page? [y/N] : ";
					$redirect = &yesprompt;
					print "---> Install phpMyAdmin ? [y/N] : ";
					$phpmyadmin = &yesprompt;
				}
			
				if ($server_type eq 'Telephony') {
					$TEL=1;
					print "Telephony server entry found\n";
					$primarydialer=0;
					
					# See if we have an archive server listed and suck in those settings
					$stmtVBOXtelarc = "select server_ip,field1,field2,field3,field4,field5 from vicibox where server_type='Archive';";
					$sthVBOXtelarc = $dbhVD->prepare($stmtVBOXtelarc) or die "Preparing stmtVBOXtelarc: ",$dbhVD->errstr;
					$sthVBOXtelarc->execute or die "Executing sthVBOXtelarc: ",$dbhVD->errstr;
					$sthVBOXtelarcrows = $sthVBOXtelarc->rows;
					if ($sthVBOXtelarcrows > 0) {
						# We found an archive server! Suck in those settings too
						@aryVBOXtelarc = $sthVBOXtelarc->fetchrow_array;
						$TELarchiveip = $aryVBOXtelarc[0];
						$TELarchiveuser = $aryVBOXtelarc[1];
						$TELarchivepass = $aryVBOXtelarc[2];
						$TELarchiveport = $aryVBOXtelarc[3];
						$TELarchivedir = $aryVBOXtelarc[4];
						$TELarchiveurl = $aryVBOXtelarc[5];
						if ($debug==1) {
							print "Archive IP : $TELarchiveip\n";
							print "Archive user : $TELarchiveuser\n";
							print "Archive pass : $TELarchivepass\n";
							print "Archive port : $TELarchiveport\n";
							print "Archive directory : $TELarchivedir\n";
							print "Archive URL : $TELarchiveurl\n";
						}
						$havearchive=1;
						} else {
							print "No Archive server found in provisioning table\n";
					}
					
				}
				
				if ($server_type eq 'Archive') {
					$ARC=1;
					print "Archive server entry found\n";
					$TELarchivedir=$field4;
					$TELarchiveuser=$field1;
					$TELarchivepass=$field2;
					$TELarchiveurl=$field5;
				}
				
			}
		
			} else {
				# Ask our legacy questions
				die "\n\nA server with IP $localip could not be located in the vicibox table!\nPerhaps the server has the wrong IP, try again.";
		}
		
		} else {
			# ask our legacy question
			print "\nLegacy mode has been enable with a restore. Extra care must be taken to\n";
			print "make sure that the server being restored exists. If you are trying to add a\n";
			print "new server then you should not be using the restore option at all.\n";
			
			print "\nWill this server be used as a Web server? [y/N] : ";
			$WEB = &yesprompt;

			# If we are a web server and an expert, we get more questions!
			if ($WEB==1) {
				print "---> Install Redirect Page? [y/N] : ";
				$redirect = &yesprompt;
				print "---> Install phpMyAdmin ? [y/N] : ";
				$phpmyadmin = &yesprompt;
			}
			
			print "\nWill this server be used as a Telephony server? [y/N] : ";
			$TEL = &yesprompt;
			
			if ($TEL==1) {
				print "---> Do you have an archive server? [y/N] : ";
				$havearchive = &yesprompt;
				if ($havearchive==1) {
					# Ask for user input for archive server
					print "Archive server IP : ";
					$TELarchiveip = trim(<STDIN>);
					if ( &checkipv4($TELarchiveip)==1) { die "Not a valid archive IP\n"; }
					print "Archive FTP User ($TELarchiveuser) : ";
					$someinput = trim(<STDIN>);
					if (length($someinput)>3) { $TELarchiveuser = $someinput; }
					print "Archive FTP Password ($TELarchivepass) : ";
					$someinput = trim(<STDIN>);
					if (length($someinput)>3) { $TELarchivepass = $someinput; }
					print "Archive FTP Port : ";
					$TELarchiveport = trim(<STDIN>);
					print "Archive FTP Directory : ";
					$TELarchivedir = trim(<STDIN>);
					print "Archive URL : ";
					$TELarchiveurl = trim(<STDIN>);
				}
			}
		
			print "\nWill this server be used as an Archive server? [y/N] : ";
			$ARC = &yesprompt;
			
			if ($ARC==1) {
				print "Archive FTP User ($TELarchiveuser) : ";
				$someinput = trim(<STDIN>);
				if (length($someinput)>3) { $TELarchiveuser = $someinput; }
				print "Archive FTP Password ($TELarchivepass) : ";
				$someinput = trim(<STDIN>);
				if (length($someinput)>3) { $TELarchivepass = $someinput; }
			}
		}

		print "\nDo you want to disable the built-in firewall? [y/N] : ";
		$myprompt=&yesprompt;
		if ($myprompt==1) { $disablefirewall=1; }

		
	# Determine the SVN version assuming that we are in legacy mode
	if ($legacy==1) {
	print "\nThe local SVN is build $buildver version $adminver from SVN $localsvn\n";
	if ( $extip ne "X") {
		print "Do you want to use the ViciDial version listed above? [Y/n] : ";
		$uselocalsvn = &yesprompt;
		if ($uselocalsvn==0) {
			print "Do you want to use the latest SVN version $svnhead? [Y/n] : ";
			$usesvnhead = &yesprompt;
			if ($usesvnhead==0) {
				print "Please enter the SVN revision to use : ";
				$usersvnrev = trim(<STDIN>);
				if ($usersvnrev > $svnhead) {
					die "The is not a valid SVN revision\n";
					} else {
						$DBsvnrev = $usersvnrev;
				}
				} else {
					$DBsvnrev = $svnhead;
			}
			} else {
				$DBsvnrev = $localsvn;
		}
		} else {
	print "Internet connectivity was not detected. If the above version of ViciDial\n";
	print "is not correct then you will need to transfer the correct version to the\n";
	print "directory /usr/share/astguiclient/trunk. If this is an all-in-one ViciBox\n";
	print "Express installation then you can disregard this message\n\n";
	}

	} elsif ($legacy==0 && $DB==0 && $DBsvnrev != $localsvn && $extip eq "X") {
		print "The SVN revision installed on the database is $DBsvnrev. The local SVN version\n";
		print "is $localsvn. Unfortunately no internet connection was detected so the install\n";
		print "can not continue. Please copy the SVN version of ViciDial from the database to\n";
		print "this machine to complete the installation or connect this machine to the internet.\n";
		die "Local SVN revision does not match database SVN revision and cannot update to it\n";
		
		} elsif ($legacy==0 && $DB==0 && $DBsvnrev != $localsvn && $extip ne "X") {
			if ($debug==1) { print "The database SVN revision is $DBsvnrev. This system will be updated to that revision\n"; }
			
			} elsif ($DB==1 && $DBS==0 && $extip eq "X") {
				# We are a database, that is not slave, without internets, we use the local SVN copy
				if ($debug==1) { print "Internet connectivity not found, using local SVN revision $localsvn.\n"; }
				$DBsvnrev = $localsvn;
				
				} elsif ($DB==1 && $DBS==0 && $extip ne "X") {
					# We are a database, that is not slave, with internets, we use the head SVN copy
					if ($debug==1) { print "Internet connectivity found, using head SVN revision $svnhead.\n"; }
					$DBsvnrev = $svnhead;
					
					} else {
						# At this point all hell has broken loose, cats and dogs sleeping together, mass hysteria
						# So we just give generic output and hope for the best
						if ($debug==1) { print "The database SVN revision is $DBsvnrev. This system will be updated to that revision\n"; }
	}
	
	# Summary output
	print "\n\n---  ViciBox v.10.0 Restore Summary  ---\n\n";
	if ($legacy==1) { print "Legacy   : Yes\n"; } else { print "Legacy   : No\n"; }
	if ($WEB==1) { print "Web      : Yes\n"; } else { print "Web      : No\n"; }
	if ($WEB==1 && $expert==1) {
		if ($redirect==1) { print "Redirect : Yes\n"; } else { print "Redirect : No\n"; }
		if ($phpmyadmin==1) { print "PMA      : Yes\n"; } else { print "PMA      : No\n"; }
	}
	if ($TEL==1) { print "Telephony: Yes\n"; } else { print "Telephony: No\n"; }
	if ($TEL==1 && $legacy==1) {
		if ($havearchive==1) { print "Have Arch: Yes\n"; } else { print "Have Arch: No\n"; }
	}
	if ($ARC==1) { print "Archive  : Yes\n"; } else { print "Archive  : No\n"; }
	if ($disablefirewall==0) {
		print "Firewall : Enabled\n";
		} else {
			print "Firewall : Disabled\n";
	}

	print "\n---  Configuration Information  ---\n";
	print "-  Database  -\n";
	print "SVN Rev  : $DBsvnrev\n";
	print "IP Addr  : $VICIDBIP\n";
	print "Name     : $VICIdatabase\n";
	print "User     : $VICIuser\n";
	print "Password : $VICIpass\n";
	print "Cust User: $VICIcustomuser\n";
	print "Cust Pass: $VICIcustompass\n";
	print "Port     : $VICIport\n";
	
	if ($TEL==1 && $havearchive==1) {
		print "\n- Archive -\n";
		print "IP Addr  : $TELarchiveip\n";
		print "User     : $TELarchiveuser\n";
		print "Password : $TELarchivepass\n";
		print "Port     : $TELarchiveport\n";
		print "Directory: $TELarchivedir\n";
		print "URL      : $TELarchiveurl\n";
	}

print "\n\nPlease verify the above information before continuing!\n";
print "Do you want to continue the restoration? [y/N] : ";
$myprompt = &yesprompt;

# Now either do the restore, or just exit out
if ($myprompt==1) { dothedeed; exit; } else { exit; }

}

# Vicibox Express stuff
if ($viciboxexpress==1) {
	# Disclaimer and BS goes here
	print "\nThis will install ViciBox in \"Express\" mode. This will result in a\n";
	print "single server installation performing all roles of the ViciDial Call\n";
	print "Center Suite. This is the simplest method of installation and generally\n";
	print "suitable for use with 20 agents or less. Recommended server specifications\n";
	print "are Quad-Core CPU, 4GB of ram or more, two 500-GB enterprise-class SATA hard\n";
	print "drives in RAID1. Software RAID can be configured through the partitioner\n";
	print "during installation as well as hardware RAID cards.\n";
	print "\nTo continue beyond this point will be destructive to the installed system.\n";
	
	print "\n\nDo you want to continue with the ViciBox Express install? [y/N] :";
	$myprompt = &yesprompt;
	if ($myprompt==0) { exit; }
	
	# Set a bunch of variables and install, most of which are defaults except for server roles
	$TEL=1;
	$DB=1;
	$WEB=1;
	# If we detect internet connectivity, update from SVN, otherwise use local copy
	if ($extip ne "X") {
		$DBsvnrev = $svnhead;
		} else {
			$DBsvnrev = $localsvn;
	}
	dothedeed;

} else {

# Disclaimer and BS goes here
print "\nThe installer will ask questions based upon the role that this server is\n";
print "to provide for the ViciBox Call Center Suite. You should have the database\n";
print "and optionally archive servers setup prior to installing any other servers.\n";
print "The installer will not run without there being a configured database! If this\n";
print "server is to be the database then it must be installed before the archive server\n";
print "Verify that all servers are connected to the same network and have connectivity\n";
print "to each other before continuing. This installer will be destructive to the the\n";
print "server if it is run.\n";

# So we get the nitty gritty out of the way and ask if they want to continue installing
print "\n\nDo you want to continue with the ViciBox install? [y/N] : ";
$myprompt = &yesprompt;
if ($myprompt==0) { exit; }
	
print "\nDo you want to enable expert installation? [y/N] : ";
$expert = &yesprompt;

if ($debug==1) {
print "\nDo you want to enable legacy install support? [y/N] : ";
$legacy = &yesprompt;
}

# Prompt for IP address to use if we don't have one
if ( $localip eq "X") {
	print "\nAn internal IP address could not be found on the system.\n";
	print "Please enter the IP address to use for this server : ";
	$someinput = trim(<STDIN>);
	if ( &checkipv4($someinput)==1 ) {
		die "That is not a valid IP address : $someinput\n";
		} else {
			$localip = $someinput;
	}
	} else {
		print "\nThe Internal IP address found was $localip.\n";
		print "Do you want to use this IP address for ViciDial? [Y/n] : ";
		$myprompt = &noprompt;
		if ($myprompt==1) {
			print "Please enter the IP address to use for this server : ";
			$someinput = trim(<STDIN>);
			if ( &checkipv4($someinput)==1 ) {
				die "That is not a valid IP address : $someinput\n";
				} else {
					$localip = $someinput;
			}
		}
}


print "\nWill this server be used as the Database? [y/N] : ";
$DB = &yesprompt;

# If we are an expert and a database, see if we are a slave server
if ($DB==1 && $expert==1) {
	print "---> Will this be a Slave Databse? [y/N] : ";
	$DBS = &yesprompt;
}


# Get the DB info and set-up our mysql connections for further fun
# This is all the DB related things to do when we are NOT the primary database
if ($DB==0 || ($DB==1 && $DBS==1)) {
	print "\nPlease input the master database IP address ($localip) : ";
	$someinput = trim(<STDIN>);
	if (length($someinput)>3) { $VICIDBIP = $someinput; } else { $VICIDBIP=$localip; }
	if (&checkipv4($VICIDBIP)!=0) {
		die "Not a valid database IP\n";
	}
	print "Do you want to connect using the default ViciDial DB settings? [Y/n] : ";
	$myprompt=&noprompt;
	if ($myprompt==0) {
		# Try connecting with default user cron and password 1234
			$dbhVD = DBI->connect("DBI:mysql:$VICIdatabase:$VICIDBIP:$VICIport", "$VICIuser", "$VICIpass") or die "Couldn't connect to ViciDial database: " . DBI->errstr;
			$dbhVDC = DBI->connect("DBI:mysql:$VICIdatabase:$VICIDBIP:$VICIport", "$VICIcustomuser", "$VICIcustompass") or die "Couldn't connect as custom user to ViciDial database. Check permissions: " . DBI->errstr;
			if ($debug==1) { print "Database Connectivity checks good\n"; }
		} else {
			# Ask what user info to use for the DB and try to connect
			print "Please enter the database information below\n";
			print "DB Username ($VICIuser) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIuser = $someinput; }
			print "DB Password ($VICIpass) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIpass = $someinput; }
			print "DB Name ($VICIdatabase) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIdatabase = $someinput; }
			print "DB Custom Username ($VICIcustomuser) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIcustomuser = $someinput; }
			print "DB Custom Password ($VICIcustompass) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIcustompass = $someinput; }
			print "DB Port ($VICIport) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIport = $someinput; }
			$dbhVD = DBI->connect("DBI:mysql:$VICIdatabase:$VICIDBIP:$VICIport", "$VICIuser", "$VICIpass") or die "Couldn't connect to ViciDial database: " . DBI->errstr;
			$dbhVDC = DBI->connect("DBI:mysql:$VICIdatabase:$VICIDBIP:$VICIport", "$VICIcustomuser", "$VICIcustompass") or die "Couldn't connect as custom user to ViciDial database. Check permissions: " . DBI->errstr;
			if ($debug==1) { print "Database Connectivity checks good\n"; }
	}
	
	# Now we check to see if we are a vicibox v.4.0+ install so we can suck in settings or enable legacy mode (yay?)
	$stmtVBOXcheck = "show tables like 'vicibox';";
	$sthVBOXcheck = $dbhVD->prepare($stmtVBOXcheck) or die "Preparing stmtVBOXcheck: ",$dbhVD->errstr;
	$sthVBOXcheck->execute or die "Executing sthVBOXcheck: ",$dbhVD->errstr;
	$sthVBOXcheckrows = $sthVBOXcheck->rows;
	if ($sthVBOXcheckrows > 0) {
		if ($debug==1) { print "ViciBox table found\n"; }
		# We found a vicibox table, so now lets make sure there's good info in it!
		# If the info doesn't match, then we enable expert mode and all bets are off
		$stmtVBOXverify = "select field1,field3,field8,field9 from vicibox where server_type='Database' and server_ip IN ('$VICIDBIP', '127.0.0.1') and field1='0';";
		$sthVBOXverify = $dbhVD->prepare($stmtVBOXverify) or die "Preparing stmtVBOXverify: ",$dbhVD->errstr;
		$sthVBOXverify->execute or die "Executing sthVBOXverify: ",$dbhVD->errstr;
		$sthVBOXverifyrows = $sthVBOXverify->rows;
		if ($sthVBOXverifyrows < 1) {
			print "Database entry does not match settings supplied! Enabling legacy mode!\n";
			print "Please verify all data before continuing! Installing on a cluster that\n";
			print "is already set-up can cause irreparable damage! You have been warned.\n";
			$legacy=1;

			} else {
				# Looks like we got results, so load our settings from the primary DB
				@aryVBOXverify = $sthVBOXverify->fetchrow_array;
				$DBmysqlid = $aryVBOXverify[0];
				$DBsvnrev = $aryVBOXverify[1];
				$VICIslaveuser = $aryVBOXverify[2];
				$VICIslavepass = $aryVBOXverify[3];
				if ($debug==1) {
					print "DB SVN rev : $DBsvnrev\n";
					print "DB Slave user : $VICIslaveuser\n";
					print "DB Slave pass : $VICIslavepass\n";
				}
				if ($legacy==1) {
					print "ViciBox v.4.0+ cluster info found! Recommend disabling legacy mode.\n";
					print "If you do not have a strong reason for enabling legacy mode, disable it.\n";
					print "Would you like to disable legacy mode? [Y/n] : ";
					$menuprompt = &noprompt;
					if ($menuprompt==0) { $legacy=0; }
				}
		}
		} elsif ($legacy==0) {
			print "ViciBox table not found, legacy mode enabled!\n";
			$legacy=1;
	}
		
	# Since we are a slave, and we are working with a legacy vicibox cluster, we need more options
	if ($DBS==1 && $legacy==1) {
		print "Please enter the MySQL Slave ID to use : ";
		$DBmysqlid = trim(<STDIN>);
		if ($DBmysqlid<2 or $DBmysqlid>10) {
			print "\n\nPlease enter a valid slave id that is 2 through 10.\n";
			exit;
		}
		print "Please make sure that the 'replication' priviledge is granted to\n";
		print "the DB user before continuing. If not then the replication will fail.\n";
	} elsif ($DBS==1) {
		# We are a slave, but we have vicibox info, so figure out what server ID to use
		$stmtVBOXmysqlid = "select field1 from vicibox where server_type='Database' order by field1 desc limit 1;";
		$sthVBOXmysqlid = $dbhVD->prepare($stmtVBOXmysqlid) or die "Preparing stmtVBOXmysqlid: ",$dbhVD->errstr;
		$sthVBOXmysqlid->execute or die "Executing sthVBOXmysqlid: ",$dbhVD->errstr;
		$sthVBOXmysqlidrows = $sthVBOXmysqlid->rows;
		if ($sthVBOXmysqlidrows > 0) {
			# We have records, so get it and set our ID
			@aryVBOXmysqlid = $sthVBOXmysqlid->fetchrow_array;
			$oldvalue = $aryVBOXmysqlid[0];
			if ($debug==1) { print "MySQL old ID : $oldvalue\n"; }
			if ($oldvalue==0) { $DBmysqlid = $oldvalue+2; } else { $DBmysqlid = $oldvalue+1; } #
			if ($debug==1) { print "MySQL ID : $DBmysqlid\n"; }
		}
	}
	} elsif ($DB==1 && $DBS==0) {
		# Since we are a primary DB, use the user-selected IP for the DB IP
		$VICIDBIP=$localip;
		# Since we are a primary DB, see if we want to use the default ViciDial DB credentials
		print "Do you want to use the default ViciDial DB settings? [Y/n] : ";
		$myprompt=&noprompt;
		if ($myprompt==1) {
			print "Please enter the database information below\n";
			print "DB Username ($VICIuser) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIuser = $someinput; }
			print "DB Password ($VICIpass) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIpass = $someinput; }
			print "DB Name ($VICIdatabase) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIdatabase = $someinput; }
			print "DB Custom Username ($VICIcustomuser) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIcustomuser = $someinput; }
			print "DB Custom Password ($VICIcustompass) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIcustompass = $someinput; }
			print "DB Port ($VICIport) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIport = $someinput; }
			print "DB Slave User ($VICIslaveuser) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIslaveuser = $someinput; }
			print "DB Slave Pass ($VICIslavepass) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $VICIslavepass = $someinput; }
		}
}

print "\nWill this server be used as a Web server? [y/N] : ";
$WEB = &yesprompt;

# If we are a web server and an expert, we get more questions!
if ($WEB==1 && $expert==1) {
	print "---> Install Redirect Page? [y/N] : ";
	$redirect = &yesprompt;
	print "---> Install phpMyAdmin ? [y/N] : ";
	$phpmyadmin = &yesprompt;
}

print "\nWill this server be used as a Telephony server? [y/N] : ";
$TEL = &yesprompt;

# If we are legacy and telephony then ask more questions
if ($TEL==1 && $legacy==1 && $DB==0) {
	print "---> Is this the first server in a cluster? [y/N] : ";
	$primarydialer = &yesprompt;
	print "---> Do you have an archive server? [y/N] : ";
	$havearchive = &yesprompt;
	if ($havearchive==1) {
		# Ask for user input for archive server
		print "Archive server IP : ";
		$TELarchiveip = trim(<STDIN>);
		if ( &checkipv4($TELarchiveip)==1) { die "Not a valid archive IP\n"; }
		print "Archive FTP User : ";
		$TELarchiveuser = trim(<STDIN>);
		print "Archive FTP Password : ";
		$TELarchivepass = trim(<STDIN>);
		print "Archive FTP Port : ";
		$TELarchiveport = trim(<STDIN>);
		print "Archive FTP Directory : ";
		$TELarchivedir = trim(<STDIN>);
		print "Archive URL : ";
		$TELarchiveurl = trim(<STDIN>);
	}

	} elsif ($TEL==1 && $legacy==0 && $DB==0) {
		# We are a telephony server, and not in legacy mode, so we suck in our settings from vicibox
		$stmtVBOXtelct = "select server from vicibox where server_type='Telephony';";
		$sthVBOXtelct = $dbhVD->prepare($stmtVBOXtelct) or die "Preparing stmtVBOXtelct: ",$dbhVD->errstr;
		$sthVBOXtelct->execute or die "Executing sthVBOXtelct: ",$dbhVD->errstr;
		$sthVBOXtelctrows = $sthVBOXtelct->rows;
		if ($sthVBOXtelctrows > 0 ) {
			$primarydialer=0;
			if ($debug==1) { print "We are not the first dialer, there are $sthVBOXtelctrows others\n"; }
			} else {
				if ($debug==1) { print "We are the first dialer\n"; }
		}
		
		# See if we have an archive server listed and suck in those settings
		$stmtVBOXtelarc = "select server_ip,field1,field2,field3,field4,field5 from vicibox where server_type='Archive';";
		$sthVBOXtelarc = $dbhVD->prepare($stmtVBOXtelarc) or die "Preparing stmtVBOXtelarc: ",$dbhVD->errstr;
		$sthVBOXtelarc->execute or die "Executing sthVBOXtelarc: ",$dbhVD->errstr;
		$sthVBOXtelarcrows = $sthVBOXtelarc->rows;
		if ($sthVBOXtelarcrows > 0) {
			# We found an archive server! Suck in those settings too
			@aryVBOXtelarc = $sthVBOXtelarc->fetchrow_array;
			$TELarchiveip = $aryVBOXtelarc[0];
			$TELarchiveuser = $aryVBOXtelarc[1];
			$TELarchivepass = $aryVBOXtelarc[2];
			$TELarchiveport = $aryVBOXtelarc[3];
			$TELarchivedir = $aryVBOXtelarc[4];
			$TELarchiveurl = $aryVBOXtelarc[5];
			if ($debug==1) {
				print "Archive IP : $TELarchiveip\n";
				print "Archive user : $TELarchiveuser\n";
				print "Archive pass : $TELarchivepass\n";
				print "Archive port : $TELarchiveport\n";
				print "Archive directory : $TELarchivedir\n";
				print "Archive URL : $TELarchiveurl\n";
			}
			$havearchive=1;
			} else {
				print "No Archive server found in provisioning table\n";
		}
}

print "\nWill this server be used as an Archive server? [y/N] : ";
$ARC = &yesprompt;

# And now we do some archive server set-up
if ($ARC==1) {
	if ($havearchive==1) { die "Archive server already found! Can't set-up two.\n"; }
	# Some defaults generated from the above messes
	$TELarchiveurl = "http://" . $localip . "/archive/";
	$TELarchiveip = $localip;
	
	if ($legacy==0 && $DB==0) {
		# Check to see if we already have an archive server defined in non-legacy mode and we aren't the DB
		$stmtVBOXtelarc = "select server_ip,field1,field2,field3,field4,field5 from vicibox where server_type='Archive';";
		$sthVBOXtelarc = $dbhVD->prepare($stmtVBOXtelarc) or die "Preparing stmtVBOXtelarc: ",$dbhVD->errstr;
		$sthVBOXtelarc->execute or die "Executing sthVBOXtelarc: ",$dbhVD->errstr;
		$sthVBOXtelarcrows = $sthVBOXtelarc->rows;
		if ($sthVBOXtelarcrows > 0) { die "Archive server found! Can't set-up two.\n"; }
	}
	
	if ($legacy==1 || $expert==1) {
		# Ask for user input for archive server
		print "Archive server IP ($TELarchiveip) : ";
		$someinput = trim(<STDIN>);
		if (length($someinput)>3) { $TELarchiveip = $someinput; }
		if ( &checkipv4($TELarchiveip)==1) { die "Not a valid archive IP\n"; }
		print "Archive FTP User ($TELarchiveuser) : ";
		$someinput = trim(<STDIN>);
		if (length($someinput)>3) { $TELarchiveuser = $someinput; }
		print "Archive FTP Password ($TELarchivepass) : ";
		$someinput = trim(<STDIN>);
		if (length($someinput)>3) { $TELarchivepass = $someinput; }
		print "Archive FTP Port ($TELarchiveport) : ";
		$someinput = trim(<STDIN>);
		if (length($someinput)>3) { $TELarchiveport = $someinput; }
		print "Archive FTP Directory ($TELarchivedir) : ";
		$someinput = trim(<STDIN>);
		if (length($someinput)>3) { $TELarchivedir = $someinput; }
		print "Archive URL ($TELarchiveurl) : ";
		$someinput = trim(<STDIN>);
		if (length($someinput)>3) { $TELarchiveurl = $someinput; }
		
		} else {
			# We will use defaults, but verify that the internal vicidial IP and external URL are correct
			print "Archive server IP ($TELarchiveip) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $TELarchiveip = $someinput; }
			if ( &checkipv4($TELarchiveip)==1) { die "Not a valid archive IP\n"; }
			print "Archive URL ($TELarchiveurl) : ";
			$someinput = trim(<STDIN>);
			if (length($someinput)>3) { $TELarchiveurl = $someinput; }
	}
}


# Determine the SVN version assuming that we are in legacy mode
if ($legacy==1) {
	print "\nThe local SVN is build $buildver version $adminver from SVN $localsvn\n";
	if ( $extip ne "X") {
		print "Do you want to use the ViciDial version listed above? [Y/n] : ";
		$uselocalsvn = &yesprompt;
		if ($uselocalsvn==0) {
			print "Do you want to use the latest SVN version $svnhead? [Y/n] : ";
			$usesvnhead = &yesprompt;
			if ($usesvnhead==0) {
				print "Please enter the SVN revision to use : ";
				$usersvnrev = trim(<STDIN>);
				if ($usersvnrev > $svnhead) {
					die "The is not a valid SVN revision\n";
					} else {
						$DBsvnrev = $usersvnrev;
				}
				} else {
					$DBsvnrev = $svnhead;
			}
			} else {
				$DBsvnrev = $localsvn;
		}
		} else {
	print "Internet connectivity was not detected. If the above version of ViciDial\n";
	print "is not correct then you will need to transfer the correct version to the\n";
	print "directory /usr/share/astguiclient/trunk. If this is an all-in-one ViciBox\n";
	print "Express installation then you can disregard this message\n\n";
	}

	} elsif ($legacy==0 && $DB==0 && $DBsvnrev != $localsvn && $extip eq "X") {
		print "The SVN revision installed on the database is $DBsvnrev. The local SVN version\n";
		print "is $localsvn. Unfortunately no internet connection was detected so the install\n";
		print "can not continue. Please copy the SVN version of ViciDial from the database to\n";
		print "this machine to complete the installation or connect this machine to the internet.\n";
		die "Local SVN revision does not match database SVN revision and cannot update to it\n";
		
		} elsif ($legacy==0 && $DB==0 && $DBsvnrev != $localsvn && $extip ne "X") {
			if ($debug==1) { print "The database SVN revision is $DBsvnrev. This system will be updated to that revision\n"; }
			
			} elsif ($DB==1 && $DBS==0 && $extip eq "X") {
				# We are a database, that is not slave, without internets, we use the local SVN copy
				if ($debug==1) { print "Internet connectivity not found, using local SVN revision $localsvn.\n"; }
				$DBsvnrev = $localsvn;
				
				} elsif ($DB==1 && $DBS==0 && $extip ne "X") {
					# We are a database, that is not slave, with internets, we use the head SVN copy
					if ($debug==1) { print "Internet connectivity found, using head SVN revision $svnhead.\n"; }
					$DBsvnrev = $svnhead;
					
					} else {
						# At this point all hell has broken loose, cats and dogs sleeping together, mass hysteria
						# So we just give generic output and hope for the best
						if ($debug==1) { print "The database SVN revision is $DBsvnrev. This system will be updated to that revision\n"; }
}

# Sanity check
if ($TEL==0 && $DB==0 && $WEB==0 && $ARC==0) { die "Did not select any server roles, exiting.\n"; }

# See if we want to disable the firewall or not
if ($DB==1 && $TEL==0 && $WEB==0 && $ARC==0) {
	# Since we seem to be a dedicated DB, we shouldn't need firewall, default to disabled
	$disablefirewall=1;
	print "\nDo you want to enable the built-in firewall? [y/N] : ";
	$myprompt=&yesprompt;
	if ($myprompt==1) { $disablefirewall=0; }
	} else {
		# Since we aren't dedicated, we are probably on the real internet, so default to enabled
		print "\nDo you want to disable the built-in firewall? [y/N] : ";
		$myprompt=&yesprompt;
		if ($myprompt==1) { $disablefirewall=1; }
}

# Summary output
print "\n\n---  ViciBox v.10.0 Install Summary  ---\n\n";
if ($expert==1) { print "Expert   : Yes\n"; } else { print "Expert   : No\n"; }
if ($legacy==1) { print "Legacy   : Yes\n"; } else { print "Legacy   : No\n"; }
if ($DB==1) { print "Database : Yes\n"; } else { print "Database : No\n"; }
if ($DBS==1) { print "Slave ID : $DBmysqlid\n"; }
if ($WEB==1) { print "Web      : Yes\n"; } else { print "Web      : No\n"; }
if ($WEB==1 && $expert==1) {
if ($redirect==1) { print "Redirect : Yes\n"; } else { print "Redirect : No\n"; }
if ($phpmyadmin==1) { print "PMA      : Yes\n"; } else { print "PMA      : No\n"; }
}
if ($TEL==1) { print "Telephony: Yes\n"; } else { print "Telephony: No\n"; }
if ($TEL==1 && $legacy==1) {
	if ($primarydialer==1) { print "First Srv: Yes\n"; } else { print "First Srv: No\n"; }
	if ($havearchive==1) { print "Have Arch: Yes\n"; } else { print "Have Arch: No\n"; }
}
if ($ARC==1) { print "Archive  : Yes\n"; } else { print "Archive  : No\n"; }
if ($disablefirewall==0) {
	print "Firewall : Enabled\n";
	} else {
		print "Firewall : Disabled\n";
}

print "\n---  Configuration Information  ---\n";
print "-  Database  -\n";
print "SVN Rev  : $DBsvnrev\n";
print "IP Addr  : $VICIDBIP\n";
print "Name     : $VICIdatabase\n";
print "User     : $VICIuser\n";
print "Password : $VICIpass\n";
print "Cust User: $VICIcustomuser\n";
print "Cust Pass: $VICIcustompass\n";
if ($DBS==1) {
	print "Slave Usr: $VICIslaveuser\n";
	print "Slave Pw : $VICIslavepass\n";
	
}
print "Port     : $VICIport\n";

if ($TEL==1 && $havearchive==1) {
print "\n- Archive -\n";
print "IP Addr  : $TELarchiveip\n";
print "User     : $TELarchiveuser\n";
print "Password : $TELarchivepass\n";
print "Port     : $TELarchiveport\n";
print "Directory: $TELarchivedir\n";
print "URL      : $TELarchiveurl\n";
}

print "\n\nPlease verify the above information before continuing!\n";
print "Do you want to continue the installation? [y/N] : ";
$myprompt = &yesprompt;

if ($myprompt==1) { dothedeed; }

}
