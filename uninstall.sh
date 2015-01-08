#!/bin/bash
echo; echo "Uninstalling DOS-Deflate"
echo; echo; echo -n "Deleting script files....."
if [ -e '/usr/local/sbin/ddos' ]; then
	rm -f /usr/local/sbin/ddos
	echo -n ".."
fi
if [ -d '/usr/local/ddos' ]; then
	rm -rf /usr/local/ddos
	echo -n ".."
fi
echo "done"
echo; echo -n "Deleting cron job....."
if [ -e '/etc/cron.d/ddos.cron' ]; then
	rm -f /etc/cron.d/ddos.cron
	echo -n ".."
fi
echo "done"
echo; echo "Uninstall Complete"; echo
