# on server
# Install K3s server without default Flannel network overlay
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--flannel-backend=none --disable-network-policy" sh -
sudo cat /var/lib/rancher/k3s/server/node-token  # Copy this token

# on agent
curl -sfL https://get.k3s.io | K3S_URL=https://<SERVER_IP>:6443 K3S_TOKEN=<PASTED_TOKEN> sh -
