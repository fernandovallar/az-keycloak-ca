targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment prefix (dev, test, prod)')
param environment string = 'dev'

@description('Keycloak admin password')
@secure()
param keycloakAdminPassword string

@description('PostgreSQL admin password')
@secure()
param postgresAdminPassword string

@description('Custom domain for Keycloak (optional)')
param customDomain string = ''

// Variables for naming
var namingPrefix = 'kc-${environment}-${substring(location, 0, 3)}'
var postgresServerName = '${namingPrefix}-postgres'
var containerAppEnvName = '${namingPrefix}-cae'
var logAnalyticsName = '${namingPrefix}-logs'
var keycloakAppName = '${namingPrefix}-app'

// PostgreSQL Flexible Server
module postgresModule 'database/main.bicep' = {
  name: 'postgres-deployment'
  params: {
    location: location
    serverName: postgresServerName
    administratorLogin: 'kcadmin'
    administratorLoginPassword: postgresAdminPassword
    version: '15'
    skuName: 'Standard_B2s'
    skuTier: 'Burstable'
    storageSizeGB: 128
    publicNetworkAccess: 'Enabled'
  }
}

// Container Apps Environment
module containerAppEnvModule 'containerapp/ca-environment.bicep' = {
  name: 'containerapp-env-deployment'
  params: {
    location: location
    environmentName: containerAppEnvName
    logAnalyticsWorkspaceName: logAnalyticsName
  }
}

// Keycloak Container App
module keycloakModule 'containerapp/ca-keycloak.bicep' = {
  name: 'keycloak-deployment'
  params: {
    location: location
    managedEnvironmentId: containerAppEnvModule.outputs.environmentId
    containerAppName: keycloakAppName
    keycloakAdminUser: 'admin'
    keycloakAdminPassword: keycloakAdminPassword
    dbHost: postgresModule.outputs.serverFQDN
    dbName: 'keycloak'
    dbUser: 'kcadmin'
    dbPassword: postgresAdminPassword
    customHostname: customDomain
  }
  dependsOn: [
    postgresModule
    containerAppEnvModule
  ]
}

// Outputs
output keycloakUrl string = keycloakModule.outputs.keycloakUrl
output keycloakAdminUrl string = keycloakModule.outputs.keycloakAdminUrl
output postgresServerFQDN string = postgresModule.outputs.serverFQDN
output managedIdentityPrincipalId string = keycloakModule.outputs.managedIdentityPrincipalId

// Instructions for next steps
output instructions object = {
  step1: 'Access Keycloak admin console at: ${keycloakModule.outputs.keycloakAdminUrl}'
  step2: 'Username: admin'
  step3: 'Password: [The password you provided]'
  step4: 'Create a new realm for your applications'
  step5: 'Configure EntraID integration using the guides provided'
}
