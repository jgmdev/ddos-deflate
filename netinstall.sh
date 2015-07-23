#!/bin/bash
cd ~
wget https://github.com/phoenixweb/ddos-deflate/archive/master.zip -O ~/ddos-deflate-latest.zip
unzip ~/ddos-deflate-latest.zip -d ~
# install.sh contains relative urls then it's important to CD to the install directory
cd ~/ddos-deflate-master/
sh install.sh
rm -rf ~/ddos-deflate-latest.zip