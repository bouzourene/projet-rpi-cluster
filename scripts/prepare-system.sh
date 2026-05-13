#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo 'This script must be run by root' >&2
    exit 1
fi

echo "[>] Upgrading packages"
apt-get update
apt-get upgrade -y

echo "[>] Enabling kernel modules (overlay, br-netfilter)"

# Kernel modules on startup
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Kernel modules while running
modprobe overlay
modprobe br-netfilter

echo "[>] Enabling IP forwarding"

# Enable IP forwarding
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# Reload system config
sysctl --system

echo "[>] Installing prerequisites"
apt install -y ca-certificates curl gpg socat conntrack ipset kmod -y

echo "[>] Installing containerd"

# Install docker repo
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update repos and install containerd
apt-get update
apt-get install containerd.io -y

echo "[>] Configuring containerd"

# Create containerd config and enable cgroups
containerd config default | tee /etc/containerd/config.toml
sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml

# Enable and restart containerd
systemctl enable containerd
systemctl restart containerd

echo "[>] Installing helm"

# Install helm repo
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | \
    gpg --dearmor | \
    tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | \
    tee /etc/apt/sources.list.d/helm-stable-debian.list

# Update repos and install helm
apt-get update
apt-get install helm -y

echo "[>] Installing kubernetes components"

# Install repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
    tee /etc/apt/sources.list.d/kubernetes.list

# Update repo
apt-get update

# Install kubelet, kubeadm, kubectl
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
