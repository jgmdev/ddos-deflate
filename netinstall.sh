#!/bin/bash
if [ ! $1 ]; then {
	BRANCH="master"
} else {
	BRANCH=$1
}

cd ~
wget "https://github.com/phoenixweb/ddos-deflate/archive/$BRANCH.zip" -O ~/ddos-deflate-latest.zip
unzip ~/ddos-deflate-latest.zip -d ~
mv ~/ddos-deflate-$BRANCH/ ~/ddos-deflate/
cd ~/ddos-deflate/
sh install.sh
rm -rf ~/ddos-deflate-latest.zip