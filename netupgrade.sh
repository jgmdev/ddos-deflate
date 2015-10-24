#!/bin/bash
if [ -z "$1" ]; then
	BRANCH="master"
else
	BRANCH=$1
fi

if [ -d "/usr/local/ddos" ]; then
	service ddos stop
	if [ -d "/root/ddos-deflate-master/" ]; then
		rm -rf /root/ddos-deflate
		mv /root/ddos-deflate-master /root/ddos-deflate
	fi
	cd /root/ddos-deflate/
	sh uninstall.sh
	rm -rf /root/ddos-deflate/
fi
cd ~
curl -s "https://raw.githubusercontent.com/phoenixweb/ddos-deflate/$BRANCH/netinstall.sh" | bash -s $BRANCH