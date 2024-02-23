#!/bin/bash

# Banner
cat << "EOF"

                                                                                                       
 /$$$$$$$                       /$$           /$$$$$$$                      /$$      
| $$__  $$                     | $$          | $$__  $$                    | $$      
| $$  \ $$ /$$$$$$   /$$$$$$  /$$$$$$        | $$  \ $$ /$$   /$$  /$$$$$$$| $$$$$$$ 
| $$$$$$$//$$__  $$ /$$__  $$|_  $$_/        | $$$$$$$/| $$  | $$ /$$_____/| $$__  $$
| $$____/| $$  \ $$| $$  \__/  | $$          | $$__  $$| $$  | $$|  $$$$$$ | $$  \ $$
| $$     | $$  | $$| $$        | $$ /$$      | $$  \ $$| $$  | $$ \____  $$| $$  | $$
| $$     |  $$$$$$/| $$        |  $$$$/      | $$  | $$|  $$$$$$/ /$$$$$$$/| $$  | $$
|__/      \______/ |__/         \___/        |__/  |__/ \______/ |_______/ |__/  |__/
                                                                                     
                                                                                  
EOF

# Validate the user's password
if ! sudo -n true 2>/dev/null; then
 echo "This script requires sudo privileges to run."
  exit 1
fi

# Check nmap and masscan are installed and install them if not
if ! command -v nmap &>/dev/null || ! command -v masscan &>/dev/null; then
  echo "Installing nmap and masscan..."
  sudo apt update
  sudo apt install -y nmap masscan

  # Check if nmap and masscan were successfully installed
  if ! command -v nmap &>/dev/null || ! command -v masscan &>/dev/null; then
    echo "Error: nmap and/or masscan could not be installed. Please install manually and try again."
    exit 1
  fi
fi

# If no IP file or IP address is provided, display the help message
if [ -z "$1" ]; then
  echo "USAGE: $0 [-i <IP_FILE> | -s <IP_ADDRESS>] [-p <PORT_RANGE>] [-o <OUTPUT_FOLDER>]"
  echo "  -i <IP_FILE>      A FILE CONTAINING A LIST OF IP ADDRESSES TO SCAN"
  echo "  -s <IP_ADDRESS>   A SINGLE IP ADDRESS TO SCAN"
  echo "  -p <PORT_RANGE>   A PORT RANGE TO SCAN (e.g. 1-100, 80,8080,443)"
  echo "  -o <OUTPUT_FOLDER>  THE FOLDER WHERE THE OUTPUT FILES WILL BE SAVED"
  echo "  -h                DISPLAY THIS HELP MESSAGE"
  exit 0
fi

# Parse command line arguments
output_folder=""
while getopts ":i:s:h:p:o:" opt; do
  case $opt in
    i)
      ip_file="$OPTARG"
      ;;
    s)
      ip="$OPTARG"
      ;;
    h)
      echo "USAGE: $0 [-i <IP_FILE> | -s <IP_ADDRESS>] [-p <PORT_RANGE>] [-o <OUTPUT_FOLDER>]"
      echo "  -i <IP_FILE>      A FILE CONTAINING A LIST OF IP ADDRESSES TO SCAN"
      echo "  -s <IP_ADDRESS>   A SINGLE IP ADDRESS TO SCAN"
      echo "  -p <PORT_RANGE>   A PORT RANGE TO SCAN (e.g. 1-100, 80,8080,443)"
      echo "  -o <OUTPUT_FOLDER>  THE FOLDER WHERE THE OUTPUT FILES WILL BE SAVED"
      echo "  -h                DISPLAY THIS HELP MESSAGE"
      exit 0
      ;;
    p)
      port_range="$OPTARG"
      ;;
    o)
      output_folder="$OPTARG"
      ;;
    \?)
      echo "INVALID OPTION: -$OPTARG" >&2
      echo "USAGE: $0 [-i <IP_FILE> | -s <IP_ADDRESS>] [-p <PORT_RANGE>] [-o <OUTPUT_FOLDER>]"
      echo "  -i <IP_FILE>      A FILE CONTAINING A LIST OF IP ADDRESSES TO SCAN"
      echo "  -s <IP_ADDRESS>   A SINGLE IP ADDRESS TO SCAN"
      echo "  -p <PORT_RANGE>   A PORT RANGE TO SCAN (e.g. 1-100, 80,8080,443)"
      echo "  -o <OUTPUT_FOLDER>  THE FOLDER WHERE THE OUTPUT FILES WILL BE SAVED"
      echo "  -h                DISPLAY THIS HELP MESSAGE"
      exit 1
      ;;
    :)
      echo "OPTION -$OPTARG REQUIRES AN ARGUMENT." >&2
      echo "USAGE: $0 [-i <IP_FILE> | -s <IP_ADDRESS>] [-p <PORT_RANGE>] [-o <OUTPUT_FOLDER>]"
      echo "  -i <IP_FILE>      A FILE CONTAINING A LIST OF IP ADDRESSES TO SCAN"
      echo "  -s <IP_ADDRESS>   A SINGLE IP ADDRESS TO SCAN"
      echo "  -p <PORT_RANGE>   A PORT RANGE TO SCAN (e.g. 1-100, 80,8080,443)"
      echo "  -o <OUTPUT_FOLDER>  THE FOLDER WHERE THE OUTPUT FILES WILL BE SAVED"
      echo "  -h                DISPLAY THIS HELP MESSAGE"
      exit 1
      ;;
  esac
done

# Set up colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
LIGHT_GREEN=$(tput setaf 5)
PURPLE=$(tput setaf 6)
RESET=$(tput sgr0)

# If no port range is provided, set it to all ports (1-65535)
if [ -z "$port_range" ]; then
  port_range="1-65535"
fi

# Create output folder if it doesn't exist
if [ ! -d "$output_folder" ]; then
  mkdir -p "$output_folder"
  if [ ! -d "$output_folder" ]; then
    echo -e "\n"
    echo -e "${RED}[-] ERROR: FAILED TO CREATE OUTPUT FOLDER $output_folder.${RESET}"
    exit 1
  fi
fi

# Change the working directory to the output folder
cd "$output_folder"

# Output Summary File
current_time=$(date +"%Y-%m-%d_%H-%M-%S")
current_dir=$(basename "$(pwd)")
output_file="${output_folder}/${current_dir}_${current_time}.txt"
exec > >(tee -a "$output_file")
exec 2>&1

# Function to check if nmap should be run
check_open_ports() {
  local ip="$1"
  local open_ports_file="$2"

  if [ ! -f "$open_ports_file" ]; then
    echo -e "\n"
    echo -e "$(generate_divider "$(tput setaf 1)[-] NO OPEN PORTS FOUND ON $ip. SKIPPING NMAP SCAN")"
    tput sgr0
    return 1
  fi

  open_ports=$(grep -oP '(?<=Ports: )\d+/open/\w+' "$open_ports_file" | awk -F/ '{print $1}' | paste -sd '\n')
  if [[ -z $open_ports ]]; then
    echo -e "\n"
    echo -e "$(generate_divider "$(tput setaf 1)[-] NO OPEN PORTS FOUND ON $ip. SKIPPING NMAP SCAN")"
    tput sgr0
    return 1
  fi

  # Format open ports for nmap
  open_ports_formatted=$(echo "$open_ports" | tr '\n' , | sed 's/,$//')

  return 0
}

# Generate a divider with given message
generate_divider() {
  local message=${1:-""}
  local message_length=$(( $(echo -n "$message$(tput sgr0)" | wc -m) ))
  local length=$(( message_length + 2 ))
  printf '%*s\n' "$length" '' | tr ' ' '~'
  printf '%*s%s%*s\n' "$((length/2 - message_length/2))" " " "$message$(tput sgr0)" "$((length/2 - message_length/2))" " "
  printf '%*s\n' "$length" '' | tr ' ' '~'
}

# If no IP file or IP address is provided, display an error message
if [ -z "$ip_file" ] && [ -z "$ip" ]; then
  echo -e "\n"
  echo -e "${RED}[-] ERROR: YOU MUST PROVIDE AN IP FILE OR A SINGLE IP ADDRESS TO SCAN.${RESET}"
  exit 1
fi

# If both IP file and IP address are provided, display an error message
if [ -n "$ip_file" ] && [ -n "$ip" ]; then
  echo -e "\n"
  echo -e "${RED}[-] ERROR: YOU CANNOT PROVIDE BOTH AN IP FILE AND A SINGLE IP ADDRESS TO SCAN.${RESET}"
  exit 1
fi

# Print nmap and masscan versions
nmap_version=$(nmap --version | head -n 1 | awk '{print $3}')
masscan_version=$(masscan --version | head -n 2 | awk '{print $3}')
echo -e "\n"
echo -e "${GREEN}+- - - - - - - - - - - - - -+${RESET}"
echo -e "| nmap version    |"$(tput setaf 2) ${nmap_version}$(tput sgr0) "|"
echo -e "${GREEN}+- - - - - - - - - - - - - -+${RESET}"
echo -e "| masscan version |"$(tput setaf 2) ${masscan_version}$(tput sgr0)"   |"
echo -e "${GREEN}+- - - - - - - - - - - - - -+${RESET}"

# If IP file is provided, scan all IP addresses in the file
if [ -n "$ip_file" ]; then
  # Check if the file exists
  if [ ! -f "$ip_file" ]; then
    echo -e "\n"
    echo -e "${RED}[-] FILE $ip_file NOT FOUND!${RESET}"
    exit 1
  fi

# Get the total number of IPs in the file
total_ips=$(wc -l < "$ip_file")
echo -e "\n"
echo -e "$(generate_divider "$(tput setaf 6) [*] SCANNING $total_ips IP ADDRESSES [*] $(tput sgr0)")"

# Loop through each IP address in the file
while IFS= read -r ip
do
  # Check if the IP address is valid
  if ! [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "\n"
    echo -e "${RED}[-] INVALID IP ADDRESS: $ip${RESET}"
    continue
  fi

  # Create a new directory for each IP address
  dir=$(basename -- "$ip")
  if ! mkdir -p "$dir" || [ ! -d "$dir" ]; then
    echo -e "\n"
    echo -e "$(generate_divider "$(tput setaf 1)[-] FAILED TO CREATE DIRECTORY $dir")"
    tput sgr0
    continue
  fi
  cd "$dir"

  # Scan the current IP address
  echo -e "\n"
  echo -e "$(generate_divider "$(tput setaf 5) [~] STARTING SCAN ON $ip [~] ")"
  tput sgr0

  # Display the command to be executed
  echo -e "\n"
  echo -e "$(generate_divider "$(tput setaf 3)[+] RUNNING MASSCAN ON $ip")"
  tput sgr0

  # Run masscan and save the output to a file with the IP address as the name
  if ! sudo masscan -p$port_range "$ip" -oG masscan.txt 2>&1 | tee -a "$output_file"; then
    echo -e "\n"
    echo -e "$(generate_divider "$(tput setaf 1)[-] FAILED TO RUN MASSCAN ON $ip")"
    tput sgr0
    cd ..
    continue
  fi

  # Check if there are any open ports before running nmap
  open_ports_file=masscan.txt
  if ! check_open_ports "$ip" "$open_ports_file"; then
    cd ..
    continue
  fi

  # Extract open ports from the masscan output
  open_ports=$(grep -oP '(?<=Ports: )[0-9,]*' "$open_ports_file" | tr -d ',')

  # Ensure that the list of open ports is in the proper format for nmap
  open_ports=$(grep -oP '(?<=Ports: )\d+/open/\w+' "$open_ports_file" | awk -F/ '{print $1}' | tr '\n' , | sed 's/,$//')

  # Display the command to be executed
  echo -e "\n"
  echo -e "$(generate_divider "$(tput setaf 3)[+] STARTING NMAP SCAN ON $ip WITH OPEN PORTS $open_ports")"
  tput sgr0

  # Run nmap scan and save the output to a file with the IP address as the name
  if ! sudo nmap -p "$open_ports_formatted" -A "$ip" -oN nmap.txt 2>&1 | tee -a "$output_file"; then
    echo -e "\n"
    echo -e "$(generate_divider "$(tput setaf 1)[-] FAILED TO RUN NMAP ON $ip")"
    tput sgr0
    cd ..
    continue
  fi

  # Check the return value of the cd command
  if [ $? -ne 0 ]; then
    echo -e "\n"
    echo -e "$(generate_divider "$(tput setaf 1)[-] FAILED TO CHANGE DIRECTORY BACK TO THE PARENT DIRECTORY.")"
    tput sgr0
    cd ..
    continue
  fi

  # Print a divider with a message that includes the scanned IP
  echo -e "\n"
  echo -e "$(generate_divider "$(tput setaf 5) [~] SCAN COMPLETED FOR $ip [~] ")"
  tput sgr0
  cd ..
done <<< "$(cat "$ip_file")"
else
  
  # Single IP address provided, run scan on that IP
  if [ -z "$ip" ]; then
    echo -e "\n"
    echo "[-] ERROR: YOU MUST PROVIDE AN IP ADDRESS TO SCAN."
    tput sgr0
    exit 1
  fi

  # Check if the IP address is valid
  if ! [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "\n"
    echo -e "${RED}[-] INVALID IP ADDRESS: $ip${RESET}"
    tput sgr0
    exit 1
  fi

  # Create a new directory for the IP address
  dir=$(basename -- "$ip")
  if ! mkdir -p "$dir" || [ ! -d "$dir" ]; then
    echo -e "\n"
    echo -e "${RED}[-] FAILED TO CREATE DIRECTORY $dir${RESET}"
    tput sgr0
    exit 1
  fi
  cd "$dir"

  # Display the command to be executed
  echo -e "\n"
  echo -e "$(generate_divider "$(tput setaf 3)[+] RUNNING MASSCAN ON $ip ")"
  tput sgr0

  # Run masscan and save the output to a file with the IP address as the name
  if ! sudo masscan -p$port_range "$ip" -oG masscan.txt; then
    echo -e "\n"
    echo -e "$(generate_divider "$(tput setaf 1)[-] FAILED TO RUN MASSCAN ON $ip")"
    tput sgr0
    cd ..
    exit 1
  fi

  # Check if there are any open ports before running nmap
  open_ports_file=masscan.txt
  if ! check_open_ports "$ip" "$open_ports_file"; then
    cd ..
    continue
  fi

  # Extract open ports from the masscan output
  open_ports=$(grep -oP '(?<=Ports: )[0-9,]*' "$open_ports_file" | tr -d ',')

  # Ensure that the list of open ports is in the proper format for nmap
  open_ports=$(grep -oP '(?<=Ports: )\d+/open/\w+' "$open_ports_file" | awk -F/ '{print $1}' | tr '\n' ,)

  # Display the command to be executed
  echo -e "\n"
  echo -e "$(generate_divider "$(tput setaf 3)[+] STARTING NMAP SCAN ON $ip WITH OPEN PORTS $open_ports")"
  tput sgr0

  # Run nmap scan and save the output to a file with the IP address as the name
  if ! sudo nmap -p "$open_ports_formatted" -sC -A "$ip" -oN nmap.txt; then
    echo -e "\n"
    echo -e "$(generate_divider "$(tput setaf 1)[-] FAILED TO RUN MASSCAN ON $ip")"
    tput sgr0
    cd ..
    exit 1
  fi

  # Check the return value of the cd command
  if [ $? -ne 0 ]; then
    echo -e "\n"
    echo -e "$(generate_divider "$(tput setaf 1)[-] FAILED TO CHANGE DIRECTORY BACK TO THE PARENT DIRECTORY.")"
    tput sgr0
    cd ..
    exit 1
  fi

  cd ..
fi

echo -e "\n"
echo -e "${GREEN}+ - - - - - - - - +${RESET}"
echo -e "${GREEN}| SCAN COMPLETED! |${RESET}"
echo -e "${GREEN}+ - - - - - - - - +${RESET}"
