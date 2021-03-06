#!/bin/bash 

# Colors
ESC="\e["
RESET=$ESC"39m"
RED=$ESC"31m"
GREEN=$ESC"32m"
BLUE=$ESC"34m"
ORANGE=$ESC"33m"

function banner {
# echo "                             _                                          _       _ "
# echo "  ___  _ __   ___           | |___      _____    _ __  _   _ _ __   ___| |__   / \\"
# echo " / _ \| '_ \ / _ \          | __\ \ /\ / / _ \  | '_ \| | | | '_ \ / __| '_ \ /  /"
# echo "| (_) | | | |  __/ ᕦ(ò_óˇ)ᕤ | |_ \ V  V / (_) | | |_) | |_| | | | | (__| | | /\_/ "
# echo " \___/|_| |_|\___|           \__| \_/\_/ \___/  | .__/ \__,_|_| |_|\___|_| |_\/   "
# echo "                                                |_|                               "
# echo "                                                                   by superkojiman"
echo " _                             _                                          _       _ "
echo "| |___      _____             | |___      _____    _ __  _   _ _ __   ___| |__   / \\"
echo "| __\ \ /\ / / _ \            | __\ \ /\ / / _ \  | '_ \| | | | '_ \ / __| '_ \ /  /"
echo "| |_ \ V  V / (_) | ᕦ(ò_óˇ)ᕤ | |_ \ V  V / (_) | | |_) | |_| | | | | (__| | | /\_/ "
echo " \__| \_/\_/ \___/             \__| \_/\_/ \___/  | .__/ \__,_|_| |_|\___|_| |_\/   "
echo "                                                  |_|                               "
echo "                                                                     by superkojiman"
echo "                                                      with updates by ellwoodthewood"
}

function usage {
    echo "Usage: $0 -t targets.txt [-p tcp/udp/all] [-i interface] [-n nmap-options] [-h]"
    echo "       -h: Help"
    echo "       -t: File containing ip addresses to scan. This option is required."
    echo "       -p: Protocol. Defaults to tcp"
    echo "       -i: Network interface. Defaults to eth0"
    echo "       -n: NMAP options (-A, -O, etc). Defaults to no options."
}


banner

if [[ ! $(id -u) == 0 ]]; then
    echo -e "${RED}[!]${RESET} This script must be run as root"
    exit 1
fi

if [[ -z $(which nmap) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find nmap. Install it and make sure it's in your PATH   environment"
    exit 1
fi

if [[ -z $(which unicornscan) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find unicornscan. Install it and make sure it's in your PATH environment"
    exit 1
fi

if [[ -z $1 ]]; then
    usage
    exit 0
fi

# commonly used default options
proto="tcp"
iface="eth0"
nmap_opt="-sV"
targets=""

while getopts "p:i:t:n:h" OPT; do
    case $OPT in
        p) proto=${OPTARG};;
        i) iface=${OPTARG};;
        t) targets=${OPTARG};;
        n) nmap_opt=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 0;;
    esac
done

if [[ -z $targets ]]; then
    echo "[!] No target file provided"
    usage
    exit 1
fi

if [[ ${proto} != "tcp" && ${proto} != "udp" && ${proto} != "all" ]]; then
    echo "[!] Unsupported protocol"
    usage
    exit 1
fi

echo -e "${BLUE}[+]${RESET} Protocol : ${proto}"
echo -e "${BLUE}[+]${RESET} Interface: ${iface}"
echo -e "${BLUE}[+]${RESET} Nmap opts: ${nmap_opt}"
echo -e "${BLUE}[+]${RESET} Targets  : ${targets}"

# backup any old scans before we start a new one
log_dir="${HOME}/.twotwopunch"
mkdir -p "${log_dir}/backup/"
if [[ -d "${log_dir}/ndir/" ]]; then 
    mv "${log_dir}/ndir/" "${log_dir}/backup/ndir-$(date "+%Y%m%d-%H%M%S")/"
fi
if [[ -d "${log_dir}/udir/" ]]; then 
    mv "${log_dir}/udir/" "${log_dir}/backup/udir-$(date "+%Y%m%d-%H%M%S")/"
fi 

rm -rf "${log_dir}/ndir/"
mkdir -p "${log_dir}/ndir/"
rm -rf "${log_dir}/udir/"
mkdir -p "${log_dir}/udir/"

while read ip; do
    echo -e "${BLUE}[+]${RESET} Scanning $ip for $proto ports..."

	# unicornscan identifies all open ports, passes all to nmap making identification easier if all ports are addressed at once
    if [[ $proto == "all" ]]; then
        echo -e "${BLUE}[+]${RESET} Obtaining all open ports using unicornscan..."
        echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mU ${ip}:a -l ${log_dir}/udir/${ip}-udp.txt"
        unicornscan -i ${iface} -mU ${ip}:a -l ${log_dir}/udir/${ip}-udp.txt
        uports=$(cat "${log_dir}/udir/${ip}-udp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
        echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mT ${ip}:a -l ${log_dir}/udir/${ip}-tcp.txt"
        unicornscan -i ${iface} -mT ${ip}:a -l ${log_dir}/udir/${ip}-tcp.txt
        tports=$(cat "${log_dir}/udir/${ip}-tcp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
        hports=$(cat "${log_dir}/udir/${ip}-tcp.txt" | grep http | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
        if [[ ! -z $uports ]]; then 
		# nmap follows up
			echo -e "${GREEN}[*]${RESET} Ports for nmap to scan: TCP:$tports UDP:$uports"
			echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -sSU -oX ${log_dir}/ndir/${ip}-tcpudp.xml -oG ${log_dir}/ndir/${ip}-tcpudp.grep -pT:${tports}U:${uports} ${ip}"
			nmap -e ${iface} ${nmap_opt} -sSU -oX ${log_dir}/ndir/${ip}-tcpudp.xml -oG ${log_dir}/ndir/${ip}-tcpudp.grep -pT:${tports}U:${uports} ${ip}
        else
            echo -e "${RED}[!]${RESET} No UDP ports found, performing TCP scan only"
			nmap -e ${iface} ${nmap_opt} -sS -oX ${log_dir}/ndir/${ip}-tcpudp.xml -oG ${log_dir}/ndir/${ip}-tcpudp.grep -pT:${tports} ${ip}
		fi	
		if [[ ! -z $hports ]]; then
			echo -e "${ORANGE}[*]${RESET} Ports for nikto to scan: $hports"
			echo -e "${BLUE}[+]${RESET} nikto -output ${log_dir}/ndir/${ip}.html -h ${ip} -p ${hports}"
			nikto -output ${log_dir}/ndir/${ip}.html -h ${ip} -p ${hports}
		else
            echo -e "${RED}[!]${RESET} No http ports found"
        fi
    fi
	
    # unicornscan identifies all open TCP ports
    if [[ $proto == "tcp" ]]; then 
        echo -e "${BLUE}[+]${RESET} Obtaining all open TCP ports using unicornscan..."
        echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mT ${ip}:a -l ${log_dir}/udir/${ip}-tcp.txt"
        unicornscan -i ${iface} -mT ${ip}:a -l ${log_dir}/udir/${ip}-tcp.txt
        ports=$(cat "${log_dir}/udir/${ip}-tcp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
        hports=$(cat "${log_dir}/udir/${ip}-tcp.txt" | grep http | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
		if [[ ! -z $hports ]]; then
			echo -e "${ORANGE}[*]${RESET} Ports for nikto to scan: $hports"
			echo -e "${BLUE}[+]${RESET} nikto -output ${log_dir}/ndir/${ip}.html -h ${ip} -p ${hports}"
			nikto -output ${log_dir}/ndir/${ip}.html -h ${ip} -p ${hports}
		else
            echo -e "${RED}[!]${RESET} No http ports found"
        fi
		if [[ ! -z $ports ]]; then 
            # nmap follows up
            echo -e "${GREEN}[*]${RESET} TCP ports for nmap to scan: $ports"
            echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -oX ${log_dir}/ndir/${ip}-tcp.xml -oG ${log_dir}/ndir/${ip}-tcp.grep -p ${ports} ${ip}"
            nmap -e ${iface} ${nmap_opt} -oX ${log_dir}/ndir/${ip}-tcp.xml -oG ${log_dir}/ndir/${ip}-tcp.grep -p ${ports} ${ip}
        else
            echo -e "${RED}[!]${RESET} No TCP ports found"
        fi
    fi

    # unicornscan identifies all open UDP ports
    if [[ $proto == "udp" ]]; then  
        echo -e "${BLUE}[+]${RESET} Obtaining all open UDP ports using unicornscan..."
        echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mU ${ip}:a -l ${log_dir}/udir/${ip}-udp.txt"
        unicornscan -i ${iface} -mU ${ip}:a -l ${log_dir}/udir/${ip}-udp.txt
        ports=$(cat "${log_dir}/udir/${ip}-udp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
        if [[ ! -z $ports ]]; then
            # nmap follows up
            echo -e "${GREEN}[*]${RESET} UDP ports for nmap to scan: $ports"
            echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -sU -oX ${log_dir}/ndir/${ip}-udp.xml -oG ${log_dir}/ndir/${ip}-udp.grep -p ${ports} ${ip}"
            nmap -e ${iface} ${nmap_opt} -sU -oX ${log_dir}/ndir/${ip}-udp.xml -oG ${log_dir}/ndir/${ip}-udp.grep -p ${ports} ${ip}
        else
            echo -e "${RED}[!]${RESET} No UDP ports found"
        fi
    fi
done < ${targets}

echo -e "${BLUE}[+]${RESET} Scans completed"
echo -e "${BLUE}[+]${RESET} Results saved to ${log_dir}"
