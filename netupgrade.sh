#!/bin/bash
if [ ! $1 ]; then {
	BRANCH="master"
} else {
	BRANCH=$1
}

service ddos stop
if [ -d ~/ddos-deflate-master/]; then {
	mv ~/ddos-deflate-master ~/ddos-deflate
}
cd ~/ddos-deflate/
sh uninstall.sh
cd ~
rm -rf ~/ddos-deflate/
curl -s "https://raw.githubusercontent.com/phoenixweb/ddos-deflate/$BRANCH/netinstall.sh" | bash -s $BRANCH