param location string = resourceGroup().location
param name string = deployment().name
param eventHubCapacity int = 1
param eventHubPartitionCount int = 8
param eventHubBatchSize int = 10
param eventHubPrefetchCount int = 300
param minBatchesPerTimer int = 1
param maxBatchesPerTimer int = 1
param minEventsPerBatch int = 10
param maxEventsPerBatch int = 10
param minValueForEvent int = 200
param maxValueForEvent int = 500
param eventHubTier string = 'Basic'

var uniqueId = toLower(uniqueString(subscription().subscriptionId, resourceGroup().id, name))

// Storage Accounts
resource producerStorage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: '${uniqueId}producer'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS'
  }
  properties: {
    accessTier: 'Hot'
  }
}

resource queueStorageService 'Microsoft.Storage/storageAccounts/queueServices@2022-05-01' = {
  name: 'default'
  parent: producerStorage
}

resource eventBatchQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2022-05-01' = {
  name: 'event-batch-queue'
  parent: queueStorageService
}

resource timerElapsedQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2022-05-01' = {
  name: 'timer-elapsed-queue'
  parent: queueStorageService
}

resource consumerStorage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: '${uniqueId}consumer'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS'
  }
  properties: {
    accessTier: 'Hot'
  }
}

// Log Analytics Workspace
resource log 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${name}-${uniqueId}-log'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Application Insights Instances
resource producerAi 'Microsoft.Insights/components@2020-02-02' = {
  name: '${name}-producer-${uniqueId}-ai'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: log.id
  }
}

resource consumerAi 'Microsoft.Insights/components@2020-02-02' = {
  name: '${name}-consumer-${uniqueId}-ai'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: log.id
  }
}

// Event Hub
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: '${name}-${uniqueId}-eh-ns'
  location: location
  sku: {
    name: eventHubTier
    tier: eventHubTier
    capacity: eventHubCapacity
  }
  properties: {
    zoneRedundant: eventHubTier == 'Premium' ? true : false
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: 'topic1'
  properties: {
    partitionCount: eventHubPartitionCount
    messageRetentionInDays: 1
  }
}

resource eventHubProducerAuthorizationRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-11-01' = {
  parent: eventHub
  name: 'producer-func'
  properties: {
    rights: [
      'Send'
    ]
  }
}

resource eventHubConsumerAuthorizationRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-11-01' = {
  parent: eventHub
  name: 'consumer-func'
  properties: {
    rights: [
      'Listen'
    ]
  }
}

// Function App Plans
resource producerFuncPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${name}-producer-func-plan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource consumerFuncPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${name}-consumer-func-plan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

// Function Apps
resource producerFunc 'Microsoft.Web/sites@2021-03-01' = {
  name: '${name}-producer-${uniqueId}-func'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: producerFuncPlan.id
    siteConfig: {
      javaVersion: '11'
      functionAppScaleLimit: null
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${producerStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${producerStorage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${producerStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${producerStorage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('${name}-producer-func')
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: producerAi.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: producerAi.properties.ConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'java'
        }
        {
          name: 'EventHubConnection'
          value: eventHubProducerAuthorizationRule.listKeys().primaryConnectionString
        }
        {
          name: 'QueueStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${producerStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${producerStorage.listKeys().keys[0].value}'
        }
        {
          name: 'TimerElapsedQueue'
          value: timerElapsedQueue.name
        }
        {
          name: 'EventBatchQueue'
          value: eventBatchQueue.name
        }
        {
          name: 'EventHubName'
          value: eventHub.name
        }
        {
          name: 'MinBatchesPerTimer'
          value: string(minBatchesPerTimer)
        }
        {
          name: 'MaxBatchesPerTimer'
          value: string(maxBatchesPerTimer)
        }
        {
          name: 'MinEventsPerBatch'
          value: string(minEventsPerBatch)
        }
        {
          name: 'MaxEventsPerBatch'
          value: string(maxEventsPerBatch)
        }
        {
          name: 'MinValueForEvent'
          value: string(minValueForEvent)
        }
        {
          name: 'MaxValueForEvent'
          value: string(maxValueForEvent)
        }
        {
          name: 'TimerSchedule'
          value: '* * * * * *'
        }
        {
          name: 'SCALE_CONTROLLER_LOGGING_ENABLED'
          value: 'AppInsights:Verbose'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

resource producerFuncLog 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'producerFuncLog'
  scope: producerFunc
  properties: {
    logAnalyticsDestinationType: null
    logs: [
      {
        category: 'FunctionAppLogs'
        categoryGroup: null
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    workspaceId: log.id
  }
}

resource consumerFunc 'Microsoft.Web/sites@2021-03-01' = {
  name: '${name}-consumer-${uniqueId}-func'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: consumerFuncPlan.id
    siteConfig: {
      javaVersion: '11'
      functionAppScaleLimit: null
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${consumerStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${consumerStorage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${consumerStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${consumerStorage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('${name}-consumer-func')
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: consumerAi.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: consumerAi.properties.ConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'java'
        }
        {
          name: 'EventHubConnection'
          value: eventHubConsumerAuthorizationRule.listKeys().primaryConnectionString
        }
        {
          name: 'EventHubName'
          value: eventHub.name
        }
        {
          name: 'EventHubConsumerGroup'
          value: '$Default'
        }
        {
          name: 'SCALE_CONTROLLER_LOGGING_ENABLED'
          value: 'AppInsights:Verbose'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'AzureFunctionsJobHost__extensions__eventHubs__eventProcessorOptions__maxBatchSize'
          value: string(eventHubBatchSize)
        }
        {
          name: 'AzureFunctionsJobHost__extensions__eventHubs__eventProcessorOptions__prefetchCount'
          value: string(eventHubPrefetchCount)
        }
      ]
    }
  }
}

resource consumerFuncLog 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'consumerFuncLog'
  scope: consumerFunc
  properties: {
    logAnalyticsDestinationType: null
    logs: [
      {
        category: 'FunctionAppLogs'
        categoryGroup: null
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    workspaceId: log.id
  }
}
