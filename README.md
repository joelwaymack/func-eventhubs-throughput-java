# Java Functions Event Hub Throughput

This is an example of a high-throughput event processing scenario with Java Functions and an Azure Event Hub.

## Solution Overview

High throughput event processing pipelines are prime candidates for Azure Functions and Event Hubs. In these scenarios, event produces can stream events into an Event Hub and Azure Functions can retrieve batches of those events and process them.

In our scenario, Azure Functions are being used to simulate the event producer as well as processing the events from the Event Hub.

![Image](assets/simple.drawio.svg)

To achieve high throughput in the production of events, two Functions are used in the Producer Function App.

The first, is a timer trigger that generates a number of batch messages and puts them in an Azure Storage Queue. Timer triggers will not execute on schedule, even if the timer has elapsed, when a previous execution of the timer-tiggered Function is still running. Also, timer triggers only fire once per Function App regardless of the number of instances of the Function App running the the hosting plan. To get around these issues if we want to generate a high volume of events, we create batch messages.

The second Function is triggered off of unprocessed Azure Storage Queue messages. When invoked, it generates the event batch and then send the batch to the Event Hub. Due to the configuration of the underlying Event Hub SDK, events are batched to a single partition in the Event Hub per Function execution when using an output binding. Therefore, a high number of batch jobs are needed to saturate all Event Hub partitions.

The consumer Function App is triggered by unprocessed (non-checkpointed) events in an Event Hub partition. The consumer Function App can scale out to the number of partitions in the Event Hub to maximize processing throughput since one instance can lock 1 to many partitions for processing.

![Image](assets/data-flow.drawio.svg)

## Settings

Each Function App requires a number of App Settings to work properly.

1. Producer
    * EventHubConnection - Connection string for the Event Hub with "Send" claim/permissions
    * QueueStorage - Connection string for the Storage Account to create the message queue in
    * MessageQueueName - The message queue name. If it does not exist, it will be created
    * EventHubName - The name of the Event Hub (not the namespace)
    * MinBatchesPerTimer - Minimum number of batches per timer execution (recommended to be the number of Event Hub partitions)
    * MaxBatchesPerTimer - Maximum number of batches per timer execution
    * MinEventsPerBatch - Minimum number of events per batch (recommended to be close to the batch size for the processor Function)
    * MaxEventsPerBatch - Maximum number of events per batch
    * MinValueForEvent - Minimum value to send for each event (this is how many prime numbers to calculate for this event)
    * MaxValueForEvent": Maximum value to send for each event
    * TimerSchedule - The timer schedule ( recommended to be every second "* * * * * *")
1. Consumer
    * EventHubConnection - Connection string for the Event Hub with "Receive" claim/permissions
    * EventHubConsumerGroup - The consumer group name to use when reading from the Event Hub
    * EventHubName - The name of the Event Hub (not the namespace)

## Deployment

All of the code and infrastructure files are in this repository for a deployment of this solution. Ensure you are logged in to the Azure CLI before running the following Powershell commands.

1. Deploy the infrastructure

    ```powershell
    $rg = "java-eh-throughput-rg"
    az group create --name $rg --location eastus
    az deployment group create --template-file ./infrastructure/main.bicep --name event-hub-throughput --resource-group $rg
    ```

    * Note: To set up massive throughput, use the following instead:
  
        ```powershell
        $rg = "java-eh-high-throughput-rg"
        az group create --name $rg --location eastus
        cd ./infrastructure
        az deployment group create --template-file ./main.bicep --name event-hub-high-throughput --parameters @high-throughput.parameters.json --resource-group $rg
        cd ..
        ```

1. Build and deploy the consumer Function App

    ```powershell
    cd ./consumer
    mvn clean package
    compress-archive -Path './target/azure-functions/consumer*/*' -DestinationPath './target/deploy.zip' -Force
    $cfunc = az functionapp list --query "([?resourceGroup=='$rg' && contains(name, 'consumer')])[0].name"
    az functionapp deployment source config-zip -g $rg -n $cfunc --src ./target/deploy.zip
    cd ..
    ```

1. Build and deploy the producer Function App

    ```powershell
    cd ./producer
    mvn clean package
    compress-archive -Path './target/azure-functions/producer*/*' -DestinationPath './target/deploy.zip' -Force
    $pfunc = az functionapp list --query "([?resourceGroup=='$rg' && contains(name, 'producer')])[0].name"
    az functionapp deployment source config-zip -g $rg -n $pfunc --src ./target/deploy.zip
    cd ..
    ```

## Change Settings

You can change the settings in the producer and consumer to increase the overall event throughput. Running a lot more events through this processing pipeline will require an increase in throughput units in the Event Hub Namespace so that it has enough processing power. The producer and consumer Function Apps are set to scale out to the maximum number of instances automatically. For the producer, this is dependent on the max scale out settings for a Windows Function App Consumption plan. For the consumer, this is limited to the number of partitions (8 set in the infrastructure deployment files) in the Event Hub.

Basic tier Event Hubs cannot have their partition count changed after creation. If you want to increase the number of partitions, stop both the Function Apps, delete the current Event Hub (topic1), and recreate it with the desired number of partitions. Then restart the Function Apps.

## Clean up resources

Don't forget to clean up your resources. While this solution runs on the lowest tier of resources, it can scale out and incur significant cost over time.

```powershell
az group delete --name $rg --yes
```
