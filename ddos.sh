#!/bin/bash
##############################################################################
# DDoS-Deflate version 0.6 Author: Zaf <zaf@vsnl.com>                        #
##############################################################################
# This program is distributed under the "Artistic License" Agreement         #
#                                                                            #
# The LICENSE file is located in the same directory as this program. Please  #
#  read the LICENSE file before you make copies or distribute this program   #
##############################################################################
load_conf()
{
	CONF="/usr/local/ddos/ddos.conf"
	if [ -f "$CONF" ] && [ ! "$CONF" ==	"" ]; then
		source $CONF
	else
		head
		echo "\$CONF not found."
		exit 1
	fi
}

head()
{
	echo "DDoS-Deflate version 0.6"
	echo "Copyright (C) 2005, Zaf <zaf@vsnl.com>"
	echo
}

showhelp()
{
	head
	echo 'Usage: ddos.sh [OPTIONS] [N]'
	echo 'N : number of tcp/udp	connections (default 150)'
	echo 'OPTIONS:'
	echo '-h | --help: Show	this help screen'
	echo '-c | --cron: Create cron job to run this script regularly (default 1 mins)'
	echo '-k | --kill: Block the offending ip making more than N connections'
}

unbanip()
{
	UNBAN_SCRIPT=`mktemp /tmp/unban.XXXXXXXX`
	TMP_FILE=`mktemp /tmp/unban.XXXXXXXX`
	UNBAN_IP_LIST=`mktemp /tmp/unban.XXXXXXXX`
	echo '#!/bin/sh' > $UNBAN_SCRIPT
	echo "sleep $BAN_PERIOD" >> $UNBAN_SCRIPT
	if [ $APF_BAN -eq 1 ]; then
		while read line; do
			echo "$APF -u $line" >> $UNBAN_SCRIPT
			echo $line >> $UNBAN_IP_LIST
		done < $BANNED_IP_LIST
	else
		while read line; do
			echo "$IPT -D INPUT -s $line -j DROP" >> $UNBAN_SCRIPT
			echo $line >> $UNBAN_IP_LIST
		done < $BANNED_IP_LIST
	fi
	echo "grep -v --file=$UNBAN_IP_LIST $IGNORE_IP_LIST > $TMP_FILE" >> $UNBAN_SCRIPT
	echo "mv $TMP_FILE $IGNORE_IP_LIST" >> $UNBAN_SCRIPT
	echo "rm -f $UNBAN_SCRIPT" >> $UNBAN_SCRIPT
	echo "rm -f $UNBAN_IP_LIST" >> $UNBAN_SCRIPT
	echo "rm -f $TMP_FILE" >> $UNBAN_SCRIPT
	. $UNBAN_SCRIPT &
}

add_to_cron()
{
	rm -f $CRON
	if [ $FREQ -le 2 ]; then
		echo "0-59/$FREQ * * * * root /usr/local/sbin/ddos >/dev/null 2>&1" > $CRON
	else
		let "START_MINUTE = $RANDOM % ($FREQ - 1)"
		let "START_MINUTE = $START_MINUTE + 1"
		let "END_MINUTE = 60 - $FREQ + $START_MINUTE"
		echo "$START_MINUTE-$END_MINUTE/$FREQ * * * * root /usr/local/sbin/ddos >/dev/null 2>&1" > $CRON
	fi
	
	chmod 644 $CRON
}


load_conf
while [ $1 ]; do
	case $1 in
		'-h' | '--help' | '?' )
			showhelp
			exit
			;;
		'--cron' | '-c' )
			add_to_cron
			exit
			;;
		'--kill' | '-k' )
			KILL=1
			;;
		 *[0-9]* )
			NO_OF_CONNECTIONS=$1
			;;
		* )
			showhelp
			exit
			;;
	esac
	shift
done

TMP_PREFIX='/tmp/ddos'
TMP_FILE="mktemp $TMP_PREFIX.XXXXXXXX"
BANNED_IP_MAIL=`$TMP_FILE`
BANNED_IP_LIST=`$TMP_FILE`
echo "Banned the following ip addresses on `date`" > $BANNED_IP_MAIL
echo >>	$BANNED_IP_MAIL
BAD_IP_LIST=`$TMP_FILE`

# Original command to get ip's
#netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr > $BAD_IP_LIST

# Improved command
netstat -ntu | \
    # Strip netstat heading
    tail -n +3 | \
    # Match only the given connection states
    grep -E "$CONN_STATES" | \
    # Extract only the fifth column
    awk '{print $5}' | \
    # Strip port without affecting ipv6 addresses (experimental)
    sed "s/:[0-9+]*$//g" | \
    # Sort addresses for uniq to work correctly
    sort | \
    # Group same occurrences of ip and prepend amount of occurences found
    uniq -c | \
    # Numerical sort in reverse order
    sort -nr > \
    $BAD_IP_LIST

cat $BAD_IP_LIST
if [ $KILL -eq 1 ]; then
	IP_BAN_NOW=0
	while read line; do
		CURR_LINE_CONN=$(echo $line | cut -d" " -f1)
		CURR_LINE_IP=$(echo $line | cut -d" " -f2)
		if [ $CURR_LINE_CONN -lt $NO_OF_CONNECTIONS ]; then
			break
		fi
		IGNORE_BAN=`grep -c $CURR_LINE_IP $IGNORE_IP_LIST`
		if [ $IGNORE_BAN -ge 1 ]; then
			continue
		fi
		IP_BAN_NOW=1
		echo "$CURR_LINE_IP with $CURR_LINE_CONN connections" >> $BANNED_IP_MAIL
		echo $CURR_LINE_IP >> $BANNED_IP_LIST
		echo $CURR_LINE_IP >> $IGNORE_IP_LIST
		if [ $APF_BAN -eq 1 ]; then
			$APF -d $CURR_LINE_IP
		else
			$IPT -I INPUT -s $CURR_LINE_IP -j DROP
		fi
	done < $BAD_IP_LIST
	if [ $IP_BAN_NOW -eq 1 ]; then
		dt=`date`
		if [ $EMAIL_TO != "" ]; then
			cat $BANNED_IP_MAIL | mail -s "IP addresses banned on $dt" $EMAIL_TO
		fi
		unbanip
	fi
fi
rm -f $TMP_PREFIX.*
