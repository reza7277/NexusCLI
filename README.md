
U need 10G swap
sudo fallocate -l 10G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile && echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

screen -S Nexus

git clone https://github.com/reza7277/NexusCLI.git && cd NexusCLI && chmod +x script.sh && ./script.sh
CTRL +A+D
