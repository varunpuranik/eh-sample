param location string = resourceGroup().location
param environmentName string = 'e4k-cloud-edge-sample-${uniqueString(resourceGroup().id)}'


// Event Hub settings
param eventHubNamespace string = 'eh-${uniqueString(resourceGroup().id)}'
param eventHubD2CName string = 'e4k-d2c'
param eventHubC2DName string = 'e4k-c2d'
param eventHubD2CConsumerGroup string = 'aca-d2c'
param eventHubC2DConsumerGroup string = 'aca-c2d'
param storageAccountName string = 'stor${uniqueString(resourceGroup().id)}'

// Container Apps settings
param eventHubImage string = 'veyalla/eh-test:0.0.1'
param registry string = 'docker.io'
param registryUsername string = ''
@secure()
param registryPassword string = ''


var eventHubConnectionSecretName = 'event-hub-connection-string'
var storageConnectionSecretName = 'storage-connection-string'
var registryPasswordPropertyName = 'registry-password'
var storageLeaseBlobName = 'aca-leases'

// Container Apps Environment (environment.bicep)
module environment 'environment.bicep' = {
  name: 'container-app-environment'
  params: {
    environmentName: environmentName
    location: location
  }
}


module eventHub 'eventhub.bicep' = {
  name: 'eventhub'
  params: {
    eventHubNamespaceName: eventHubNamespace
    eventHubD2CName: eventHubD2CName
    eventHubC2DName: eventHubC2DName
    consumerGroupD2CName: eventHubD2CConsumerGroup
    consumerGroupC2DName: eventHubC2DConsumerGroup
    storageAccountName: storageAccountName
    storageLeaseBlobName: storageLeaseBlobName
  }
}

resource ehContainerApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: 'event-hub-app'
  location: location
  properties: {
    managedEnvironmentId: environment.outputs.environmentId
    configuration: {
      activeRevisionsMode: 'single'
      secrets: [
        {
          name: registryPasswordPropertyName
          value: registryPassword
        }
        {
          name: eventHubConnectionSecretName
          value: eventHub.outputs.eventHubD2CConnectionString
        }
        {
          name: storageConnectionSecretName
          value: eventHub.outputs.storageConnectionString
        }
      ]
      registries: [
        {
          server: registry
          username: registryUsername
          passwordSecretRef: registryPasswordPropertyName
        }
      ]
    }
    template: {
      containers: [
        {
          image: eventHubImage
          name: 'event-hub-app'
          env: [
            {
              name: 'EVENTHUB_D2C_CONNECTION_STRING'
              secretRef: eventHubConnectionSecretName
            }
            {
              name: 'EVENTHUB_D2C_NAME'
              value: eventHubD2CName
            }
	          {
              name: 'EVENTHUB_C2D_NAME'
              value: eventHubC2DName
            }
            {
              name: 'EVENTHUB_D2C_CONSUMER_GROUP'
              value: eventHubD2CConsumerGroup
            }
            {
              name: 'EVENTHUB_C2D_CONSUMER_GROUP'
              value: eventHubC2DConsumerGroup
            }
            {
              name: 'STORAGE_CONNECTION_STRING'
              secretRef: storageConnectionSecretName
            }
            {
              name: 'STORAGE_BLOB_NAME'
              value: storageLeaseBlobName
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
    }
  }
}
