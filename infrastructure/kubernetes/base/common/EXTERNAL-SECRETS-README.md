# 🔐 External Secrets Operator - Azure Key Vault Integration

This project uses [External Secrets Operator](https://external-secrets.io/) to synchronize secrets from Azure Key Vault with Kubernetes.

## 🎯 Execution Order

> **IMPORTANT**: Follow this order when setting up the local environment.

```
1. .\k3d-manager.ps1 create              # Create cluster (ArgoCD, KEDA, Prometheus)
       ↓
2. .\k3d-manager.ps1 external-secrets    # Install ESO + configure Azure Key Vault
       ↓
3. ArgoCD Application Bootstrap          # Deploy apps via ArgoCD (apps use synced secrets)
       ↓
4. .\k3d-manager.ps1 port-forward all    # Start port-forwards
```

### Automated Setup (Recommended)

```powershell
cd infrastructure/kubernetes/scripts

# Option 1: Interactive menu
.\k3d-manager.ps1
# Choose [1] Create cluster
# Choose [11] Configure External Secrets (Azure Key Vault)

# Option 2: Command line
.\k3d-manager.ps1 create
.\k3d-manager.ps1 external-secrets
```

## 📋 Prerequisites (Manual Setup)

### 1. Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true
```

### 2. Create Service Principal for Key Vault access

```bash
# Create Service Principal
az ad sp create-for-rbac --name "external-secrets-k8s" --skip-assignment

# Save the output:
# {
#   "appId": "<CLIENT_ID>",
#   "password": "<CLIENT_SECRET>",
#   "tenant": "<TENANT_ID>"
# }

# Grant read permissions to Key Vault
az keyvault set-policy --name <KEY_VAULT_NAME> \
  --spn <CLIENT_ID> \
  --secret-permissions get list
```

### 3. Create Secret with Azure credentials in the cluster

```bash
kubectl create namespace external-secrets

kubectl create secret generic azure-sp-credentials \
  -n external-secrets \
  --from-literal=clientId=<CLIENT_ID> \
  --from-literal=clientSecret=<CLIENT_SECRET>
```

## 🔐 Security Notes

| Data | Sensitive? | Can be in Git? | Explanation |
|------|------------|----------------|-------------|
| **tenantId** | ❌ No | ✅ Yes | Public Azure AD identifier |
| **clientId** | ⚠️ Semi-public | ✅ Yes | Like a "username", alone doesn't grant access |
| **clientSecret** | ✅ **YES!** | ❌ **NEVER** | This is the critical credential! |

The `clientSecret` is requested interactively by `setup-external-secrets.ps1` and is **never** saved to files or Git.

## 🏗️ Architecture

```
Azure Key Vault
      │
      ▼
┌─────────────────────┐
│ ClusterSecretStore  │  ← Connection configuration to Key Vault
│  (azure-keyvault)   │
└─────────────────────┘
      │
      ▼
┌─────────────────────┐
│  ExternalSecret     │  ← Defines which secrets to sync
│  (user-api-secrets) │
└─────────────────────┘
      │
      ▼
┌─────────────────────┐
│  Kubernetes Secret  │  ← Automatically created secret
│  (user-api-secrets) │
└─────────────────────┘
      │
      ▼
┌─────────────────────┐
│    Deployment       │  ← Pod consumes secret via envFrom
│    (user-api)       │
└─────────────────────┘
```

## 📁 File Structure

```
base/
├── common/
│   └── cluster-secret-store.yaml   # Azure Key Vault connection
├── user/
│   ├── external-secret.yaml        # Secrets for user-api
│   └── deployment.yaml             # Uses envFrom: secretRef
├── games/
│   ├── external-secret.yaml        # Secrets for games-api
│   └── deployment.yaml
└── payments/
    ├── external-secret.yaml        # Secrets for payments-api
    └── deployment.yaml
```

## 🔑 Secrets in Azure Key Vault

The following secrets must exist in Azure Key Vault:

### Database
- `db-host`
- `db-port`
- `db-name-users` / `db-name-games` / `db-name-payments`
- `db-admin-login`
- `db-password`
- `db-name-maintenance`
- `db-schema`
- `db-connection-timeout`

### Cache (Redis)
- `cache-host`
- `cache-port`
- `cache-password`
- `cache-secure`
- `cache-users-instance-name`

### Service Bus
- `servicebus-connection-string`
- `servicebus-namespace`
- `servicebus-auto-provision`
- `servicebus-max-delivery-count`
- `servicebus-enable-dead-lettering`
- `servicebus-auto-purge-on-startup`
- `servicebus-use-control-queues`
- `servicebus-users-topic-name`
- `servicebus-games-topic-name`
- `servicebus-payments-topic-name`

### Grafana / OpenTelemetry
- `grafana-logs-api-token`
- `grafana-otel-prometheus-api-token`
- `grafana-otel-users-resource-attributes`
- `grafana-otel-exporter-endpoint`
- `grafana-otel-exporter-protocol`
- `grafana-otel-auth-header`

## 🔄 Synchronization

- **Interval**: Secrets are synchronized every 1 hour (`refreshInterval: 1h`)
- **Automatic**: Any changes in Key Vault are reflected on the next refresh
- **Secure**: Secrets are never stored in Git

## 🛠️ Troubleshooting

```bash
# Check ExternalSecret status
kubectl get externalsecrets -n cloudgames-dev

# View sync details
kubectl describe externalsecret user-api-secrets -n cloudgames-dev

# Check if secret was created
kubectl get secrets -n cloudgames-dev

# View operator logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### Common Issues

#### "no matches for kind ClusterSecretStore in version external-secrets.io/v1beta1"

This error occurs when the YAML files use an outdated API version. The External Secrets Operator now uses `v1` instead of `v1beta1`.

**Solution**: Update all YAML files to use `apiVersion: external-secrets.io/v1`

```bash
# Check available API versions
kubectl api-resources | findstr external-secrets
```

#### CRDs not registered after Helm install

The CRDs may take a few seconds to register after Helm install completes.

**Solution**: Wait a few seconds and retry, or run the setup script again:
```powershell
.\k3d-manager.ps1 external-secrets
```

#### ClusterSecretStore shows "Invalid" status

Check if the Azure credentials are correct:
```bash
kubectl get clustersecretstores
kubectl describe clustersecretstore azure-keyvault
```

Verify the secret exists:
```bash
kubectl get secret azure-sp-credentials -n external-secrets
```
