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
- [x] Azure free account created (neelkant.aditya5@gmail.com)
- [x] All CLI tools installed
- [x] VS Code extensions installed
- [x] GitHub repo created: https://github.com/adityaneelkant23/aks-lab
- [x] Repo cloned to: C:\Users\neelk\Desktop\Projects\Azure Kubernatives\aks-lab
- [ ] NEXT STEP: Build folder structure inside repo
- [ ] Write Bicep infrastructure files
- [ ] Deploy AKS manually from terminal
- [ ] Build Hello World Docker image, push to ACR
- [ ] Deploy via Helm
- [ ] GitHub Actions CI/CD pipeline
- [ ] Final HTML reference document

## Target Architecture
- Single region (decide: eastus or australiaeast)
- Resource naming:
  - rg-aks-lab-dev (Resource Group)
  - vnet-aks-lab-dev (VNet)
  - aks-akslab-dev (AKS cluster)
  - acrakslabdev (ACR - no hyphens allowed)
  - agw-aks-lab-dev (Application Gateway + WAF)
  - psql-aks-lab-dev (PostgreSQL Flexible Server)
  - st-aks-lab-dev (Storage Account)
  - vm-jumpbox-dev (Windows jump box VM)
- VNet subnets:
  - snet-presentation: Application Gateway + WAF
  - snet-application: Private AKS nodes + pods (Azure CNI) + Windows jump box
  - snet-restricted: PostgreSQL + Storage private endpoints
  - AzureBastionSubnet: Azure Bastion (must be this exact name)
- AKS: private cluster, Azure CNI (not overlay), 1 system pool + 1 user node pool (2 nodes, Standard_B2s)
- Hello World: 2 replicas, topology spread constraints, user node pool only
- Windows jump box in application subnet, connect via Azure Bastion (no public RDP)
- Deployment: Bicep manual first, then GitHub Actions

## Key teaching points already covered
- VS Code terminal = your machine terminal (same thing)
- Docker = builds images. ACR = stores images. AKS = runs images.
- kubectl = remote control for K8s cluster (one command at a time)
- Helm = package installer for K8s (deploy whole apps with one command)
- README.md = front page of your GitHub repo
- Azure Bastion = secure way to RDP into jump box without public IP
