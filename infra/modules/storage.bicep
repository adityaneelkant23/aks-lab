// =============================================================
// storage.bicep - Azure Storage Account + Blob Container + Private Endpoint
// =============================================================
// Storage Account = Azure's equivalent of AWS S3
// Blob container = like an S3 bucket - stores unstructured files
//
// Private Endpoint = gives the storage account a private IP inside your VNet
//   Without it: traffic goes over public internet (even if authenticated)
//   With it: traffic stays inside VNet, never leaves Azure backbone
//
// Naming rules for Storage Account:
//   - 3 to 24 characters
//   - Lowercase letters and numbers ONLY (no hyphens, no underscores)
//   - Globally unique across all Azure
//   Pattern: st{project}{environment} --> stakslabdev
// =============================================================

param location string
param environment string
param projectName string

@description('Resource ID of restricted subnet - private endpoint goes here')
param restrictedSubnetId string

@description('Resource ID of the VNet - needed for private DNS zone link')
param vnetId string

// ------ STORAGE ACCOUNT ------
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${projectName}${environment}'   // = stakslabdev
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
  sku: {
    name: 'Standard_LRS'    // LRS = Locally Redundant Storage (3 copies in same datacenter)
                             // Cheapest option - fine for learning
                             // GRS = Geo-Redundant (copies to another region, more expensive)
  }
  kind: 'StorageV2'          // StorageV2 = latest, supports all features including Blob

  properties: {
    // Disable public access - ONLY accessible via private endpoint
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: false       // No anonymous public blob access
    minimumTlsVersion: 'TLS1_2'       // Enforce TLS 1.2+ (security best practice)
    supportsHttpsTrafficOnly: true     // Reject plain HTTP connections

    networkAcls: {
      defaultAction: 'Deny'           // Deny all traffic by default
      bypass: 'AzureServices'         // Allow Azure internal services (backups etc)
    }
  }
}

// ------ BLOB CONTAINER ------
// Like an S3 bucket - this is where your app will store/read files
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/appdata'   // Container name: appdata
  properties: {
    publicAccess: 'None'    // No public access - only accessible from inside VNet
  }
}

// ------ PRIVATE DNS ZONE FOR STORAGE ------
// So AKS pods can resolve: stakslabdev.blob.core.windows.net → private IP
resource storageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}

resource storageDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storageDnsZone
  name: 'vnet-link-storage'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ------ PRIVATE ENDPOINT ------
// Creates a private network interface (NIC) inside snet-restricted
// Storage account gets a private IP like 10.0.4.10
// Your pods connect to that private IP - traffic never leaves Azure backbone
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-storage-aks-lab-${environment}'
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
  properties: {
    subnet: {
      id: restrictedSubnetId    // Goes into snet-restricted
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']    // 'blob' = Blob storage endpoint
                                // Could also be 'file', 'table', 'queue'
        }
      }
    ]
  }
}

// Link private endpoint to DNS zone so hostname resolves to private IP
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: privateEndpoint
  name: 'storage-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'storage-config'
        properties: {
          privateDnsZoneId: storageDnsZone.id
        }
      }
    ]
  }
}

// ------ OUTPUTS ------
output storageAccountName string = storageAccount.name
output blobContainerName string = 'appdata'
output storageAccountId string = storageAccount.id
