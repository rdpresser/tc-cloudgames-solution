# 🎬 TC Cloud Games — Roteiro Técnico (Phase_04)

Apresentação de 15 minutos cobrindo Terraform, AKS/Kubernetes, k6, PostgreSQL, Redis, Marten (Event Sourcing), Wolverine (Outbox), GitOps e resultados de performance.

---

## 📋 Parte 1 — Roteiro em Bullet Points (15 min)
- **Abertura (1-2 min)**: Contexto acadêmico, objetivo da Phase_04, visão geral da arquitetura.
- **Arquitetura & Padrões (3-4 min)**: Hexagonal + DDD; Microservices (Users, Games, Payments); Event-Driven; CQRS + Event Sourcing.
- **Infra como Código (3-4 min)**: Terraform (15+ recursos Azure); AKS produção; Workload Identity + External Secrets; GitOps (ArgoCD bootstrap).
- **Mensageria & Integração (2-3 min)**: Wolverine + Outbox; Azure Service Bus tópicos; Integration Events; Saga de compra.
- **Performance & Otimização (2-3 min)**: k6 smoke/load/perf; 20k+ req com 0% falhas; otimização memória 700Mi → 512Mi; HPA/auto-scaling.
- **Encerramento (1 min)**: Conquistas, lições, próximos passos.

---

## 📖 Parte 2 — Roteiro Detalhado

### 🎯 1. Abertura (1-2 min)
- Slide: "TC Cloud Games - Phase_04: Production Kubernetes Deployment".
- Plataforma: distribuição digital de jogos (estilo Steam/Epic), arquitetura cloud-native.
- Números de impacto:
  - 3 microservices; 15+ recursos Azure via Terraform.
  - 20.651 requisições, 0% falhas (Games load), P95 194ms, 38 req/s.
  - Deploy automatizado via GitOps (ArgoCD); zero credenciais (Workload Identity + ESO).
- Stack visual: .NET 9 + FastEndpoints | PostgreSQL + Marten | Redis | Service Bus + Wolverine | AKS | Terraform | ArgoCD | k6.

### 🏗️ 2. Arquitetura & Padrões (3-4 min)
- Hexagonal (Ports & Adapters) com DDD tático.
- Estrutura por serviço: Core/Domain (Aggregates, Value Objects, Domain Events) + Application (Commands/Queries, Handlers) + Adapters (API FastEndpoints, Marten, Redis, Service Bus).
- CQRS + Event Sourcing (Users): Event Store em PostgreSQL/Marten; replay/time-travel; projeções para leitura.
- DDD: Aggregates (User, Game, Payment); Value Objects (Email, Price); Domain Events (UserRegistered, PaymentApproved).
- Visual: ![Arquitetura AKS](images/tc-cloudgames-aks-architecture.png)

### ☁️ 3. Infraestrutura como Código (3-4 min)
- Terraform módulos (infrastructure/terraform/modules/): aks_cluster, container_registry, postgres, redis, service_bus, key_vault, virtual_network, log_analytics, application_insights, external_secrets, nginx_ingress, argocd.
- AKS produção: autoscaling 2-6 nós (Standard_D2s_v3), Workload Identity, Log Analytics.
- Segurança: zero credenciais; External Secrets Operator + Key Vault; RBAC mínimo; TLS no Ingress.
- GitOps (ArgoCD bootstrap): app-of-apps instala WI webhook, ingress-nginx, ESO; aplica user/games/payments (Deployment + Service + Ingress + ExternalSecret + HPA + PDB).
- Fonte editável: docs/tc-cloudgames-aks-architecture.drawio (exportar para PNG se precisar).

### 📨 4. Mensageria & Integração (2-3 min)
- Wolverine + Outbox Pattern (Marten) para entrega transacional (at-least-once).
- Azure Service Bus: tópicos com filtros SQL; DLQ para retries.
- Saga compra de jogo:
  1) Games publica GamePurchaseRequestedIntegrationEvent
  2) Payments processa e publica PaymentApproved/Failed
  3) Games adiciona à biblioteca ou compensa
- Visuais: ![Message Broker Flow](images/message_broker_flow.png) · ![Microservices Communication](images/microservices-communication-flow.png) · ![Service Bus Topology](images/servicebus_queues.png)

### 📊 5. Performance & Otimização (2-3 min)
- k6 suites: Smoke (1 VU/30s), Load (25 VUs/9m ramp 10→25→0), Performance (50-100 VUs/15m).
- Resultados (Games load): 20.651 req, 0% falhas, P95 194ms, 38 req/s.
- Otimização: memória 700Mi → 512Mi (-27%); limits 1800Mi → 1400Mi; densidade +50%; HPA funcional (2-5 réplicas); custo reduzido.
- Exemplo comando (timestamped):
```powershell
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
k6 run k6/load/games-load.js --summary-export="k6/output/games-load_$ts.json"
```

### 🧠 6. Encerramento (1 min)
- Conquistas: AKS produção + GitOps; zero credenciais; ESO + KV; Outbox + Saga; CQRS + Event Sourcing; HA (2+ réplicas) + HPA + PDB; P95 194ms; custo otimizado (-27% req memória).
- Lições: decisões guiadas por métricas (k6, kubectl top); segurança desde o início (WI/ESO); confiança em deploys (ArgoCD rollback).
- Próximos passos: Network Policies, PSS, chaos engineering, multi-region, service mesh.

---

## 🖼️ Referências Visuais
- Arquitetura AKS: images/tc-cloudgames-aks-architecture.png
- Fluxo mensageria: images/message_broker_flow.png
- Comunicação microservices: images/microservices-communication-flow.png
- Topologia Service Bus: images/servicebus_queues.png
- Fonte editável: docs/tc-cloudgames-aks-architecture.drawio

---

## ⚙️ Comandos Úteis (demo rápida)
```powershell
# k6 smoke/load/perf
k6 run k6/smoke/users-smoke.js
k6 run k6/load/games-load.js --summary-export="k6/output/games-load_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

# Terraform (exemplo genérico)
cd infrastructure/terraform/foundation
terraform init
terraform plan

# ArgoCD (após kubeconfig)
argocd app list
argocd app sync cloudgames-prod
```

---

## 🎥 Dicas de Gravação (tempo sugerido)
- Abertura: 1:30
- Arquitetura & Padrões: 3:30
- Infra: 3:30
- Mensageria: 2:30
- Performance: 3:00
- Encerramento: 1:00
- Total: ~15 minutos

Use as imagens em docs/images e o draw.io para apoiar os trechos visuais. Ajuste o tempo conforme necessidade e destaque números concretos (20k req, 0% falhas, P95 194ms, -27% memória).
