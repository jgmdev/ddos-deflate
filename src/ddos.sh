#!/bin/bash
##############################################################################
# DDoS-Deflate version 0.8.0 Author: Massimiliano Cuttini                    #
# DDoS-Deflate version 0.7.1 Author: Zaf <zaf@vsnl.com>                      #
##############################################################################
# Contributors:                                                              #
# Jefferson González <jgmdev@gmail.com>                                      #
##############################################################################
# This program is distributed under the "Artistic License" Agreement         #
#                                                                            #
# The LICENSE file is located in the same directory as this program. Please  #
#  read the LICENSE file before you make copies or distribute this program   #
##############################################################################

CONF_PATH="/etc/ddos"
CONF_PATH="${CONF_PATH}/"
BANNED_DB="/var/lib/ddos/banned.ip.db"

load_conf()
{
    CONF="${CONF_PATH}ddos.conf"
    if [ -f "$CONF" ] && [ ! "$CONF" == "" ]; then
        source $CONF
    else
        head
        echo "\$CONF not found."
        exit 1
    fi
}

head()
{
    echo "DDoS-Deflate version 0.8.0 Copyright (C) 2015, Massimiliano Cuttini"
    echo "DDoS-Deflate version 0.7.1 Copyright (C) 2005, Zaf <zaf@vsnl.com>"
    echo
}

showhelp()
{
    head
    echo 'Usage: ddos [OPTIONS] [N]'
    echo 'N : number of tcp/udp connections (default 150)'
    echo
    echo 'OPTIONS:'
    echo '-h | --help:	Show this help screen'
    echo '-b | --ban:	Ban an IP immediatly'
    echo '-u | --unban:	Unban an IP immediatly'
    echo '-c | --cron:	Create cron job to run this script regularly (default 1 mins)'
    echo '-i | --ignore-list: List whitelisted ip addresses'
    echo '-d | --start:	Initialize a daemon to monitor connections'
    echo '-s | --stop:	Stop the daemon'
    echo '-t | --status: Show status of daemon and pid if currently running'
    echo '-v | --view:	Display active connections to the server'
    echo '-k | --kill:	Block all ip addresses making more than N connections'
	echo '--startonboot [on|off]: Insert DDOS in the chkconfig to start when system boot'
}

# Check if super user is executing the
# script and exit with message if not.
su_required()
{
    user_id=`id -u`

    if [ "$user_id" != "0" ]; then
        echo "You need super user priviliges for this."
        exit
    fi
}

log_msg()
{
    if [ ! -e /var/log/ddos.log ]; then
        touch /var/log/ddos.log
        chmod 0640 /var/log/ddos.log
    fi

    echo "$(date +'[%Y-%m-%d %T]') $1" >> /var/log/ddos.log
}

# Define a timestamp function
timestamp() {
  date +"%T"
}
# Create full list of IP to ignore
ignore_list()
{
    # Get ip's of ethernet interfaces to prevent blocking it self.
    for iface_ip in $(ifconfig | grep "inet " | awk '{print $2}' | sed "s/addr://g"); do
        echo $iface_ip
    done

	if [ "$IGNORE_KNOW_HOSTS" = "1" ]; then
		get_know_hosts
    fi

	if [ "$USE_IGNORE_HOST_LIST" = "1" ]; then
		get_ignore_hosts
    fi

	if [ "$USE_IGNORE_IP_LIST" = "1" ]; then
		get_ignore_ips
    fi	
}

# Gets the list of hosts to ignore
get_ignore_hosts() {
	for the_host in $(grep -v "#" "${CONF_PATH}${IGNORE_HOST_LIST}"); do
        host_ip=`nslookup $the_host | tail -n +3 | grep "Address" | awk '{print $2}'`

        # In case an ip is given instead of hostname
        # in the ignore.hosts.list file
        if [ "$host_ip" = "" ]; then
            echo $the_host
        else
            for ips in $host_ip; do
                echo $ips
            done
        fi
    done
}
get_ignore_ips() {
	grep -v "#" "${CONF_PATH}${IGNORE_IP_LIST}"
}
# Gets the list of know hosts
get_know_hosts() {
	grep -v "#"  "${KNOW_HOST_FILE}" | awk '{print $1}'
}

ban_ip_now() {
	IP_TO_BAN=$1;
	TIME_TO_BAN=$2;
	START_TIME=timestamp;
	END_TIME=$(timestamp + $TIME_TO_BAN);

	if [$3 = "" ]; then
		SERVICE="manual";
	else
		SERVICE=$3;
	fi

	if [$4 = "" ]; then
		NUM_OF_CONNECTIONS="-";
	else
		NUM_OF_CONNECTIONS=$4;
	fi

	if [ "$FIREWALL" = "apf" ]; then
		$APF -d $IP_TO_BAN
	elif [ "$FIREWALL" = "csf" ]; then
		$CSF -d $IP_TO_BAN
	elif [ "$FIREWALL" = "iptables" ]; then
		$IPT -I INPUT -s $IP_TO_BAN -j REJECT
	fi

	kill_connections $IP_TO_BAN

	echo "Adding banned IP to database";
	echo "$IP_TO_BAN    $START_TIME    $END_TIME    $SERVICE    $NUM_OF_CONNECTIONS" >> $BANNED_DB
}

list_banned_ip() {
	cat $BANNED_DB
}

unban_ip_now() {
	IP_TO_UNBAN=$1;

	if [ "$FIREWALL" = "apf" ]; then
		$APF -u $IP_TO_UNBAN
	elif [ "$FIREWALL" = "csf" ]; then
		$CSF -dr $IP_TO_UNBAN
	elif [ "$FIREWALL" = "iptables" ]; then
		$IPT -D INPUT -s $IP_TO_UNBAN -j REJECT
	fi

	echo "$(date +'[%Y-%m-%d %T]') unbanned $IP_TO_UNBAN" >> /var/log/ddos.log

	echo "Removing banned IP $IP_TO_UNBAN from database";
	sed -i.bak '/^$IP_TO_UNBAN/d' $BANNED_DB
}
kill_connections() {
	IP_TO_KILL=$1;

	echo "Kill all TCP connections with host $IP_TO_KILL"
	tcpkill host $IP_TO_KILL &
	sleep 10
	for child in $(jobs -p); do
		kill "$child"
	done
	wait $(jobs -p)
}
# Generates a shell script that unbans a list of ip's after the
# amount of time given on BAN_PERIOD
free_banned() {
    if [ -f "$BANNED_DB" ] && [ ! "$BANNED_DB" == "" ]; then
        while read line; do
			[ -z "$line" ] && continue
			IP_TO_CHECK=$(awk '{print $1}' $line);
			START_TIME=$(awk '{print $2}' $line)
			END_TIME=$(awk '{print $3}' $line)
			END_TIME_HUMAN=$(awk 'strftime("%c", $0)' $END_TIME_HUMAN);
			NOW=timestamp

			if ( $NOW > $END_TIME ); then
				echo "Block on $IP_TO_CHECK expired";
				unban_ip_now $line
			else
				echo "IP $IP_TO_CHECK remain blocked till $END_TIME_HUMAN"
			fi
		done < $BANNED_DB
    else
        echo "" > $BANNED_DB
    fi
}
unban_ip_list()
{
    UNBAN_SCRIPT=`mktemp /tmp/unban.sh.XXXXXXXX`
    echo '#!/bin/sh' > $UNBAN_SCRIPT
    echo "sleep $BAN_PERIOD" >> $UNBAN_SCRIPT
    echo "$SBINDIR/ddos -f" >> $UNBAN_SCRIPT
    echo "rm -f $UNBAN_SCRIPT" >> $UNBAN_SCRIPT
    . $UNBAN_SCRIPT &
}

add_to_cron()
{
    su_required

    rm -f $CRON
    if [ $FREQ -le 2 ]; then
        echo "0-59/$FREQ * * * * root $SBINDIR/ddos >/dev/null 2>&1" > $CRON
    else
        let "START_MINUTE = $RANDOM % ($FREQ - 1)"
        let "START_MINUTE = $START_MINUTE + 1"
        let "END_MINUTE = 60 - $FREQ + $START_MINUTE"
        echo "$START_MINUTE-$END_MINUTE/$FREQ * * * * root $SBINDIR/ddos >/dev/null 2>&1" > $CRON
    fi

    chmod 644 $CRON

    log_msg "added cron job"
}

# Check active connections and ban if neccessary.
check_connections() {
	check_service_connections "http"
	check_service_connections
}

check_service_connections()
{
    su_required

	SERVICE=$1
    TMP_PREFIX='/tmp/ddos'
    TMP_FILE="mktemp $TMP_PREFIX.XXXXXXXX"
    BAD_IP_LIST=`$TMP_FILE`

    # Original command to get ip's
    #netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr > $BAD_IP_LIST

	if [ "$SERVICE" = "http" ]; then
		echo "Checking IP with more than $NO_OF_CONNECTIONS_HTTP HTTP connections..."
		view_http_connections | awk "{ if (\$1 >= $NO_OF_CONNECTIONS_HTTP) print; }" > $BAD_IP_LIST
	else
		SERVICE="all"
		echo "Checking IP with more than $NO_OF_CONNECTIONS total connections..."
		view_connections | awk "{ if (\$1 >= $NO_OF_CONNECTIONS) print; }" > $BAD_IP_LIST
	fi

    FOUND=$(cat $BAD_IP_LIST)

    if [ "$FOUND" = "" ]; then
        rm -f $BAD_IP_LIST

        if [ $KILL -eq 1 ]; then
            echo "No connections exceeding max allowed."
        fi

        return 0
    fi

    if [ $KILL -eq 1 ]; then
        echo "List of connections that exceed max allowed on $SERVICE services"
        echo "==========================================="
        cat $BAD_IP_LIST
    fi

	BANNED_IP_MAIL=`$TMP_FILE`
    BANNED_IP_LIST=`$TMP_FILE`

    echo "Banned the following ip addresses on `date`" > $BANNED_IP_MAIL
    echo >> $BANNED_IP_MAIL

    IP_BAN_NOW=0

    while read line; do
        CURR_LINE_CONN=$(echo $line | cut -d" " -f1)
        CURR_LINE_IP=$(echo $line | cut -d" " -f2)

        IGNORE_BAN=`ignore_list | grep -c $CURR_LINE_IP`

        if [ $IGNORE_BAN -ge 1 ]; then
            continue
        fi

        IP_BAN_NOW=1

		ban_ip_now CURR_LINE_CONN
        echo "$CURR_LINE_IP with $CURR_LINE_CONN connections" >> $BANNED_IP_MAIL
        echo $CURR_LINE_IP >> $BANNED_IP_LIST

		ban_ip_now $CURR_LINE_IP $BAN_PERIOD

        log_msg "banned $CURR_LINE_IP with $CURR_LINE_CONN connections on service $SERVICE for ban period $BAN_PERIOD"
    done < $BAD_IP_LIST

    if [ $IP_BAN_NOW -eq 1 ]; then
        if [ $EMAIL_TO != "" ]; then
            dt=`date`
            cat $BANNED_IP_MAIL | mail -s "[$HOSTNAME] service $SERVICE - IPs banned on $dt" $EMAIL_TO
        fi

        unban_ip_list

        if [ $KILL -eq 1 ]; then
            echo "==========================================="
            echo "Banned IP addresses:"
            echo "==========================================="
            cat $BANNED_IP_LIST
        fi
    fi

    rm -f $TMP_PREFIX.*
}

# Active connections to server.
view_connections()
{
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
        sort -nr
}

# Active HTTP connections to server.
view_http_connections()
{
    netstat -ntu | \
        # Strip netstat heading
        tail -n +3 | \
        # Match only the given connection states
        grep -E "$CONN_STATES" | \
        # Extract both destination and source ip address
        awk '{print $5" "$4}' | \
		# Extract only HTTP and HTTPS ports
		egrep ":($HTTP_PORTS)$"	| \
		# Extract only source IP address
		awk '{print $1}' | \
        # Strip port without affecting ipv6 addresses (experimental)
        sed "s/:[0-9+]*$//g" | \
        # Sort addresses for uniq to work correctly
        sort | \
        # Group same occurrences of ip and prepend amount of occurences found
        uniq -c | \
        # Numerical sort in reverse order
        sort -nr
}

#Start UP
start_on_boot() {
	SELECT=$1
	if [ "$SELECT" = "off" ]; then
		echo "On system start level 235 DDOS is OFF"
		chkconfig --levels 235 ddos off
	else
		echo "On system start level 235 DDOS is ON"
		chkconfig --levels 235 ddos on
	fi
}


# Executed as a cleanup function when the daemon is stopped
on_daemon_exit()
{
    if [ -e /var/run/ddos.pid ]; then
        rm -f /var/run/ddos.pid
    fi

    exit 0
}

# Return the current process id of the daemon or 0 if not running
daemon_pid()
{
    if [ -e /var/run/ddos.pid ]; then
        echo $(cat /var/run/ddos.pid)

        return
    fi

    echo "0"
}

# Check if daemon us running.
# Outputs 1 if running 0 if not.
daemon_running()
{
    if [ -e /var/run/ddos.pid ]; then
        running_pid=$(ps -A | grep ddos | awk '{print $1}')

        if [ "$running_pid" != "" ]; then
            current_pid=$(daemon_pid)

            for pid_num in $running_pid; do
                if [ "$current_pid" = "$pid_num" ]; then
                    echo "1"
                    return
                fi
            done
        fi
    fi

    echo "0"
}

start_daemon_debug() {
	su_required

    if [ $(daemon_running) = "1" ]; then
        echo "ddos daemon is already running..."
        exit 0
    fi

    echo "starting ddos daemon for debugging..."

    $0 -l
}
start_daemon()
{
    su_required

    if [ $(daemon_running) = "1" ]; then
        echo "ddos daemon is already running..."
        exit 0
    fi

    echo "starting ddos daemon..."

    nohup $0 -l > /dev/null 2>&1 &

    log_msg "daemon started"
}

stop_daemon()
{
    su_required

    if [ $(daemon_running) = "0" ]; then
        echo "ddos daemon is not running..."
        exit 0
    fi

    echo "stopping ddos daemon..."

    kill $(daemon_pid)

    while [ -e /var/run/ddos.pid ]; do
        continue
    done

    log_msg "daemon stopped"
}

daemon_loop()
{
    su_required

    if [ $(daemon_running) = "1" ]; then
        exit 0
    fi

    echo "$$" > /var/run/ddos.pid

    trap 'on_daemon_exit' INT
    trap 'on_daemon_exit' QUIT
    trap 'on_daemon_exit' TERM
    trap 'on_daemon_exit' EXIT

    detect_firewall

    while true; do
        check_connections
        sleep $DAEMON_FREQ
    done
}

daemon_status()
{
    current_pid=$(daemon_pid)

    if [ $(daemon_running) = "1" ]; then
        echo "ddos status: running with pid $current_pid"
    else
        echo "ddos status: not running"
    fi
}

detect_firewall()
{
    if [ "$FIREWALL" = "auto" ] || [ "$FIREWALL" = "" ]; then
        apf_where=`whereis apf`;
        csf_where=`whereis csf`;
        ipt_where=`whereis iptables`;

        if [ -e "$APF" ]; then
            FIREWALL="apf"
        elif [ -e "$CSF" ]; then
            FIREWALL="csf"
        elif [ -e "$IPT" ]; then
            FIREWALL="iptables"
        elif [ "$apf_where" != "apf:" ]; then
            FIREWALL="apf"
            APF="apf"
        elif [ "$csf_where" != "csf:" ]; then
            FIREWALL="csf"
            CSF="csf"
        elif [ "$ipt_where" != "iptables:" ]; then
            FIREWALL="iptables"
            IPT="iptables"
        else
            echo "error: No valid firewall found."
            log_msg "error: no valid firewall found"
            exit 1
        fi
    fi
}

load_conf

KILL=0

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
        '--free-banned' | '-f' )
			echo "Checking if there are IPs to unban..."
            free_banned
			echo "Done!"
            exit
            ;;
        '--ignore-list' | '-i' )
            echo "List of currently whitelisted IPs"
            echo "==================================="
            ignore_list
            exit
            ;;
		'--ban' | '-b' )
			echo "Ban now the following IP: $2"
			ban_ip_now $2
			exit
			;;
		'--unban' | '-u' )
			echo "Delist now the following IP: $2"
			unban_ip_now $2
			exit
			;;
        '--start' | '-d' )
            start_daemon
            exit
            ;;
        '--stop' | '-s' )
            stop_daemon
            exit
            ;;
        '--status' | '-t' )
            daemon_status
            exit
            ;;
        '--debug')
			stop_daemon
            start_daemon_debug
            exit
            ;;
        '--loop' | '-l' )
            # start daemon loop, used internally by --start | -s
            daemon_loop
            exit
            ;;
        '--view' | '-v' )
			LIST_HTTP_CONNECTIONS=$(view_http_connections)
			NUM_HTTP_CONNECTIONS=$(printf "$LIST_HTTP_CONNECTIONS" | wc -l)
			echo "==================================="
			echo "List of currently HTTP ($HTTP_PORTS) connections"
			echo "Number of clients connected: $NUM_HTTP_CONNECTIONS"			
			echo "==================================="			
			printf "$LIST_HTTP_CONNECTIONS"
			echo

			LIST_ALL_CONNECTIONS=$(view_connections)
			NUM_ALL_CONNECTIONS=$(printf "$LIST_ALL_CONNECTIONS" | wc -l)
			echo "==================================="
			echo "List of all currently active connections"
			echo "Number of clients connected: $NUM_ALL_CONNECTIONS"	
			echo "==================================="
			printf "$LIST_ALL_CONNECTIONS"
			echo

            exit
            ;;
		'--startonboot')
            start_on_boot $2
            exit
            ;;
        '--kill' | '-k' )
            su_required
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

if [ $KILL -eq 1 ]; then
    detect_firewall
    check_connections
else
    showhelp
fi

exit 0
