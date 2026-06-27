// =============================================================
// main.bicep - Master orchestrator for AKS Lab infrastructure
// Deploys at SUBSCRIPTION scope so it can create the Resource Group
// =============================================================

targetScope = 'subscription'

// ------ PARAMETERS ------
// Parameters are inputs you can change without editing the file

@description('Azure region where all resources will be created')
param location string = 'southcentralus'

@description('Environment name - used in resource naming')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('Short project name - used in resource naming (no hyphens, lowercase)')
param projectName string = 'akslab'

@description('PostgreSQL admin password - passed at deploy time, never stored in files')
@secure()
param adminPassword string

// ------ RESOURCE GROUP ------
// A resource group is a logical container for all your Azure resources.
// Like a folder that holds everything for this project.
// Naming: rg-{project}-{environment} --> rg-aks-lab-dev

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-aks-lab-${environment}'
  location: location
  tags: {
    environment: environment
    project: projectName
    managedBy: 'bicep'
    owner: 'adityaneelkant23'
  }
}

// ------ MODULES ------
// Each module is a separate Bicep file responsible for one Azure resource.
// 'scope: rg' means "deploy this inside the resource group above".
// 'params' passes values INTO the module file.

// 1. NETWORK - VNet with 4 subnets (must be first - others depend on subnet IDs)
module network 'modules/network.bicep' = {
  name: 'deploy-network'
  scope: rg
  params: {
    location: location
    environment: environment
  }
}

// 2. ACR - Azure Container Registry (stores your Docker images)
module acr 'modules/acr.bicep' = {
  name: 'deploy-acr'
  scope: rg
  params: {
    location: location
    environment: environment
    projectName: projectName
  }
}

// 3. AKS - Private Kubernetes Cluster
// Needs the application subnet ID from network module (Azure CNI puts pods in this subnet)
// Needs ACR ID so AKS can pull images from it
module aks 'modules/aks.bicep' = {
  name: 'deploy-aks'
  scope: rg
  params: {
    location: location
    environment: environment
    projectName: projectName
    nodeSubnetId: network.outputs.applicationSubnetId
    acrId: acr.outputs.acrId
  }
}

// 3b. GRANT AKS IDENTITY - Network Contributor on VNet
// WHY: AKS managed identity needs to read subnets + create internal Load Balancers
//      Without this, NGINX internal LB (type=LoadBalancer) fails with 403 Forbidden
//      Error seen: "does not have authorization to perform action
//                   Microsoft.Network/virtualNetworks/subnets/read"
// Network Contributor role ID: 4d97b98b-1d4f-4787-a291-c67834d212e7
// Scope to the VNet resource (not whole RG) - principle of least privilege
// AKS only needs rights on this specific VNet to create internal LBs
var vnetResourceId = network.outputs.vnetId
resource vnetRef 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: 'vnet-${projectName}-${environment}'
  scope: rg
}

resource aksNetworkContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.outputs.aksId, vnetResourceId, 'network-contributor')
  scope: vnetRef
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
    principalId: aks.outputs.aksManagedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// 4. POSTGRESQL - Commented out: PostgreSQL Flexible Server restricted in southcentralus on free trial
// To enable: change location to 'eastus' in postgresql module or request quota increase
// module postgresql 'modules/postgresql.bicep' = {
//   name: 'deploy-postgresql'
//   scope: rg
//   params: {
//     location: location
//     environment: environment
//     delegatedSubnetId: network.outputs.databaseSubnetId
//     privateDnsZoneId: network.outputs.postgreSqlDnsZoneId
//     adminPassword: adminPassword
//   }
// }

// 5. AZURE SQL DATABASE (FREE TIER) - COMMENTED OUT (southcentralus free trial restriction)
// Same restriction as PostgreSQL - enable on paid subscription or eastus region
// module sqldb 'modules/sqldb.bicep' = {
//   name: 'deploy-sqldb'
//   scope: rg
//   params: {
//     location: location
//     environment: environment
//     restrictedSubnetId: network.outputs.restrictedSubnetId
//     vnetId: network.outputs.vnetId
//     adminPassword: adminPassword
//   }
// }

// 6. STORAGE - Blob storage with private endpoint
module storage 'modules/storage.bicep' = {
  name: 'deploy-storage'
  scope: rg
  params: {
    location: location
    environment: environment
    projectName: projectName
    restrictedSubnetId: network.outputs.restrictedSubnetId
    vnetId: network.outputs.vnetId
  }
}

// 7. APPLICATION GATEWAY - WAF + load balancer (placed in presentation subnet)
module appGateway 'modules/appgateway.bicep' = {
  name: 'deploy-appgateway'
  scope: rg
  params: {
    location: location
    environment: environment
    presentationSubnetId: network.outputs.presentationSubnetId
  }
}

// ------ OUTPUTS ------
// These values are printed after deployment - useful for next steps

output resourceGroupName string = rg.name
output aksClusterName string = aks.outputs.aksClusterName
output acrLoginServer string = acr.outputs.acrLoginServer
