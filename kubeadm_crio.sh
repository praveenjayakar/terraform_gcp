#!/bin/bash
#
# Common setup for all servers (Control Plane and Nodes)

set -euxo pipefail

# Kubernetes Variable Declaration
KUBERNETES_VERSION="v1.30"
CRIO_VERSION="v1.30"
KUBERNETES_INSTALL_VERSION="1.30.0-1.1"

# Disable swap
sudo swapoff -a

# Keep swap off after reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true

# Update package list
sudo apt-get update -y

# Create the .conf file to load the necessary modules at boot
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Load kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl parameters for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl parameters
sudo sysctl --system

# Install dependencies
sudo apt-get install -y apt-transport-https ca-certificates curl gpg software-properties-common

# Install CRI-O Runtime
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update -y
sudo apt-get install -y cri-o

# Enable and start CRI-O
sudo systemctl daemon-reload
sudo systemctl enable --now crio

echo "CRI-O runtime installed successfully"

# Install Kubernetes components: kubelet, kubectl, and kubeadm
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet="$KUBERNETES_INSTALL_VERSION" \
                        kubectl="$KUBERNETES_INSTALL_VERSION" \
                        kubeadm="$KUBERNETES_INSTALL_VERSION"

# Prevent automatic updates for Kubernetes packages
sudo apt-mark hold kubelet kubeadm kubectl

# Install jq, a command-line JSON processor
sudo apt-get install -y jq

# Retrieve the local IP address of the ens4 interface
local_ip="$(ip --json addr show ens4 | jq -r '.[0].addr_info[] | select(.family == "inet") | .local')"

# Configure kubelet to use the local IP
cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
EOF

# Kubernetes initialization variables
PUBLIC_IP_ACCESS="true"
NODENAME=$(hostname -s)
POD_CIDR="192.168.0.0/16"

# Pull required Kubernetes images
sudo kubeadm config images pull

# Initialize kubeadm based on PUBLIC_IP_ACCESS
if [[ "$PUBLIC_IP_ACCESS" == "false" ]]; then
    MASTER_PRIVATE_IP=$(ip addr show ens4 | awk '/inet / {print $2}' | cut -d/ -f1)
    sudo kubeadm init --apiserver-advertise-address="$MASTER_PRIVATE_IP" \
                      --apiserver-cert-extra-sans="$MASTER_PRIVATE_IP" \
                      --pod-network-cidr="$POD_CIDR" \
                      --node-name "$NODENAME" \
                      --ignore-preflight-errors Swap
elif [[ "$PUBLIC_IP_ACCESS" == "true" ]]; then
    MASTER_PUBLIC_IP=$(curl -s ifconfig.me)
    sudo kubeadm init --control-plane-endpoint="$MASTER_PUBLIC_IP" \
                      --apiserver-cert-extra-sans="$MASTER_PUBLIC_IP" \
                      --pod-network-cidr="$POD_CIDR" \
                      --node-name "$NODENAME" \
                      --ignore-preflight-errors Swap
else
    echo "Error: Invalid value for PUBLIC_IP_ACCESS: $PUBLIC_IP_ACCESS"
    exit 1
fi

# Configure kubeconfig for kubectl
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u)":"$(id -g)" "$HOME/.kube/config"

# Install Calico Network Plugin
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

echo "Calico network plugin installed."

# Install Helm
echo "Setting up Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Install kubecolor
echo "Installing kubecolor..."
KUBECOLOR_VERSION="0.5.0"
KUBECOLOR_URL="https://github.com/kubecolor/kubecolor/releases/download/v$KUBECOLOR_VERSION/kubecolor_${KUBECOLOR_VERSION}_linux_amd64.tar.gz"

curl -fsSL -o kubecolor.tar.gz "$KUBECOLOR_URL"
tar -xzf kubecolor.tar.gz kubecolor
sudo mv kubecolor /usr/local/bin/
rm -f kubecolor.tar.gz

echo "Kubecolor installed successfully."
echo "alias k=kubecolor" >> ~/.bashrc

# Display success message
echo "Cluster setup complete! Use 'kubectl' (or 'k' if you use the alias) to manage your cluster."
echo "You can also use 'kubecolor' for colored output of kubectl commands."