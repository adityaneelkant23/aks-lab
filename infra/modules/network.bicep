// =============================================================
// network.bicep - Virtual Network with subnets
// =============================================================
// VNet = your private network in Azure (like your office LAN)
// Subnets = segments of that network, each with a purpose
//
// Subnet plan (Azure CNI Overlay - pods get IPs from overlay, NOT from VNet):
//   snet-presentation  10.68.10.0/24  (256 IPs) - Application Gateway + WAF
//   snet-application   10.68.20.0/24  (256 IPs) - AKS NODES ONLY (CNI Overlay: pods use 192.168.0.0/16)
//   snet-restricted    10.68.30.0/24  (256 IPs) - Storage/SQL private endpoints
//   AzureBastionSubnet 10.68.40.0/26  (64 IPs)  - Azure Bastion (name must be exact)
//   snet-database      10.68.50.0/24  (256 IPs) - Reserved for future DB use
//
// KEY DIFFERENCE from Azure CNI (flat):
//   Azure CNI Flat:    pod IPs come from VNet subnet (exhausts VNet IPs fast)
//   Azure CNI Overlay: pod IPs come from separate Pod CIDR 192.168.0.0/16
//                      node subnet only needs IPs for NODES (much smaller)
// =============================================================

param location string
param environment string

// ------ VIRTUAL NETWORK ------
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-aks-lab-${environment}'
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.68.0.0/16'   // 65,536 total IPs available across all subnets
      ]
    }

    subnets: [

      // SUBNET 1: PRESENTATION
      // Purpose: Application Gateway + WAF sits here
      // Traffic from internet hits App Gateway first (your front door)
      {
        name: 'snet-presentation'
        properties: {
          addressPrefix: '10.68.10.0/24'
        }
      }

      // SUBNET 2: APPLICATION (AKS NODES ONLY - CNI Overlay)
      // Purpose: AKS WORKER NODES get IPs here (NOT pods anymore)
      // With Azure CNI Overlay: nodes = 10.68.20.x, pods = 192.168.x.x (overlay)
      // /24 is now ENOUGH because pods no longer consume VNet IPs
      // This is the key benefit of Overlay mode vs flat CNI
      {
        name: 'snet-application'
        properties: {
          addressPrefix: '10.68.20.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }

      // SUBNET 3: RESTRICTED
      // Purpose: Private PaaS services - Storage/SQL private endpoints
      // Nothing public touches this subnet - most secure zone
      {
        name: 'snet-restricted'
        properties: {
          addressPrefix: '10.68.30.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }

      // SUBNET 4: AZURE BASTION
      // IMPORTANT: Name MUST be exactly 'AzureBastionSubnet'
      // IMPORTANT: Must be /26 or larger
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.68.40.0/26'
        }
      }

      // SUBNET 5: DATABASE (reserved for future use)
      // PostgreSQL delegation kept for office deployment reference
      {
        name: 'snet-database'
        properties: {
          addressPrefix: '10.68.50.0/24'
          delegations: [
            {
              name: 'postgresql-delegation'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }

    ]
  }
}

// ------ AZURE BASTION (COMMENTED OUT - DEPLOY ONLY WHEN NEEDED) ------
// Cost: ~$4.56/day for Basic tier. Uncomment when you need RDP to jump box.
// Bastion = secure RDP without exposing port 3389 to internet.
// For now, use: az aks command invoke (free, no jump box needed for kubectl)
//
// resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
//   name: 'pip-bastion-aks-lab-${environment}'
//   location: location
//   sku: { name: 'Standard' }
//   properties: { publicIPAllocationMethod: 'Static' }
// }
//
// resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
//   name: 'bas-aks-lab-${environment}'
//   location: location
//   sku: { name: 'Basic' }
//   properties: {
//     ipConfigurations: [{
//       name: 'ipconfig'
//       properties: {
//         subnet: { id: '${vnet.id}/subnets/AzureBastionSubnet' }
//         publicIPAddress: { id: bastionPip.id }
//       }
//     }]
//   }
// }

// ------ PRIVATE DNS ZONE FOR POSTGRESQL ------
// PostgreSQL Flexible Server in delegated subnet needs a private DNS zone
// so that your apps can resolve the DB hostname inside the VNet

resource postgreSqlDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
}

resource postgreSqlDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: postgreSqlDnsZone
  name: 'vnet-link-postgresql'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

// ------ OUTPUTS ------
// These values are returned to main.bicep so other modules can use them

output vnetId string = vnet.id
output vnetName string = vnet.name

// Subnet IDs - passed into AKS, PostgreSQL, Storage, App Gateway modules
output presentationSubnetId string = '${vnet.id}/subnets/snet-presentation'
output applicationSubnetId string = '${vnet.id}/subnets/snet-application'
output restrictedSubnetId string = '${vnet.id}/subnets/snet-restricted'
output databaseSubnetId string = '${vnet.id}/subnets/snet-database'
output bastionSubnetId string = '${vnet.id}/subnets/AzureBastionSubnet'

// PostgreSQL DNS zone ID - passed into postgresql module
output postgreSqlDnsZoneId string = postgreSqlDnsZone.id
