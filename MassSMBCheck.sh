#!/bin/bash

#############################################################################################################################
#
# Script Name    : MassSMBCheck.sh
# Description    : This script launching scanning process in parallel to find potential vulnerables hosts for CVE-2020-079
#                  if no patching applied.
# Author         : https://github.com/choupit0
# Site           : https://hack2know.how/
# Date           : 20200313
# Version        : 1.0
# Usage          : ./MassSMBCheck.sh "file containing ips to scan" "number of process to launch"
#		   e.g. ./MassSMBCheck.sh hosts.txt 100
# Prerequisites  : scanner.py from https://github.com/ollypwn/SMBGhost
#
#############################################################################################################################

version="1.0"
yellow_color="\033[1;33m"
green_color="\033[0;32m"
red_color="\033[1;31m"
blue_color="\033[0;36m"
bold_color="\033[1m"
end_color="\033[0m"
script_start="$SECONDS"
report_folder="$(pwd)/"
date="$(date +%F_%H-%M-%S)"

# Time elapsed
time_elapsed(){
script_end="$SECONDS"
script_duration="$((script_end-script_start))"

printf 'Duration: %02dh:%02dm:%02ds\n' $((${script_duration}/3600)) $((${script_duration}%3600/60)) $((${script_duration}%60))
}

hosts="$1"
nb_proc="$2"

usage(){
echo -e "${blue_color}${bold_color}[-] Usage: ${end_color} ./$(basename "$0") ${bold_color}\"file containing ips to scan\" \"number of process to launch\"${end_color}"
}

# Scanner.py script present?
if [[ -z scanner.py ]] || [[ ! -s scanner.py ]]; then
        echo -e "${red_color}[X] \"scanner.py\" does not exist or is empty.${end_color}"
        echo -e "${yellow_color}[I] This script is a prerequisite to scan.${end_color}"
        echo -e "${bold_color}Please, download the source from Github and try again: git clone https://github.com/ollypwn/SMBGhost${end_color}"
        exit 1
fi

# Valid input file?
if [[ -z ${hosts} ]] || [[ ! -s ${hosts} ]]; then
        echo -e "${red_color}[X] Input file \"${hosts}\" does not exist or is empty.${end_color}"
        echo "Please, try again."
	usage
        exit 1
fi

# Valid input parameter?
if [[ -z ${nb_proc} ]] || [[ ! ${nb_proc} = +([0-9]) ]]; then
        echo -e "${red_color}[X] Input parameter \"${nb_proc}\" does not exist or is not an (positive) integer.${end_color}"
        echo "Please, try again."
	usage
        exit 1
fi

# Cleaning
rm process_done.txt ips 2>/dev/null

# Parsing the file
sort -u "${hosts}" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' > ips
nb_hosts="$(sort -u ${hosts} | grep -oEc '([0-9]{1,3}\.){3}[0-9]{1,3}')"

# Function for parallel scans
parallels_scans(){
ip="${1}"

python3 scanner.py "${ip}" >> ${report_folder}vulnerable_hosts_${date}.txt 2>/dev/null
echo "${ip} : Done" >> process_done.txt

nmap_proc_ended="$(grep "$Done" -co process_done.txt)"
pourcentage="$(awk "BEGIN {printf \"%.2f\n\", "${nmap_proc_ended}/${nb_hosts}*100"}")"
echo -n -e "\r                                                                                                         "
echo -n -e "${yellow_color}${bold_color}\r[I] Scan is done for ${ip} -> ${nmap_proc_ended}/${nb_hosts} Scan process launched...(${pourcentage}%)${end_color}"

}

echo -e "${blue_color}${bold_color}[-] ${nb_hosts} host(s) to scan and we are launching ${nb_proc} scanner(s) in the same time...${end_color}"

# Queue files
new_job(){
job_act="$(jobs | wc -l)"
while ((job_act >= ${nb_proc})); do
	job_act="$(jobs | wc -l)"
done
parallels_scans "${ip_to_scan}" &
}

# We are launching the scans
count="1"

rm -rf process_done.txt

while IFS=, read -r ip_to_scan; do
	new_job $i
	count="$(expr $count + 1)"
done < ips

wait

sleep 2 && tset

echo -e "${green_color}[V] Scan phase is ended.${end_color}"

if [[ $(grep "Vulnerable" ${report_folder}vulnerable_hosts_${date}.txt) ]]; then
	nb_vuln="$(grep -c "Vulnerable" ${report_folder}vulnerable_hosts_${date}.txt)"
	echo -e "${bold_color}${nb_vuln} vulnerable host(s):${end_color}"
	grep "Vulnerable" ${report_folder}vulnerable_hosts_${date}.txt
else
	echo -e "${bold_color}No vulnerable host(s) found.${end_color}"
fi

rm process_done.txt ips 2>/dev/null

time_elapsed

exit 0
