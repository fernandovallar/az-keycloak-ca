@description('Location for all resources')
param location string = resourceGroup().location

@description('PostgreSQL server name')
param serverName string = 'kc-postgres-dev-eus'

@description('Administrator login for PostgreSQL')
param administratorLogin string = 'kcadmin'

@description('Administrator password for PostgreSQL')
@secure()
param administratorLoginPassword string

@description('PostgreSQL version')
@allowed([
  '12'
  '13'
  '14'
  '15'
  '16'
])
param version string = '15'

@description('SKU name for the server')
param skuName string = 'Standard_B2s'

@description('SKU tier')
param skuTier string = 'Burstable'

@description('Storage size in GB')
param storageSizeGB int = 32

@description('Enable public access')
param publicNetworkAccess string = 'Enabled'

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: version
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      publicNetworkAccess: publicNetworkAccess
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
    }
  }
}

// Create Keycloak database
resource keycloakDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresServer
  name: 'keycloak'
  properties: {
    charset: 'utf8'
    collation: 'en_US.utf8'
  }
}

// Firewall rule to allow Azure services
resource allowAzureServices 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = {
  parent: postgresServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Output connection information
output serverFQDN string = postgresServer.properties.fullyQualifiedDomainName
output databaseName string = keycloakDatabase.name
output connectionString string = 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=${keycloakDatabase.name};Username=${administratorLogin};Password=${administratorLoginPassword};Port=5432;SSL Mode=Require;'
output jdbcUrl string = 'jdbc:postgresql://${postgresServer.properties.fullyQualifiedDomainName}:5432/${keycloakDatabase.name}?sslmode=require'
