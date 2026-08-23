# 1. Run official uninstaller
sudo /usr/local/bin/k3s-agent-uninstall.sh

# 2. Kill remaining processes & unmount lingering drives
sudo pkill -9 -f k3s
sudo awk '{print $2}' /proc/mounts | grep -E '(k3s|kubelet|containerd)' | xargs -r -l sudo umount -f

# 3. Wipe directories
sudo rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /var/lib/containerd /run/k3s /run/flannel

# 4. Flush network rules & interfaces
sudo ip link delete cni0 2>/dev/null
sudo ip link delete flannel.1 2>/dev/null
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F
sudo nft flush ruleset

# 5. Reboot
sudo reboot
