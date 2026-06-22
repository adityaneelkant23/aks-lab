// =============================================================
// aks.bicep - Private AKS Cluster with Azure CNI
// =============================================================
// AKS = Azure Kubernetes Service (managed Kubernetes)
// Azure manages the control plane (API server, etcd, scheduler)
// You manage the worker nodes (node pools)
//
// Our cluster has 2 node pools:
//   system pool  - runs Kubernetes system pods (coredns, metrics etc)
//                  tainted so your app pods DON'T land here
//   user pool    - runs YOUR application pods (hello-world etc)
//                  this is where business workloads go
//
// Azure CNI: pods get real IPs from snet-application subnet
// Private cluster: API server has no public IP - only reachable from inside VNet
// =============================================================

param location string
param environment string
param projectName string

@description('Resource ID of the application subnet - AKS nodes and pods get IPs from here')
param nodeSubnetId string

@description('Resource ID of ACR - AKS gets pull permission to this registry')
param acrId string

// ------ AKS CLUSTER ------
resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: 'aks-${projectName}-${environment}'   // = aks-akslab-dev
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }

  // Managed Identity for AKS
  // AKS uses this identity to:
  //   - pull images from ACR
  //   - create load balancers
  //   - attach disks
  identity: {
    type: 'SystemAssigned'   // Azure creates and manages this identity automatically
  }

  properties: {

    dnsPrefix: '${projectName}-${environment}'   // Used in the cluster FQDN

    // ------ PRIVATE CLUSTER ------
    // API server will have NO public IP
    // You can only run kubectl from inside the VNet (jump box) or via az aks command invoke
    apiServerAccessProfile: {
      enablePrivateCluster: true
    }

    // ------ NETWORK - AZURE CNI ------
    // This is the most important section for your learning
    networkProfile: {
      networkPlugin: 'azure'          // 'azure' = Azure CNI (real VNet IPs for pods)
                                      // 'kubenet' = overlay (fake IPs) - we don't use this
      networkPolicy: 'azure'          // Controls which pods can talk to which (firewall between pods)
      serviceCidr: '172.16.0.0/16'   // Internal Kubernetes service IPs (NOT in your VNet)
                                      // These are virtual IPs for Services - must not overlap VNet
      dnsServiceIP: '172.16.0.10'    // CoreDNS service IP - must be inside serviceCidr
    }

    // ------ NODE POOLS ------
    agentPoolProfiles: [

      // SYSTEM NODE POOL
      // Purpose: runs Kubernetes system components only
      // Tainted with CriticalAddonsOnly so your app pods are FORCED onto user pool
      // 1 node is enough for system components in a learning environment
      {
        name: 'system'
        mode: 'System'                    // System mode = runs system pods, tainted for user pods
        count: 1                          // 1 node for system pool (saves cost)
        vmSize: 'Standard_B2s'           // 2 vCPUs, 4 GB RAM - cheapest that AKS accepts
        osType: 'Linux'
        osDiskSizeGB: 30                 // Minimum OS disk
        vnetSubnetID: nodeSubnetId       // Gets IP from snet-application
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'   // Prevents YOUR pods from landing on system nodes
        ]
        nodeLabels: {
          'nodepool-type': 'system'
          'environment': environment
        }
        type: 'VirtualMachineScaleSets'   // Required for autoscaling (even if we don't autoscale yet)
        availabilityZones: []             // No zones for learning (would need 3 nodes for 3 zones)
        enableAutoScaling: false          // Manual scaling for learning - keep costs predictable
      }

      // USER NODE POOL
      // Purpose: runs YOUR application pods (hello-world, nginx ingress etc)
      // 2 nodes so hello-world can run 1 replica per node (HA even at small scale)
      {
        name: 'user'
        mode: 'User'                      // User mode = meant for application workloads
        count: 2                          // 2 nodes for HA - hello-world pod 1 on node 1, pod 2 on node 2
        vmSize: 'Standard_B2s'           // Same cheap size - fine for Hello World
        osType: 'Linux'
        osDiskSizeGB: 30
        vnetSubnetID: nodeSubnetId       // Same subnet as system pool
        nodeLabels: {
          'nodepool-type': 'user'
          'environment': environment
          'workload': 'applications'      // We'll use this label to target this pool in Helm
        }
        type: 'VirtualMachineScaleSets'
        availabilityZones: []
        enableAutoScaling: false
      }

    ]

    // ------ ADDON PROFILES ------
    addonProfiles: {
      // Azure Key Vault secrets integration (disabled for now, enable later if needed)
      azureKeyvaultSecretsProvider: {
        enabled: false
      }
    }

    // ------ RBAC + SECURITY ------
    enableRBAC: true                    // Role-based access control - always enable this
    disableLocalAccounts: false         // Allow local kubeconfig for learning (in production, disable this)

    // Skip http proxy, just basic setup for learning
    oidcIssuerProfile: {
      enabled: true                     // Needed for workload identity (modern way for pods to access Azure)
    }

    securityProfile: {
      workloadIdentity: {
        enabled: true                   // Allows pods to have Azure identities (no hardcoded secrets)
      }
    }

  }
}

// ------ ACR PULL PERMISSION ------
// Grant AKS permission to pull images from ACR
// This replaces the old way of storing ACR username/password as a Kubernetes secret
// AcrPull role = read-only access to pull images (not push, not delete)
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, acrId, 'acrpull')    // guid() creates a unique ID from these values
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')  // AcrPull built-in role ID
    principalId: aks.properties.identityProfile.kubeletidentity.objectId   // AKS kubelet identity
    principalType: 'ServicePrincipal'
  }
}

// ------ OUTPUTS ------
output aksClusterName string = aks.name
output aksId string = aks.id
output aksFqdn string = aks.properties.privateFQDN   // Private FQDN of the API server
