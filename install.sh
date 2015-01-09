#!/bin/bash
if [ -d '/usr/local/ddos' ]; then
	echo; echo; echo "Please un-install the previous version first"
	exit 0
else
	mkdir /usr/local/ddos
fi
clear

if [ ! -d '/etc/ddos' ]; then
	mkdir /etc/ddos
fi

echo; echo 'Installing DOS-Deflate 0.7'; echo

if [ ! -e /etc/ddos/ddos.conf ]; then
	echo 'Adding: /etc/ddos/ddos.conf'
	cp config/ddos.conf /etc/ddos/ddos.conf > /dev/null 2>&1
fi

if [ ! -e /etc/ddos/ignore.ip.list ]; then
	echo 'Adding: /etc/ddos/ignore.ip.list'
	cp config/ignore.ip.list /etc/ddos/ignore.ip.list > /dev/null 2>&1
fi

if [ ! -e /etc/ddos/ignore.host.list ]; then
	echo 'Adding: /etc/ddos/ignore.host.list'
	cp config/ignore.host.list /etc/ddos/ignore.host.list > /dev/null 2>&1
fi

echo 'Adding: /usr/local/ddos/LICENSE'
cp LICENSE /usr/local/ddos/LICENSE > /dev/null 2>&1

echo 'Adding: /usr/local/ddos/ddos.sh'
cp src/ddos.sh /usr/local/ddos/ddos.sh > /dev/null 2>&1
chmod 0755 /usr/local/ddos/ddos.sh > /dev/null 2>&1

echo 'Creating ddos symlink: /usr/local/sbin/ddos'
cp -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos > /dev/null 2>&1

echo 'Installing man page...'
cp man/ddos.1 /usr/share/man/man1/ddos.1 > /dev/null 2>&1
chmod 0644 /usr/share/man/man1/ddos.1 > /dev/null 2>&1

echo;

if [ -d /etc/init.d ]; then
	echo -n 'Setting up init script...'
	cp src/ddos.initd /etc/init.d/ddos > /dev/null 2>&1
	chmod 0755 /etc/init.d/ddos > /dev/null 2>&1
	
	# Check if update-rc is installed and activate service
	UPDATERC_PATH=`whereis update-rc.d`
	if [ "$UPDATERC_PATH" != "update-rc.d:" ]; then
		echo "Activating ddos service..."
		update-rc.d ddos defaults
		service ddos start
	else
		echo "ddos service needs to be manually started..."
	fi
elif [ -d /etc/cron.d ]; then
	echo -n 'Creating cron to run script every minute.....(Default setting)'
	/usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
	echo '.....done'
fi

echo; echo 'Installation has completed!'
echo 'Config files are located at /etc/ddos/'
echo
echo 'Please send in your comments and/or suggestions to:'
echo 'https://github.com/jgmdev/ddos-deflate/issues'
echo

exit 0
