// rbac.bicep
// Purpose: Grant AKS managed identity Network Contributor on the VNet
// WHY: AKS needs to read subnets and create internal Load Balancers
//      Without this, NGINX internal LB fails with 403 AuthorizationFailed
// This is a separate module because main.bicep is subscription-scoped,
// but role assignments on a VNet must be deployed at resource group scope.

param aksIdentityPrincipalId string   // AKS managed identity object ID
param vnetName string                  // VNet to grant access on

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: vnetName
}

// Network Contributor role ID (built-in Azure role)
// Grants: subnets/read, subnets/join/action, loadBalancers/write etc.
resource aksNetworkContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksIdentityPrincipalId, vnet.id, 'network-contributor')
  scope: vnet
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
    principalId: aksIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
