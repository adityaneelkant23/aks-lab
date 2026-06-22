// =============================================================
// sqldb.bicep - Azure SQL Database (Free Tier)
// =============================================================
// Azure SQL Database = Azure's equivalent of AWS RDS SQL Server
// Free tier: 32 GB storage, 100,000 vCore-seconds/month, auto-pauses when idle
// Auto-pause = ZERO cost when not in use (perfect for learning)
//
// Private endpoint = database only reachable from inside VNet
// No public internet access
//
// Naming:
//   SQL Server: sql-aks-lab-dev
//   Database:   akslab
// =============================================================

param location string
param environment string

@description('Resource ID of restricted subnet - private endpoint goes here')
param restrictedSubnetId string

@description('Resource ID of the VNet - needed for DNS zone link')
param vnetId string

@description('SQL admin username')
param adminUsername string = 'sqladmin'

@description('SQL admin password - secure, never logged')
@secure()
param adminPassword string

// ------ SQL SERVER ------
// The server is the container - like an RDS instance
// The database sits inside the server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: 'sql-aks-lab-${environment}'
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    publicNetworkAccess: 'Disabled'    // No public access - private endpoint only
    minimalTlsVersion: '1.2'           // Enforce TLS 1.2+
  }
}

// ------ SQL DATABASE (FREE TIER) ------
// The actual database inside the server
// useFreeLimit: true = uses Azure's free 100,000 vCore-seconds/month
// Serverless = auto-pauses after 1 hour idle (no compute cost while idle)
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: 'akslab'
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
  sku: {
    name: 'GP_S_Gen5_1'        // General Purpose Serverless, 1 vCore
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 34359738368          // 32 GB max size
    autoPauseDelay: 60                 // Auto-pause after 60 mins idle = zero compute cost
    useFreeLimit: true                 // USE FREE TIER - 100,000 vCore-seconds/month free
    freeLimitExhaustionBehavior: 'AutoPause'   // Pause if free limit hit (don't charge)
  }
}

// ------ PRIVATE DNS ZONE FOR SQL ------
resource sqlDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.database.windows.net'
  location: 'global'
}

resource sqlDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlDnsZone
  name: 'vnet-link-sql'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ------ PRIVATE ENDPOINT ------
// Creates a NIC in snet-restricted with private IP
// SQL server gets e.g. 10.0.4.5 - only reachable from inside VNet
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-sql-aks-lab-${environment}'
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
  properties: {
    subnet: {
      id: restrictedSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'sql-connection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: ['sqlServer']    // 'sqlServer' is the group ID for Azure SQL
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: privateEndpoint
  name: 'sql-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql-config'
        properties: {
          privateDnsZoneId: sqlDnsZone.id
        }
      }
    ]
  }
}

// ------ OUTPUTS ------
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
  // = sql-aks-lab-dev.database.windows.net (resolves to private IP inside VNet)
output sqlServerName string = sqlServer.name
output databaseName string = sqlDatabase.name
