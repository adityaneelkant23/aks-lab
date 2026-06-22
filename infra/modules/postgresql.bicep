// =============================================================
// postgresql.bicep - Azure PostgreSQL Flexible Server
// =============================================================
// PostgreSQL Flexible Server = Azure's equivalent of AWS RDS PostgreSQL
// Fully managed: Azure handles backups, patching, HA, storage scaling
//
// Networking: DELEGATED SUBNET mode
//   The entire snet-restricted subnet is "delegated" to PostgreSQL
//   This means PostgreSQL gets IPs directly from the subnet (like Azure CNI for pods)
//   No public endpoint - only reachable from inside the VNet
//   Requires a Private DNS Zone so apps can resolve the hostname
//
// Cost for learning: B1ms (1 vCPU, 2GB RAM) = ~$13/month
// =============================================================

param location string
param environment string

@description('Resource ID of restricted subnet - PostgreSQL will be delegated here')
param delegatedSubnetId string

@description('Resource ID of the PostgreSQL private DNS zone (created in network.bicep)')
param privateDnsZoneId string

@description('PostgreSQL admin username')
param adminUsername string = 'pgadmin'

@description('PostgreSQL admin password - marked secure so it never appears in logs')
@secure()
param adminPassword string

// ------ POSTGRESQL FLEXIBLE SERVER ------
resource postgresql 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: 'psql-aks-lab-${environment}'   // = psql-aks-lab-dev
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }

  sku: {
    name: 'Standard_B1ms'    // Burstable B1ms = cheapest tier
                              // 1 vCPU, 2 GB RAM
                              // Good enough for learning/dev
                              // Production would use General Purpose or Memory Optimized
    tier: 'Burstable'        // Burstable = can burst CPU above baseline (like t3 in AWS)
  }

  properties: {

    // ------ ADMIN CREDENTIALS ------
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword

    // ------ VERSION ------
    version: '16'             // PostgreSQL version 16 (latest stable)

    // ------ STORAGE ------
    storage: {
      storageSizeGB: 32       // Minimum 32 GB - enough for learning
    }

    // ------ BACKUP ------
    backup: {
      backupRetentionDays: 7           // Keep 7 days of backups (minimum)
      geoRedundantBackup: 'Disabled'   // No geo-backup for learning (saves cost)
    }

    // ------ HIGH AVAILABILITY ------
    highAvailability: {
      mode: 'Disabled'    // No HA for learning - HA doubles the cost
                          // In production: 'ZoneRedundant' or 'SameZone'
    }

    // ------ PRIVATE NETWORKING ------
    // This is what keeps PostgreSQL off the public internet
    // 'Private' mode with delegated subnet = no public IP ever created
    network: {
      delegatedSubnetResourceId: delegatedSubnetId     // snet-restricted subnet
      privateDnsZoneArmResourceId: privateDnsZoneId    // DNS zone from network.bicep
                                                        // Lets AKS pods resolve:
                                                        // psql-aks-lab-dev.postgres.database.azure.com
    }

    // ------ MAINTENANCE ------
    maintenanceWindow: {
      customWindow: 'Disabled'    // Azure chooses maintenance window (fine for learning)
    }

  }
}

// ------ DATABASE ------
// Create an initial database inside the server
// Like creating a schema/database in psql: CREATE DATABASE akslab;
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: postgresql
  name: 'akslab'
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// ------ OUTPUTS ------
output postgresqlFqdn string = postgresql.properties.fullyQualifiedDomainName
  // = psql-aks-lab-dev.postgres.database.azure.com
  // Your app connects to this hostname (resolved privately via DNS zone)
output postgresqlName string = postgresql.name
output databaseName string = database.name
