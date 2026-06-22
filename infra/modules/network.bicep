// =============================================================
// network.bicep - Virtual Network with 4 subnets
// =============================================================
// VNet = your private network in Azure (like your office LAN)
// Subnets = segments of that network, each with a purpose
//
// Subnet plan (southcentralus):
//   snet-presentation  10.0.1.0/24  (256 IPs) - Application Gateway + WAF
//   snet-application   10.0.2.0/23  (512 IPs) - AKS nodes + pods (Azure CNI needs more IPs)
//   snet-restricted    10.0.4.0/24  (256 IPs) - PostgreSQL + Storage private endpoints
//   AzureBastionSubnet 10.0.5.0/26  (64 IPs)  - Azure Bastion (name must be exact)
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
        '10.0.0.0/16'   // 65,536 total IPs available across all subnets
      ]
    }

    subnets: [

      // SUBNET 1: PRESENTATION
      // Purpose: Application Gateway + WAF sits here
      // Traffic from internet hits App Gateway first (your front door)
      // /24 = 256 IPs. App Gateway needs at least 1 IP per instance + buffer.
      {
        name: 'snet-presentation'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }

      // SUBNET 2: APPLICATION
      // Purpose: AKS worker nodes AND pods live here (Azure CNI mode)
      // Azure CNI = every pod gets a REAL VNet IP (not a hidden overlay IP)
      // This is why it needs /23 (512 IPs) - nodes + up to 30 pods each
      // Also: Windows jump box VM will live here
      {
        name: 'snet-application'
        properties: {
          addressPrefix: '10.0.2.0/23'
          // privateEndpointNetworkPolicies disabled = allows private endpoints in this subnet
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }

      // SUBNET 3: RESTRICTED
      // Purpose: Private PaaS services - PostgreSQL and Storage private endpoints
      // Nothing public touches this subnet - most secure zone
      {
        name: 'snet-restricted'
        properties: {
          addressPrefix: '10.0.4.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }

      // SUBNET 4: AZURE BASTION
      // Purpose: Secure RDP/SSH to jump box - NO public IP needed on the VM
      // IMPORTANT: Name MUST be exactly 'AzureBastionSubnet' - Azure enforces this
      // IMPORTANT: Must be /26 or larger - Azure enforces this minimum size
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.5.0/26'
        }
      }

    ]
  }
}

// ------ AZURE BASTION ------
// Bastion = managed jump service. Connect to your Windows jump box VM
// via browser (HTTPS) without exposing RDP port 3389 to internet.
// Needs a Public IP (for users to reach it) but the VM itself stays private.

resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-bastion-aks-lab-${environment}'
  location: location
  sku: {
    name: 'Standard'   // Must be Standard for Bastion
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: 'bas-aks-lab-${environment}'
  location: location
  sku: {
    name: 'Basic'    // Basic tier is cheapest - enough for learning
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

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
output bastionSubnetId string = '${vnet.id}/subnets/AzureBastionSubnet'

// PostgreSQL DNS zone ID - passed into postgresql module
output postgreSqlDnsZoneId string = postgreSqlDnsZone.id
