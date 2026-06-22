// =============================================================
// appgateway.bicep - Application Gateway with WAF
// =============================================================
// Application Gateway = Azure's Layer 7 load balancer (like AWS ALB)
// WAF = Web Application Firewall - protects against OWASP Top 10 attacks
//       (SQL injection, XSS, etc.)
//
// Traffic flow:
//   Internet → App Gateway (presentation subnet) → NGINX Ingress (application subnet)
//            → Hello World pods (application subnet)
//
// App Gateway sits in snet-presentation and routes to NGINX Ingress Controller
// NGINX Ingress then routes to the correct Kubernetes service/pod
//
// Cost warning: App Gateway WAF_v2 minimum ~$0.448/hour = ~$10/day
// We deploy it but you can delete after testing to save credits
//
// Naming: agw-aks-lab-dev
// =============================================================

param location string
param environment string
param projectName string

@description('Resource ID of presentation subnet - App Gateway goes here')
param presentationSubnetId string

@description('Enable WAF policy. Set false to use Standard_v2 (cheaper) for initial testing')
param enableWaf bool = true

// ------ PUBLIC IP FOR APP GATEWAY ------
// App Gateway needs a public IP - this is the IP users type in their browser
// Standard SKU required for App Gateway v2
resource appGwPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-agw-aks-lab-${environment}'
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
  sku: {
    name: 'Standard'    // Must be Standard for App Gateway v2
  }
  properties: {
    publicIPAllocationMethod: 'Static'    // Static = IP never changes (important for DNS)
  }
}

// ------ WAF POLICY ------
// Defines the WAF rules - OWASP 3.2 ruleset
// Only created when enableWaf = true
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-09-01' = if (enableWaf) {
  name: 'waf-aks-lab-${environment}'
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
  properties: {
    policySettings: {
      mode: 'Detection'         // Detection = log threats but don't block (safe for learning)
                                // Prevention = actively block threats (use in production)
      state: 'Enabled'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'   // OWASP Top 10 ruleset version 3.2
        }
      ]
    }
  }
}

// ------ APPLICATION GATEWAY ------
resource appGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: 'agw-aks-lab-${environment}'
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
  properties: {

    sku: {
      name: enableWaf ? 'WAF_v2' : 'Standard_v2'   // WAF_v2 if WAF enabled, else Standard_v2
      tier: enableWaf ? 'WAF_v2' : 'Standard_v2'
      capacity: 1                                    // 1 instance = minimum (enough for learning)
    }

    // Link WAF policy if enabled
    firewallPolicy: enableWaf ? { id: wafPolicy.id } : null

    // ------ FRONTEND ------
    // The public-facing side of App Gateway
    gatewayIPConfigurations: [
      {
        name: 'appgw-ip-config'
        properties: {
          subnet: {
            id: presentationSubnetId    // App Gateway lives in snet-presentation
          }
        }
      }
    ]

    frontendIPConfigurations: [
      {
        name: 'appgw-frontend-ip'
        properties: {
          publicIPAddress: {
            id: appGwPip.id             // The public IP users connect to
          }
        }
      }
    ]

    frontendPorts: [
      {
        name: 'port-80'
        properties: {
          port: 80    // HTTP for now - in production add port 443 (HTTPS) with SSL cert
        }
      }
    ]

    // ------ BACKEND ------
    // Points to NGINX Ingress Controller service IP
    // NGINX Ingress gets a private IP from AKS LoadBalancer (internal)
    // We use a placeholder IP here - updated after AKS + NGINX are deployed
    backendAddressPools: [
      {
        name: 'nginx-ingress-backend'
        properties: {
          backendAddresses: [
            {
              // Placeholder - replace with actual NGINX Ingress internal IP after deployment
              // Run: kubectl get svc -n ingress-nginx
              ipAddress: '10.0.2.100'
            }
          ]
        }
      }
    ]

    backendHttpSettingsCollection: [
      {
        name: 'http-settings'
        properties: {
          port: 80
          protocol: 'Http'
          requestTimeout: 30
          pickHostNameFromBackendAddress: false
          hostName: 'hello-world.local'   // Must match NGINX Ingress host rule
        }
      }
    ]

    // ------ ROUTING RULE ------
    // Connects frontend (public IP:80) to backend (NGINX Ingress)
    httpListeners: [
      {
        name: 'http-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'agw-aks-lab-${environment}', 'appgw-frontend-ip')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'agw-aks-lab-${environment}', 'port-80')
          }
          protocol: 'Http'
        }
      }
    ]

    requestRoutingRules: [
      {
        name: 'routing-rule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'agw-aks-lab-${environment}', 'http-listener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'agw-aks-lab-${environment}', 'nginx-ingress-backend')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'agw-aks-lab-${environment}', 'http-settings')
          }
        }
      }
    ]

  }
}

// ------ OUTPUTS ------
output appGatewayName string = appGateway.name
output appGatewayPublicIp string = appGwPip.properties.ipAddress
output appGatewayId string = appGateway.id
