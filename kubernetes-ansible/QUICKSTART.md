# Kubernetes Ansible - Quick Start Guide

## What's Been Created

Your fully parameterized, production-grade Kubernetes automation project is ready at `c:\Users\Swetha\TRYG\kubernetes-ansible\`.

### Directory Structure

```
kubernetes-ansible/
├── ansible.cfg                 # Ansible configuration
├── requirements.txt            # Python dependencies
├── README.md                   # Full documentation
│
├── inventory/
│   ├── production/            # Production environment (3 nodes: 1 master, 2 workers)
│   └── staging/               # Staging environment (2 nodes: 1 master, 1 worker)
│       ├── hosts.ini          # Node inventory
│       └── group_vars/        # Environment-specific variables (edit these!)
│
├── roles/                     # 9 Kubernetes-focused Ansible roles
│   ├── prerequisites/         # OS setup (swap, networking, firewalls)
│   ├── container_runtime/     # Docker or containerd
│   ├── kubernetes_repo/       # K8s APT/YUM repositories
│   ├── kubeadm_prepare/       # kubeadm, kubelet, kubectl installation
│   ├── kube_master/           # Control plane initialization
│   ├── kube_worker/           # Worker node joins
│   ├── cni_calico/            # Calico network plugin
│   ├── cni_flannel/           # Flannel network plugin (alternative)
│   ├── ingress_nginx/         # Nginx Ingress Controller
│   ├── metrics_server/        # Kubernetes Metrics Server
│   └── storage_provisioner/   # Storage class provisioner
│
├── playbooks/                 # Orchestration workflows
│   ├── site.yml               # Main deployment playbook
│   ├── add_worker.yml         # Add new workers to cluster
│   ├── deploy_cni.yml         # Deploy/switch CNI plugins
│   ├── verify_deployment.yml  # Post-deployment validation
│   ├── backup_etcd.yml        # Backup etcd database
│   └── upgrade_k8s.yml        # In-place cluster upgrade
│
└── templates/                 # Shared configuration templates
```

## Configuration: Variables-First Approach

**All configuration values are fully parameterized.** There are NO hardcoded values in roles—everything comes from inventory variables.

### Key Variable Files to Edit

1. **`inventory/production/group_vars/all.yml`** — Global settings
   ```yaml
   kubernetes_version: "1.28.0"        # K8s version
   pod_network_cidr: "10.244.0.0/16"   # Pod CIDR
   service_cidr: "10.96.0.0/12"        # Service CIDR
   docker_version: "24.0.*"            # Container runtime version
   cni_plugin: "calico"                # CNI: calico or flannel
   registry_url: "docker.io"           # Container registry
   cloud_provider: "aws"               # Cloud: aws, azure, gcp, none
   ```

2. **`inventory/production/group_vars/k8s_masters.yml`** — Master-specific
   ```yaml
   cluster_name: "production-k8s"
   control_plane_endpoint: "k8s-master.prod.internal:6443"
   etcd_quota_bytes: 2147483648        # 2GB for production
   ```

3. **`inventory/production/group_vars/k8s_workers.yml`** — Worker-specific
   ```yaml
   kubelet_extra_args: "--max-pods=110"
   ```

4. **`inventory/production/host_vars/`** — Per-node overrides
   ```yaml
   # master-1.yml
   ansible_host: "10.0.1.10"
   node_labels: "role=master,workload=system"
   ```

5. **`inventory/production/hosts.ini`** — Edit node inventory
   ```ini
   [k8s_masters]
   master-1 ansible_host=10.0.1.10

   [k8s_workers]
   worker-1 ansible_host=10.0.2.10
   worker-2 ansible_host=10.0.2.11
   ```

## Quick Start (Linux/Mac)

```bash
cd kubernetes-ansible

# 1. Install dependencies
pip install -r requirements.txt

# 2. Edit your inventory and variables
nano inventory/production/hosts.ini
nano inventory/production/group_vars/all.yml
nano inventory/production/group_vars/k8s_masters.yml

# 3. Test connectivity to nodes
ansible -i inventory/production/hosts.ini k8s_all -m ping

# 4. Dry-run the deployment
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --check

# 5. Deploy to staging FIRST
ansible-playbook playbooks/site.yml -i inventory/staging/hosts.ini

# 6. Deploy to production
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini

# 7. Verify deployment
ansible-playbook playbooks/verify_deployment.yml -i inventory/production/hosts.ini
```

## Deployment Features

### What Gets Deployed?

✅ **Master Nodes**
- Kubernetes control plane (API Server, Controller Manager, Scheduler, etcd)
- RBAC enabled
- Audit logging configured
- API server with extra SANs for HA

✅ **Worker Nodes**
- kubelet with configurable pod limits
- Auto-labels and taints applied
- Drain-safe node join process

✅ **Networking**
- **Calico**: Multi-tenant network policy, easy troubleshooting (default)
- **Flannel**: Simple overlay, lightweight (alternative)
- Both fully parameterized (CIDR ranges, backends, MTU, etc.)

✅ **Ingress**
- Nginx Ingress Controller with LoadBalancer service
- Custom resource limits
- Multiple replicas for HA

✅ **Metrics**
- Kubernetes Metrics Server for `kubectl top` commands
- 2 replicas for HA
- CPU/memory resource requests/limits

✅ **Storage**
- Local storage class provisioner (extensible for EBS/NFS)

✅ **System Configuration**
- Swap disabled
- IP forwarding enabled
- br_netfilter kernel module loaded
- Kubelet systemd service configured
- Container runtime (Docker or containerd)

## Role Descriptions

| Role | Purpose | Key Variables |
|------|---------|---------------|
| **prerequisites** | OS setup (kernel, networking, firewall) | `enable_swap`, `enable_firewall`, `ntp_servers` |
| **container_runtime** | Docker/containerd install & config | `container_runtime`, `docker_version`, `registry_url` |
| **kubernetes_repo** | Add K8s package repos | `kubernetes_version` |
| **kubeadm_prepare** | Install kubeadm, kubelet, kubectl | `kubernetes_version`, `kubelet_extra_args` |
| **kube_master** | Initialize control plane | `cluster_name`, `control_plane_endpoint`, `pod_network_cidr` |
| **kube_worker** | Join worker nodes | Auto-discovers join command from master |
| **cni_calico** | Deploy Calico network plugin | `calico_version`, `pod_network_cidr`, `calico_backend` |
| **cni_flannel** | Deploy Flannel network plugin | `flannel_version`, `pod_network_cidr`, `flannel_backend` |
| **ingress_nginx** | Deploy Nginx Ingress | `nginx_ingress_version`, `replica_count`, `service_type` |
| **metrics_server** | Deploy Metrics Server | `metrics_server_version`, `kubelet_insecure_tls` |
| **storage_provisioner** | Deploy storage class | `storage_class_name`, `storage_provisioner_type` |

## Common Deployment Scenarios

### Scenario 1: Single Master + 2 Workers (Default)

```yaml
# inventory/production/hosts.ini already configured for this:
[k8s_masters]
master-1 ansible_host=10.0.1.10

[k8s_workers]
worker-1 ansible_host=10.0.2.10
worker-2 ansible_host=10.0.2.11
```

```bash
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini
```

### Scenario 2: HA Cluster (3 Masters)

Edit `inventory/production/hosts.ini`:

```ini
[k8s_masters]
master-1 ansible_host=10.0.1.10
master-2 ansible_host=10.0.1.11
master-3 ansible_host=10.0.1.12

[k8s_workers]
worker-1 ansible_host=10.0.2.10
worker-2 ansible_host=10.0.2.11
```

Update `control_plane_endpoint` in `group_vars/k8s_masters.yml`:

```yaml
control_plane_endpoint: "k8s-api-lb.example.com:6443"  # Point to load balancer
```

### Scenario 3: Use Flannel Instead of Calico

Edit `inventory/production/group_vars/all.yml`:

```yaml
cni_plugin: "flannel"  # Change from "calico"
```

```bash
ansible-playbook playbooks/deploy_cni.yml -i inventory/production/hosts.ini
```

### Scenario 4: Add New Worker Nodes

1. Add to inventory: Edit `inventory/production/hosts.ini`
2. Create host vars: Create `inventory/production/host_vars/worker-3.yml`
3. Run: `ansible-playbook playbooks/add_worker.yml -i inventory/production/hosts.ini`

### Scenario 5: Upgrade Kubernetes 1.28 → 1.29

```bash
ansible-playbook playbooks/backup_etcd.yml -i inventory/production/hosts.ini
ansible-playbook playbooks/upgrade_k8s.yml -i inventory/production/hosts.ini --extra-vars "target_k8s_version=1.29.0"
```

## Workflow for Customization

### To Change Pod CIDR Range

1. Edit `inventory/production/group_vars/all.yml`:
   ```yaml
   pod_network_cidr: "10.100.0.0/16"  # Changed from 10.244.0.0/16
   ```

2. This propagates to:
   - kubeadm init config (via template)
   - Calico/Flannel manifests (via template)
   - All roles that reference `pod_network_cidr`

### To Use containerd Instead of Docker

1. Edit `inventory/production/group_vars/all.yml`:
   ```yaml
   container_runtime: "containerd"
   ```

2. Roles automatically use `/run/containerd/containerd.sock` for kubelet

### To Add Custom API Server Feature Gates

1. Edit `inventory/production/group_vars/k8s_masters.yml`:
   ```yaml
   api_server_feature_gates: "RotateKubeletServerCertificate=true,MyFeature=true"
   ```

2. Template `kubeadm-init.yaml.j2` automatically includes them

## Troubleshooting

### View what changed without applying
```bash
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --check
```

### Run with extra verbosity
```bash
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini -vvv
```

### SSH to a specific host
```bash
ansible -i inventory/production/hosts.ini k8s_masters -m setup
```

### Check specific role variables
```bash
ansible -i inventory/production/hosts.ini k8s_masters -m debug -a "var=control_plane_endpoint"
```

### Verify Kubernetes cluster
```bash
# SSH to master and run:
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes
kubectl get pods -A
kubectl top nodes
```

## File and Directory Reference

**Variables (Highest Priority; Edit These)**
- `inventory/production/group_vars/all.yml` — Global config
- `inventory/production/group_vars/k8s_*.yml` — Group-specific
- `inventory/production/host_vars/*.yml` — Node-specific

**Roles (Lower Priority; Mostly Read-Only)**
- `roles/*/defaults/main.yml` — Role defaults (can override in group_vars)
- `roles/*/templates/*.j2` — Jinja2 templates using variables
- `roles/*/tasks/main.yml` — Actual tasks (logic is role-independent)

**Inventory**
- `inventory/production/hosts.ini` — Node list and grouping

**Playbooks (Orchestration)**
- `playbooks/site.yml` — Complete workflow
- `playbooks/verify_deployment.yml` — Health checks

## Key Design Decisions Implemented

✅ **Fully Parameterized** — No hardcoded values; all config from `group_vars` and `host_vars`
✅ **Role-Based** — Each component is independent and reusable
✅ **Multi-Environment** — Separate staging and production inventories
✅ **Cloud-Agnostic** — AWS, Azure, GCP parameterized
✅ **kubectl-Native** — Direct manifest application (no Helm)
✅ **Idempotent** — Safe to re-run; no state conflicts
✅ **Production-Ready** — Includes RBAC, audit logging, multi-replica add-ons, storage provisioning

## Next Steps

1. **Edit inventory** — Update `hosts.ini` with real node IPs
2. **Configure variables** — Customize `group_vars/all.yml` for your cloud/network
3. **Test connectivity** — Run `ansible -i inventory/production/hosts.ini k8s_all -m ping`
4. **Dry-run** — Use `--check` flag before real deployment
5. **Deploy** — Execute playbooks against staging, then production
6. **Verify** — Run verification playbook to confirm health

---

**Need help?** Refer to `README.md` for detailed role documentation and `ansible.cfg` for Ansible configuration options.
