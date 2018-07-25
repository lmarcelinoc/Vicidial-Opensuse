#!/bin/bash

# Some color scheme's
BLACK="tput setf 0"
BLUE="tput setf 1"
GREEN="tput setf 2"
CYAN="tput setf 3"
RED="tput setf 4"
MAGENTA="tput setf 5"
YELLOW="tput setf 6"
WHITE="tput setf 7"

User choices
function choice {
	CHOICE=''
	local prompt="$*"
	local answer
	read -p "$prompt" answer
	case "$answer" in
		[yY1] ) CHOICE='y';;
		[nN0] ) CHOICE='n';;
		*     ) CHOICE="$answer";;
	esac
}

# Simple user-feedback Function
function pause {
	read -p "`${YELLOW}`$*`${WHITE}`"
}

# The Do Or Die function! If we dont get a clean 0 exit code, consider it failed and bomb as such!
function doordie {
	eval $1

	if [ $? != 0 ]; then
		echo "`${RED}`ERROR! ERROR!  Something has gone horribly wrong! Processing stopped!`${WHITE}`"
		echo
		echo "Failure Area : `${MAGENTA}`$2`${WHITE}`"
		echo
		exit 1
	fi
}

echo
echo
echo "ViciDial Installer for OpenSuSE v.11.1"
echo
echo "This is for 32-bit and 64-bit x86 microarchitecture's only"
echo
echo "Please note that an Internet connection will be required for this script"
echo "to function."
echo
echo

choice "Do you want to continue? (y/N) : "

if [ "$CHOICE" == "y" ]; then # All code to run before here

echo
echo
echo
echo "OK. Now I will ask some simple set-up questions to determine how I should"
echo "be installed."
echo

echo "We highly recommend updating the base OS distribution with the updates"
echo "available for OpenSuSE. If you want to run a newer kernel you will need"
echo "to recompile zaptel, wanpipe, and asterisk for the system to work."
echo
choice "Would you like to update the OS before installing ViciDial? (y/N) : "
OSUPD="$CHOICE"

echo
echo "By default, all new installs of OpenSuSE v.11.1 have the firewall enabled."
echo "You will either need to disable the firewall or open up ports in order to do"
echo "multi-server configurations or access services externally. Unless this server"
echo "is going to be directly connected to the internet we recommend disabling the"
echo "firewall."
echo
choice "Would you like to turn the built-in firewall off? (y/N) : "
STOPFIRE="$CHOICE"

echo "ViciDial currently has two standard codebases. Version 2.0.5 is the latest"
echo "release of the software. There is also the SVN Current branch of the software"
echo "which includes any new features and/or bugfixes. Any custom development or"
echo "other bug fixes done after the last release will be in the SVN Current codebase."
echo "We normally recommend our customers use the SVN Current code base."
echo
choice "Do you want to use the SVN Trunk codebase? (y/N) : "
USESVN="$CHOICE"

echo
choice "Will this server be used as the Database? (y/N) : "
DBSERV="$CHOICE"

echo
choice "Will this server be used as the webserver? (y/N) : "
WEBSERV="$CHOICE"

echo
choice "Will this server be used as an Agent/Dialer Server? (y/N) : "
VICISERV="$CHOICE"

ARCH=`uname -m`

if [ "$VICISERV" == "y" ]; then
	choice "---> Do you have a Sangoma T1/E1 card installed? (y/N) : "
	SANGOMA="$CHOICE"
	if [ "$SANGOMA" == "n" ]; then
		choice "---> Do you have a Sangoma VoiceTime USB timer installed? (y/N) : "
		SANGOMAVT="$CHOICE"
	fi
	choice "---> Do you want to install the extra Asterisk sounds? (y/N) : "
	SOUNDSEXTRA="$CHOICE"
	echo
fi

echo
echo
echo
echo "Your system will be configured as follows:"
echo
echo "OS Update	: $OSUPD"
echo "Stop Firewall 	: $STOPFIRE"
echo "Use SVN Code	: $USESVN"
echo "Install Core DB	: $DBSERV"
echo "Install Web App	: $WEBSERV"
echo "Install Dialer	: $VICISERV"
echo
echo "Please make sure the OpenSuSE install media is in the drive or"
echo "otherwise disabled in yast before continuing. Hit Ctrl-C now to exit"
echo
echo "If you plan to install and boot from the new kernel you will need"
echo "to recompile libPRI, Zaptel, Wanpipe, and Asterisk after isntallation"
echo
echo "Some repositories will be added to the system now. When prompted"
echo "please press 'a' and enter for each prompt."
echo
echo "The system will give you instructions as it progresses on certain key"
echo "combinations to enter for proper installation. This script will"
echo "automatically pause at those instructions."
echo
pause "--- Press Enter to continue or CTRL-C to exit ---"

### Create working directory
mkdir -p /usr/src/astguiclient
cd /usr/src/astguiclient

### Lets run a basic internet sanity check before we get knee-deep in something else
doordie "wget http://download.vicidial.com/test.html" "Failed basic internet check! Check your network and/or internet connection!"

if [ ! -f /usr/src/astguiclient/.addrepos ]; then
	### Add all Repositories that we need later (less of a headache this way)
	doordie "zypper ar http://download.opensuse.org/repositories/server:/php:/applications/openSUSE_Leap_42.3/server:php:applications.repo" "Could not add PHP Applications respository. Check that you are connected to the internet."
	doordie "zypper ar -cf http://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_42.3/ packman" "Could not add Packman respository. Check that you are connected to the internet."
	doordie "zypper --no-gpg-checks refresh" "Could not refresh active respositories. Check that you are connected to the internet."
	touch /usr/src/astguiclient/.addrepos
fi

### Check Firewall for good measure
if [ "$STOPFIRE" == "y" ]; then
	/sbin/SuSEfirewall2 off
fi

### Remove apparmor if installed, and make it taboo
zypper --non-interactive rm *apparmor*
zypper al -t pattern apparmor

### Update OS
if [ "$OSUPD" == "y" ]; then
	echo
	echo "If during the OS Update a new kernel is downloaded then zaptel will fail compile."
	echo "You will need to reboot and re-run this script to continue installation."
	echo
	pause " --- Press Enter to continue or CTRL-C to exit ---"
	doordie "zypper --non-interactive up" "Could not update the operating system. Check that you are connected to the internet."
fi

### Install some known pre-req's
doordie "zypper --non-interactive in subversion pico nano findutils-locate iftop irqbalance curl zip unzip libmysqlclient-devel screen apache2 memtest86+" "Could not add pre-requisite packages. Check that you are connected to the internet."
doordie "zypper --non-interactive in -t pattern devel_kernel" "Could not add Kernel Development packages. Check that you are connected to the internet."

# Grab SVN Code
if [ "$USESVN" == "y" ]; then
	doordie "svn checkout svn://svn.eflo.net:3690/agc_2-X/trunk" "Could not connect to SVN server. Matt probably broke it again. E-Mail support@vicidial.com"
	else
		doordie "svn checkout svn://svn.eflo.net:3690/agc_2-X/branches/agc_2.0.5" "Could not connect to SVN server. Matt probably broke it again. E-Mail support@vicidial.com"
fi

### Create download directory, download/install common components
mkdir -p /usr/src/tars

# Install TTYLoad
cd /usr/src/tars
if [ ! -f ttyload-0.4.4.tar.gz ]; then
	doordie "wget http://www.daveltd.com/src/util/ttyload/ttyload-0.4.4.tar.gz" "Could now download ttyload.  Check that you are connected to the internet."
fi
cd /usr/src
tar -xzf tars/ttyload-0.4.4.tar.gz
cd /usr/src/ttyload-0.4.4
make
doordie "make install" "Could not compile TTY Load."
cd ../

# Some sane CPAN settings, and do perl updates
cd /tmp
doordie "wget http://download.vicidial.com/conf/Config.pm" "Could not get PERL configuration settings.  Check that you are connected to the internet."
mv -f /tmp/Config.pm /usr/lib/perl5/5.10.0/CPAN/Config.pm

# Give feedback about silly PERL compiling stuff
echo
echo
echo "PERL will need you to press enter twice as components are installed."
echo "You do not need to select anything just hit Enter."
echo
pause " --- Press Enter when ready to Continue; PERL Modules are being compiled next! --- "

doordie "cpan -i MD5 Digest::MD5 Digest::SHA1 readline" "Could not update CPAN pre-requisites."
doordie "cpan -i Bundle::CPAN" "Could not update CPAN"
doordie "cpan -fi Scalar::Util" "Could not install Scalar::UTIL"
doordie "cpan -i DBI" "Could not install DBI"
doordie "cpan -fi DBD::mysql" "Could not install DBD::mysql"
doordie "cpan -fi Net::Telnet Time::HiRes Net::Server Switch Unicode::Map Jcode Spreadsheet::WriteExcel OLE::Storage_Lite Proc::ProcessTable IO::Scalar Spreadsheet::ParseExcel Curses Getopt::Long Net::Domain Mail::Sendmail" "Could not install ViciDial PERL Pre-Requisites"

# Set-up NTP with good defaults
cd /etc
if [ ! -f /usr/src/astguiclient/.ntpinstall ]; then
	doordie "wget http://download.vicidial.com/conf/ntp-server.conf" "Could not download default ntp-server configuration.  Check that you are connected to the internet."
	mv -f ntp-server.conf ntp.conf
	/etc/init.d/ntp restart
	touch /usr/src/astguiclient/.ntpinstall
fi
chkconfig ntp on

### Task Specific stuff here
if [ "$DBSERV" == "y" ]; then
	doordie "zypper --non-interactive in -t pattern lamp_server" "Could not install LAMP Server packages. Check that you are connected to the internet."
	doordie "zypper --non-interactive in phpMyAdmin mytop" "Could not install MySQL tools. Check that you are connected to the internet."

	# Insert and md5 into phpMyAdmin for a cookie value, it's funny like that
	COOKIEMD5="`date | md5sum | sed 's/ //g'`"
	cd /srv/www/htdocs/phpMyAdmin
	sed "s/''; \/*/'${COOKIEMD5}'; \/*/" config.sample.inc.php > config.inc.php

	# Download files that are DB-Specific, compile, install
	cd /usr/src/tars

	# Install mtop for matt
	if [ ! -f mtop-0.6.6.tar.gz ]; then
		doordie "wget http://internap.dl.sourceforge.net/sourceforge/mtop/mtop-0.6.6.tar.gz" "Could not download mtop.  Check that you are connected to the internet."
	fi
	cd /usr/src
	tar -xzf tars/mtop-0.6.6.tar.gz
	cd /usr/src/mtop-0.6.6
	perl Makefile.PL
	make
	make install
	cd /usr/src/tars

	# Get us some settings for MySQL that are Vici friendly
	cd /etc
	if [ ! -f /usr/src/astguiclient/.dbconfig ]; then
		doordie "wget http://download.vicidial.com/conf/my-vici.cnf" "Could not download vicidial-specific my.cnf configuration. Check that you are connected to the internet."
		mv -f my-vici.cnf my.cnf
		touch /usr/src/astguiclient/.dbconfig
	fi

	# Start related services or restart if running
	/etc/init.d/apache2 restart
	/etc/init.d/mysql restart

	# Make sure stuff starts on reboot
	chkconfig mysql on
	chkconfig apache2 on

fi

if [ "$WEBSERV" == "y" ]; then
	# Make sure pre-req's are installed
	doordie "zypper --non-interactive in -t pattern lamp_server" "Could not install LAMP Server packages. Check that you are connected to the internet."
	doordie "zypper --non-interactive in php5-eaccelerator" "Could not install E-Accelerator. Check that you are connected to the internet."

	# give better eaccel options
	cd /etc/php5/conf.d
	sed 's/eaccelerator.shm_size=\"16\"/eaccelerator.shm_size=\"48\"/' eaccelerator.ini > temp
	mv -f temp eaccelerator.ini

	# Some PHP mangling
	cd /etc/php5/apache2
	rm php.ini
	wget http://download.vicidial.com/conf/opensuse-11.1/php.ini

	if [ "$ARCH" == "x86_64" ]; then
		sed 's/extension_dir \= \/usr\/lib\/php5\/extensions/extension_dir \= \/usr\/lib64\/php5\/extensions/' php.ini > php.new
		mv -f php.new php.ini
	fi

	# Install Ploticus
	cd /usr/src/tars
	if [ ! -f pl241src.tar.gz ]; then
		wget https://sourceforge.net/projects/ploticus/files/ploticus/2.41/pl241src.tar.gz

	fi
	cd /usr/src
	tar -xzf tars/pl241src.tar.gz
	cd pl241src/src/
	make clean
	make
	doordie "make install" "Could not install Ploticus"

	# make sure apache starts on reboot
	chkconfig apache2 on
fi

if [ "$VICISERV" == "y" ]; then
	# Grab us some pre-req's for Asterisk
	doordie "zypper --non-interactive in lame sox mpg123 newt newt-devel madplay" "Could not install audio utilities. Check that you are connected to the internet."

	# Install Asterisk perl
	cd /usr/src/tars
	if [ ! -f asterisk-perl-0.08.tar.gz ]; then
		doordie "wget https://sourceforge.net/projects/vicidial/files/asterisk-perl-0.08.tar.gz" or "Could not download Asterisk PERL modules. Check that you are connected to the internet."
	fi
	cd /usr/src
	tar -xzf tars/asterisk-perl-0.08.tar.gz
	cd /usr/src/asterisk-perl-0.08
	perl Makefile.PL
	make all
	make install
	cd ../

	# Set-up apache for recordings
	cd /etc/apache2/conf.d
	if [ ! -f vicirecord.conf ]; then
		wget http://download.vicidial.com/conf/vicirecord.conf
	fi
	chown -R wwwrun /var/spool/asterisk/monitorDONE
	chkconfig apache2 on

	# pre-load our files for asterisk
	cd /usr/src/tars
	if [ ! -f asterisk-1.4.21.2-vici.tar.gz ]; then
		doordie "wget http://download.vicidial.com/required-apps/asterisk-1.4.21.2-vici.tar.gz" "Could not download Asterisk v.1.4.21.2-vici. Check that you are connected to the internet."
	fi
	if [ ! -f libpri-1.4.10.tar.gz ]; then
		doordie "wget http://downloads.asterisk.org/pub/telephony/libpri/releases/libpri-1.4.10.1.tar.gz" "Could not download libPRI. Check that you are connected to the internet."
	fi
	if [ ! -f zaptel-1.4.12.1.tar.gz ]; then
		doordie "wget http://downloads.digium.com/pub/zaptel/releases/zaptel-1.4.12.1.tar.gz" "Could not download Zaptel. Check that you are connected to the internet."
	fi
	if [ ! -f asterisk-core-sounds-en-ulaw-current.tar.gz ]; then
		doordie "wget http://downloads.digium.com/pub/telephony/sounds/asterisk-core-sounds-en-ulaw-current.tar.gz" "Could not download Core ULAW sounds. Check that you are connected to the internet."
	fi
	if [ ! -f asterisk-core-sounds-en-wav-current.tar.gz ]; then
		doordie "wget http://downloads.digium.com/pub/telephony/sounds/asterisk-core-sounds-en-wav-current.tar.gz" "Could not download Core WAV sounds. Check that you are connected to the internet."
	fi
	if [ ! -f asterisk-core-sounds-en-gsm-current.tar.gz ]; then
		doordie "wget http://downloads.digium.com/pub/telephony/sounds/asterisk-core-sounds-en-gsm-current.tar.gz" "Could not download core GSM sounds. Check that you are connected to the internet."
	fi
	if [ ! -f asterisk-extra-sounds-en-ulaw-current.tar.gz ]; then
		doordie "wget http://downloads.digium.com/pub/telephony/sounds/asterisk-extra-sounds-en-ulaw-current.tar.gz" "Could not download extra ULAW sounds. Check that you are connected to the internet."
	fi
	if [ ! -f asterisk-extra-sounds-en-wav-current.tar.gz ]; then
		doordie "wget http://downloads.digium.com/pub/telephony/sounds/asterisk-extra-sounds-en-wav-current.tar.gz" "Could not download extra WAV sounds. Check that you are connected to the internet."
	fi
	if [ ! -f asterisk-extra-sounds-en-gsm-current.tar.gz ]; then
		doordie "wget http://downloads.digium.com/pub/telephony/sounds/asterisk-extra-sounds-en-gsm-current.tar.gz" "Could not download extra GSM sounds. Check that you are connected to the internet."
	fi
	if [ ! -f asterisk-moh-freeplay-gsm.tar.gz ]; then
		doordie "wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-moh-opsound-gsm-current.tar.gz" "Could not download GSM MOH. Check that you are connected to the internet."
	fi
	if [ ! -f asterisk-moh-freeplay-ulaw.tar.gz ]; then
		doordie "wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-moh-opsound-ulaw-current.tar.gz" "Could not download ULAW MOH. Check that you are connected to the internet."
	fi
	if [ ! -f asterisk-moh-freeplay-wav.tar.gz ]; then
		doordie "wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-moh-opsound-wav-current.tar.gz" "Could not download WAV MOH. Check that you are connected to the internet."
	fi
	if [ ! -f wanpipe-3.4.4.tgz ]; then
		doordie "wget ftp://ftp.sangoma.com/linux/current_wanpipe/wanpipe-3.4.4.tgz" "Could not download Sangoma Wanpipe. Check that you are connected to the internet."
	fi
	if [ ! -f wanpipe-voicetime-1.0.9.tgz ]; then
		doordie "wget ftp://ftp.sangoma.com/linux/wanpipe_voicetime/wanpipe-voicetime-1.0.9.tgz" "Could not download Sangoma Wanpipe Voicetime. Check that you are connected to the internet."
	fi
#	if [ ! -f sipsak-0.9.6-1.tar.gz ]; then
#		doordie "wget http://download2.berlios.de/sipsak/sipsak-0.9.6-1.tar.gz" "Could not download SIPSAK. Check that you are connected to the internet."
#	fi

	# Uncompress archives
	cd /usr/src
	doordie "tar -xzf /usr/src/tars/asterisk-1.4.21.2-vici.tar.gz" "Could not uncompress Asterisk archive."
	doordie "tar -xzf /usr/src/tars/libpri-1.4.10.1.tar.gz" "Could not uncompress libPRI archive."
	doordie "tar -xzf /usr/src/tars/zaptel-1.4.12.1.tar.gz" "Could not uncompress Zaptel archive."
	doordie "tar -xzf /usr/src/tars/wanpipe-3.4.4.tgz" "Could not uncompress Wanpipe archive."
	doordie "tar -xzf /usr/src/tars/wanpipe-voicetime-1.0.9.tgz" "Could not uncompress Wanpipe Voicetime archive."
#	doordie "tar -xzf /usr/src/tars/sipsak-0.9.6-1.tar.gz" "Could not uncompress SIPSAK archive."

	# Start Compiling
	cd /usr/src/libpri-1.4.10.1
	make clean
	make
	doordie "make install" "Could not install libPRI"

	# Compile Zaptel
	cd /usr/src/zaptel-1.4.12.1
	make clean
	./configure
	make
	doordie "make install" "Could not install Zaptel"
	cd ..
	ln -s zaptel-1.4.12.1 zaptel

	if [ "$SANGOMA" == "y" ]; then
	# Compile Wanpipe on top of Zaptel/libPRI
	cd /usr/src/wanpipe-3.4.4
	doordie "./Setup install --silent --protocol=TDM" "Could not install Sangoma Wanpipe drivers."
	fi

	if [ "$SANGOMAVT" == "y" ]; then
	# Install some VoiceTime!
	cd /usr/src/wanpipe-voicetime-1.0.9
	doordie "make ZAPDIR=/usr/src/zaptel-1.4.12.1/kernel/" "Could not compile Sangoma Wanpipe Voicetime drivers."
	make install
	fi

	# Compile Asterisk finally
	cd /usr/src/asterisk-1.4.21.2-vici
	make clean
	./configure
	doordie "make" "Could not compile Asterisk."
	make install

	if [ ! -f /usr/src/astguiclient/.astsamples ]; then
		make samples
		touch /usr/src/astguiclient/.astsamples
		ASTSAMPLES="y"
	fi


	# Compile SIPSAK
#	cd /usr/src/sipsak-0.9.6-1
#	./configure
#	doordie "make" "Could not compile SIPSAK"
#	make install
#	cd ..

	# Set-up ramdrive recording and default sounds in ulaw/gsm/raw
	if [ ! -f /usr/src/astguiclient/.ramdrive ]; then
		echo "tmpfs   /var/spool/asterisk/monitor       tmpfs      rw                    0 0" >> /etc/fstab
		touch /usr/src/astguiclient/.ramdrive
	fi

	# Set the sounds in place
	cd /var/lib/asterisk/sounds
	tar -xzf /usr/src/tars/asterisk-core-sounds-en-gsm-current.tar.gz
	tar -xzf /usr/src/tars/asterisk-core-sounds-en-ulaw-current.tar.gz
	tar -xzf /usr/src/tars/asterisk-core-sounds-en-wav-current.tar.gz

	if [ "$SOUNDSEXTRA" == "y" ]; then
		tar -xzf /usr/src/tars/asterisk-extra-sounds-en-gsm-current.tar.gz
		tar -xzf /usr/src/tars/asterisk-extra-sounds-en-ulaw-current.tar.gz
		tar -xzf /usr/src/tars/asterisk-extra-sounds-en-wav-current.tar.gz
	fi


	# Grab parking file, and convert audio to native formats
	wget http://download.vicidial.com/conf/conf.gsm
	sox conf.gsm conf.wav
	sox conf.gsm -t ul conf.ulaw
	cp conf.gsm park.gsm
	cp conf.ulaw park.ulaw
	cp conf.wav park.wav
	cd /var/lib/asterisk
	ln -s moh mohmp3
	mkdir mohmp3
	cd mohmp3
	tar -xzf /usr/src/tars/asterisk-moh-freeplay-gsm.tar.gz
	tar -xzf /usr/src/tars/asterisk-moh-freeplay-ulaw.tar.gz
	tar -xzf /usr/src/tars/asterisk-moh-freeplay-wav.tar.gz
	rm CHANGES*
	rm LICENSE*
	rm .asterisk*
	mkdir /var/lib/asterisk/quiet-mp3
	cd /var/lib/asterisk/quiet-mp3
	sox ../mohmp3/macroform-cold_day.wav macroform-cold_day.wav vol 0.25
	sox ../mohmp3/macroform-cold_day.gsm macroform-cold_day.gsm vol 0.25
	sox -t ul -r 8000 -c 1 ../mohmp3/macroform-cold_day.ulaw -t ul macroform-cold_day.ulaw vol 0.25
	sox ../mohmp3/macroform-robot_dity.wav macroform-robot_dity.wav vol 0.25
	sox ../mohmp3/macroform-robot_dity.gsm macroform-robot_dity.gsm vol 0.25
	sox -t ul -r 8000 -c 1 ../mohmp3/macroform-robot_dity.ulaw -t ul macroform-robot_dity.ulaw vol 0.25
	sox ../mohmp3/macroform-the_simplicity.wav macroform-the_simplicity.wav vol 0.25
	sox ../mohmp3/macroform-the_simplicity.gsm macroform-the_simplicity.gsm vol 0.25
	sox -t ul -r 8000 -c 1 ../mohmp3/macroform-the_simplicity.ulaw -t ul macroform-the_simplicity.ulaw vol 0.25
	sox ../mohmp3/reno_project-system.wav reno_project-system.wav vol 0.25
	sox ../mohmp3/reno_project-system.gsm reno_project-system.gsm vol 0.25
	sox -t ul -r 8000 -c 1 ../mohmp3/reno_project-system.ulaw -t ul reno_project-system.ulaw vol 0.25
	sox ../mohmp3/manolo_camp-morning_coffee.wav manolo_camp-morning_coffee.wav vol 0.25
	sox ../mohmp3/manolo_camp-morning_coffee.gsm manolo_camp-morning_coffee.gsm vol 0.25
	sox -t ul -r 8000 -c 1 ../mohmp3/manolo_camp-morning_coffee.ulaw -t ul manolo_camp-morning_coffee.ulaw vol 0.25


	# See if we've already installed the all cron
	if [ ! -f /usr/src/astguiclient/.allcron ]; then
		wget http://download.vicidial.com/conf/opensuse-11.1/allcron
		crontab -l > rootcron
		cat allcron >> rootcron
		crontab rootcron
		touch /usr/src/astguiclient/.allcron
	fi

	# See if we've already installed the dial cron
	if [ ! -f /usr/src/astguiclient/.dialcron ]; then
		wget http://download.vicidial.com/conf/opensuse-11.1/dialcron
		crontab -l > rootcron
		cat dialcron >> rootcron
		crontab rootcron
		touch /usr/src/astguiclient/.dialcron
	fi

	# Put the init-script in place
	cd /etc/init.d
	doordie "wget http://download.vicidial.com/conf/vicidial" "Could not download ViciDial init.d script. Check that you are connected to the internet."
	# If we compiled Voicetime, set init script to use it
	if [ "$SANGOMAVT" == "y" ]; then
		sed 's/ZAP_MOD=ztdummy/ZAP_MOD=wanpipe_voicetime/' vicidial > vicidial.new
		mv -f vicidial.new vicidial
	fi
	chmod 755 /etc/init.d/vicidial

	# Make sure everything starts for us on reboot :)
	chkconfig apache2 on
	chkconfig vicidial on
	/etc/init.d/apache2 restart
	/etc/init.d/vicidial start


fi

### Put us in the right directory for system-specific install stuff
if [ "$USESVN" == "y" ]; then
	cd /usr/src/astguiclient/trunk
	else
		cd /usr/src/astguiclient/agc_2.0.5
fi


if [ "$DBSERV" == "y" ]; then
	# Check to see if we've already been here
	if [ ! -f /usr/src/astguiclient/.dbinstall ]; then
		cd extras
		/usr/bin/mysql --execute="create database asterisk default character set utf8 collate utf8_unicode_ci;"
		/usr/bin/mysql asterisk --execute="GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES on asterisk.* TO cron@'%' IDENTIFIED BY '1234';"
		/usr/bin/mysql asterisk --execute="GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES on asterisk.* TO cron@localhost IDENTIFIED BY '1234';"
		/usr/bin/mysql asterisk --execute="\. ./MySQL_AST_CREATE_tables.sql"
		/usr/bin/mysql asterisk --execute="\. ./first_server_install.sql"
		mysql asterisk --execute="INSERT INTO vicidial_lists (list_id, list_name, active, list_description) VALUES ('997', 'Test List', 'N', 'Performance and Test List');"
		mysql asterisk --execute="UPDATE vicidial_users set pass='1234',full_name='Admin',user_level='9',user_group='ADMIN',phone_login='',phone_pass='',delete_users='1',delete_user_groups='1',delete_lists='1',delete_campaigns='1',delete_ingroups='1',delete_remote_agents='1',load_leads='1',campaign_detail='1',ast_admin_access='1',ast_delete_phones='1',delete_scripts='1',modify_leads='1',hotkeys_active='0',change_agent_campaign='1',agent_choose_ingroups='1',closer_campaigns='',scheduled_callbacks='1',agentonly_callbacks='0',agentcall_manual='0',vicidial_recording='1',vicidial_transfers='1',delete_filters='1',alter_agent_interface_options='1',closer_default_blended='0',delete_call_times='1',modify_call_times='1',modify_users='1',modify_campaigns='1',modify_lists='1',modify_scripts='1',modify_filters='1',modify_ingroups='1',modify_usergroups='1',modify_remoteagents='1',modify_servers='1',view_reports='1',vicidial_recording_override='DISABLED',alter_custdata_override='NOT_ACTIVE',qc_enabled='',qc_user_level='',qc_pass='',qc_finish='',qc_commit='',add_timeclock_log='1',modify_timeclock_log='1',delete_timeclock_log='1',alter_custphone_override='NOT_ACTIVE',vdc_agent_api_access='1',modify_inbound_dids='1',delete_inbound_dids='1',active='Y',download_lists='1',agent_shift_enforcement_override='DISABLED',manager_shift_enforcement_override='1',export_reports='1',delete_from_dnc='1',email='',user_code='',territory='' where user='6666';"
		touch /usr/src/astguiclient/.dbinstall
		cd ..
	fi

	# See if we've already installed the all cron
	if [ ! -f /usr/src/astguiclient/.allcron ]; then
		wget http://download.vicidial.com/conf/opensuse-11.1/allcron
		crontab -l > rootcron
		cat allcron >> rootcron
		crontab rootcron
		touch /usr/src/astguiclient/.allcron
	fi

	# See if we've already installed the db cron
	if [ ! -f /usr/src/astguiclient/.dbcron ]; then
		wget http://download.vicidial.com/conf/opensuse-11.1/dbcron
		crontab -l > rootcron
		cat dbcron >> rootcron
		crontab rootcron
		touch /usr/src/astguiclient/.dbcron
	fi
fi


### What to run if we are all 3, skip the 7 keepalive since we aren't multi-server
if [ "$VICISERV" == "y" ] && [ "$WEBSERV" == "y" ] && [ "$DBSERV" == "y" ]; then
	if [ ! -f /usr/src/astguiclient/.viciinstall ]; then
		doordie "perl install.pl --web=/srv/www/htdocs --asterisk_server=1.4 --copy_sample_conf_files --active_keepalives=12345689" "Could not run ViciDial installer"
		/usr/share/astguiclient/ADMIN_update_server_ip.pl --old-server_ip=10.10.10.15
		touch /usr/src/astguiclient/.viciinstall
		/usr/share/astguiclient/ADMIN_area_code_populate.pl
                cp /usr/src/astguiclient/trunk/extras/performance_test_leads.txt /usr/share/astguiclient/LEADS_IN/
                /usr/share/astguiclient/VICIDIAL_IN_new_leads_file.pl --forcelistid=997 --forcephonecode=1
	fi
fi

if [ "$WEBSERV" == "y" ] && [ "$DBSERV" == "y" ] && [ "$VICISERV" == "n" ]; then
	if [ ! -f /usr/src/astguiclient/.viciinstall ]; then
		doordie "perl install.pl --web=/srv/www/htdocs --asterisk_server=1.4 --copy_sample_conf_files --active_keepalives=579" "Could not run ViciDial installer"
		touch /usr/src/astguiclient/.viciinstall
		/usr/share/astguiclient/ADMIN_area_code_populate.pl
                cp /usr/src/astguiclient/trunk/extras/performance_test_leads.txt /usr/share/astguiclient/LEADS_IN/
                /usr/share/astguiclient/VICIDIAL_IN_new_leads_file.pl --forcelistid=997 --forcephonecode=1
	fi
fi

if [ "$VICISERV" == "y" ] && [ "$WEBSERV" == "y" ] && [ "$DBSERV" == "n" ]; then
	if [ ! -f /usr/src/astguiclient/.viciinstall ]; then
		doordie "perl install.pl --web=/srv/www/htdocs --asterisk_server=1.4 --copy_sample_conf_files --active_keepalives=123468" "Could not run ViciDial installer"
		/usr/share/astguiclient/ADMIN_update_server_ip.pl --old-server_ip=10.10.10.15
		touch /usr/src/astguiclient/.viciinstall
	fi
fi

if [ "$VICISERV" == "y" ] && [ "$DBSERV" == "y" ] && [ "$WEBSERV" == "n" ]; then
	if [ ! -f /usr/src/astguiclient/.viciinstall ]; then
		doordie "perl install.pl --web=/srv/www/htdocs --asterisk_server=1.4 --copy_sample_conf_files --active_keepalives=12345689" "Could not run ViciDial installer"
		/usr/share/astguiclient/ADMIN_update_server_ip.pl --old-server_ip=10.10.10.15
		touch /usr/src/astguiclient/.viciinstall
		/usr/share/astguiclient/ADMIN_area_code_populate.pl
                cp /usr/src/astguiclient/trunk/extras/performance_test_leads.txt /usr/share/astguiclient/LEADS_IN/
                /usr/share/astguiclient/VICIDIAL_IN_new_leads_file.pl --forcelistid=997 --forcephonecode=1
	fi
fi


if [ "$DBSERV" == "y" ] && [ "$VICISERV" == "n" ] && [ "$WEBSERV" == "n" ]; then
	if [ ! -f /usr/src/astguiclient/.viciinstall ]; then
		doordie "perl install.pl --web=/srv/www/htdocs --asterisk_server=1.4 --copy_sample_conf_files --active_keepalives=579" "Could not run ViciDial installer"
		touch /usr/src/astguiclient/.viciinstall
		/usr/share/astguiclient/ADMIN_area_code_populate.pl
                cp /usr/src/astguiclient/trunk/extras/performance_test_leads.txt /usr/share/astguiclient/LEADS_IN/
                /usr/share/astguiclient/VICIDIAL_IN_new_leads_file.pl --forcelistid=997 --forcephonecode=1
	fi
fi

if [ "$WEBSERV" == "y" ] && [ "$DBSERV" == "n" ] && [ "$VICISERV" == "n" ]; then
	if [ ! -f /usr/src/astguiclient/.viciinstall ]; then
		doordie "perl install.pl --web=/srv/www/htdocs --asterisk_server=1.4 --active_keepalives=X" "Could not run ViciDial installer"
		touch /usr/src/astguiclient/.viciinstall
	fi
fi

if [ "$VICISERV" == "y" ] && [ "$WEBSERV" == "n" ] && [ "$DBSERV" == "n" ]; then
	if [ ! -f /usr/src/astguiclient/.viciinstall ]; then
		doordie "perl install.pl --web=/srv/www/htdocs --asterisk_server=1.4 --copy_sample_conf_files --active_keepalives=123468" "Could not run ViciDial installer"
		/usr/share/astguiclient/ADMIN_update_server_ip.pl --old-server_ip=10.10.10.15
		touch /usr/src/astguiclient/.viciinstall
	fi
fi


fi
