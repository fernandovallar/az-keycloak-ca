@description('Location for all resources')
param location string = resourceGroup().location

@description('Container Apps Environment ID')
param managedEnvironmentId string

@description('Keycloak container app name')
param containerAppName string = 'kc-app-dev-eus'

@description('Keycloak admin username')
param keycloakAdminUser string = 'admin'

@description('Keycloak admin password')
@secure()
param keycloakAdminPassword string

@description('PostgreSQL connection details')
param dbHost string
param dbName string = 'keycloak'
param dbUser string
@secure()
param dbPassword string

@description('Custom hostname (leave empty for Azure default)')
param customHostname string = ''

// Container App with Keycloak
resource keycloakApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: managedEnvironmentId
    configuration: {
      activeRevisionsMode:'Single'
      ingress: {
        transport: 'Http'
        external: true
        targetPort: 8080
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        customDomains: customHostname != '' ? [
          {
            name: customHostname
            bindingType: 'SniEnabled'
          }
        ] : []
      }
      secrets: [
        {
          name: 'keycloak-admin-password'
          value: keycloakAdminPassword
        }
        {
          name: 'db-password'
          value: dbPassword
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'quay.io/keycloak/keycloak:26.0'
          name: 'keycloak'
          command: [
            'sh', '-c'
          ]
          args: [
            '/opt/keycloak/bin/kc.sh build && /opt/keycloak/bin/kc.sh start --optimized --http-port=8080 --http-management-port=9000'
          ]
          env: [
            // Database Configuration
            {
              name: 'KC_DB'
              value: 'postgres'
            }
            {
              name: 'KC_DB_URL'
              value: 'jdbc:postgresql://${dbHost}:5432/${dbName}?sslmode=require'
            }
            {
              name: 'KC_DB_USERNAME'
              value: dbUser
            }
            {
              name: 'KC_DB_PASSWORD'
              secretRef: 'db-password'
            }
            // Admin Configuration
            {
              name: 'KEYCLOAK_ADMIN'
              value: keycloakAdminUser
            }
            {
              name: 'KEYCLOAK_ADMIN_PASSWORD'
              secretRef: 'keycloak-admin-password'
            }
            // Network and Proxy Configuration
            {
              name: 'KC_HOSTNAME_STRICT'
              value: 'false'
            }
            {
              name: 'KC_HTTP_ENABLED'
              value: 'true'
            }
            {
              name: 'KC_HTTP_PORT'
              value: '8080'
            }
            {
              name: 'KC_PROXY_HEADERS'
              value: 'xforwarded'
            }
            {
              name: 'KC_PROXY'
              value: 'edge'
            }
            // Health and Metrics
            {
              name: 'KC_HEALTH_ENABLED'
              value: 'true'
            }
            {
              name: 'KC_METRICS_ENABLED'
              value: 'true'
            }
            // Production optimizations
            {
              name: 'KC_LOG_LEVEL'
              value: 'INFO'
            }
            {
              name: 'KC_CACHE'
              value: 'local'
            }
          ]
          resources: {
            cpu: json('2.0')
            memory: '4Gi'
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health/live'
                port: 9000
                scheme: 'HTTP'
              }
              initialDelaySeconds: 60
              periodSeconds: 30
              timeoutSeconds: 10
              failureThreshold: 10
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health/ready'
                port: 9000
                scheme: 'HTTP'
              }
              initialDelaySeconds: 60
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 8
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Outputs
output keycloakUrl string = 'https://${keycloakApp.properties.configuration.ingress.fqdn}'
output keycloakAdminUrl string = 'https://${keycloakApp.properties.configuration.ingress.fqdn}/admin'
output managedIdentityPrincipalId string = keycloakApp.identity.principalId
