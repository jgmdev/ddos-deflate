#!/bin/bash
if [ -d "$DESTDIR/usr/local/ddos" ]; then
	echo "Please un-install the previous version first"
	exit 0
else
	mkdir -p "$DESTDIR/usr/local/ddos"
fi

clear

echo; echo 'Installing DOS-Deflate 0.8.0'; echo
echo "Resolving dependencies";
echo "Check if epel in installed";
EPEL_ENABLED=$(yum repolist all | grep "epel")
if [ "$EPEL_ENABLED" = "" ]; then
	echo "Epel is not installed";
	yum -y install epel-release
	echo "Set epel to disable in order to do not mess with enabled repository"
	sed -i.bak "s/enabled\=1/enabled\=0/g" "/etc/yum.repos.d/epel.repo"
else 
	echo "Epel is already installed!"
fi
yum -y install dsniff --enablerepo=epel

if [ ! -d "$DESTDIR/etc/ddos" ]; then
	echo "Adding $DESTDIR/etc/ddos directory"	
	mkdir -p "$DESTDIR/etc/ddos"
fi

if [ ! -d "/var/lib/ddos/" ]; then
	echo "Adding /var/lib/ddos directory"
	mkdir -p "/var/lib/ddos/"
fi

echo; echo 'Installing DOS-Deflate 0.8.0'; echo

if [ ! -e "$DESTDIR/etc/ddos/ddos.conf" ]; then
	echo -n 'Adding: /etc/ddos/ddos.conf...'
	cp config/ddos.conf "$DESTDIR/etc/ddos/ddos.conf" > /dev/null 2>&1
	echo " (done)"
fi

if [ ! -e "$DESTDIR/etc/ddos/ignore.ip.list" ]; then
	echo -n 'Adding: /etc/ddos/ignore.ip.list...'
	cp config/ignore.ip.list "$DESTDIR/etc/ddos/ignore.ip.list" > /dev/null 2>&1
	echo " (done)"
fi

if [ ! -e "$DESTDIR/etc/ddos/ignore.host.list" ]; then
	echo -n 'Adding: /etc/ddos/ignore.host.list...'
	cp config/ignore.host.list "$DESTDIR/etc/ddos/ignore.host.list" > /dev/null 2>&1
	echo " (done)"
fi

echo -n 'Adding: /usr/local/ddos/LICENSE...'
cp LICENSE "$DESTDIR/usr/local/ddos/LICENSE" > /dev/null 2>&1
echo " (done)"

echo -n 'Adding: /usr/local/ddos/ddos.sh...'
cp src/ddos.sh "$DESTDIR/usr/local/ddos/ddos.sh" > /dev/null 2>&1
chmod 0755 /usr/local/ddos/ddos.sh > /dev/null 2>&1
echo " (done)"

echo -n 'Creating ddos script: /usr/local/sbin/ddos...'
mkdir -p "$DESTDIR/usr/local/sbin/"
echo "#!/bin/bash" > "$DESTDIR/usr/local/sbin/ddos"
echo "/usr/local/ddos/ddos.sh \$@" >> "$DESTDIR/usr/local/sbin/ddos"
chmod 0755 "$DESTDIR/usr/local/sbin/ddos"
echo " (done)"

echo -n 'Adding man page...'
mkdir -p "$DESTDIR/usr/share/man/man1/"
cp man/ddos.1 "$DESTDIR/usr/share/man/man1/ddos.1" > /dev/null 2>&1
chmod 0644 "$DESTDIR/usr/share/man/man1/ddos.1" > /dev/null 2>&1
echo " (done)"

if [ -d /etc/logrotate.d ]; then
	echo -n 'Adding logrotate configuration...'
	mkdir -p "$DESTDIR/etc/logrotate.d/"
	cp src/ddos.logrotate "$DESTDIR/etc/logrotate.d/ddos" > /dev/null 2>&1
	chmod 0644 "$DESTDIR/etc/logrotate.d/ddos"
	echo " (done)"
fi

echo;

if [ -d /etc/init.d ]; then
	echo -n 'Setting up init script...'
	mkdir -p "$DESTDIR/etc/init.d/"
	cp src/ddos.initd "$DESTDIR/etc/init.d/ddos" > /dev/null 2>&1
	chmod 0755 "$DESTDIR/etc/init.d/ddos" > /dev/null 2>&1
	echo " (done)"

	# Check if update-rc is installed and activate service
	UPDATERC_PATH=`whereis update-rc.d`
	if [ "$UPDATERC_PATH" != "update-rc.d:" ] && [ "$DESTDIR" = "" ]; then
		echo -n "Activating ddos service..."
		update-rc.d ddos defaults > /dev/null 2>&1
		service ddos start > /dev/null 2>&1
		echo " (done)"
		echo "Start DDOS when the system is booting"
		chkconfig --levels 235 ddos on
	else
		echo "ddos service needs to be manually started... (warning)"
	fi
elif [ -d /etc/cron.d ] && [ "$DESTDIR" = "" ]; then
	echo -n 'Creating cron to run script every minute...'
	mkdir -p "$DESTDIR/etc/cron.d/"
	/usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
	echo " (done)"
elif [ -d /usr/lib/systemd/system ]; then
	echo -n 'Setting up systemd service...'
	mkdir -p "$DESTDIR/usr/lib/systemd/system/"
	cp src/ddos.service "$DESTDIR/usr/lib/systemd/system/" > /dev/null 2>&1
	chmod 0755 "$DESTDIR/usr/lib/systemd/system/ddos.service" > /dev/null 2>&1
	echo " (done)"

	# Check if systemctl is installed and activate service
	SYSTEMCTL_PATH=`whereis systemctl`
	if [ "$SYSTEMCTL_PATH" != "systemctl:" ] && [ "$DESTDIR" = "" ]; then
		echo -n "Activating ddos service..."
		systemctl enable ddos > /dev/null 2>&1
		systemctl start ddos > /dev/null 2>&1
		echo " (done)"
	else
		echo "ddos service needs to be manually started... (warning)"
	fi
fi

echo; echo 'Installation has completed!'
echo 'Config files are located at /etc/ddos/'
echo
echo 'Please send in your comments and/or suggestions to:'
echo 'https://github.com/phoenixweb/ddos-deflate/issues'
echo

exit 0
