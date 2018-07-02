#!/bin/sh
##############################################################################
# DDoS-Deflate version 0.9 Author: Zaf <zaf@vsnl.com>                        #
##############################################################################
# Contributors:                                                              #
# Jefferson González <jgmdev@gmail.com>                                      #
# Marc S. Brooks <devel@mbrooks.info>                                        #
##############################################################################
# This program is distributed under the "Artistic License" Agreement         #
#                                                                            #
# The LICENSE file is located in the same directory as this program. Please  #
# read the LICENSE file before you make copies or distribute this program    #
##############################################################################

CONF_PATH="/etc/ddos"
CONF_PATH="${CONF_PATH}/"

# Other variables
BANS_IP_LIST="/var/lib/ddos/bans.list"
SERVER_IP_LIST=`ifconfig | egrep "inet6? " | sed "s/addr: /addr:/g" | awk '{print $2}' | sed -E "s/addr://g" | sed -E "s/\/[0-9]+//g" | xargs | sed -e 's/ /|/g'`

load_conf()
{
    CONF="${CONF_PATH}ddos.conf"
    if [ -f "$CONF" ] && [ -n "$CONF" ]; then
        . $CONF
    else
        head
        echo "\$CONF not found."
        exit 1
    fi
}

head()
{
    echo "DDoS-Deflate version 0.9"
    echo "Copyright (C) 2005, Zaf <zaf@vsnl.com>"
    echo
}

showhelp()
{
    head
    echo 'Usage: ddos [OPTIONS] [N]'
    echo 'N : number of tcp/udp connections (default 150)'
    echo
    echo 'OPTIONS:'
    echo '-h | --help: Show this help screen'
    echo '-c | --cron: Create cron job to run this script regularly (default 1 mins)'
    echo '-i | --ignore-list: List whitelisted ip addresses'
    echo '-b | --bans-list: List currently banned ip addresses.'
    echo '-u | --unban: Unbans a given ip address.'
    echo '-d | --start: Initialize a daemon to monitor connections'
    echo '-s | --stop: Stop the daemon'
    echo '-t | --status: Show status of daemon and pid if currently running'
    echo '-v | --view: Display active connections to the server'
    echo '-k | --kill: Block all ip addresses making more than N connections'
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

# Gets a list of ip address to ignore with hostnames on the
# ignore.host.list resolved to ip numbers
# param1 can be set to 1 to also include the bans list
ignore_list()
{
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

    # Get ip's of ethernet interfaces to prevent blocking it self.
    #for iface_ip in $(ifconfig | grep "inet " | awk '{print $2}' | sed "s/addr://g"); do
    #    echo $iface_ip
    #done

    grep -v "#" "${CONF_PATH}${IGNORE_IP_LIST}"

    if [ "$1" = "1" ]; then
        cut -d" " -f2 "${BANS_IP_LIST}"
    fi
}

unban_ip()
{
    if [ "$1" = "" ]; then
        return 1
    fi

    if [ "$FIREWALL" = "apf" ]; then
        $APF -u "$1"
    elif [ "$FIREWALL" = "csf" ]; then
        $CSF -dr "$1"
    elif [ "$FIREWALL" = "ipfw" ]; then
        rule_number=`$IPF list | awk "/$1/{print $1}"`
        $IPF -q delete $rule_number
    elif [ "$FIREWALL" = "iptables" ]; then
        $IPT -D INPUT -s "$1" -j DROP
    fi

    log_msg "unbanned $ip"

    grep -v "$1" "${BANS_IP_LIST}" > "${BANS_IP_LIST}.tmp"
    rm "${BANS_IP_LIST}"
    mv "${BANS_IP_LIST}.tmp" "${BANS_IP_LIST}"

    return 0
}

# Unbans ip's after the amount of time given on BAN_PERIOD
unban_ip_list()
{
    current_unban_time=`date +"%s"`

    while read line; do
        if [ "$line" = "" ]; then
            continue
        fi

        ban_time=`echo "$line" | cut -d" " -f1`
        ip=`echo "$line" | cut -d" " -f2`
        connections=`echo "$line" | cut -d" " -f3`

        if [ $current_unban_time -gt $ban_time ]; then
            unban_ip "$ip"
        fi
    done < $BANS_IP_LIST
}

add_to_cron()
{
    su_required

    if [ $FREQ -le 2 ]; then
        cron_task="0-59/$FREQ * * * * root $SBINDIR/ddos -k >/dev/null 2>&1"

        if [ "$FIREWALL" = "ipfw" ]; then
            cron_file=/etc/crontab
            sed -i '' '/ddos/d' $cron_file
            echo $cron_task >> $cron_file
        else
            rm -f $CRON
            echo $cron_task > $CRON
            chmod 644 $CRON
        fi
    else
        let "START_MINUTE = $RANDOM % ($FREQ - 1)"
        let "START_MINUTE = $START_MINUTE + 1"
        let "END_MINUTE = 60 - $FREQ + $START_MINUTE"

        cron_task="$START_MINUTE-$END_MINUTE/$FREQ * * * * root $SBINDIR/ddos -k >/dev/null 2>&1"

        if [ "$FIREWALL" = "ipfw" ]; then
            echo $cron_task >> /etc/crontab
        else
            echo $cron_task > $CRON
            chmod 644 $CRON
        fi
    fi

    log_msg "added cron job"
}

ban_incoming_and_outgoing()
{
    # Find all connections
    netstat -an | \
        # Match only the given connection states
        grep -E "$CONN_STATES" | \
        # Extract only the fifth column
        awk '{print $5}' | \
        # Strip port without affecting ipv4 addresses
        sed -r 's/^([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})(:|\.)[0-9+]*$/\1.\2.\3.\4/' | \
        # Strip port without affecting ipv6 addresses (experimental)
        sed 's/:[0-9+]*$//g' | \
        # Ignore Server IP
        sed -r "/^($SERVER_IP_LIST)$/Id" | \
        # Sort addresses for uniq to work correctly
        sort | \
        # Group same occurrences of ip and prepend amount of occurences found
        uniq -c | \
        # Numerical sort in reverse order
        sort -nr | \
        # Replace ::fff: String on ip
        sed 's/::ffff://g' | \
        # Only store connections that exceed max allowed
        awk "{ if (\$1 >= $NO_OF_CONNECTIONS) print; }" > \
        $1
}

ban_only_incoming()
{
    ALL_LISTENING=$(mktemp $TMP_PREFIX.XXXXXXXX)
    ALL_CONNS=$(mktemp $TMP_PREFIX.XXXXXXXX)

    # Find all connections
    netstat -an | \
        # Match only the given connection states
        grep -E "$CONN_STATES" | \
        # Extract both local and foreign address:port
        awk '{print $4" "$5;}'> \
        $ALL_CONNS

    # Find all connections
    netstat -an | \
        # Only keep local address:port
        awk '{print $4}' | \
        # Also include specific server address when address is 0.0.0.0 (only ipv4)
        awk -v host_ip=$HOST_IP \
        '{ ip_pos = index($0, "0.0.0.0");
            if (ip_pos != 0) {
                port_pos = index($0, ":");
                print $0;
                print host_ip substr($0, port_pos);
            } else {
                print $0;
            }
        }' > \
        $ALL_LISTENING

    # Only keep connections which are connected to local listening address:port but print foreign address:port
    # ipv6 is always included
    awk 'NR==FNR{a[$1];next} $1 in a {print $2}' $ALL_LISTENING $ALL_CONNS | \
        # Strip port without affecting ipv4 addresses
        sed -r 's/^([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})(:|\.)[0-9+]*$/\1.\2.\3.\4/' | \
        # Strip port without affecting ipv6 addresses (experimental)
        sed "s/:[0-9+]*$//g" | \
        # Ignore Server IP
        sed -r "/^($SERVER_IP_LIST)$/Id" | \
        # Sort addresses for uniq to work correctly
        sort | \
        # Group same occurrences of ip and prepend amount of occurences found
        uniq -c | \
        # Numerical sort in reverse order
        sort -nr | \
        # Replace ::fff: String on ip
        sed 's/::ffff://g' | \
        # Only store connections that exceed max allowed
        awk "{ if (\$1 >= $NO_OF_CONNECTIONS) print; }" > \
        $1

    rm $ALL_LISTENING
    rm $ALL_CONNS
}

# Check active connections and ban if neccessary.
check_connections()
{
    su_required

    TMP_PREFIX='/tmp/ddos'
    TMP_FILE="mktemp $TMP_PREFIX.XXXXXXXX"
    BAD_IP_LIST=`$TMP_FILE`

    # Original command to get ip's
    #netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr > $BAD_IP_LIST

    if $ONLY_INCOMING; then
        ban_only_incoming $BAD_IP_LIST
    else
        ban_incoming_and_outgoing $BAD_IP_LIST
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
        echo "List of connections that exceed max allowed"
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

        IGNORE_BAN=`ignore_list "1" | grep -c $CURR_LINE_IP`

        if [ $IGNORE_BAN -ge 1 ]; then
            continue
        fi

        IP_BAN_NOW=1

        echo "$CURR_LINE_IP with $CURR_LINE_CONN connections" >> $BANNED_IP_MAIL
        echo $CURR_LINE_IP >> $BANNED_IP_LIST

        current_time=`date +"%s"`
        echo "$(($current_time+$BAN_PERIOD)) ${CURR_LINE_IP} ${CURR_LINE_CONN}" >> "${BANS_IP_LIST}"

        # execute tcpkill for 60 seconds
        timeout -k 60 -s 9 60 \
            tcpkill -9 host $CURR_LINE_IP > /dev/null 2>&1 &

        if [ "$FIREWALL" = "apf" ]; then
            $APF -d $CURR_LINE_IP
        elif [ "$FIREWALL" = "csf" ]; then
            $CSF -d $CURR_LINE_IP
        elif [ "$FIREWALL" = "ipfw" ]; then
            rule_number=`ipfw list | tail -1 | awk '/deny/{print $1}'`
            next_number=$((rule_number + 1))
            $IPF -q add $next_number deny all from $CURR_LINE_IP to any
        elif [ "$FIREWALL" = "iptables" ]; then
            $IPT -I INPUT -s $CURR_LINE_IP -j DROP
        fi

        log_msg "banned $CURR_LINE_IP with $CURR_LINE_CONN connections for ban period $BAN_PERIOD"
    done < $BAD_IP_LIST

    if [ $IP_BAN_NOW -eq 1 ]; then
        if [ -n "$EMAIL_TO" ]; then
            dt=`date`
            hn=`hostname`
            cat $BANNED_IP_MAIL | mail -s "[$hn] IP addresses banned on $dt" $EMAIL_TO
        fi

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
    # Find all connections
    netstat -an | \
        # Match only the given connection states
        grep -E "$CONN_STATES" | \
        # Extract only the fifth column
        awk '{print $5}' | \
        # Strip port without affecting ipv4 addresses
        sed -r 's/^([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})(:|\.)[0-9+]*$/\1.\2.\3.\4/' | \
        # Strip port without affecting ipv6 addresses (experimental)
        sed "s/:[0-9+]*$//g" | \
        # Ignore Server IP
        sed -r "/($SERVER_IP_LIST)/Id" | \
        # Sort addresses for uniq to work correctly
        sort | \
        # Group same occurrences of ip and prepend amount of occurences found
        uniq -c | \
        # Numerical sort in reverse order
        sort -nr | \
        # Replace ::fff: String on ip
        sed 's/::ffff://g'
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

# Check if daemon is running.
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

start_daemon()
{
    su_required

    if [ $(daemon_running) = "1" ]; then
        echo "ddos daemon is already running..."
        exit 0
    fi

    echo "starting ddos daemon..."

    if [ ! -e "$BANS_IP_LIST" ]; then
        touch "${BANS_IP_LIST}"
    fi

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

    # run unban_ip_list after 2 minutes of initialization
    ban_check_timer=`date +"%s"`
    ban_check_timer=$(($ban_check_timer+120))

    while true; do
        check_connections

        # unban expired ip's every 1 minute
        current_loop_time=`date +"%s"`
        if [ $current_loop_time -gt $ban_check_timer ]; then
            unban_ip_list
            ban_check_timer=`date +"%s"`
            ban_check_timer=$(($ban_check_timer+60))
        fi

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
        ipf_where=`whereis ipfw`;
        ipt_where=`whereis iptables`;

        if [ -e "$APF" ]; then
            FIREWALL="apf"
        elif [ -e "$CSF" ]; then
            FIREWALL="csf"
        elif [ -e "$IPF" ]; then
            FIREWALL="ipfw"
        elif [ -e "$IPT" ]; then
            FIREWALL="iptables"
        elif [ "$apf_where" != "apf:" ]; then
            FIREWALL="apf"
            APF="apf"
        elif [ "$csf_where" != "csf:" ]; then
            FIREWALL="csf"
            CSF="csf"
        elif [ "$ipf_where" != "ipfw:" ]; then
            FIREWALL="ipfw"
            IPF="ipfw"
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

# Set Default settings
PROGDIR="/usr/local/ddos"
SBINDIR="/usr/local/sbin"
PROG="$PROGDIR/ddos.sh"
IGNORE_IP_LIST="ignore.ip.list"
IGNORE_HOST_LIST="ignore.host.list"
CRON="/etc/cron.d/ddos"
APF="/usr/sbin/apf"
CSF="/usr/sbin/csf"
IPF="/sbin/ipfw"
IPT="/sbin/iptables"
FREQ=1
DAEMON_FREQ=5
NO_OF_CONNECTIONS=150
FIREWALL="auto"
EMAIL_TO="root"
BAN_PERIOD=600
CONN_STATES="ESTABLISHED|SYN_SENT|SYN_RECV|FIN_WAIT1|FIN_WAIT2|TIME_WAIT|CLOSE_WAIT|LAST_ACK|CLOSING"
ONLY_INCOMING=false
HOST_IP="0.0.0.0"

# Load custom settings
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
        '--ignore-list' | '-i' )
            echo "List of currently whitelisted ip's."
            echo "==================================="
            ignore_list
            exit
            ;;
        '--bans-list' | '-b' )
            echo "List of currently banned ip's."
            echo "==================================="
            if [ -e "${BANS_IP_LIST}" ]; then
                cat "${BANS_IP_LIST}"
            fi
            exit
            ;;
        '--unban' | '-u' )
            su_required
            shift
            unban_ip $1
            if [ $? -gt 0 ]; then
                echo "Please specify a valid ip address."
            fi
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
        '--loop' | '-l' )
            # start daemon loop, used internally by --start | -s
            daemon_loop
            exit
            ;;
        '--view' | '-v' )
            view_connections
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
