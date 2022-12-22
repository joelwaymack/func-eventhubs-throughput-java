param location string
param name string

var uniqueId = toLower(uniqueString(subscription().subscriptionId, resourceGroup().id))

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

resource storageQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2022-05-01' = {
  name: 'event-batch-queue'
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
    name: 'Basic'
    tier: 'Basic'
    capacity: 1
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: 'topic1'
  properties: {
    partitionCount: 8
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
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'java'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: '11'
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
          name: 'MessageQueueName'
          value: storageQueue.name
        }
        {
          name: 'EventHubName'
          value: eventHub.name
        }
        {
          name: 'MinBatchesPerTimer'
          value: '1'
        }
        {
          name: 'MaxBatchesPerTimer'
          value: '1'
        }
        {
          name: 'MinEventsPerBatch'
          value: '10'
        }
        {
          name: 'MaxEventsPerBatch'
          value: '10'
        }
        {
          name: 'MinValueForEvent'
          value: '200'
        }
        {
          name: 'MaxValueForEvent'
          value: '500'
        }
        {
          name: 'TimerSchedule'
          value: '* * * * * *'
        }
      ]
    }
  }
}

// Function Apps
resource consumerFunc 'Microsoft.Web/sites@2021-03-01' = {
  name: '${name}-consumer-${uniqueId}-func'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: consumerFuncPlan.id
    siteConfig: {
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
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'java'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: '11'
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
      ]
    }
  }
}
