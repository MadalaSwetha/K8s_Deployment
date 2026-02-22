# Production Kubernetes Cluster Automation with Ansible

Fully parameterized, production-grade Kubernetes cluster deployment automation using Ansible. Deploy on cloud VMs (AWS, Azure, GCP) with Calico/Flannel CNI, Nginx Ingress Controller, Metrics Server, and related add-ons.

## Architecture

- **Highly parameterized**: All configuration values in `group_vars/` and `host_vars/`
- **Role-based**: Each Kubernetes component as a separate, reusable role
- **Multi-environment**: Separate inventory structures for staging and production
- **Cloud-agnostic**: Support for AWS, Azure, GCP with automatic provider detection
- **Idempotent**: Safe to re-run; no state duplication
- **kubectl-native**: Direct manifest application (no Helm)

## Project Structure

```
kubernetes-ansible/
├── ansible.cfg                          # Global Ansible configuration
├── requirements.txt                     # Python dependencies
├── README.md                            # This file
│
├── inventory/
│   ├── production/
│   │   ├── hosts.ini                   # Master/worker inventory
│   │   ├── group_vars/
│   │   │   ├── all.yml                 # Global variables
│   │   │   ├── k8s_all.yml             # All K8s nodes
│   │   │   ├── k8s_masters.yml         # Control plane specific
│   │   │   └── k8s_workers.yml         # Worker node specific
│   │   └── host_vars/                  # Per-host overrides
│   │       ├── master-1.yml
│   │       └── worker-1.yml
│   │
│   └── staging/
│       ├── hosts.ini
│       └── group_vars/
│           ├── all.yml
│           ├── k8s_all.yml
│           ├── k8s_masters.yml
│           └── k8s_workers.yml
│
├── roles/
│   ├── prerequisites/                  # OS-level setup
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   └── handlers/main.yml
│   ├── container_runtime/              # Docker/containerd
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   ├── handlers/main.yml
│   │   ├── templates/daemon.json.j2
│   │   └── vars/
│   │       ├── main.yml
│   │       ├── debian.yml
│   │       └── redhat.yml
│   ├── kubernetes_repo/                # APT/YUM repos
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   └── handlers/main.yml
│   ├── kubeadm_prepare/                # Install kubeadm/kubelet/kubectl
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   └── handlers/main.yml
│   ├── kube_master/                    # Control plane init
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   ├── handlers/main.yml
│   │   ├── templates/kubeadm-init.yaml.j2
│   │   └── files/audit-policy.yaml
│   ├── kube_worker/                    # Worker node join
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   └── handlers/main.yml
│   ├── cni_calico/                     # Calico CNI plugin
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   ├── handlers/main.yml
│   │   └── templates/calico-manifest.yaml.j2
│   ├── cni_flannel/                    # Flannel CNI plugin
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   ├── handlers/main.yml
│   │   └── templates/flannel-manifest.yaml.j2
│   ├── ingress_nginx/                  # Nginx Ingress Controller
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   ├── handlers/main.yml
│   │   └── templates/nginx-ingress.yaml.j2
│   ├── metrics_server/                 # Kubernetes Metrics Server
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   └── templates/metrics-server.yaml.j2
│   └── storage_provisioner/            # Storage class provisioner
│       ├── tasks/main.yml
│       ├── defaults/main.yml
│       └── templates/storage-class.yaml.j2
│
├── playbooks/
│   ├── site.yml                        # Main orchestration playbook
│   ├── add_worker.yml                  # Add worker nodes to cluster
│   ├── deploy_cni.yml                  # Deploy selected CNI
│   ├── verify_deployment.yml           # Post-deployment verification
│   ├── backup_etcd.yml                 # Backup etcd database
│   └── upgrade_k8s.yml                 # In-place cluster upgrade
│
└── templates/                          # Shared configuration templates
    └── (supplementary templates for complex configs)
```

## Prerequisites

- Ansible 2.10+
- Python 3.6+
- SSH access to all target nodes with sudo privileges
- Target nodes: Ubuntu 20.04/22.04 LTS or RHEL 8/9+ (configured via `os_family` var)
- Cloud VMs with at least 2CPU, 4GB RAM for masters; 2CPU, 4GB RAM for workers

## Quick Start

### 1. Setup Local Environment

```bash
cd kubernetes-ansible
pip install -r requirements.txt
ansible-galaxy install -r requirements.yml  # If using community roles (optional)
```

### 2. Configure Inventory

Edit `inventory/production/hosts.ini`:

```ini
[k8s_masters]
master-1 ansible_host=10.0.1.10

[k8s_workers]
worker-1 ansible_host=10.0.2.10
worker-2 ansible_host=10.0.2.11

[k8s_all:children]
k8s_masters
k8s_workers
```

### 3. Configure Variables

Edit `inventory/production/group_vars/all.yml` with your environment values:
- Kubernetes version
- Pod/service CIDR ranges
- Container registry URLs
- Cloud provider settings
- CNI plugin selection

### 4. Deploy Cluster

```bash
# Deploy to staging first
ansible-playbook playbooks/site.yml -i inventory/staging/hosts.ini

# Deploy to production
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini
```

### 5. Verify Deployment

```bash
ansible-playbook playbooks/verify_deployment.yml -i inventory/production/hosts.ini
```

## Key Variables

### Global (group_vars/all.yml)

| Variable | Type | Example | Purpose |
|----------|------|---------|---------|
| `kubernetes_version` | string | "1.28.0" | K8s release version |
| `pod_network_cidr` | string | "10.244.0.0/16" | Pod network range |
| `service_cidr` | string | "10.96.0.0/12" | Service network range |
| `cni_plugin` | string | "calico" or "flannel" | CNI provider |
| `container_runtime` | string | "docker" or "containerd" | Container engine |
| `docker_version` | string | "24.0.*" | Docker version |
| `registry_url` | string | "registry.example.com" | Container registry |
| `cloud_provider` | string | "aws", "azure", "gcp" | Cloud platform |

### Master Nodes (group_vars/k8s_masters.yml)

| Variable | Type | Example |
|----------|------|---------|
| `cluster_name` | string | "production-k8s" |
| `control_plane_endpoint` | string | "k8s-master.prod.internal:6443" |
| `api_server_cert_extra_sans` | list | ["k8s-api.prod.example.com"] |
| `etcd_quota_bytes` | int | 2147483648 (2GB) |

### Per-Host (host_vars/master-1.yml)

```yaml
ansible_host: "10.0.1.10"
node_labels: "role=master"
node_taints: "node-role.kubernetes.io/master=:NoSchedule"
```

## Deployment Workflow

1. **Common tasks** — OS updates, prerequisites, disable swap, configure networking
2. **Container runtime** — Install Docker/containerd and configure
3. **K8s tools** — Add Kubernetes repo and install kubeadm, kubelet, kubectl
4. **Master initialization** — Run kubeadm init, bootstrap control plane
5. **CNI deployment** — Apply selected CNI plugin (Calico or Flannel)
6. **Worker nodes join** — kubeadm join to cluster
7. **Add-ons** — Deploy Nginx Ingress, Metrics Server, Storage provisioner
8. **Verification** — Post-deployment health checks

## Scaling

### Add Worker Nodes

1. Add new nodes to inventory under `[k8s_workers]`
2. Define host vars if needed
3. Run: `ansible-playbook playbooks/add_worker.yml -i inventory/production/hosts.ini`

## Maintenance

### Backup etcd

```bash
ansible-playbook playbooks/backup_etcd.yml -i inventory/production/hosts.ini
```

### Upgrade Kubernetes

```bash
ansible-playbook playbooks/upgrade_k8s.yml -i inventory/production/hosts.ini --extra-vars "target_k8s_version=1.29.0"
```

### Verify Cluster Health

```bash
ansible-playbook playbooks/verify_deployment.yml -i inventory/production/hosts.ini
```

## Role Details

### prerequisites
Configures OS-level requirements: kernel parameters, sysctl, firewall, swap disable, cgroups.

### container_runtime
Installs Docker or containerd with daemon configuration, registry mirrors, logging drivers.

### kubernetes_repo
Adds Kubernetes package repositories and GPG keys for APT/YUM.

### kubeadm_prepare
Installs kubeadm, kubelet, kubectl binaries from repositories.

### kube_master
Initializes Kubernetes control plane using kubeadm init with custom configuration template.

### kube_worker
Joins worker nodes to cluster using kubeadm join command.

### cni_calico
Deploys Calico network plugin for pod networking.

### cni_flannel
Deploys Flannel as alternative CNI plugin.

### ingress_nginx
Deploys Nginx Ingress Controller for external HTTP/HTTPS routing.

### metrics_server
Deploys Kubernetes Metrics Server for CPU/memory usage metrics.

### storage_provisioner
Deploys storage class provisioner (local volumes, cloud storage, NFS).

## Troubleshooting

### View role source
```bash
cat inventory/production/group_vars/all.yml
```

### Dry-run playbook
```bash
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --check
```

### Increase verbosity
```bash
ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini -vvv
```

### SSH to nodes
```bash
ansible -i inventory/production/hosts.ini k8s_masters -m setup
```

## Best Practices

1. **Version variables** — Always pin versions in group_vars, not defaults
2. **Staging first** — Test all changes in staging before production
3. **Backup before upgrades** — Always backup etcd before cluster upgrades
4. **Idempotence** — Playbooks are safe to re-run; no data loss
5. **Inventory management** — Keep hosts.ini in version control, use secrets for credentials
6. **Monitoring** — Metrics Server enables `kubectl top` commands for resource usage

## License

MIT
