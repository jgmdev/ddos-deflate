#!/bin/bash
if [ -d '/usr/local/ddos' ]; then
	echo; echo; echo "Please un-install the previous version first"
	exit 0
else
	mkdir /usr/local/ddos
fi
clear

echo; echo 'Installing DOS-Deflate 0.6'; echo

echo; echo 'Adding: /usr/local/ddos/ddos.conf'
cp ddos.conf /usr/local/ddos/ddos.conf
echo '.....done'

echo; echo 'Adding: /usr/local/ddos/LICENSE'
cp LICENSE /usr/local/ddos/LICENSE
echo '.....done'

echo; echo 'Adding: /usr/local/ddos/ddos.conf'
cp ignore.ip.list /usr/local/ddos/ignore.ip.list
echo '.....done'

echo; echo 'Adding: /usr/local/ddos/ddos.sh'
cp ddos.sh /usr/local/ddos/ddos.sh
chmod 0755 /usr/local/ddos/ddos.sh
echo '.....done'

echo; echo 'Creating ddos symlink: /usr/local/sbin/ddos'
cp -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos
echo '.....done'

echo; echo -n 'Creating cron to run script every minute.....(Default setting)'
/usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
echo '.....done'
echo; echo 'Installation has completed.'
echo 'Config file is at /usr/local/ddos/ddos.conf'
echo 'Please send in your comments and/or suggestions to zaf@vsnl.com'
echo

# Check if less is installed and use it to print display license
LESS_PATH=`whereis less`
if [ "$LESS_PATH" -eq "less:" ]; then
	cat /usr/local/ddos/LICENSE
else
	cat /usr/local/ddos/LICENSE | less
fi

exit 0
