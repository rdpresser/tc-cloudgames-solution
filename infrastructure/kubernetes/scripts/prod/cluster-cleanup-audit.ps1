<#
.SYNOPSIS
  Cluster Cleanup Audit - Analyze what can be safely deleted

.DESCRIPTION
  Scans the cluster and shows all non-system resources that can be cleaned up.
  Helps identify what needs to be deleted for a clean reset.

.EXAMPLE
  .\cluster-cleanup-audit.ps1
  # Shows all deletable resources
#>

[CmdletBinding()]
param()

$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
    Muted   = "Gray"
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Info
Write-Host "║     🔍 Cluster Cleanup Audit                              ║" -ForegroundColor $Colors.Info
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Info
Write-Host ""

$systemNamespaces = @("default", "kube-system", "kube-public", "kube-node-lease")
$systemPrefixes = @("system:", "kubeadm:", "azure:", "addon-")

# Section 1: Namespaces
Write-Host "📋 NAMESPACES TO DELETE:" -ForegroundColor $Colors.Warning
Write-Host ""

$allNs = kubectl get namespaces --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
$toDelete = @()
$toKeep = @()

foreach ($ns in $allNs) {
    if ($ns -in $systemNamespaces) {
        $toKeep += $ns
    } else {
        $toDelete += $ns
    }
}

if ($toDelete) {
    foreach ($ns in $toDelete) {
        $status = kubectl get namespace $ns --no-headers 2>$null | awk '{print $2}'
        Write-Host "  ✗ $ns ($status)" -ForegroundColor $Colors.Error
    }
} else {
    Write-Host "  ✓ No custom namespaces to delete" -ForegroundColor $Colors.Success
}

Write-Host ""
Write-Host "System namespaces (will keep):" -ForegroundColor $Colors.Muted
foreach ($ns in $toKeep) {
    Write-Host "  ✓ $ns" -ForegroundColor $Colors.Success
}
Write-Host ""

# Section 2: ClusterRoles
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor $Colors.Info
Write-Host "🔐 CLUSTERROLES TO DELETE:" -ForegroundColor $Colors.Warning
Write-Host ""

$clusterRoles = kubectl get clusterroles --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
$rolesToDelete = @()
$rolesToKeep = @()

foreach ($role in $clusterRoles) {
    $isSystem = $systemPrefixes | Where-Object { $role -like "$_*" }
    if ($isSystem) {
        $rolesToKeep += $role
    } else {
        $rolesToDelete += $role
    }
}

if ($rolesToDelete) {
    Write-Host "Deletable ClusterRoles ($($rolesToDelete.Count)):" -ForegroundColor $Colors.Error
    foreach ($role in $rolesToDelete | Sort-Object) {
        Write-Host "  ✗ $role" -ForegroundColor $Colors.Error
    }
} else {
    Write-Host "  ✓ No custom ClusterRoles to delete" -ForegroundColor $Colors.Success
}

Write-Host ""
Write-Host "System ClusterRoles (will keep): $($rolesToKeep.Count)" -ForegroundColor $Colors.Muted
Write-Host ""

# Section 3: ClusterRoleBindings
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor $Colors.Info
Write-Host "🔗 CLUSTERROLEBINDINGS TO DELETE:" -ForegroundColor $Colors.Warning
Write-Host ""

$clusterRoleBindings = kubectl get clusterrolebindings --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
$bindingsToDelete = @()
$bindingsToKeep = @()

foreach ($binding in $clusterRoleBindings) {
    $isSystem = $systemPrefixes | Where-Object { $binding -like "$_*" }
    if ($isSystem) {
        $bindingsToKeep += $binding
    } else {
        $bindingsToDelete += $binding
    }
}

if ($bindingsToDelete) {
    Write-Host "Deletable ClusterRoleBindings ($($bindingsToDelete.Count)):" -ForegroundColor $Colors.Error
    foreach ($binding in $bindingsToDelete | Sort-Object) {
        Write-Host "  ✗ $binding" -ForegroundColor $Colors.Error
    }
} else {
    Write-Host "  ✓ No custom ClusterRoleBindings to delete" -ForegroundColor $Colors.Success
}

Write-Host ""
Write-Host "System ClusterRoleBindings (will keep): $($bindingsToKeep.Count)" -ForegroundColor $Colors.Muted
Write-Host ""

# Section 4: ServiceAccounts
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor $Colors.Info
Write-Host "👤 SERVICEACCOUNTS TO DELETE:" -ForegroundColor $Colors.Warning
Write-Host ""

$saToDelete = @()
foreach ($ns in $allNs) {
    if ($ns -notin $systemNamespaces) {
        $sas = kubectl get serviceaccounts -n $ns --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
        foreach ($sa in $sas) {
            if ($sa -ne "default") {
                $saToDelete += "$ns/$sa"
            }
        }
    }
}

if ($saToDelete) {
    Write-Host "Deletable ServiceAccounts ($($saToDelete.Count)):" -ForegroundColor $Colors.Error
    foreach ($sa in $saToDelete | Sort-Object) {
        Write-Host "  ✗ $sa" -ForegroundColor $Colors.Error
    }
} else {
    Write-Host "  ✓ No custom ServiceAccounts to delete" -ForegroundColor $Colors.Success
}
Write-Host ""

# Section 5: Webhooks
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor $Colors.Info
Write-Host "🪝 WEBHOOKS TO DELETE:" -ForegroundColor $Colors.Warning
Write-Host ""

$vwhooks = kubectl get validatingwebhookconfigurations --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
$mwhooks = kubectl get mutatingwebhookconfigurations --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }

$webhooksToDelete = @()
foreach ($hook in $vwhooks) {
    if ($hook -notmatch "^(aks-|kubernetes-)") {
        $webhooksToDelete += "ValidatingWebhook: $hook"
    }
}
foreach ($hook in $mwhooks) {
    if ($hook -notmatch "^(aks-|kubernetes-)") {
        $webhooksToDelete += "MutatingWebhook: $hook"
    }
}

if ($webhooksToDelete) {
    Write-Host "Deletable Webhooks ($($webhooksToDelete.Count)):" -ForegroundColor $Colors.Error
    foreach ($hook in $webhooksToDelete | Sort-Object) {
        Write-Host "  ✗ $hook" -ForegroundColor $Colors.Error
    }
} else {
    Write-Host "  ✓ No custom Webhooks to delete" -ForegroundColor $Colors.Success
}
Write-Host ""

# Section 6: CRDs
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor $Colors.Info
Write-Host "📦 CRDS TO DELETE:" -ForegroundColor $Colors.Warning
Write-Host ""

$systemCrdPrefixes = @("apiextensions.k8s.io", "metrics.k8s.io", "admissionregistration.k8s.io")
$crds = kubectl get crds --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }

$crdsToDelete = @()
foreach ($crd in $crds) {
    $isSystem = $systemCrdPrefixes | Where-Object { $crd -like "*$_*" }
    if (-not $isSystem) {
        $crdsToDelete += $crd
    }
}

if ($crdsToDelete) {
    Write-Host "Deletable CRDs ($($crdsToDelete.Count)):" -ForegroundColor $Colors.Error
    foreach ($crd in $crdsToDelete | Sort-Object) {
        Write-Host "  ✗ $crd" -ForegroundColor $Colors.Error
    }
} else {
    Write-Host "  ✓ No custom CRDs to delete" -ForegroundColor $Colors.Success
}
Write-Host ""

# Section 7: Helm Releases
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor $Colors.Info
Write-Host "📦 HELM RELEASES:" -ForegroundColor $Colors.Warning
Write-Host ""

$releases = helm list --all-namespaces 2>$null | Select-Object -Skip 1
if ($releases) {
    Write-Host "Found Helm releases ($($releases | Measure-Object).Count):" -ForegroundColor $Colors.Error
    foreach ($release in $releases) {
        $parts = $release -split '\s+' | Where-Object { $_ }
        if ($parts.Count -ge 2) {
            Write-Host "  ✗ $($parts[0]) in $($parts[1])" -ForegroundColor $Colors.Error
        }
    }
} else {
    Write-Host "  ✓ No Helm releases found" -ForegroundColor $Colors.Success
}
Write-Host ""

# Summary
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor $Colors.Info
Write-Host "📊 CLEANUP SUMMARY:" -ForegroundColor $Colors.Info
Write-Host ""
Write-Host "  Namespaces to delete:          $($toDelete.Count)" -ForegroundColor $(if ($toDelete.Count -gt 0) { $Colors.Warning } else { $Colors.Success })
Write-Host "  ClusterRoles to delete:        $($rolesToDelete.Count)" -ForegroundColor $(if ($rolesToDelete.Count -gt 0) { $Colors.Warning } else { $Colors.Success })
Write-Host "  ClusterRoleBindings to delete: $($bindingsToDelete.Count)" -ForegroundColor $(if ($bindingsToDelete.Count -gt 0) { $Colors.Warning } else { $Colors.Success })
Write-Host "  ServiceAccounts to delete:     $($saToDelete.Count)" -ForegroundColor $(if ($saToDelete.Count -gt 0) { $Colors.Warning } else { $Colors.Success })
Write-Host "  Webhooks to delete:            $($webhooksToDelete.Count)" -ForegroundColor $(if ($webhooksToDelete.Count -gt 0) { $Colors.Warning } else { $Colors.Success })
Write-Host "  CRDs to delete:                $($crdsToDelete.Count)" -ForegroundColor $(if ($crdsToDelete.Count -gt 0) { $Colors.Warning } else { $Colors.Success })
Write-Host ""

if ($toDelete.Count -gt 0 -or $rolesToDelete.Count -gt 0 -or $crdsToDelete.Count -gt 0) {
    Write-Host "Next step:" -ForegroundColor $Colors.Info
    Write-Host "  .\aks-manager.ps1 reset-cluster" -ForegroundColor $Colors.Muted
    Write-Host ""
} else {
    Write-Host "✅ Cluster is clean!" -ForegroundColor $Colors.Success
    Write-Host ""
}
