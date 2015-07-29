#!/bin/bash
if [ -z "$1" ]; then
	BRANCH="master"
else
	BRANCH=$1
fi

if [ -d "$DESTDIR/usr/local/ddos" ]; then
	service ddos stop
	if [ -d "~/ddos-deflate-master/" ]; then
		mv ~/ddos-deflate-master ~/ddos-deflate
	fi
	cd ~/ddos-deflate/
	sh uninstall.sh
	cd ~
	rm -rf ~/ddos-deflate/
fi
curl -s "https://raw.githubusercontent.com/phoenixweb/ddos-deflate/$BRANCH/netinstall.sh" | bash -s $BRANCH