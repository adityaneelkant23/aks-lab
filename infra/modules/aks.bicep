// =============================================================
// aks.bicep - Private AKS Cluster with Azure CNI Overlay + Cilium
// =============================================================
// AKS = Azure Kubernetes Service (managed Kubernetes)
//
// KEY CHANGES from previous version:
//   networkPluginMode: overlay  → pods get IPs from 192.168.0.0/16 (NOT VNet)
//   networkDataplane: cilium    → Cilium replaces kube-proxy + adds eBPF networking
//   networkPolicy: cilium       → Cilium enforces pod-to-pod firewall rules
//
// WHY CILIUM? (replaces Illumio in your office context)
//   - eBPF-based: hooks into Linux kernel directly, no iptables overhead
//   - NetworkPolicy enforcement: microsegmentation between pods/namespaces
//   - Identity-aware: policies based on pod labels, not just IP addresses
//   - Observability: Hubble UI shows all pod-to-pod traffic flows
//   - FREE: built into AKS, no license cost (unlike Illumio)
//   - Cyber teams love it: L3/L4/L7 policies, encryption, audit trail
//
// Our cluster has 2 node pools:
//   system pool  - runs Kubernetes system pods (coredns, metrics etc)
//   user pool    - runs YOUR application pods
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

    // ------ NETWORK - AZURE CNI OVERLAY + CILIUM ------
    // This is the most important section
    networkProfile: {
      networkPlugin: 'azure'            // 'azure' = Azure CNI (required for Cilium)
      networkPluginMode: 'overlay'      // NEW: pods get IPs from podCidr, NOT from VNet subnet
                                        // Nodes = 10.68.20.x (VNet), Pods = 192.168.x.x (overlay)
      networkDataplane: 'cilium'        // NEW: Cilium handles all packet forwarding (replaces kube-proxy)
                                        // Uses eBPF = faster, lower CPU, kernel-level networking
      networkPolicy: 'cilium'           // NEW: Cilium enforces NetworkPolicy rules between pods
                                        // This is what replaces Illumio for microsegmentation
      podCidr: '192.168.0.0/16'        // NEW: Pod overlay CIDR - pods get IPs from here
                                        // Completely separate from VNet - no IP exhaustion
      serviceCidr: '10.0.0.0/16'       // Internal Kubernetes service IPs (virtual, not in VNet)
      dnsServiceIP: '10.0.0.10'        // CoreDNS IP - must be inside serviceCidr
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
        vmSize: 'Standard_D2als_v6'      // 2 vCPUs, 4 GB RAM - cheapest available in southcentralus free trial
        osType: 'Linux'
        osDiskSizeGB: 30                 // Minimum OS disk
        vnetSubnetID: nodeSubnetId       // Gets IP from snet-application
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'   // Prevents YOUR pods from landing on system nodes
        ]
        nodeLabels: {
          nodePoolType: 'system'
          environment: environment
        }
        type: 'VirtualMachineScaleSets'   // Required for autoscaling (even if we don't autoscale yet)
        availabilityZones: []             // No zones for learning (would need 3 nodes for 3 zones)
        enableAutoScaling: false          // Manual scaling for learning - keep costs predictable
      }

      // USER NODE POOL
      // Purpose: runs YOUR application pods (hello-world, nginx ingress etc)
      // 1 node only - limited by free trial vCPU quota (4 total, 2 used by system)
      // In production/office: increase to 2+ nodes for true HA across nodes
      {
        name: 'user'
        mode: 'User'
        count: 1                          // 1 node (quota constraint - upgrade to 2 at office)
        vmSize: 'Standard_D2als_v6'
        osType: 'Linux'
        osDiskSizeGB: 30
        vnetSubnetID: nodeSubnetId
        nodeLabels: {
          nodePoolType: 'user'
          environment: environment
          workload: 'applications'
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
output aksManagedIdentityPrincipalId string = aks.identity.principalId  // For role assignments
