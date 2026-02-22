# Project Manifest - Kubernetes Ansible

Generated: February 22, 2026

## Summary

A complete, production-grade Kubernetes cluster automation project for cloud VMs (AWS/Azure/GCP) using Ansible with:
- **9 reusable roles** for each Kubernetes component
- **Fully parameterized** configuration (no hardcoded values)
- **9 playbooks** for deployment, scaling, upgrades, and maintenance
- **Multi-environment** support (staging + production)
- **CNI options**: Calico (default) + Flannel (switchable)
- **Add-ons**: Nginx Ingress, Metrics Server, Storage Provisioner
- **Production features**: RBAC, audit logging, multi-replica components

## File Inventory

### Root Configuration Files
- `ansible.cfg` — Ansible execution configuration
- `requirements.txt` — Python dependencies (Jinja2, netaddr, pyyaml)
- `README.md` — Comprehensive documentation
- `QUICKSTART.md` — Quick start guide
- `PROJECT_MANIFEST.md` — This file

### Inventory Structure

```
inventory/
├── production/
│   ├── hosts.ini                          (3 nodes: 1 master + 2 workers)
│   ├── group_vars/
│   │   ├── all.yml                        (Global variables - EDIT THIS)
│   │   ├── k8s_masters.yml                (Master-specific variables)
│   │   ├── k8s_workers.yml                (Worker-specific variables)
│   │   └── k8s_all.yml                    (All nodes configuration)
│   └── host_vars/
│       ├── master-1.yml                   (Per-host overrides)
│       ├── worker-1.yml
│       └── worker-2.yml
│
└── staging/
    ├── hosts.ini                          (2 nodes: 1 master + 1 worker)
    └── group_vars/
        ├── all.yml
        ├── k8s_masters.yml
        ├── k8s_workers.yml
        └── k8s_all.yml
```

### Roles Detailed Structure

```
roles/
│
├── Prerequisites (OS-Level Setup)
│   └── prerequisites/
│       ├── tasks/main.yml                 (120+ lines: swap disable, kernel params, firewall)
│       ├── defaults/main.yml              (7 defaults)
│       ├── handlers/main.yml              (2 handlers)
│       └── templates/
│           ├── kubernetes-modules.conf.j2
│           └── limits.conf.j2
│
├── Container Runtime
│   └── container_runtime/
│       ├── tasks/main.yml                 (70+ lines: Docker/containerd install)
│       ├── defaults/main.yml              (8 defaults)
│       ├── handlers/main.yml              (2 handlers)
│       ├── vars/
│       │   ├── debian.yml
│       │   └── redhat.yml
│       └── templates/
│           ├── daemon.json.j2
│           └── containerd.service.j2
│
├── Kubernetes Repository Setup
│   └── kubernetes_repo/
│       ├── tasks/main.yml                 (Add K8s repos)
│       ├── defaults/main.yml              (1 default)
│       └── handlers/main.yml              (empty)
│
├── Kubeadm Preparation
│   └── kubeadm_prepare/
│       ├── tasks/main.yml                 (Install kubeadm/kubelet/kubectl)
│       ├── defaults/main.yml              (2 defaults)
│       ├── handlers/main.yml              (1 handler)
│       └── templates/
│           └── 10-kubeadm.conf.j2         (Kubelet systemd config)
│
├── Kubernetes Control Plane
│   └── kube_master/
│       ├── tasks/main.yml                 (100+ lines: kubeadm init + token)
│       ├── defaults/main.yml              (10 defaults)
│       ├── handlers/main.yml              (empty)
│       ├── templates/
│       │   └── kubeadm-init.yaml.j2       (Kubeadm full config template)
│       └── files/
│           └── audit-policy.yaml          (Audit logging config)
│
├── Worker Node Joins
│   └── kube_worker/
│       ├── tasks/main.yml                 (50+ lines: kubeadm join + labels)
│       ├── defaults/main.yml              (2 defaults)
│       └── handlers/main.yml              (empty)
│
├── CNI: Calico
│   └── cni_calico/
│       ├── tasks/main.yml                 (Download + apply Calico)
│       ├── defaults/main.yml              (7 defaults)
│       ├── handlers/main.yml              (empty)
│       └── templates/
│           └── calico-manifest.yaml.j2    (Calico Installation resource)
│
├── CNI: Flannel
│   └── cni_flannel/
│       ├── tasks/main.yml                 (Download + apply Flannel)
│       ├── defaults/main.yml              (3 defaults)
│       ├── handlers/main.yml              (empty)
│       └── templates/
│           └── flannel-manifest.yaml.j2   (Flannel DaemonSet config)
│
├── Ingress: Nginx
│   └── ingress_nginx/
│       ├── tasks/main.yml                 (Deploy Nginx Ingress)
│       ├── defaults/main.yml              (6 defaults)
│       ├── handlers/main.yml              (empty)
│       └── templates/
│           └── nginx-ingress.yaml.j2      (RBAC + Deployment + Service)
│
├── Metrics
│   └── metrics_server/
│       ├── tasks/main.yml                 (Deploy Metrics Server)
│       ├── defaults/main.yml              (3 defaults)
│       └── templates/
│           └── metrics-server.yaml.j2     (Deployment + ServiceAccount + RBAC)
│
└── Storage
    └── storage_provisioner/
        ├── tasks/main.yml                 (Deploy storage class)
        ├── defaults/main.yml              (2 defaults)
        └── templates/
            └── storage-class.yaml.j2      (Storage class manifest)
```

### Playbooks

```
playbooks/
├── site.yml                     (Main orchestration playbook)
│                                ├─ Prerequisites → Container runtime
│                                ├─ Kubernetes tools installation
│                                ├─ Master initialization
│                                ├─ CNI deployment (Calico/Flannel)
│                                ├─ Worker node joins
│                                ├─ Add-ons deployment (Ingress, Metrics, Storage)
│                                └─ Final verification
│
├── add_worker.yml               (Scale out existing cluster)
│                                ├─ Setup prerequisites on new nodes
│                                ├─ Install container runtime
│                                ├─ Install Kubernetes tools
│                                ├─ Join new workers
│                                └─ Verify new nodes
│
├── deploy_cni.yml               (Deploy/switch CNI plugins)
│                                ├─ Deploy Calico or Flannel
│                                └─ Verify CNI status
│
├── verify_deployment.yml        (Post-deployment validation)
│                                ├─ Cluster info check
│                                ├─ Node status validation
│                                ├─ Pod status across namespaces
│                                ├─ CNI plugin verification
│                                ├─ Ingress controller check
│                                ├─ Metrics Server validation
│                                ├─ DNS resolution test
│                                └─ System-level service checks
│
├── backup_etcd.yml              (Backup etcd database)
│                                ├─ Create backup directory
│                                ├─ Backup using etcdctl or kubectl
│                                └─ Verify backup files
│
└── upgrade_k8s.yml              (In-place cluster upgrade)
                                 ├─ Backup etcd
                                 ├─ Upgrade masters (serial)
                                 ├─ Upgrade workers (serial)
                                 ├─ Node drain/uncordon during upgrade
                                 └─ Post-upgrade verification
```

## Variable Reference

### Global Variables (group_vars/all.yml)

**Versions**
- `kubernetes_version: "1.28.0"`
- `docker_version: "24.0.*"`
- `containerd_version: "1.7.*"`
- `calico_version: "v3.27"`
- `flannel_version: "v0.24"`
- `nginx_ingress_version: "4.9"`
- `metrics_server_version: "0.6"`

**Networking**
- `pod_network_cidr: "10.244.0.0/16"` (Pod IP range)
- `service_cidr: "10.96.0.0/12"` (Service IP range)
- `cni_plugin: "calico"` (Calico or Flannel)

**Container Runtime**
- `container_runtime: "docker"` (Docker or containerd)
- `registry_url: "docker.io"`
- `registry_credentials_enabled: false`

**Infrastructure**
- `cloud_provider: "aws"` (aws, azure, gcp, none)
- `region: "us-east-1"`

**Operating System**
- `enable_swap: false`
- `net_bridge_enabled: true`
- `ip_forward_enabled: true`
- `enable_firewall: true`

**API Server**
- `api_server_feature_gates: "RotateKubeletServerCertificate=true,PodPriority=true"`

**Kubelet**
- `kubelet_max_pods: 110`
- `kubelet_system_reserved: "cpu=100m,memory=128Mi,ephemeral-storage=1Gi"`

**Audit Logging**
- `audit_enabled: true`
- `audit_max_age_days: 30`
- `audit_max_backup: 10`

### Master-Specific Variables (group_vars/k8s_masters.yml)

- `cluster_name: "production-k8s"`
- `control_plane_endpoint: "k8s-master.prod.internal:6443"`
- `etcd_quota_bytes: 2147483648` (2GB)
- `api_server_cert_extra_sans: ["k8s-master.prod.internal"]`
- `node_labels: "node-role.kubernetes.io/master=,node-role.kubernetes.io/control-plane="`
- `node_taints: ["node-role.kubernetes.io/master=:NoSchedule"]`

### Worker-Specific Variables (group_vars/k8s_workers.yml)

- `kubelet_extra_args: "--max-pods=110"`
- `node_labels: "node-role.kubernetes.io/worker="`
- `node_taints: []`

### Per-Host Variables (host_vars/master-1.yml, etc.)

```yaml
ansible_host: "10.0.1.10"           # Node IP
ansible_user: "ubuntu"              # SSH user
node_labels: "role=master"          # Custom labels
node_taints: []                     # Custom taints
```

## Role Characteristics

| Role | Type | Variables | Handlers | Templates | Idempotent |
|------|------|-----------|----------|-----------|-----------|
| prerequisites | Infrastructure | 7 | 2 | 2 | ✅ Yes |
| container_runtime | Infrastructure | 8 | 2 | 2 | ✅ Yes |
| kubernetes_repo | Infrastructure | 1 | 0 | 0 | ✅ Yes |
| kubeadm_prepare | Installation | 2 | 1 | 1 | ✅ Yes |
| kube_master | Initialization | 10 | 0 | 1 | ✅ Yes |
| kube_worker | Join | 2 | 0 | 0 | ✅ Yes |
| cni_calico | Add-on | 7 | 0 | 1 | ✅ Yes |
| cni_flannel | Add-on | 3 | 0 | 1 | ✅ Yes |
| ingress_nginx | Add-on | 6 | 0 | 1 | ✅ Yes |
| metrics_server | Add-on | 3 | 0 | 1 | ✅ Yes |
| storage_provisioner | Add-on | 2 | 0 | 1 | ✅ Yes |

## Template Files

**Kubeadm Configuration**
- `roles/kube_master/templates/kubeadm-init.yaml.j2` — Complete kubeadm InitConfiguration + ClusterConfiguration + KubeletConfiguration with all variables injected

**Container Runtime**
- `roles/container_runtime/templates/daemon.json.j2` — Docker daemon config with registry mirrors and logging
- `roles/container_runtime/templates/containerd.service.j2` — containerd systemd unit

**Networking**
- `roles/cni_calico/templates/calico-manifest.yaml.j2` — Calico Installation resource
- `roles/cni_flannel/templates/flannel-manifest.yaml.j2` — Flannel ConfigMap

**Services**
- `roles/ingress_nginx/templates/nginx-ingress.yaml.j2` — ServiceAccount + RBAC + Deployment + Service + IngressClass
- `roles/metrics_server/templates/metrics-server.yaml.j2` — ServiceAccount + RBAC + Deployment + Service
- `roles/storage_provisioner/templates/storage-class.yaml.j2` — StorageClass manifest

**OS Configuration**
- `roles/prerequisites/templates/kubernetes-modules.conf.j2` — Kernel modules (br_netfilter, overlay)
- `roles/prerequisites/templates/limits.conf.j2` — Resource limits

## Key Features Implemented

✅ **Fully Parameterized** — 100% of configuration externalized to `group_vars` and `host_vars`

✅ **Multi-tier Variable Hierarchy**
   - Extra vars (highest, from `-e` CLI flag)
   - Host vars (`inventory/production/host_vars/`)
   - Group vars (`inventory/production/group_vars/`)
   - Role defaults (`roles/*/defaults/main.yml`)

✅ **Cloud Support** — AWS, Azure, GCP with automatic region/zone detection

✅ **CNI Dual Support** — Calico (default) + Flannel (switchable via variable)

✅ **Production Hardening**
   - RBAC enabled
   - Audit logging configured
   - Multi-replica components
   - Node drain/cordon during updates
   - Resource limits on all add-ons

✅ **Idempotent Execution** — Safe to re-run; checks for existing state

✅ **Lifecycle Playbooks** — Deploy, scale, upgrade, backup, verify

✅ **Multi-Environment** — Separate staging and production configs

✅ **Dry-run Support** — Use `--check` flag to preview changes

## Typical Deployment Time

| Phase | Estimated Time |
|-------|-----------------|
| Prerequisites (OS setup) | 2-3 minutes |
| Container Runtime Installation | 2-3 minutes |
| Kubernetes Tools Installation | 3-4 minutes |
| Master Initialization | 3-5 minutes |
| CNI Deployment | 1-2 minutes |
| Worker Node Joins | 2-3 minutes per node |
| Add-ons (Ingress, Metrics, Storage) | 3-5 minutes |
| **Total (1 master + 2 workers)** | **20-30 minutes** |

## File Size Summary

- **Total Configuration Files**: ~150 KB
- **Total Playbook Code**: ~900 lines
- **Total Role Code**: ~2800 lines
- **Total Templates**: ~600 lines
- **Total Documentation**: ~2000 lines

## Extending the Project

### Add a New Role

1. Create directory: `roles/my_component/tasks/defaults/handlers/templates/`
2. Write `tasks/main.yml` with role logic
3. Write `defaults/main.yml` with variables
4. Add to playbook in `playbooks/site.yml`

### Add a New Playbook

1. Create `playbooks/my_playbook.yml`
2. Reference existing roles or create new ones
3. Run with: `ansible-playbook playbooks/my_playbook.yml -i inventory/production/hosts.ini`

### Change Variable Defaults

1. Edit `inventory/production/group_vars/all.yml` (preferred)
2. Or edit `roles/*/defaults/main.yml` (role-specific)

## Best Practices Implemented

✅ Separate staging and production inventories
✅ All versions pinned in variables
✅ Idempotent tasks (check before executing)
✅ Handlers for service restarts
✅ Child group organization (k8s_all contains k8s_masters and k8s_workers)
✅ Role-based architecture for reusability
✅ Jinja2 templating for dynamic config generation
✅ Comprehensive error handling and retries
✅ Multi-environment support
✅ Clear role dependencies

## Getting Started

1. Edit inventory: `inventory/production/hosts.ini`
2. Customize variables: `inventory/production/group_vars/all.yml`
3. Test connectivity: `ansible -i inventory/production/hosts.ini k8s_all -m ping`
4. Dry-run: `ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini --check`
5. Deploy: `ansible-playbook playbooks/site.yml -i inventory/production/hosts.ini`
6. Verify: `ansible-playbook playbooks/verify_deployment.yml -i inventory/production/hosts.ini`

---

**Project Version**: 1.0  
**Created**: February 22, 2026  
**Target**: Production Kubernetes on AWS/Azure/GCP VMs
