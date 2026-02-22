@echo off
REM Kubernetes Ansible Deployment Script for Windows PowerShell
REM Usage: .\deploy.ps1 -Environment production

param(
    [string]$Environment = "production",
    [switch]$CheckOnly = $false,
    [switch]$SkipDryRun = $false
)

Write-Host "======================================================================"
Write-Host "  Kubernetes Cluster Deployment via Ansible (Windows)"
Write-Host "======================================================================"
Write-Host "Environment: $Environment"
Write-Host "Check Only:  $CheckOnly"
Write-Host "Skip Dry-Run: $SkipDryRun"
Write-Host "======================================================================"
Write-Host ""

# Check if running from correct directory
if (-not (Test-Path "ansible.cfg")) {
    Write-Host "ERROR: Please run this script from the kubernetes-ansible root directory" -ForegroundColor Red
    exit 1
}

$INVENTORY_PATH = "inventory/$Environment/hosts.ini"
$PLAYBOOK_PATH = "playbooks/site.yml"
$LOG_FILE = "deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Step 1: Prerequisites
Write-Host "[STEP 1] Checking prerequisites..." -ForegroundColor Cyan
Write-Host ""

if ((Get-Command ansible -ErrorAction SilentlyContinue) -eq $null) {
    Write-Host "ERROR: Ansible not found. Install with: pip install ansible" -ForegroundColor Red
    exit 1
}

if ((Get-Command ansible-playbook -ErrorAction SilentlyContinue) -eq $null) {
    Write-Host "ERROR: ansible-playbook not found." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $INVENTORY_PATH)) {
    Write-Host "ERROR: Inventory file not found: $INVENTORY_PATH" -ForegroundColor Red
    exit 1
}

$ANSIBLE_VERSION = ansible --version | Select-Object -First 1
Write-Host "✓ Ansible installed: $ANSIBLE_VERSION" -ForegroundColor Green
Write-Host "✓ Inventory file found: $INVENTORY_PATH" -ForegroundColor Green
Write-Host ""

# Step 2: SSH Connectivity Check
Write-Host "[STEP 2] Verifying SSH connectivity..." -ForegroundColor Cyan
Write-Host ""

try {
    $PING = ansible -i $INVENTORY_PATH k8s_all -m ping -q
    if ($PING -match "SUCCESS" -or $PING -match "pong") {
        Write-Host "✓ All hosts reachable" -ForegroundColor Green
    } else {
        Write-Host "⚠ Some hosts may not be reachable" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠ Could not verify connectivity: $_" -ForegroundColor Yellow
}

Write-Host ""

# Step 3: Dry-Run
if (-not $SkipDryRun) {
    Write-Host "[STEP 3] Running deployment in check mode (dry-run)..." -ForegroundColor Cyan
    Write-Host "This will preview all changes without applying them." -ForegroundColor Yellow
    Write-Host ""
    
    $DRYRUN_OUTPUT = ansible-playbook -i $INVENTORY_PATH $PLAYBOOK_PATH --check -v 2>&1 | Tee-Object -FilePath $LOG_FILE
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ Dry-run failed. Check the output above for errors." -ForegroundColor Red
        Write-Host "Logs saved to: $LOG_FILE" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host ""
    Write-Host "✓ Dry-run completed successfully" -ForegroundColor Green
    Write-Host ""
    
    $RESPONSE = Read-Host "Do you want to proceed with actual deployment? (yes/no)"
    if ($RESPONSE -ne "yes" -and $RESPONSE -ne "y") {
        Write-Host "Deployment cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Step 4: Actual Deployment (or skip if check-only)
Write-Host ""
if ($CheckOnly) {
    Write-Host "[STEP 4] Check-only mode enabled. Skipping actual deployment." -ForegroundColor Yellow
} else {
    Write-Host "[STEP 4] Running actual deployment..." -ForegroundColor Cyan
    Write-Host "⏳ This may take 20-30 minutes..." -ForegroundColor Yellow
    Write-Host ""
    
    $DEPLOY_OUTPUT = ansible-playbook -i $INVENTORY_PATH $PLAYBOOK_PATH -v 2>&1 | Tee-Object -FilePath $LOG_FILE -Append
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ Deployment failed. Check logs:" -ForegroundColor Red
        Write-Host "Get-Content $LOG_FILE -Tail 100" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "=============================================================="
Write-Host "  ✓ Kubernetes Cluster Deployment Process Complete!"
Write-Host "=============================================================="
Write-Host ""
Write-Host "Logs saved to: $LOG_FILE" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. SSH to master node:"
Write-Host "   ssh ubuntu@<master-ip>"
Write-Host ""
Write-Host "2. Check cluster status:"
Write-Host "   kubectl get nodes"
Write-Host ""
Write-Host "3. View all pods:"
Write-Host "   kubectl get pods -A"
Write-Host ""
Write-Host "4. Check Ingress Controller:"
Write-Host "   kubectl get pods -n ingress-nginx"
Write-Host ""
Write-Host "5. View metrics:"
Write-Host "   kubectl top nodes"
Write-Host ""
