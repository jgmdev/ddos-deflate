# DDoS Deflate
Fork of DDoS Deflate http://deflate.medialayer.com/ with
fixes, improvements and new features.

**Original Author:** Zaf <zaf@vsnl.com> (Copyright (C) 2005)

**Maintainer:** Jefferson González <jgmdev@gmail.com>

**Contributor (BSD support):** Marc S. Brooks <devel@mbrooks.info>

## About

(D)DoS Deflate is a lightweight bash shell script designed to assist in
the process of blocking a denial of service attack. It utilizes the
command below to create a list of IP addresses connected to the server,
along with their total number of connections. It is one of the simplest
and easiest to install solutions at the software level.

netstat -an | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n

IP addresses with over a pre-configured number of connections are
automatically blocked in the server's firewall, which can be direct
ipfw, iptables, or Advanced Policy Firewall (APF). (We highly recommend that
you use APF on your server in general, but deflate will work without it.)

### Notable Features

* It is possible to whitelist IP addresses, via /etc/ddos/ignore.ip.list.
* It is possible to whitelist hostnames, via /etc/ddos/ignore.host.list.
* Simple configuration file: /etc/ddos/ddos.conf
* IP addresses are automatically unblocked after a preconfigured time limit (default: 600 seconds)
* The script can run as a cron job at chosen frequency via the configuration file (default: 1 minute)
* The script can run as a daemon at chosen frequency via the configuration file (default: 5 seconds)
* You can receive email alerts when IP addresses are blocked.
* Control blocking by connection state (see man netstat).
* Auto-detection of firewall.
* Support for APF, CSF, ipfw, and iptables.
* Logs events to /var/log/ddos.log
* Uses tcpkill to reduce the amount of processes opened by attackers.

## Installation

As root user execute the following commands:

```shell
wget https://github.com/jgmdev/ddos-deflate/archive/master.zip
unzip master.zip
cd ddos-deflate-master
./install.sh
```

## Uninstallation

As root user execute the following commands:

```shell
cd ddos-deflate-master
./uninstall.sh
```

## Usage

The installer will automatically detect if your system supports
init.d scripts, systemd services or cron jobs. If one of them is found
it will install apropiate files and start the ddos script. In the
case of init.d and systemd the ddos script is started as a daemon,
which monitoring interval is set at 5 seconds by default. The daemon
is much faster detecting attacks than the cron job since cron's are
capped at 1 minute intervals.

Once you hava (D)Dos deflate installed proceed to modify the config
files to fit your needs.

**/etc/ddos/ignore.host.list**

On this file you can add a list of host names to be whitelisted, for
example:

> googlebot.com <br />
> my-dynamic-ip.somehost.com

**/etc/ddos/ignore.ip.list**

On this file you can add a list of ip addresses to be whitelisted, for
example:

> 12.43.63.13 <br />
> 129.134.131.2

**/etc/ddos/ddos.conf**

The behaviour of the ddos script is modified by this configuration file.
For more details see **man ddos** which has documentation of the
different configuration options.

After you modify the config files you will need to restart the daemon.
If running on systemd:

> systemctl restart ddos

If running as classical init.d script:

> /etc/init.d/ddos restart <br />
> or <br />
> service ddos restart

When running the script as a cronjob no restarting is required.

## CLI Usage

**ddos** [OPTIONS] [N]

*N : number of tcp/udp  connections (default 150)*

#### OPTIONS

**-h | --help:**

   Show the help screen.

**-c | --cron:**

   Create cron job to run the script regularly (default 1 mins).

**-i | --ignore-list:**

   List whitelisted ip addresses.

**-b | --bans-list:**

   List currently banned ip addresses.

**-u | --unban:**

   Unbans a given ip address.

**-d | --start:**

   Initialize a daemon to monitor connections.

**-s | --stop:**

   Stop the daemon.

**-t | --status:**

   Show status of daemon and pid if currently running.

**-v | --view:**

   Display active connections to the server.

**-k | --kill:**

   Block all ip addresses making more than N connections.
