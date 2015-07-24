#!/bin/bash
service ddos stop
cd ~/ddos-deflate-master/
sh uninstall.sh
cd ~
rm -rf ~/ddos-deflate-master/
curl -s "https://raw.githubusercontent.com/phoenixweb/ddos-deflate/master/netinstall.sh" | bash