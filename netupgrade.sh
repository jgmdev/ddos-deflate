#!/bin/bash
if [ -z "$1" ]; then
	BRANCH="master"
else
	BRANCH=$1
fi

service ddos stop
if [ -d ~/ddos-deflate-master/]; then if
	mv ~/ddos-deflate-master ~/ddos-deflate
fi
cd ~/ddos-deflate/
sh uninstall.sh
cd ~
rm -rf ~/ddos-deflate/
curl -s "https://raw.githubusercontent.com/phoenixweb/ddos-deflate/$BRANCH/netinstall.sh" | bash -s $BRANCH