// =============================================================
// acr.bicep - Azure Container Registry
// =============================================================
// ACR = your private Docker image store in Azure
// Like Docker Hub but private and inside your Azure subscription
//
// Flow:
//   You build image on laptop → push to ACR → AKS pulls from ACR → runs as pod
//
// Naming rule: ACR name must be GLOBALLY unique, alphanumeric only, no hyphens
//   Pattern: acr{project}{environment} --> acrakslabdev
// =============================================================

@minLength(5)
@maxLength(50)
param location string

@minLength(1)
param environment string

@minLength(1)
param projectName string

// ------ AZURE CONTAINER REGISTRY ------
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acr${projectName}${environment}'   // = acrakslabdev (no hyphens allowed)
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
  sku: {
    name: 'Basic'   // Basic = cheapest tier (~$5/month)
                    // Standard = adds geo-replication
                    // Premium = adds private endpoints
                    // Basic is perfect for learning
  }
  properties: {
    adminUserEnabled: false   // Best practice: use managed identity, not username/password
                              // AKS will authenticate to ACR using its identity (no secrets needed)
  }
}

// ------ OUTPUTS ------
// Returned to main.bicep

output acrId string = acr.id                       // Used by AKS module to attach ACR
output acrLoginServer string = acr.properties.loginServer  // e.g. acrakslabdev.azurecr.io
output acrName string = acr.name
