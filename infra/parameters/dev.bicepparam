// =============================================================
// dev.bicepparam - Parameter values for dev environment
// =============================================================
// This file provides all values to main.bicep for the dev environment
// In future you would create test.bicepparam and prod.bicepparam
// with different values (larger VM sizes, HA enabled, etc.)
//
// Deploy command (we will run this later):
//   az deployment sub create \
//     --location southcentralus \
//     --template-file ../main.bicep \
//     --parameters @dev.bicepparam \
//     --parameters adminPassword='YourSecurePassword123!'
// =============================================================

using '../main.bicep'   // Points to the main.bicep this file belongs to

// Azure region - all resources go here
param location = 'southcentralus'

// Environment tag - used in all resource names
param environment = 'dev'

// Short project name - used in resource names (no hyphens, lowercase)
// Results in names like: aks-akslab-dev, acrakslabdev, psql-aks-lab-dev
param projectName = 'akslab'
