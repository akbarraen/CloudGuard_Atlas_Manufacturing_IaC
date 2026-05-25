# ManufacturingCorp – Azure Environment Deep Dive
## CloudGuard Atlas Reference Architecture

---

# 1. Executive Summary

## Company Profile

| Attribute | Details |
|-----------|---------|
| **Company** | ManufacturingCorp |
| **Industry** | Manufacturing (Industrial / Discrete) |
| **Headcount** | ~8,000 employees globally |
| **Cloud Strategy** | Hybrid; ~40% workloads in Azure |
| **Primary Region** | West Europe (`westeurope`) |
| **Cloud Maturity** | Mid-to-high; IaC-managed, multi-subscription |

## Why Azure?

ManufacturingCorp chose Azure because:
- Deep integration with Microsoft 365, Active Directory, and Windows Server estate
- Azure Virtual WAN simplifies branch + cloud connectivity for factory sites
- Azure Sentinel provides unified SIEM across hybrid workloads
- Strong IaC (Terraform) and DevOps (Azure DevOps) ecosystem

## Cloud Footprint (Azure)

| Resource Type | Count |
|--------------|-------|
| Subscriptions | 6 |
| Virtual Networks | 7 (1 shared + 5 spoke + 1 vWAN hub) |
| Subnets | 27 |
| VMs | ~503 |
| Web Apps | 40 |
| Function Apps | 20 |
| NSGs | 12+ |
| Route Tables | 12+ |
| Azure Firewall | 1 (hub-secured) |
| vWAN Hub | 1 |
| Sentinel | 1 workspace |

---

# 2. Subscription Strategy

ManufacturingCorp uses a **dedicated subscription per workload type** model, which is a well-established Azure landing zone pattern.

## Subscription Layout

| Subscription | ID (dummy) | Purpose | Owner | Billing Model |
|-------------|-----------|---------|-------|---------------|
| `sub-hub-network` | `00000000-aaaa-bbbb-cccc-111111111111` | Shared networking: vWAN, Firewall, DNS, AD, Jumpbox, Monitoring | Platform/Network Team | Shared/Platform |
| `sub-prod` | `00000000-aaaa-bbbb-cccc-222222222222` | Production workloads | App Ops Team | Production |
| `sub-dev` | `00000000-aaaa-bbbb-cccc-333333333333` | Development workloads | Dev Team | Development |
| `sub-test` | `00000000-aaaa-bbbb-cccc-444444444444` | Test / QA workloads | QA Team | Non-Production |
| `sub-frontend` | `00000000-aaaa-bbbb-cccc-555555555555` | Customer-facing web tier | Web Team | Production |
| `sub-backend` | `00000000-aaaa-bbbb-cccc-666666666666` | Internal APIs, middleware, databases, batch | Backend Team | Production |

### Why separate subscriptions?

1. **Billing isolation**: each team/environment has its own cost boundary
2. **RBAC isolation**: dev team cannot accidentally modify production resources
3. **Policy isolation**: stricter Azure Policies on prod/frontend; relaxed on dev
4. **Quota management**: each subscription has its own vCPU/resource quotas
5. **Blast radius containment**: a misconfiguration in dev does not affect prod networking

### Governance Model

- **Management Group**: `mg-mfgcorp` (root)
  - `mg-platform` → `sub-hub-network`
  - `mg-production` → `sub-prod`, `sub-frontend`, `sub-backend`
  - `mg-nonproduction` → `sub-dev`, `sub-test`
- **Azure Policy**: enforced at management group level
  - Allowed locations: `westeurope` only
  - Required tags: `company`, `env`, `managed_by`
  - Deny public IP on VMs (production)
  - Require NSG on every subnet

---

# 3. Network Architecture

## 3.1 Hub-and-Spoke via Azure Virtual WAN

ManufacturingCorp uses **Azure Virtual WAN (vWAN)** instead of a traditional hub-spoke with VNet peering.

### Why vWAN?

| Feature | Traditional Hub-Spoke | Azure vWAN |
|---------|----------------------|-----------|
| Routing | Manual UDR management | Automatic route propagation |
| Scalability | Limited by peering count | Scales to 500+ connections |
| Branch connectivity | Requires separate VPN GW | Built-in VPN/ExpressRoute |
| Firewall integration | Manual | Native "Secured Virtual Hub" |
| Transitive routing | Requires NVA/Firewall | Automatic |
| Management overhead | High | Low |

### vWAN Hub

| Property | Value |
|----------|-------|
| Name | `hub-mfgcorp-weu` |
| Resource Group | `rg-hub-network-weu` |
| Location | `westeurope` |
| Address Prefix | `10.0.0.0/23` |
| Type | Secured Virtual Hub |
| Firewall | `afw-mfgcorp-weu` (integrated) |

## 3.2 IP Addressing Scheme

| Network | CIDR | Purpose |
|---------|------|---------|
| vWAN Hub | `10.0.0.0/23` | Hub routing fabric |
| Shared Services | `10.10.0.0/16` | AD, DNS, Jumpbox, Monitoring, Management |
| Production | `10.20.0.0/16` | Prod app, data, web, func, middleware |
| Development | `10.30.0.0/16` | Dev app, data, web, func |
| Test | `10.40.0.0/16` | Test app, data, web, func |
| Frontend | `10.50.0.0/16` | Customer-facing web, app, func, CDN/cache |
| Backend | `10.60.0.0/16` | Internal APIs, DB, middleware, batch, func |

### Design Principles

- Each subscription gets a `/16` (65,536 addresses) — plenty of room for growth
- Subnets are `/24` (254 usable addresses) — standard for most workloads
- No overlapping CIDRs across any VNets
- All spokes connect to vWAN hub for transitive routing

## 3.3 Shared Services VNet (Hub Subscription)

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `snet-ad-dns` | `10.10.1.0/24` | Active Directory Domain Controllers + DNS |
| `snet-jumpbox` | `10.10.2.0/24` | Jumpbox / Bastion for remote management |
| `snet-monitoring` | `10.10.3.0/24` | Log Analytics agents, monitoring infrastructure |
| `snet-mgmt` | `10.10.4.0/24` | Management tools, SCCM, WSUS, patching |

### Why "Shared Services" is in the Hub subscription

- AD/DNS must be reachable from ALL spokes
- Jumpbox needs management access to ALL workloads
- Monitoring must collect telemetry from ALL environments
- Placing them in hub ensures shortest network path and centralized security

## 3.4 Spoke VNets (per environment)

### Production Spoke (`10.20.0.0/16`)

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `snet-app` | `10.20.1.0/24` | Application servers (Windows) |
| `snet-data` | `10.20.2.0/24` | Database servers (SQL Server) |
| `snet-web` | `10.20.3.0/24` | Web servers + Web App VNet integration |
| `snet-func` | `10.20.4.0/24` | Function App VNet integration |
| `snet-middleware` | `10.20.5.0/24` | Middleware / message brokers |

### Development Spoke (`10.30.0.0/16`)

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `snet-app` | `10.30.1.0/24` | Dev application servers |
| `snet-data` | `10.30.2.0/24` | Dev database servers |
| `snet-web` | `10.30.3.0/24` | Dev web servers + Web App VNet integration |
| `snet-func` | `10.30.4.0/24` | Dev Function App VNet integration |

### Test Spoke (`10.40.0.0/16`)

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `snet-app` | `10.40.1.0/24` | Test application servers |
| `snet-data` | `10.40.2.0/24` | Test database servers |
| `snet-web` | `10.40.3.0/24` | Test web servers + Web App VNet integration |
| `snet-func` | `10.40.4.0/24` | Test Function App VNet integration |

### Frontend Spoke (`10.50.0.0/16`)

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `snet-app` | `10.50.1.0/24` | Frontend application logic |
| `snet-data` | `10.50.2.0/24` | Frontend data cache / session state |
| `snet-web` | `10.50.3.0/24` | Customer-facing web servers + Web App VNet integration |
| `snet-func` | `10.50.4.0/24` | Frontend Function App VNet integration |
| `snet-cdn` | `10.50.5.0/24` | CDN origin / cache servers |

### Backend Spoke (`10.60.0.0/16`)

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `snet-app` | `10.60.1.0/24` | Backend API servers |
| `snet-data` | `10.60.2.0/24` | Backend database servers (SQL + MySQL) |
| `snet-middleware` | `10.60.3.0/24` | Message brokers, ESB, integration middleware |
| `snet-batch` | `10.60.4.0/24` | Batch processing / ETL workloads |
| `snet-func` | `10.60.5.0/24` | Backend Function App VNet integration |
| `snet-web` | `10.60.6.0/24` | Internal web portals (not customer-facing) |

---

# 4. Security Architecture

## 4.1 Azure Firewall

| Property | Value |
|----------|-------|
| Name | `afw-mfgcorp-weu` |
| SKU | AZFW_Hub (Standard) |
| Deployment | Secured Virtual Hub |
| Private IP | `10.0.0.68` (assigned by vWAN) |
| Policy | `afw-mfgcorp-weu-policy` |

### Why Azure Firewall in Secured Hub?

- All inter-spoke traffic is **forced through the firewall** via vWAN routing
- All internet-bound traffic is **inspected and filtered**
- Centralized logging and threat intelligence
- Single policy management point

## 4.2 Firewall Rule Collections

### Collection 1: `AllowEgress` (Priority 300, Action: Allow)

| Rule | Protocol | Source | Destination | Ports | Purpose |
|------|----------|--------|-------------|-------|---------|
| HTTPS | TCP | `10.0.0.0/8` | `*` | 443 | Allow outbound HTTPS (updates, APIs, telemetry) |
| HTTP | TCP | `10.0.0.0/8` | `*` | 80 | Allow outbound HTTP (package repos, CRL) |
| DNS | UDP | `10.0.0.0/8` | `*` | 53 | Allow outbound DNS resolution |

### Collection 2: `SpokeToSpoke` (Priority 400, Action: Allow)

| Rule | Protocol | Source | Destination | Ports | Purpose |
|------|----------|--------|-------------|-------|---------|
| FE-BE-SQL | TCP | `10.50.0.0/16` (Frontend) | `10.60.0.0/16` (Backend) | 1433 | Frontend apps query backend SQL |
| FE-BE-HTTPS | TCP | `10.50.0.0/16` (Frontend) | `10.60.0.0/16` (Backend) | 443 | Frontend calls backend APIs |
| BE-DB | TCP | `10.60.0.0/16` (Backend) | `10.60.2.0/24` (Backend data) | 1433, 3306 | Backend services access databases |
| AD-DNS | TCP+UDP | `10.0.0.0/8` (All) | `10.10.1.0/24` (AD/DNS) | 53, 88, 389, 445, 636, 3268 | All workloads authenticate and resolve DNS via AD |

#### AD/DNS Ports Explained

| Port | Protocol | Service | Why Needed |
|------|----------|---------|-----------|
| 53 | TCP+UDP | DNS | Name resolution for all internal and external hostnames |
| 88 | TCP+UDP | Kerberos | Windows domain authentication (login, service tickets) |
| 389 | TCP+UDP | LDAP | Directory queries (user/group lookups, GPO) |
| 445 | TCP | SMB | Sysvol/Netlogon share access, GPO download |
| 636 | TCP | LDAPS | Encrypted LDAP (secure directory queries) |
| 3268 | TCP | Global Catalog | Cross-domain queries in multi-domain forests |

**Impact if AD/DNS ports are blocked:**
- Users cannot log in to Windows machines
- DNS resolution fails (internal and conditional forwarder)
- Group Policy stops applying
- Service accounts cannot authenticate
- SSO/Kerberos delegation breaks for web apps
- Domain join fails for new VMs

### Collection 3: `DenyAll` (Priority 4000, Action: Deny)

| Rule | Protocol | Source | Destination | Ports | Purpose |
|------|----------|--------|-------------|-------|---------|
| DenyAllTraffic | Any | `*` | `*` | `*` | Default deny — blocks everything not explicitly allowed |

**This is the safety net.** Any traffic not matched by higher-priority allow rules is dropped and logged.

## 4.3 NSG Strategy

### Philosophy: "Default Deny + Explicit Allow"

Every subnet has an NSG with:
1. Specific allow rules for known traffic patterns
2. A final `DenyAllInbound` rule at priority 4096
3. Outbound rules are generally permissive (firewall handles filtering)

### NSG: AD/DNS Subnet (`nsg-ad-dns-weu`)

| Rule | Priority | Direction | Access | Protocol | Source | Dest Port | Purpose |
|------|----------|-----------|--------|----------|--------|-----------|---------|
| DNS | 100 | Inbound | Allow | UDP | `10.0.0.0/8` | 53 | DNS queries from all workloads |
| Kerberos | 110 | Inbound | Allow | TCP | `10.0.0.0/8` | 88 | Kerberos authentication |
| LDAP | 120 | Inbound | Allow | TCP | `10.0.0.0/8` | 389 | Directory queries |
| LDAPS | 130 | Inbound | Allow | TCP | `10.0.0.0/8` | 636 | Encrypted directory queries |
| SMB | 140 | Inbound | Allow | TCP | `10.0.0.0/8` | 445 | Sysvol/Netlogon |
| GlobalCatalog | 150 | Inbound | Allow | TCP | `10.0.0.0/8` | 3268 | Cross-domain queries |
| RDP | 200 | Inbound | Allow | TCP | `10.10.2.0/24` (jumpbox) | 3389 | RDP from jumpbox only |
| DenyAllInbound | 4096 | Inbound | Deny | * | * | * | Block everything else |

**What happens if each rule is removed:**
- Remove DNS (100) → All name resolution fails across entire environment
- Remove Kerberos (110) → All Windows authentication fails
- Remove LDAP (120) → Directory queries fail, apps cannot look up users/groups
- Remove RDP (200) → Cannot manage domain controllers remotely
- Remove DenyAll (4096) → Subnet becomes open to all inbound traffic (security risk)

### NSG: Jumpbox Subnet (`nsg-jumpbox-weu`)

| Rule | Priority | Direction | Access | Protocol | Source | Dest Port | Purpose |
|------|----------|-----------|--------|----------|--------|-----------|---------|
| RDP | 100 | Inbound | Allow | TCP | `10.10.4.0/24` (mgmt) | 3389 | RDP from management subnet only |
| SSH | 110 | Inbound | Allow | TCP | `10.10.4.0/24` (mgmt) | 22 | SSH from management subnet only |
| DenyAllInbound | 4096 | Inbound | Deny | * | * | * | Block everything else |

### NSG: Spoke App Subnet (per environment, e.g., `nsg-prod-app-weu`)

| Rule | Priority | Direction | Access | Protocol | Source | Dest Port | Purpose |
|------|----------|-----------|--------|----------|--------|-----------|---------|
| AllowHTTPS | 100 | Inbound | Allow | TCP | `*` | 443 | HTTPS ingress for web/app traffic |
| AllowHTTP | 110 | Inbound | Allow | TCP | `*` | 80 | HTTP ingress (redirect to HTTPS) |
| AllowRDPJump | 200 | Inbound | Allow | TCP | `10.10.2.0/24` | 3389 | RDP from jumpbox only |
| AllowSSHJump | 210 | Inbound | Allow | TCP | `10.10.2.0/24` | 22 | SSH from jumpbox only |
| DenyAllInbound | 4096 | Inbound | Deny | * | * | * | Block everything else |

**What happens if AllowHTTPS (100) is removed:**
- Web/app servers stop receiving HTTPS traffic
- Customer-facing applications become unreachable
- Health probes from load balancers may fail
- Web Apps with VNet integration lose connectivity

### NSG: Spoke Data Subnet (per environment, e.g., `nsg-prod-data-weu`)

| Rule | Priority | Direction | Access | Protocol | Source | Dest Port | Purpose |
|------|----------|-----------|--------|----------|--------|-----------|---------|
| AllowSQLFromApp | 100 | Inbound | Allow | TCP | VNet CIDR | 1433 | SQL Server access from app subnet |
| AllowRDPJump | 200 | Inbound | Allow | TCP | `10.10.2.0/24` | 3389 | RDP from jumpbox only |
| DenyAllInbound | 4096 | Inbound | Deny | * | * | * | Block everything else |

**What happens if AllowSQLFromApp (100) is removed:**
- App servers cannot connect to SQL databases
- All database-dependent applications fail
- Transaction processing stops

---

# 5. Routing Architecture

## 5.1 UDR Strategy

**Every spoke subnet has a User-Defined Route (UDR)** that forces the default route through Azure Firewall.

### Route Table: `rt-{env}-app-weu` / `rt-{env}-data-weu`

| Route Name | Address Prefix | Next Hop Type | Next Hop IP |
|-----------|---------------|---------------|-------------|
| `default-to-fw` | `0.0.0.0/0` | VirtualAppliance | `10.0.0.68` |

### Route Table: `rt-shared-weu` (shared services)

| Route Name | Address Prefix | Next Hop Type | Next Hop IP |
|-----------|---------------|---------------|-------------|
| `default-to-fw` | `0.0.0.0/0` | VirtualAppliance | `10.0.0.68` |

Applied to: `snet-ad-dns`, `snet-jumpbox`, `snet-monitoring`, `snet-mgmt`

### Why force traffic through the firewall?

1. **Inspection**: all inter-spoke and internet traffic is logged and inspected
2. **Policy enforcement**: firewall rules determine what is allowed
3. **Threat intelligence**: Azure Firewall can block known malicious IPs
4. **Compliance**: regulatory requirements often mandate traffic inspection

### What happens if the default route is changed?

| Scenario | Impact |
|---------|--------|
| Route removed entirely | Traffic takes system default route (direct to internet), bypasses firewall |
| Changed to wrong IP | Traffic blackholes (packets sent to non-existent appliance) |
| Changed to different NVA | May work if NVA is healthy; may break if SNAT/return path missing |
| Prefix changed from `0.0.0.0/0` to specific | Only that prefix is affected; other traffic still goes to firewall |

---

# 6. Identity & Directory Services

## 6.1 Active Directory / DNS Design

| Property | Value |
|----------|-------|
| Subnet | `snet-ad-dns` (`10.10.1.0/24`) |
| Domain Controllers | `vm-dc01`, `vm-dc02` |
| VM Size | `Standard_D4s_v5` (4 vCPU, 16 GB RAM) |
| OS | Windows Server 2022 Datacenter |
| Role | Domain Controller + DNS Server |
| Tags | `role=DomainController`, `tier=identity` |

### Why two DCs?

- **Redundancy**: if one DC fails, the other continues serving authentication
- **Load balancing**: DNS queries and Kerberos can be distributed
- **Maintenance**: one can be patched while the other serves traffic

## 6.2 Dependency Chain

```
All Windows VMs (503 total)
    └── depend on → vm-dc01 / vm-dc02
         └── for → DNS resolution (port 53)
         └── for → Kerberos authentication (port 88)
         └── for → LDAP/LDAPS queries (ports 389, 636)
         └── for → Group Policy (port 445)
         └── for → Global Catalog (port 3268)
```

## 6.3 Impact Analysis: AD/DNS Subnet Connectivity Lost

If `snet-ad-dns` loses connectivity (NSG block, route failure, firewall rule removal):

| Impact | Severity | Scope |
|--------|----------|-------|
| DNS resolution fails | CRITICAL | ALL environments, ALL subnets |
| Windows login fails | CRITICAL | ALL Windows VMs (~400+) |
| Kerberos ticket renewal fails | CRITICAL for any Kerberos-dependent app |
| Group Policy stops applying | HIGH | All domain-joined machines |
| Domain join for new VMs fails | HIGH | New deployments blocked |
| SSO/delegation breaks | HIGH | Web apps using Windows auth |
| GPO-managed configurations drift | MEDIUM | Over time, security settings may weaken |

**Blast radius: ENTIRE ENVIRONMENT** — this is the single highest-risk dependency.

---

# 7. Compute Workloads (Detailed)

## 7.1 Production Subscription (`sub-prod`)

### VMs (150 total)

| Prefix | Subnet | Count | OS | Size | Role | Tier |
|--------|--------|-------|------|------|------|------|
| `vm-prod-app-001` to `vm-prod-app-060` | snet-app | 60 | Windows | Standard_D4s_v5 | AppServer | app |
| `vm-prod-db-001` to `vm-prod-db-030` | snet-data | 30 | Windows | Standard_E8s_v5 | Database | data |
| `vm-prod-mw-001` to `vm-prod-mw-030` | snet-middleware | 30 | Linux | Standard_D4s_v5 | Middleware | middleware |
| `vm-prod-web-001` to `vm-prod-web-030` | snet-web | 30 | Linux | Standard_D2s_v5 | WebServer | web |

### Web Apps (15)

| Name | Subnet | Tier |
|------|--------|------|
| `webapp-prod-01` to `webapp-prod-15` | snet-web (VNet integration) | web |

### Function Apps (8)

| Name | Subnet | Tier |
|------|--------|------|
| `func-prod-01` to `func-prod-08` | snet-func (VNet integration) | compute |

## 7.2 Development Subscription (`sub-dev`)

### VMs (80 total)

| Prefix | Subnet | Count | OS | Size | Role | Tier |
|--------|--------|-------|------|------|------|------|
| `vm-dev-app-001` to `vm-dev-app-040` | snet-app | 40 | Windows | Standard_D2s_v5 | AppServer | app |
| `vm-dev-db-001` to `vm-dev-db-020` | snet-data | 20 | Windows | Standard_D4s_v5 | Database | data |
| `vm-dev-web-001` to `vm-dev-web-020` | snet-web | 20 | Linux | Standard_D2s_v5 | WebServer | web |

### Web Apps (10)

| Name | Subnet | Tier |
|------|--------|------|
| `webapp-dev-01` to `webapp-dev-10` | snet-web | web |

### Function Apps (5)

| Name | Subnet | Tier |
|------|--------|------|
| `func-dev-01` to `func-dev-05` | snet-func | compute |

## 7.3 Test Subscription (`sub-test`)

### VMs (50 total)

| Prefix | Subnet | Count | OS | Size | Role | Tier |
|--------|--------|-------|------|------|------|------|
| `vm-test-app-001` to `vm-test-app-025` | snet-app | 25 | Windows | Standard_D2s_v5 | AppServer | app |
| `vm-test-db-001` to `vm-test-db-015` | snet-data | 15 | Windows | Standard_D4s_v5 | Database | data |
| `vm-test-web-001` to `vm-test-web-010` | snet-web | 10 | Linux | Standard_D2s_v5 | WebServer | web |

### Web Apps (5)

| Name | Subnet | Tier |
|------|--------|------|
| `webapp-test-01` to `webapp-test-05` | snet-web | web |

### Function Apps (3)

| Name | Subnet | Tier |
|------|--------|------|
| `func-test-01` to `func-test-03` | snet-func | compute |

## 7.4 Frontend Subscription (`sub-frontend`)

### VMs (80 total)

| Prefix | Subnet | Count | OS | Size | Role | Tier |
|--------|--------|-------|------|------|------|------|
| `vm-fe-web-001` to `vm-fe-web-040` | snet-web | 40 | Linux | Standard_D2s_v5 | WebFrontend | web |
| `vm-fe-app-001` to `vm-fe-app-030` | snet-app | 30 | Linux | Standard_D4s_v5 | AppFrontend | app |
| `vm-fe-cache-001` to `vm-fe-cache-010` | snet-cdn | 10 | Linux | Standard_D2s_v5 | Cache | cache |

### Web Apps (10)

| Name | Subnet | Tier |
|------|--------|------|
| `webapp-fe-01` to `webapp-fe-10` | snet-web | web |

### Function Apps (4)

| Name | Subnet | Tier |
|------|--------|------|
| `func-fe-01` to `func-fe-04` | snet-func | compute |

## 7.5 Backend Subscription (`sub-backend`)

### VMs (140 total)

| Prefix | Subnet | Count | OS | Size | Role | Tier |
|--------|--------|-------|------|------|------|------|
| `vm-be-api-001` to `vm-be-api-040` | snet-app | 40 | Linux | Standard_D4s_v5 | APIServer | api |
| `vm-be-db-001` to `vm-be-db-030` | snet-data | 30 | Windows | Standard_E8s_v5 | Database | data |
| `vm-be-mw-001` to `vm-be-mw-040` | snet-middleware | 40 | Linux | Standard_D4s_v5 | Middleware | middleware |
| `vm-be-batch-001` to `vm-be-batch-030` | snet-batch | 30 | Linux | Standard_D8s_v5 | BatchProcessor | batch |

### Web Apps: 0 (backend has no public-facing web apps)
### Function Apps: 0

## 7.6 Hub Subscription (Shared Services)

### VMs (3 total)

| Name | Subnet | OS | Size | Role | Tier |
|------|--------|------|------|------|------|
| `vm-dc01` | snet-ad-dns | Windows | Standard_D4s_v5 | DomainController | identity |
| `vm-dc02` | snet-ad-dns | Windows | Standard_D4s_v5 | DomainController | identity |
| `vm-jump01` | snet-jumpbox | Windows | Standard_D2s_v5 | Jumpbox | management |

## 7.7 VM Naming Convention

```
vm-{env}-{role}-{sequence}
```

Examples:
- `vm-prod-app-001` → Production Application Server #1
- `vm-be-db-015` → Backend Database Server #15
- `vm-fe-cache-003` → Frontend Cache Server #3

## 7.8 Tagging Strategy

Every resource has:

| Tag | Purpose |
|-----|---------|
| `company` | `ManufacturingCorp` |
| `env` | `prod`, `dev`, `test`, `frontend`, `backend`, `hub` |
| `managed_by` | `Terraform` |
| `role` | `AppServer`, `Database`, `WebServer`, `Middleware`, `DomainController`, etc. |
| `tier` | `app`, `data`, `web`, `middleware`, `batch`, `identity`, `management`, `cache` |

---

# 8. Application Architecture

## 8.1 Three-Tier Pattern

```
Internet
    ↓
[Azure Firewall / AppGW / LB] (implied, not in IaC)
    ↓
Frontend Spoke (10.50.0.0/16)
  ├── snet-web: Web VMs + Web Apps (customer-facing)
  ├── snet-app: Frontend application logic
  ├── snet-func: Serverless event handlers
  └── snet-cdn: Cache / CDN origin
    ↓ (via Azure Firewall — FE-BE-HTTPS / FE-BE-SQL)
Backend Spoke (10.60.0.0/16)
  ├── snet-app: API servers
  ├── snet-middleware: Message brokers, ESB
  ├── snet-data: SQL Server, MySQL databases
  └── snet-batch: ETL / batch processing
    ↓
Shared Services (10.10.0.0/16)
  ├── snet-ad-dns: Authentication + DNS
  ├── snet-jumpbox: Remote management
  └── snet-monitoring: Telemetry collection
```

## 8.2 Web Apps with VNet Integration

All 40 Web Apps use **VNet Integration** to reach backend services through the private network rather than going over the internet.

- Production Web Apps → integrated into `snet-web` (10.20.3.0/24)
- Frontend Web Apps → integrated into `snet-web` (10.50.3.0/24)
- Dev/Test Web Apps → integrated into respective `snet-web` subnets

**Why VNet Integration matters:**
- Outbound traffic from Web Apps goes through the VNet (and therefore through the firewall)
- Web Apps can access private endpoints and internal services
- Security policies (NSG + firewall) apply to Web App traffic

## 8.3 Function Apps with VNet Integration

All 20 Function Apps use VNet Integration for the same reasons.

- Production Functions → integrated into `snet-func` (10.20.4.0/24)
- Frontend Functions → integrated into `snet-func` (10.50.4.0/24)

**Impact if VNet integration subnet route changes:**
- Function Apps lose access to backend services
- Event-driven processing stops
- Timeouts on dependent API calls

## 8.4 Middleware Layer

- 30 middleware VMs in Production (`snet-middleware`)
- 40 middleware VMs in Backend (`snet-middleware`)
- Role: message brokers, ESB, integration services
- Connects frontend to backend and backend to database

## 8.5 Batch Processing Layer

- 30 batch VMs in Backend (`snet-batch`)
- Role: ETL, data transformation, scheduled jobs
- Size: `Standard_D8s_v5` (8 vCPU, 32 GB) — larger for compute-intensive work

## 8.6 Cache Layer

- 10 cache VMs in Frontend (`snet-cdn`)
- Role: in-memory caching (Redis-like), CDN origin
- Reduces load on backend by caching frequently accessed data

---

# 9. Monitoring & Security Operations

## 9.1 Log Analytics Workspace

| Property | Value |
|----------|-------|
| Name | `law-mfgcorp-weu` |
| SKU | PerGB2018 |
| Retention | 90 days |
| Location | westeurope |

## 9.2 Microsoft Sentinel

- Onboarded on top of the Log Analytics workspace
- Provides: threat detection, investigation, automated response
- Ingests: Azure Activity Logs, NSG flow logs, firewall logs, VM security events

## 9.3 Monitoring Subnet

- `snet-monitoring` (`10.10.3.0/24`) in shared services
- Hosts monitoring infrastructure (agents, collectors)
- Depends on outbound connectivity (via firewall) to reach:
  - Log Analytics ingestion endpoints
  - Azure Monitor endpoints
  - Defender for Cloud endpoints

**Impact if monitoring egress breaks:**
- Telemetry stops flowing
- Sentinel alerts stop generating
- Security visibility is lost
- Compliance logging gaps occur

---

# 10. Traffic Flow Patterns

## 10.1 Internet → Frontend → Backend → Database

```
Internet
  → Azure Firewall (AllowEgress HTTPS)
    → Frontend Spoke: snet-web (10.50.3.0/24)
      → vm-fe-web-* / webapp-fe-*
        → Azure Firewall (FE-BE-HTTPS)
          → Backend Spoke: snet-app (10.60.1.0/24)
            → vm-be-api-*
              → Backend Spoke: snet-data (10.60.2.0/24)
                → vm-be-db-*
```

## 10.2 All Spokes → AD/DNS

```
Any VM in any spoke
  → Azure Firewall (AD-DNS rule)
    → Shared Services: snet-ad-dns (10.10.1.0/24)
      → vm-dc01 / vm-dc02
```

## 10.3 Management (Jumpbox → Any VM)

```
Admin
  → VPN/Bastion → snet-mgmt (10.10.4.0/24)
    → snet-jumpbox (10.10.2.0/24): vm-jump01
      → RDP/SSH to any VM (via NSG AllowRDP/SSHFromJump rules)
```

## 10.4 Monitoring Egress

```
Any VM (monitoring agent)
  → Azure Firewall (AllowEgress HTTPS 443)
    → Log Analytics ingestion endpoint
      → Sentinel workspace
```

## 10.5 Function App Outbound

```
func-prod-* (in snet-func 10.20.4.0/24)
  → VNet Integration
    → Azure Firewall (AllowEgress / SpokeToSpoke)
      → Backend API or external service
```

---

# 11. Dependency Map (Critical Paths)

## 11.1 Application Dependency Chain

```
Customer Request
  └── Frontend Web Apps / VMs
        └── depends on: snet-web NSG allows 443
        └── depends on: route to firewall (default-to-fw)
        └── calls: Backend APIs (via FE-BE-HTTPS firewall rule)
              └── depends on: Backend snet-app NSG allows 443
              └── depends on: route to firewall
              └── calls: Database (via BE-DB firewall rule)
                    └── depends on: snet-data NSG allows 1433
                    └── depends on: route to firewall
```

## 11.2 Identity Dependency Chain

```
ALL Windows VMs (~400+)
  └── depend on: AD/DNS subnet connectivity
        └── requires: firewall rule AD-DNS (ports 53/88/389/445/636/3268)
        └── requires: NSG nsg-ad-dns allows inbound from 10.0.0.0/8
        └── requires: route table rt-shared routes to firewall
        └── requires: vm-dc01 and/or vm-dc02 are healthy
```

## 11.3 Monitoring Dependency Chain

```
Security Operations / Sentinel
  └── depends on: Log Analytics Workspace ingest
        └── depends on: monitoring agents on VMs
              └── depends on: outbound HTTPS (443) to Azure Monitor endpoints
                    └── depends on: firewall AllowEgress rule
                    └── depends on: route table default-to-fw
```

## 11.4 Management Dependency Chain

```
Operations Team
  └── depends on: vm-jump01 in snet-jumpbox
        └── requires: NSG allows RDP/SSH from snet-mgmt
        └── requires: route to target VMs via firewall
        └── requires: target VM NSG allows RDP/SSH from jumpbox (10.10.2.0/24)
```

---

# 12. Risk Scenarios (CloudGuard Atlas Detection Target)

## Scenario 1: Remove Inbound HTTPS (443) from Frontend App Subnet

**Change:** Remove `AllowHTTPS` rule (priority 100) from `nsg-frontend-app-weu`

**What breaks:**
- All frontend web/app VMs stop receiving HTTPS traffic
- Web Apps with VNet integration cannot receive inbound calls
- Customer-facing applications become unreachable

**Blast radius:**
- 40 frontend web VMs
- 30 frontend app VMs
- 10 web apps
- 4 function apps (indirectly)

**Impacted services:** AzureVM, AzureVMSS (if applicable), AzureFunctionApp (indirectly)

**Risk level:** HIGH

**Recommended fix:**
- Restore the AllowHTTPS rule
- If tightening source: use specific source IP ranges instead of `*`
- Staged rollout: add new restricted rule first, then remove old one

---

## Scenario 2: Change Default Route to Wrong NVA IP

**Change:** Update `default-to-fw` route from `10.0.0.68` to `10.99.99.99` (non-existent)

**What breaks:**
- ALL outbound traffic from affected subnet blackholes
- No internet access (updates, APIs, telemetry)
- No inter-spoke connectivity via firewall
- Monitoring stops

**Blast radius:** Entire subnet(s) with the modified route table

**Impacted services:** ALL services in affected subnets

**Risk level:** CRITICAL

**Recommended fix:**
- Revert route to correct firewall IP (`10.0.0.68`)
- Validate with effective routes check
- Test connectivity before and after

---

## Scenario 3: Block AD/DNS Ports (53/88/389)

**Change:** Remove DNS (100), Kerberos (110), LDAP (120) rules from `nsg-ad-dns-weu`

**What breaks:**
- DNS resolution fails for ALL environments
- Windows authentication fails for ALL domain-joined machines
- LDAP queries for user/group lookups fail
- New VM domain joins fail

**Blast radius:** ENTIRE ORGANIZATION (all 503 VMs + all web apps + all functions)

**Impacted services:** AzureVM, AzureVMSS, AzureFunctionApp, AzureSentinel (log correlation), ALL

**Risk level:** CRITICAL

**Recommended fix:**
- Immediately restore NSG rules
- Never modify AD/DNS NSG without simulation
- Always maintain redundant DC connectivity

---

## Scenario 4: Remove Firewall Rule Allowing Spoke-to-Spoke

**Change:** Remove `SpokeToSpoke` rule collection from firewall policy

**What breaks:**
- Frontend cannot reach Backend (FE-BE-SQL, FE-BE-HTTPS rules gone)
- Backend cannot reach its own database subnet (BE-DB rule gone)
- ALL spokes lose AD/DNS connectivity (AD-DNS rule gone)

**Blast radius:** ALL cross-spoke communication breaks

**Impacted services:** EVERYTHING

**Risk level:** CRITICAL

**Recommended fix:**
- Restore rule collection immediately
- Use firewall policy versioning
- Test in dev/test first

---

## Scenario 5: Change Route Table Association

**Change:** Disassociate route table from `snet-app` in production

**What breaks:**
- Production app subnet loses forced routing through firewall
- Traffic takes default system routes (may bypass security inspection)
- Depending on effective routes, connectivity may still work but is UNINSPECTED

**Blast radius:** 60 production app VMs + 15 web apps (VNet integrated)

**Impacted services:** AzureVM, AzureFunctionApp (indirect)

**Risk level:** HIGH (security) / MEDIUM (connectivity)

**Recommended fix:**
- Re-associate route table
- Verify effective routes on a sample NIC
- Confirm traffic is flowing through firewall

---

## Scenario 6: Modify Jumpbox NSG (Lose Management Access)

**Change:** Remove `RDPMgmt` and `SSHMgmt` rules from `nsg-jumpbox-weu`

**What breaks:**
- Cannot RDP/SSH to jumpbox
- Cannot reach ANY VM for management (since all VMs only allow RDP/SSH from jumpbox)
- Incident response capability is lost

**Blast radius:** ALL environments (management plane)

**Risk level:** HIGH

**Recommended fix:**
- Restore NSG rules
- Consider Azure Bastion as additional management path
- Never modify jumpbox NSG without backup access plan

---

## Scenario 7: Break Monitoring Egress Path

**Change:** Modify firewall AllowEgress to block port 443 outbound

**What breaks:**
- Log Analytics agent cannot send telemetry
- Sentinel stops receiving logs
- Azure Monitor metrics stop
- Defender for Cloud alerts stop
- Updates (Windows Update, apt) fail

**Blast radius:** Security visibility for ALL environments

**Impacted services:** AzureSentinel, ALL monitoring, patching

**Risk level:** HIGH

**Recommended fix:**
- Restore HTTPS outbound allow
- If restricting, use FQDN-based rules to allow only Azure Monitor endpoints
- Validate Sentinel data flow after change

---

## Scenario 8: Remove SQL Allow Rule from Data Subnet

**Change:** Remove `AllowSQLFromApp` (priority 100) from `nsg-prod-data-weu`

**What breaks:**
- App servers cannot connect to SQL databases
- All database-dependent applications fail
- Transaction processing stops
- Web Apps calling backend APIs get timeout errors

**Blast radius:**
- 30 production DB VMs
- 60 production app VMs (indirect — their DB calls fail)
- 15 web apps (indirect)
- 8 function apps (indirect)

**Impacted services:** AzureVM, AzureFunctionApp

**Risk level:** HIGH

**Recommended fix:**
- Restore SQL allow rule
- If tightening: restrict source to specific app subnet CIDR
- Test with a single app VM before broad change

---

# 13. CloudGuard Atlas Integration

## 13.1 How This IaC Maps to CloudGuard Atlas Twin Model

| IaC Construct | CloudGuard Atlas Twin Field |
|--------------|---------------------------|
| `azurerm_virtual_network` | `subnets[]` (parent) |
| `azurerm_subnet` | `subnets[]` |
| `azurerm_network_security_group` | `nsgs[]` |
| `azurerm_network_security_rule` | `nsg_rules[]` |
| `azurerm_route_table` | `route_tables[]` |
| `azurerm_route` | `routes[]` |
| `azurerm_subnet_network_security_group_association` | `associations[]` (subnet→nsg) |
| `azurerm_subnet_route_table_association` | `associations[]` (subnet→route_table) |
| `azurerm_windows_virtual_machine` / `azurerm_linux_virtual_machine` | `service_map[]` |
| `azurerm_linux_web_app` | `service_map[]` (AzureAppService/AzureFunctionApp) |
| `azurerm_linux_function_app` | `service_map[]` (AzureFunctionApp) |

## 13.2 How to Use with MCP Tool

1. **Push this repo to GitHub** (public)
2. In CloudGuard Atlas, provide:
   - `repo_url`: `https://github.com/<owner>/<repo>`
   - `folder_path`: `environments/prod` (or any environment)
3. MCP tool:
   - `scan_repo` → detects `.tf` files
   - `fetch_artifacts` → downloads Terraform files
   - `ingest` → normalizes to twin_min
   - `simulate_network` → evaluates NSG/route changes

Alternatively:
- Run `terraform plan -out=tfplan && terraform show -json tfplan > plan.json`
- Provide `plan.json` directly to the `ingest` action

## 13.3 How Knowledge Fabric Should Model This Environment

### Nodes

| Node Type | Examples |
|-----------|---------|
| `Environment` | hub-network, prod, dev, test, frontend, backend |
| `NetworkSegment` | vnet-shared-weu, vnet-prod-weu, snet-app, snet-data |
| `SecurityBoundary` | nsg-prod-app-weu, nsg-ad-dns-weu |
| `RouteControl` | rt-prod-app-weu, rt-shared-weu |
| `Workload` | vm-prod-app-001, webapp-prod-01, func-prod-01 |
| `IdentityService` | vm-dc01, vm-dc02 (DomainController) |
| `MonitoringSystem` | law-mfgcorp-weu (Log Analytics + Sentinel) |

### Key Relationships

| From | Relationship | To |
|------|-------------|-----|
| Environment:prod | CONTAINS | NetworkSegment:vnet-prod-weu |
| NetworkSegment:snet-app | PROTECTED_BY | SecurityBoundary:nsg-prod-app-weu |
| NetworkSegment:snet-app | ROUTED_BY | RouteControl:rt-prod-app-weu |
| NetworkSegment:snet-app | HOSTS | Workload:vm-prod-app-001 |
| Workload:vm-prod-app-001 | DEPENDS_ON | Workload:vm-be-db-001 |
| Workload:vm-prod-app-001 | DEPENDS_ON | IdentityService:vm-dc01 |
| MonitoringSystem:law-mfgcorp-weu | MONITORS | NetworkSegment:* |

## 13.4 How RAG Documents Should Reference This Environment

| RAG Document | Content Reference |
|-------------|------------------|
| NSG Change Runbook | References NSG naming: `nsg-{env}-{subnet}-weu` |
| Route Change Validation | References route tables: `rt-{env}-{subnet}-weu` |
| AD/DNS SOP | References `snet-ad-dns`, ports 53/88/389/445/636/3268 |
| CAB Template | References subscription layout, blast radius patterns |
| Rollback SOP | References `terraform plan` / `terraform apply` workflow |

---

# 14. Resource Inventory Summary

## Complete VM Inventory

| Subscription | Environment | # VMs | # Web Apps | # Functions | Total Resources |
|-------------|-------------|-------|-----------|-------------|----------------|
| sub-hub-network | Hub | 3 | 0 | 0 | 3 |
| sub-prod | Production | 150 | 15 | 8 | 173 |
| sub-dev | Development | 80 | 10 | 5 | 95 |
| sub-test | Test | 50 | 5 | 3 | 58 |
| sub-frontend | Frontend | 80 | 10 | 4 | 94 |
| sub-backend | Backend | 140 | 0 | 0 | 140 |
| **TOTAL** | | **503** | **40** | **20** | **563** |

## Network Inventory

| Subscription | VNet | # Subnets | # NSGs | # Route Tables |
|-------------|------|-----------|--------|---------------|
| sub-hub-network | vnet-shared-weu | 4 | 2 | 1 |
| sub-prod | vnet-prod-weu | 5 | 2 | 2 |
| sub-dev | vnet-dev-weu | 4 | 2 | 2 |
| sub-test | vnet-test-weu | 4 | 2 | 2 |
| sub-frontend | vnet-frontend-weu | 5 | 2 | 2 |
| sub-backend | vnet-backend-weu | 6 | 2 | 2 |
| **TOTAL** | **7 VNets** | **28** | **12** | **11** |

## Security Inventory

| Component | Count |
|-----------|-------|
| Azure Firewall | 1 |
| Firewall Policy | 1 |
| Rule Collections | 3 |
| Network Rules | 7+ |
| NSGs | 12 |
| NSG Rules | 50+ |
| Route Tables | 11 |
| Routes | 11 |

---

# End of Document

This document serves as the complete reference for the ManufacturingCorp Azure environment used by CloudGuard Atlas for change impact simulation and risk assessment.

**Version:** 1.0
**Last Updated:** 2026-05-25
