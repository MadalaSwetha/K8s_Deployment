#!/bin/bash

# Kubernetes Ansible Deployment Script
# Run this on your Ansible control machine (Linux/Mac/WSL)
# Usage: ./deploy-kubernetes.sh [environment]

set -e

ENVIRONMENT=${1:-production}
INVENTORY_PATH="inventory/${ENVIRONMENT}/hosts.ini"
PLAYBOOK_PATH="playbooks/site.yml"
LOG_FILE="deploy-$(date +%Y%m%d-%H%M%S).log"

echo "======================================================================"
echo "  Kubernetes Cluster Deployment via Ansible"
echo "======================================================================"
echo "Environment: $ENVIRONMENT"
echo "Inventory: $INVENTORY_PATH"
echo "Playbook: $PLAYBOOK_PATH"
echo "Log File: $LOG_FILE"
echo "======================================================================"
echo ""

# Step 1: Check Prerequisites
echo "[STEP 1] Checking prerequisites..."
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible not found. Install with: pip install ansible"
    exit 1
fi

if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ ansible-playbook not found."
    exit 1
fi

if [ ! -f "$INVENTORY_PATH" ]; then
    echo "❌ Inventory file not found: $INVENTORY_PATH"
    exit 1
fi

echo "✅ Ansible installed: $(ansible --version | head -1)"
echo "✅ Inventory file found: $INVENTORY_PATH"
echo ""

# Step 2: Verify Connectivity
echo "[STEP 2] Verifying SSH connectivity to all hosts..."
if ansible -i "$INVENTORY_PATH" k8s_all -m ping -q 2>&1 | grep -q "SUCCESS\|pong"; then
    echo "✅ All hosts reachable"
else
    echo "⚠️  Some hosts may not be reachable. Continuing anyway..."
fi
echo ""

# Step 3: Dry-Run (Check Mode)
echo "[STEP 3] Running deployment in check mode (dry-run)..."
echo "This will preview all changes without applying them."
echo ""
ansible-playbook -i "$INVENTORY_PATH" "$PLAYBOOK_PATH" --check -v 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✅ Dry-run completed successfully"
    echo ""
    read -p "Do you want to proceed with actual deployment? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
else
    echo ""
    echo "❌ Dry-run failed. Check the output above for errors."
    exit 1
fi

# Step 4: Actual Deployment
echo ""
echo "[STEP 4] Running actual deployment..."
echo "⏳ This may take 20-30 minutes..."
echo ""
ansible-playbook -i "$INVENTORY_PATH" "$PLAYBOOK_PATH" -v 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "==============================================================="
    echo "  ✅ Kubernetes Cluster Deployment Completed Successfully!"
    echo "==============================================================="
    echo ""
    
    # Step 5: Verification
    echo "[STEP 5] Verifying cluster..."
    MASTER=$(ansible-inventory -i "$INVENTORY_PATH" --list | grep -o '"k8s_masters": \[' -A 1 | grep -o '".*"' | head -1 | tr -d '"')
    
    if [ -n "$MASTER" ]; then
        echo "Running post-deployment verification on: $MASTER"
        ansible -i "$INVENTORY_PATH" k8s_masters[0] -m shell -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes" -q
        echo ""
        ansible -i "$INVENTORY_PATH" k8s_masters[0] -m shell -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A" -q
    fi
    
    echo ""
    echo "Logs saved to: $LOG_FILE"
    echo ""
    echo "Next steps:"
    echo "1. SSH to master: ssh ubuntu@<master-ip>"
    echo "2. Check cluster: kubectl get nodes"
    echo "3. Monitor pods: kubectl get pods -A"
    echo "4. Check Ingress: kubectl get ingress -A"
    echo "5. View metrics: kubectl top nodes"
    echo ""
else
    echo ""
    echo "❌ Deployment failed. Check logs:"
    echo "tail -100 $LOG_FILE"
    exit 1
fi
