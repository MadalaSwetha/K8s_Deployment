# Troubleshooting Guide

## Pre-Deployment Checks

### SSH Connectivity Issues

**Problem**: `Permission denied` or `Connection refused`

```bash
# Test connectivity
ansible -i inventory/production/hosts.ini k8s_all -m ping

# Verify SSH key
ssh -i ~/.ssh/id_rsa ubuntu@10.0.1.10

# Check SSH user is correct in inventory
grep -A 2 "master-1" inventory/production/hosts.ini
```

**Solution**:
1. Ensure SSH key is added to agent: `ssh-add ~/.ssh/id_rsa`
2. Check `ansible_user` in inventory or `group_vars/all.yml`
3. Verify nodes allow password-less SSH: `sudo visudo` add `ansible ALL=(ALL) NOPASSWD:ALL`

### Ansible Module Errors

**Problem**: `fatal: [master-1]: FAILED! => {"msg": "Error: Module failed to initialize."}`

```bash
# Check if Python is installed on target
ansible all -i inventory/production/hosts.ini -m raw -a "python3 --version"

# Fix: Install Python
ansible all -i inventory/production/hosts.ini -m raw -a "apt-get update && apt-get install -y python3"
```

**Solution**:
- Add `ansible_python_interpreter=/usr/bin/python3` to inventory
- Or set in `ansible.cfg`: `interpreter_python = /usr/bin/python3`

### Inventory Group Issues

**Problem**: `no hosts matched` or hosts not in group

```bash
# Verify inventory structure
ansible-inventory -i inventory/production/hosts.ini --list

# Check specific group
ansible -i inventory/production/hosts.ini k8s_masters --list-hosts
```

**Solution**:
1. Ensure `[k8s_all:children]` includes both master and worker groups
2. Check for typos in group names
3. Verify INI format is correct (no extra spaces)

---

## Deployment Issues

### Kubeadm Init Failures

**Problem**: `error execution phase preflight: Port 6443 already in use`

```bash
# Check if kubelet already running
systemctl status kubelet

# Check for stale kubeadm init
stat /var/lib/kubelet/kubeadm-flags.env
```

**Solution**:
1. Clean up: `kubeadm reset -f`
2. Remove `/var/lib/kubelet/kubeadm-flags.env`
3. Re-run playbook

**Problem**: `[preflight] Some fatal errors occurred`

```bash
# Check swap is disabled
free -h  # Should show 0 for Swap

# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Should be 1

# Check br_netfilter loaded
lsmod | grep br_netfilter
```

**Solution**: Re-run `prerequisites` role to fix OS-level issues

### Container Runtime Issues

**Problem**: `ERROR: Service 'docker' not found` or `daemon not running`

```bash
# Check Docker status
systemctl status docker

# View Docker logs
journalctl -u docker -n 50

# Check if Docker is installable
apt search docker.io
```

**Solution**:
1. Ensure `container_runtime: "docker"` in `group_vars/all.yml`
2. Check Docker version exists: `apt-cache search docker-ce=24.0`
3. Run container_runtime role in isolation:
   ```bash
   ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --tags "container_runtime"
   ```

**Problem**: `docker: permission denied while trying to connect to the Docker daemon`

```bash
# Check docker group
groups ubuntu

# Add user to docker group
sudo usermod -aG docker ubuntu
newgrp docker
```

**Solution**: Add Ansible user to docker group or run kubelet with root

### Kubelet Service Issues

**Problem**: `kubelet: command not found`

```bash
# Check if installed
which kubelet

# Check Kubernetes repo
apt-cache search kubelet

# Manual install
apt-get install -y kubelet=1.28.0-*
```

**Solution**: Ensure `kubernetes_repo` role ran successfully before `kubeadm_prepare`

**Problem**: `kubelet service failed to start`

```bash
# Check systemd service
systemctl status kubelet
journalctl -u kubelet -n 100

# Check config
cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
```

**Solution**:
1. Verify systemd config is correct
2. Check kubelet log: `journalctl -u kubelet --no-pager | tail -50`
3. Ensure container runtime is running

---

## Master Node Issues

### API Server Won't Start

**Problem**: `ERROR: API server failed to start`

```bash
# Check API server logs (Docker)
docker ps | grep kube-apiserver

# Check API server logs (static pod)
journalctl -u kubelet -n 200 | grep apiserver
```

**Solution**:
1. Check kubeadm config: `cat /tmp/kubeadm-init.yaml`
2. Investigate logs for specific error (usually port conflicts or missing files)
3. Check `/etc/kubernetes/manifests/kube-apiserver.yaml` for errors

### etcd Won't Start

**Problem**: `UNAVAILABLE: etcd cluster is unavailable`

```bash
# Check etcd pod
kubectl get pods -n kube-system | grep etcd

# Check etcd logs
docker logs <etcd-container-id>

# Check etcd data directory
ls -la /var/lib/etcd/
```

**Solution**:
1. Ensure `/var/lib/etcd/` has correct permissions
2. Check disk space: `df -h`
3. Reset kubeadm and retry if data corrupted

---

## Worker Node Issues

### kubeadm join Fails

**Problem**: `[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key`

```bash
# Check join token file exists
stat /tmp/kubeadm-join-command.txt

# Verify token format
cat /tmp/kubeadm-join-command.txt

# Check connectivity to control plane
ping k8s-master.prod.internal:6443
```

**Solution**:
1. Ensure `kube_master` role completed successfully on master
2. Verify `control_plane_endpoint` is resolvable and network-accessible
3. Check join token hasn't expired (default 24h)
4. Re-generate token if needed:
   ```bash
   kubeadm token create --print-join-command
   ```

**Problem**: `error reading bootstrap kubelet config: ... failed to get bootstrap token ... not found`

```bash
# Check if bootstrap token exists on master
kubectl get secrets -n kube-system | grep bootstrap-token
```

**Solution**: Regenerate token and retry join

### Node Not Ready

**Problem**: `kubectl get nodes` shows `NotReady`

```bash
# Check node status details
kubectl describe node worker-1

# Check kubelet logs
journalctl -u kubelet -n 100

# Check container runtime
docker ps -a
```

**Common causes**:
1. **CNI not deployed**: Deploy Calico/Flannel from master
2. **Container runtime issues**: Restart Docker/containerd
3. **Network issues**: Check routing, check node IP

**Solution**:
```bash
# From master:
kubectl get pods -n kube-system

# If no CNI pods:
ansible-playbook playbooks/deploy_cni.yml -i inventory/production/hosts.ini
```

---

## CNI Plugin Issues

### Pods Can't Communicate

**Problem**: `Connection refused` between pods on different nodes

```bash
# Test pod connectivity
kubectl run test1 --image=busybox --restart=Never -- sleep 1000
kubectl run test2 --image=busybox --restart=Never -- sleep 1000
kubectl exec -it test1 -- ping <test2-pod-ip>

# Check CNI pods running
kubectl get pods -n kube-system -l k8s-app=calico-node
```

**Solution**:
1. Ensure CNI pods are running: `kubectl get pods -n kube-system`
2. Verify pod CIDR matches: `grep pod_network_cidr group_vars/all.yml`
3. Check node-to-node connectivity: `ping` between nodes
4. Restart CNI pod if needed: `kubectl delete pods -n kube-system -l k8s-app=calico-node`

### Calico Installation Fails

**Problem**: `error: unable to recognize "...calico...": no matches for kind "Installation"`

```bash
# Check if Tigera operator is installed
kubectl get namespace tigera-system
kubectl get pods -n tigera-system

# Check CRDs
kubectl get crd | grep calico
```

**Solution**:
1. Re-run Calico role:
   ```bash
   ansible-playbook -i inventory/production/hosts.ini -e "{hosts: k8s_masters}" -m include_role -a name=cni_calico
   ```
2. Or manually apply Tigera operator:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27/manifests/tigera-operator.yaml
   kubectl wait --for=condition=Ready pod -n tigera-operator -l k8s-app=tigera-operator --timeout=120s
   ```

---

## Add-On Issues

### Nginx Ingress Not Ready

**Problem**: Ingress pod stuck in `Pending`

```bash
# Check ingress deployment
kubectl get deployment -n ingress-nginx

# Check pod events
kubectl describe pods -n ingress-nginx

# Check logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

**Common causes**:
1. **No node available**: Worker nodes not `Ready` yet
2. **Image pull issues**: Network connectivity to registry
3. **Resource constraints**: Not enough CPU/memory

**Solution**:
```bash
# Check node capacity
kubectl top nodes

# Check if image pulled
docker images | grep ingress-nginx

# Retry deployment
kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx
```

### Metrics Server Not Collecting

**Problem**: `kubectl top nodes` shows `unknown` or `<unknown>`

```bash
# Check metrics server pod
kubectl get pods -n kube-system metrics-server

# Check pod logs
kubectl logs -n kube-system deployment/metrics-server

# Check metrics API
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
```

**Common causes**:
1. **Kubelet certificate issues**: `kubelet_insecure_tls: true` not set
2. **Metrics not collected**: Node `Ready` but metrics blank (give it 1-2 min)
3. **RBAC issues**: ServiceAccount permissions

**Solution**:
```bash
# Check kubelet TLS setting in defaults
grep kubelet_insecure_tls roles/metrics_server/defaults/main.yml

# If not present, add to group_vars/all.yml:
kubelet_insecure_tls: true

# Restart metrics server
kubectl delete pod -n kube-system -l k8s-app=metrics-server
```

---

## Network Issues

### DNS Resolution Fails

**Problem**: `nslookup kubernetes.default` hangs or fails

```bash
# Test DNS from pod
kubectl run dns-test --image=busybox --rm -i --restart=Never -- nslookup kubernetes.default

# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check DNS service
kubectl get svc -n kube-system kube-dns
```

**Solution**:
1. Ensure CoreDNS is running (deployed by kubeadm by default)
2. Check CNI pod network: `kubectl get pods -o wide`
3. Verify service CIDR: `grep service_cidr group_vars/all.yml`

### Nodes Can't Reach Pod Network

**Problem**: `ping <pod-ip>` from worker node fails

```bash
# Check routes
ip route

# Check CNI bridge
ip addr show

# Check iptables
sudo iptables -L

# Test pod-to-node connectivity
kubectl exec -it <pod> -- ping <node-ip>
```

**Solution**:
1. Verify CNI plugin deployed: `kubectl get daemonset -n kube-system`
2. Check node IP allocation: `ip addr show`
3. Check firewall rules allow inter-pod traffic
4. Verify pod CIDR doesn't overlap with node network

---

## Performance Issues

### Slow Cluster Operations

**Problem**: `kubectl apply` hangs or is very slow

```bash
# Check API server load
kubectl get events -A

# Check etcd health
kubectl exec -n kube-system etcd-master-1 -- etcdctl member list

# Check API server logs
docker logs <api-server-container>
```

**Solution**:
1. Check node resources: `kubectl top nodes`
2. Check API server CPU/memory: `kubectl top pods -n kube-system`
3. Increase etcd quota if needed: Edit `etcd_quota_bytes` in `group_vars/k8s_masters.yml`

### Pod Startup Is Slow

**Problem**: New pods take too long to reach `Running`

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check kubelet logs
journalctl -u kubelet | tail -50

# Check image pull
kubectl get events -A | grep Pull
```

**Solution**:
1. Pre-pull images on worker nodes
2. Check network to container registry
3. Increase imagePullBackOff timeout if needed

---

## Playbook Execution Issues

### Playbook Fails Partway Through

**Problem**: Playbook stops executing after a task

```bash
# Re-run specific role
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --start-at-task="<task-name>"

# Dry-run from that point
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --start-at-task="<task-name>" --check
```

**Solution**:
1. Check the failed task output for error message
2. Fix the underlying issue (e.g., internet connectivity, disk space)
3. Re-run playbook (most tasks are idempotent)

### Playbook Hangs or Times Out

**Problem**: Playbook seems stuck

```bash
# Increase timeout in ansible.cfg
grep timeout ansible.cfg
```

**Solution**:
1. Increase `timeout` in `ansible.cfg` (default 30s)
2. Use `-vvv` flag to see current task:
   ```bash
   ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini -vvv
   ```
3. Check network connectivity to target hosts

---

## Debugging Techniques

### Enable Verbose Output

```bash
# Single verbosity level
ansible-playbook playbooks/site.yml -v

# Double verbosity (shows variable values)
ansible-playbook playbooks/site.yml -vv

# Triple verbosity (shows all module calls)
ansible-playbook playbooks/site.yml -vvv

# Show all variables for a host
ansible k8s_masters -i inventory/production/hosts.ini -m debug -a "var=hostvars[inventory_hostname]"
```

### Dry-Run Mode

```bash
# Preview changes without executing
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --check

# Check a specific role
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --check -e "ansible_tags=prerequisites"
```

### Manual Task Execution

```bash
# Run specific role only
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --start-at-task="Initialize Kubernetes control plane"

# Skip a role
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --skip-tags="cni"

# Run only specific tag
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --tags="docker"
```

### SSH Debugging

```bash
# Direct SSH to debug manually
ssh -i ~/.ssh/id_rsa ubuntu@10.0.1.10

# Once on host, check services
systemctl status docker
systemctl status kubelet
systemctl status containerd

# View logs
journalctl -f -u kubelet
docker logs -f <container-id>
```

---

## Quick Reference: Common Commands

```bash
# Verify cluster is up
kubectl get nodes -o wide
kubectl get pods -A

# Check Kubernetes version
kubectl version --short

# View resource usage
kubectl top nodes
kubectl top pods -A

# Check cluster info
kubectl cluster-info

# View events
kubectl get events -A --sort-by='.lastTimestamp'

# SSH to master for kubectl operations
ssh ubuntu@<master-ip>
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes

# View kubeadm logs
journalctl -u kubelet -n 100

# Reset cluster completely (if needed)
kubeadm reset -f
rm -rf /var/lib/kubelet/*
rm -rf /etc/kubernetes/*
systemctl restart kubelet
```

---

## Getting Help

1. **Check playbook output** — Most errors are self-explanatory
2. **View role defaults** — `cat roles/<role>/defaults/main.yml`
3. **Check Kubernetes logs** — `kubectl logs -n kube-system <pod-name>`
4. **Ansible debug mode** — Add `-vvv` flag
5. **Manual testing** — SSH and run commands directly
6. **Check documentation** — README.md and QUICKSTART.md

---

**Last Updated**: February 22, 2026
