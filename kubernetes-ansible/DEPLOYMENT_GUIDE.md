# Kubernetes Ansible Deployment & Verification Guide

**Important Note**: You're on Windows. Ansible playbooks must run from a Linux/Mac system or WSL.

## Option 1: Using Windows PowerShell (with WSL)

### 1.1 Setup WSL (Windows Subsystem for Linux)

```powershell
# Open PowerShell as Administrator
wsl --install -d Ubuntu-22.04

# After installation, open WSL terminal
wsl

# Install Ansible in WSL
sudo apt update
sudo apt install -y ansible python3-pip
pip install -r requirements.txt
```

### 1.2 Prepare Your Inventory

```bash
# Navigate to project directory
cd /mnt/c/Users/Swetha/TRYG/kubernetes-ansible

# Edit inventory for your actual VMs
nano inventory/production/hosts.ini

# Example content:
# [k8s_masters]
# master-1 ansible_host=10.0.1.10 ansible_user=ubuntu

# [k8s_workers]  
# worker-1 ansible_host=10.0.2.10 ansible_user=ubuntu
# worker-2 ansible_host=10.0.2.11 ansible_user=ubuntu
```

### 1.3 Configure SSH Keys

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copy key to all target VMs
ssh-copy-id -i ~/.ssh/id_rsa ubuntu@10.0.1.10
ssh-copy-id -i ~/.ssh/id_rsa ubuntu@10.0.2.10
ssh-copy-id -i ~/.ssh/id_rsa ubuntu@10.0.2.11
```

### 1.4 Verify & Deploy

```bash
# Test connectivity
ansible -i inventory/production/hosts.ini k8s_all -m ping

# Dry-run (preview)
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --check

# Deploy to staging first (RECOMMENDED)
ansible-playbook playbooks/site.yml -i inventory/staging/hosts.ini -v

# Deploy to production
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini -v
```

---

## Option 2: Using PowerShell Script (Windows)

```powershell
# Make sure Ansible is installed on Windows
pip install ansible

# Navigate to project directory
cd C:\Users\Swetha\TRYG\kubernetes-ansible

# Run deployment script
.\deploy.ps1 -Environment production -SkipDryRun

# Or check-only mode
.\deploy.ps1 -Environment production -CheckOnly
```

---

## Option 3: Using Bash Script (Linux/WSL/Mac)

```bash
cd /path/to/kubernetes-ansible

# Make script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh production

# The script will:
# 1. Check prerequisites
# 2. Verify SSH connectivity
# 3. Run dry-run (check mode)
# 4. Ask for confirmation
# 5. Execute actual deployment
# 6. Verify the cluster
```

---

## Pre-Deployment Checklist

Before running the playbooks, verify:

```bash
# ✓ 1. SSH connectivity
ssh -i ~/.ssh/id_rsa ubuntu@10.0.1.10 "echo Connected"

# ✓ 2. VMs have internet access
ssh ubuntu@10.0.1.10 "ping 8.8.8.8 -c 1"

# ✓ 3. VMs have sufficient resources
ssh ubuntu@10.0.1.10 "free -h && lscpu | head -5"

# ✓ 4. Inventory is correct
ansible-inventory -i inventory/production/hosts.ini --list

# ✓ 5. Python is installed
ssh ubuntu@10.0.1.10 "python3 --version"

# ✓ 6. Sudo works without password
ssh ubuntu@10.0.1.10 "sudo whoami"
```

---

## Deployment Command Reference

### Standard Deployment

```bash
# Production deployment with verbose output
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini -v

# With extra verbosity (shows all variable values)
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini -vv

# With debug verbosity (shows all module calls)
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini -vvv
```

### Dry-Run (Preview Mode)

```bash
# Preview all changes without applying
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --check

# Preview specific role
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --check -e "ansible_tags=prerequisites"
```

### Targeted Deployment

```bash
# Only run prerequisites role
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --tags "prerequisites" -v

# Skip container runtime
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --skip-tags "container_runtime" -v

# Start from specific task
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --start-at-task="Initialize Kubernetes control plane" -v
```

### Deploy to Specific Host Group

```bash
# Only deploy to masters
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --limit "k8s_masters" -v

# Only deploy to workers
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --limit "k8s_workers" -v
```

---

## Deployment Timeline

| Phase | Time | Description |
|-------|------|-------------|
| **Prerequisites** | 2-3 min | OS updates, kernel params, firewall rules |
| **Container Runtime** | 2-3 min | Docker/containerd installation |
| **K8s Tools** | 3-4 min | kubeadm, kubelet, kubectl installation |
| **Master Init** | 3-5 min | Control plane bootstrap |
| **CNI Deploy** | 1-2 min | Calico/Flannel network plugin |
| **Worker Join** | 2-3 min | Per worker node join |
| **Add-ons** | 3-5 min | Ingress, Metrics, Storage |
| **Verification** | 2-3 min | Health checks |
| **TOTAL** | **20-30 min** | End-to-end deployment |

---

## Verification After Deployment

### From Master Node

```bash
# SSH to master node
ssh -i ~/.ssh/id_rsa ubuntu@10.0.1.10

# Check cluster status
kubectl get nodes -o wide

# Check pod status
kubectl get pods -A

# Check control plane components
kubectl get componentstatus

# Check kubelet version
kubelet --version

# Check Calico/Flannel pods
kubectl get pods -n kube-system -l k8s-app=calico-node
# OR
kubectl get pods -n kube-flannel

# Check Ingress Controller
kubectl get pods -n ingress-nginx

# Check Metrics Server
kubectl get deployment -n kube-system metrics-server

# Test metrics
kubectl top nodes
kubectl top pods -A

# View cluster events
kubectl get events -A

# Check DNS
kubectl run dns-test --image=busybox --rm -i --restart=Never -- nslookup kubernetes.default
```

### From Local Machine (Ansible)

```bash
# Verify all nodes are ready
ansible-playbook playbooks/verify_deployment.yml -i inventory/production/hosts.ini

# Check cluster info
ansible k8s_masters[0] -i inventory/production/hosts.ini -m shell -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf cluster-info"

# Check nodes
ansible k8s_masters[0] -i inventory/production/hosts.ini -m shell -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes"

# Check pods
ansible k8s_masters[0] -i inventory/production/hosts.ini -m shell -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A"
```

---

## Quick Verification Script

```bash
#!/bin/bash
# Save as: verify-cluster.sh
# Usage: ./verify-cluster.sh production

ENVIRONMENT=${1:-production}
MASTER=$(ansible-inventory -i inventory/$ENVIRONMENT/hosts.ini --list | grep -m1 'hostname' | grep -o '"[^"]*' | tail -1)

echo "Verifying Kubernetes Cluster in $ENVIRONMENT environment..."
echo "Master node: $MASTER"
echo ""

echo "1. Node Status:"
ansible -i inventory/$ENVIRONMENT/hosts.ini k8s_masters[0] -m shell -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide"
echo ""

echo "2. Pod Status (All Namespaces):"
ansible -i inventory/$ENVIRONMENT/hosts.ini k8s_masters[0] -m shell -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A"
echo ""

echo "3. Control Plane Components:"
ansible -i inventory/$ENVIRONMENT/hosts.ini k8s_masters[0] -m shell -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get componentstatus"
echo ""

echo "4. Kubernetes Version:"
ansible -i inventory/$ENVIRONMENT/hosts.ini k8s_masters[0] -m shell -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf version --short"
echo ""

echo "5. Metrics Server Status:"
ansible -i inventory/$ENVIRONMENT/hosts.ini k8s_masters[0] -m shell -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get deployment -n kube-system metrics-server"
echo ""

echo "6. Ingress Controller Status:"
ansible -i inventory/$ENVIRONMENT/hosts.ini k8s_masters[0] -m shell -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -n ingress-nginx"
echo ""

echo "✓ Verification complete"
```

---

## Troubleshooting During Deployment

### Issue: SSH Connection Refused

```bash
# Check SSH service on target
ssh -v ubuntu@10.0.1.10 # View verbose output

# Solution: Ensure SSH key is added
ssh-add ~/.ssh/id_rsa
ssh-copy-id -i ~/.ssh/id_rsa ubuntu@10.0.1.10
```

### Issue: Insufficient Permissions

```bash
# Make sure sudo works without password
ssh ubuntu@10.0.1.10 "sudo visudo"
# Add line: ubuntu ALL=(ALL) NOPASSWD:ALL
```

### Issue: Ansible Module Not Found

```bash
# Ensure Python is available
ssh ubuntu@10.0.1.10 "python3 --version"

# Set interpreter in inventory
# master-1 ansible_host=10.0.1.10 ansible_python_interpreter=/usr/bin/python3
```

### Issue: Task Times Out

```bash
# Increase timeout in ansible.cfg
# In kubernetes-ansible/ansible.cfg, change:
# timeout = 30  →  timeout = 300  (5 minutes)
```

---

## Post-Deployment Steps

1. **Copy kubeconfig to Local Machine**
   ```bash
   scp -i ~/.ssh/id_rsa ubuntu@10.0.1.10:/etc/kubernetes/admin.conf ~/.kube/config-k8s
   chmod 600 ~/.kube/config-k8s
   export KUBECONFIG=~/.kube/config-k8s
   ```

2. **Access Cluster from Local**
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

3. **Create Test Workload**
   ```bash
   kubectl create deployment nginx --image=nginx:latest
   kubectl expose deployment nginx --port=80 --type=LoadBalancer
   kubectl get pods  # Monitor deployment
   ```

4. **Setup Ingress for App**
   ```bash
   kubectl create ingress test-ingress --class=nginx \
     --rule="test.local/*=nginx:80"
   kubectl get ingress
   ```

5. **Monitor Cluster**
   ```bash
   kubectl top nodes
   kubectl top pods -A
   watch kubectl get pods -A  # Real-time monitoring
   ```

---

## Helpful Commands After Deployment

```bash
# Monitor logs in real-time
kubectl logs -f pod/nginx-123456 -n default

# Get into a pod shell
kubectl exec -it pod/nginx-123456 -n default -- /bin/bash

# Describe problematic resource
kubectl describe node worker-1
kubectl describe pod nginx-123456

# Scale deployment
kubectl scale deployment nginx --replicas=3

# Update deployment
kubectl set image deployment/nginx nginx=nginx:1.25

# Delete resources
kubectl delete pod nginx-123456
kubectl delete deployment nginx

# View cluster info
kubectl cluster-info
kubectl get nodes -o wide
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory
```

---

## Backup Cluster Before Making Changes

```bash
# Backup etcd database
ansible-playbook playbooks/backup_etcd.yml -i inventory/production/hosts.ini

# Backup will be saved at: /var/backups/etcd/ on master node

# Download backup locally
scp -r -i ~/.ssh/id_rsa ubuntu@10.0.1.10:/var/backups/etcd ~/etcd-backup-$(date +%Y%m%d)
```

---

## Next: Scale Cluster or Upgrade

### Add New Worker Node

```bash
# 1. Add to inventory
# Edit inventory/production/hosts.ini:
# worker-3 ansible_host=10.0.2.12 ansible_user=ubuntu

# 2. Run add_worker playbook
ansible-playbook playbooks/add_worker.yml -i inventory/production/hosts.ini -v

# 3. Verify new node
kubectl get nodes
```

### Upgrade Kubernetes Version

```bash
# Backup first
ansible-playbook playbooks/backup_etcd.yml -i inventory/production/hosts.ini

# Upgrade to new version
ansible-playbook playbooks/upgrade_k8s.yml -i inventory/production/hosts.ini \
  --extra-vars "target_k8s_version=1.29.0"

# Verify
kubectl version --short
```

---

**Now Ready to Deploy!** 🚀

Choose your deployment method above and follow the steps for your environment.
