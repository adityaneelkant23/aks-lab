# AKS Lab - Copilot Context (Auto-loaded every session)

## Who I am helping
- Student: Aditya Neelkant (learning Azure Kubernetes for office deployment)
- GitHub: adityaneelkant23
- Azure email: neelkant.aditya5@gmail.com ($200 free credits active)
- Laptop: Windows, LAPTOP-7BAVHCMA

## Project
This is a step-by-step AKS learning project. Guide ONE step at a time. Wait for confirmation before next step.
Repo: https://github.com/adityaneelkant23/aks-lab

## Azure Account
- Subscription name: Azure subscription 1
- Subscription ID: c08990f3-f943-4db9-af75-d819675d8971
- Region: southcentralus
- az login: DONE

## Tools already installed (DO NOT reinstall)
- Azure CLI 2.87.0 (32-bit, works fine)
- Git 2.54.0
- Docker Desktop 29.5.3
- kubectl v1.34.1
- Helm v4.2.2
- VS Code Extensions: Bicep, Docker, Kubernetes, GitHub Actions, Azure Account

## Progress
- [x] Azure free account created (neelkant.aditya5@gmail.com, $200 credits, expires July 21 2026)
- [x] All CLI tools installed (az 2.87, git 2.54, docker 29.5, kubectl v1.34, helm v4.2)
- [x] VS Code extensions installed (Bicep, Docker, Kubernetes, GitHub Actions, Azure Account)
- [x] GitHub repo created: https://github.com/adityaneelkant23/aks-lab
- [x] Repo cloned to: C:\Users\neelk\Desktop\Projects\Azure Kubernatives\aks-lab
- [x] Folder structure created (infra/modules, infra/parameters, app, helm/hello-world, .github/workflows)
- [x] az login done - subscription active
- [x] All Bicep files written and validated (zero errors):
      - infra/main.bicep (master orchestrator, subscription scope)
      - infra/modules/network.bicep (VNet + 4 subnets + DNS zones)
      - infra/modules/acr.bicep (Container Registry - acrakslabdev)
      - infra/modules/aks.bicep (Private AKS, Azure CNI, system+user pools)
      - infra/modules/postgresql.bicep (PostgreSQL Flexible Server - private)
      - infra/modules/storage.bicep (Storage + Blob + Private Endpoint)
      - infra/modules/appgateway.bicep (App Gateway + WAF)
      - infra/parameters/dev.bicepparam
- [x] what-if validated: 18 resources ready, zero warnings
- [x] All code pushed to GitHub
- [ ] NEXT STEP: Run actual deployment (az deployment sub create)
- [ ] Build Hello World Docker image + push to ACR
- [ ] Deploy via Helm (2 replicas, user node pool)
- [ ] Install NGINX Ingress Controller via Helm
- [ ] Wire App Gateway → NGINX → Hello World
- [ ] GitHub Actions CI/CD pipeline
- [ ] Final HTML reference document

## Target Architecture
- Region: southcentralus (decided)
- VM size: Standard_D2als_v6 (B2s not available on free trial)
- Node pools: 1 system node + 1 user node (4 vCPU limit on free trial; at office use 2 user nodes)
- Resource naming (final):
  - rg-aks-lab-dev (Resource Group)
  - vnet-aks-lab-dev (VNet)
  - aks-akslab-dev (AKS cluster)
  - acrakslabdev (ACR - no hyphens allowed)
  - agw-aks-lab-dev (Application Gateway + WAF)
  - psql-aks-lab-dev (PostgreSQL Flexible Server)
  - stakslabdev001 (Storage Account)
- VNet subnets:
  - snet-presentation (10.0.1.0/24): Application Gateway + WAF
  - snet-application (10.0.2.0/23): Private AKS nodes + pods (Azure CNI) + future jump box
  - snet-restricted (10.0.4.0/24): PostgreSQL + Storage private endpoints
  - AzureBastionSubnet (10.0.5.0/26): defined but Bastion NOT deployed (cost saving)
- AKS: private cluster, Azure CNI, 1 system pool + 1 user pool
- Hello World: 2 replicas, user node pool only
- Bastion: NOT deployed (use az aks command invoke for kubectl access)
- PostgreSQL password: AksLab@2026! (CLI only, never in files)

## Deploy Command (run this NEXT SESSION to deploy everything - takes 15-20 mins)
```
az deployment sub create `
  --location southcentralus `
  --template-file infra/main.bicep `
  --parameters infra/parameters/dev.bicepparam `
  --parameters adminPassword='AksLab@2026!'
```

## Key teaching points already covered
- VS Code terminal = your machine terminal (same thing)
- Docker = builds images. ACR = stores images. AKS = runs images.
- kubectl = remote control for K8s cluster (one command at a time)
- Helm = package installer for K8s (deploy whole apps with one command)
- README.md = front page of your GitHub repo
- Azure Bastion = secure way to RDP into jump box without public IP
