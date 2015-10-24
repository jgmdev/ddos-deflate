#!/bin/bash

clear

echo "Uninstalling DOS-Deflate"

if [ -e '/etc/init.d/ddos' ]; then
	echo; echo -n "Deleting init service..."
	UPDATERC_PATH=`whereis update-rc.d`
	if [ "$UPDATERC_PATH" != "update-rc.d:" ]; then
		service ddos stop > /dev/null 2>&1
		update-rc.d ddos remove > /dev/null 2>&1
	fi
	rm -f /etc/init.d/ddos
	echo -n ".."
	echo " (done)"
fi

if [ -e '/usr/lib/systemd/system/ddos.service' ]; then
	echo; echo -n "Deleting systemd service..."
	SYSTEMCTL_PATH=`whereis update-rc.d`
	if [ "$SYSTEMCTL_PATH" != "systemctl:" ]; then
		systemctl stop ddos > /dev/null 2>&1
		systemctl disable ddos > /dev/null 2>&1
	fi
	rm -f /usr/lib/systemd/system/ddos.service
	echo -n ".."
	echo " (done)"
fi

echo -n "Deleting script files..."
if [ -e '/usr/local/sbin/ddos' ]; then
	rm -f /usr/local/sbin/ddos
	echo -n "."
fi

if [ -d '/usr/local/ddos' ]; then
	rm -rf /usr/local/ddos
	echo -n "."
fi

if [ -d '/var/lib/ddos' ]; then
	rm -rf /var/lib/ddos
	echo -n "."
fi
echo " (done)"

echo -n "Removing man page..."
if [ -e '/usr/share/man/man1/ddos.1' ]; then
	rm -f /usr/share/man/man1/ddos.1
	echo -n "."
fi
if [ -e '/usr/share/man/man1/ddos.1.gz' ]; then
	rm -f /usr/share/man/man1/ddos.1.gz
	echo -n "."
fi
echo " (done)"

if [ -e '/etc/cron.d/ddos' ]; then
	echo -n "Deleting cron job..."
	rm -f /etc/cron.d/ddos
	echo -n ".."
	echo " (done)"
fi

echo; echo "Uninstall Complete!"; echo
