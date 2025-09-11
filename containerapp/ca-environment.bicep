@description('Location for all resources')
param location string = resourceGroup().location

@description('Container Apps Environment name')
param environmentName string = 'kc-cae-dev-eus'

@description('Log Analytics workspace name')
param logAnalyticsWorkspaceName string = 'kc-logs-dev-eus'

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

// Outputs
output environmentId string = containerAppsEnvironment.id
output environmentName string = containerAppsEnvironment.name
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
