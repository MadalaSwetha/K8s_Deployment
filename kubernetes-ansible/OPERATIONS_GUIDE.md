# Kubernetes Ansible - Deployment Checklist & Operations

## 📋 Pre-Deployment Checklist

### Infrastructure Preparation
- [ ] VMs provisioned (1 master + 2 workers minimum)
- [ ] Each VM has:
  - [ ] Ubuntu 20.04/22.04 LTS or RHEL 8/9+
  - [ ] At least 2 CPU cores
  - [ ] At least 4GB RAM
  - [ ] At least 20GB disk space
  - [ ] Network connectivity (can reach each other and internet)
  - [ ] IP addresses assigned and static
- [ ] SSH key pairs created for all VMs
- [ ] Ansible control machine ready (Linux/Mac/WSL)

### Ansible Setup
- [ ] Ansible installed on control machine (`pip install ansible`)
- [ ] Python dependencies installed (`pip install -r requirements.txt`)
- [ ] SSH keys copied to all VMs (`ssh-copy-id` for each node)
- [ ] SSH connectivity verified from control machine
- [ ] Inventory files updated with correct IP addresses

### Configuration Review
- [ ] Reviewed `inventory/production/hosts.ini`
- [ ] Updated IPs and hostnames if different from examples
- [ ] Reviewed `inventory/production/group_vars/all.yml`
- [ ] Confirmed Kubernetes version and container runtime
- [ ] Confirmed pod and service CIDR ranges
- [ ] Confirmed CNI plugin selection (Calico or Flannel)

---

## 🚀 Quick Start (Choose One Method)

### Method 1: Linux/Mac/WSL (Recommended)

```bash
# 1. Navigate to project
cd ~/kubernetes-ansible  # or WSL path

# 2. Install dependencies
pip install -r requirements.txt

# 3. Update inventory
nano inventory/production/hosts.ini

# 4. Update group variables
nano inventory/production/group_vars/all.yml

# 5. Verify connectivity
ansible -i inventory/production/hosts.ini k8s_all -m ping

# 6. Dry-run
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --check -v

# 7. Deploy to staging first (RECOMMENDED)
ansible-playbook playbooks/site.yml -i inventory/staging/hosts.ini -v

# 8. Deploy to production (after staging success)
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini -v

# 9. Verify deployment
ansible-playbook playbooks/verify_deployment.yml -i inventory/production/hosts.ini
```

### Method 2: Windows PowerShell

```powershell
# 1. Install Ansible
pip install ansible

# 2. Navigate to project
cd C:\Users\Swetha\TRYG\kubernetes-ansible

# 3. Install dependencies in Python
pip install -r requirements.txt

# 4. Update inventory
notepad inventory/production/hosts.ini

# 5. Test connectivity
ansible -i inventory/production/hosts.ini k8s_all -m ping

# 6. Run deployment script
.\deploy.ps1 -Environment production
```

### Method 3: Docker Container (No Local Install Needed)

```bash
# Run Ansible in Docker
docker run -it --rm \
  -v ~/.ssh:/root/.ssh \
  -v $(pwd):/workspace \
  -w /workspace \
  ansible/ansible:latest \
  bash

# Inside container:
pip install -r requirements.txt
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini -v
```

---

## 📊 Deployment Timeline

**Estimated total time: 20-30 minutes**

```
Prerequisites      2-3 min   | ████
Container Runtime  2-3 min   | ████
K8s Tools          3-4 min   | █████
Master Init        3-5 min   | █████
CNI Deploy         1-2 min   | ███
Worker Join        2-3 min   | ████
Add-ons            3-5 min   | █████
Verification       2-3 min   | ████
─────────────────────────────
TOTAL             20-30 min
```

---

## ✅ Post-Deployment Verification

### From Ansible Control Machine

```bash
# 1. Verify all nodes are ready
ansible -i inventory/production/hosts.ini k8s_masters[0] -m shell \
  -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes"

# 2. Check pod status
ansible -i inventory/production/hosts.ini k8s_masters[0] -m shell \
  -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A"

# 3. Run full verification
ansible-playbook playbooks/verify_deployment.yml -i inventory/production/hosts.ini
```

### SSH to Master Node

```bash
# Connect to master
ssh -i ~/.ssh/id_rsa ubuntu@10.0.1.10

# Check nodes
kubectl get nodes -o wide

# Check pods
kubectl get pods -A

# Check Ingress Controller
kubectl get pods -n ingress-nginx

# Check Metrics Server
kubectl get deployment -n kube-system metrics-server

# Test metrics
kubectl top nodes
```

### Success Indicators

✅ All nodes show `STATUS: Ready`
✅ All pods in `kube-system` show `STATUS: Running`
✅ Calico or Flannel pods running in `kube-system`
✅ Ingress controller running in `ingress-nginx`
✅ Metrics server deployed in `kube-system`
✅ `kubectl top nodes` shows resource usage
✅ DNS resolution working (nslookup test)

---

## 🔧 Quick Operations After Deployment

### Monitor Cluster

```bash
# Real-time pod monitoring
kubectl get pods -A --watch

# View events
kubectl get events -A --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods -A

# View cluster info
kubectl cluster-info
```

### Add Worker Node

```bash
# 1. Add to inventory
echo "worker-3 ansible_host=10.0.2.12" >> inventory/production/hosts.ini

# 2. Run add_worker playbook
ansible-playbook playbooks/add_worker.yml -i inventory/production/hosts.ini

# 3. Verify
kubectl get nodes
```

### Backup Cluster

```bash
# Backup etcd
ansible-playbook playbooks/backup_etcd.yml -i inventory/production/hosts.ini

# Backup location: /var/backups/etcd/ on master node
# Download: scp -r ubuntu@10.0.1.10:/var/backups/etcd ~/backup
```

### Upgrade Kubernetes

```bash
# Backup before upgrade
ansible-playbook playbooks/backup_etcd.yml -i inventory/production/hosts.ini

# Upgrade to new version
ansible-playbook playbooks/upgrade_k8s.yml -i inventory/production/hosts.ini \
  --extra-vars "target_k8s_version=1.29.0"

# Verify
kubectl version --short
```

### Deploy Application

```bash
# Create deployment
kubectl create deployment nginx --image=nginx:latest
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Create ingress
kubectl create ingress test-ingress --class=nginx \
  --rule="test.local/*=nginx:80"

# Monitor
kubectl get pods
kubectl get svc
kubectl get ingress
```

---

## 🛠️ Troubleshooting Common Issues

### SSH Connection Issues

```bash
# Test SSH
ssh -v ubuntu@10.0.1.10

# If key auth fails:
ssh-add ~/.ssh/id_rsa
ssh-copy-id -i ~/.ssh/id_rsa ubuntu@10.0.1.10

# If sudo fails:
ssh ubuntu@10.0.1.10 "sudo visudo"
# Add: ubuntu ALL=(ALL) NOPASSWD:ALL
```

### Playbook Fails at Task

```bash
# Re-run from specific task
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini \
  --start-at-task="Task Name" -v

# With more verbosity
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini -vvv

# Check logs
tail -100 deploy-*.log
```

### Node Not Ready

```bash
# SSH to master
ssh ubuntu@10.0.1.10

# Check node status
kubectl describe node worker-1

# Check kubelet logs
ssh ubuntu@10.0.2.10 "journalctl -u kubelet -n 50"

# Restart kubelet if needed
ssh ubuntu@10.0.2.10 "sudo systemctl restart kubelet"
```

### CNI Pods Not Running

```bash
# Check CNI pods
kubectl get pods -n kube-system -l k8s-app=calico-node

# Restart CNI pod
kubectl delete pods -n kube-system -l k8s-app=calico-node

# Verify
kubectl get pods -n kube-system
```

---

## 📑 Important File References

| File | Purpose |
|------|---------|
| `ansible.cfg` | Ansible global configuration |
| `inventory/production/hosts.ini` | Node inventory (IPs, groups) |
| `inventory/production/group_vars/all.yml` | Global variables (versions, CIDRs, etc) |
| `inventory/production/group_vars/k8s_masters.yml` | Master-specific variables |
| `inventory/production/group_vars/k8s_workers.yml` | Worker-specific variables |
| `playbooks/site.yml` | Main deployment playbook |
| `playbooks/verify_deployment.yml` | Verification playbook |
| `roles/prerequisites/` | OS-level setup role |
| `roles/container_runtime/` | Docker/containerd role |
| `roles/kube_master/` | Master initialization role |
| `roles/cni_calico/` | Calico CNI role |

---

## 📋 Useful Commands After Deployment

```bash
# Get cluster info
kubectl cluster-info
kubectl get nodes -o wide
kubectl api-versions
kubectl api-resources

# View resource usage
kubectl top nodes
kubectl top pods -A

# Access pod shell
kubectl exec -it pod-name -- /bin/bash

# View pod logs
kubectl logs pod-name
kubectl logs -f deployment-name  # Follow logs

# Troubleshoot specific resource
kubectl describe pod pod-name
kubectl describe node node-name

# Create test deployment
kubectl create deployment test-app --image=nginx:latest --replicas=3

# Scale deployment
kubectl scale deployment test-app --replicas=5

# Update deployment
kubectl set image deployment/test-app nginx=nginx:latest

# Monitor rolling update
kubectl rollout status deployment/test-app
```

---

## 🎯 Success Criteria

Your deployment is successful when:

- ✅ All master and worker nodes show `STATUS: Ready`
- ✅ All pods in `kube-system` namespace are `Running`
- ✅ CNI plugin (Calico/Flannel) pods are `Running`
- ✅ Ingress controller is `Running` in `ingress-nginx` namespace
- ✅ Metrics server is `Running` in `kube-system` namespace
- ✅ `kubectl top nodes` returns CPU/memory stats
- ✅ DNS resolution works (nslookup test pod succeeds)
- ✅ Pod-to-pod communication works across nodes

---

## 📞 Common Resources

- **Kubernetes Docs**: https://kubernetes.io/docs/
- **Ansible Docs**: https://docs.ansible.com/
- **Calico Docs**: https://docs.projectcalico.org/
- **Flannel Docs**: https://github.com/coreos/flannel
- **Nginx Ingress**: https://kubernetes.github.io/ingress-nginx/

---

## 🚀 Ready to Deploy?

1. **Prepare infrastructure** (VMs with Ubuntu 20.04+)
2. **Update inventory** (`hosts.ini` with your IPs)
3. **Configure variables** (`group_vars/all.yml`)
4. **Verify connectivity** (`ansible -i ... k8s_all -m ping`)
5. **Run deployment** (`ansible-playbook playbooks/site.yml -i ...`)
6. **Verify cluster** (`kubectl get nodes`)

**Good luck! 🎉**

---

**Project**: Kubernetes Ansible  
**Status**: Ready to Deploy  
**Last Updated**: February 22, 2026
