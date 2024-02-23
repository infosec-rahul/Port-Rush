#!/bin/bash

# Check if portrush.sh exists
if [ ! -f portrush.sh ]; then
  echo -e "\033[31mError: portrush.sh not found.\033[0m"
  exit 1
fi

# Install portrush.sh to /usr/local/bin
sudo install -m 755 portrush.sh /usr/local/bin/portrush

# Create a symlink to the portrush.sh script in /usr/bin
sudo ln -s /usr/local/bin/portrush /usr/bin/portrush

# Display success message
echo -e "\033[32mPort Rush successfully installed\033[0m"
echo -e "\033[36mEnjoy!!\033[0m"
