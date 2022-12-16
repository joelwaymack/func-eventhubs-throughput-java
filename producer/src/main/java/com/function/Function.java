package com.function;

import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

import java.util.Optional;
import java.util.Random;

public class Function {
    private int minBatchesPerTimer = 1;
    private int maxBatchesPerTimer = 1;
    private int minEventsPerBatch = 10;
    private int maxEventsPerBatch = 10;
    private int minValueForEvent = 5000;
    private int maxValueForEvent = 5000;
    private Random random = new Random();

    public Function() {
        minBatchesPerTimer = parseEnvInt("MinBatchesPerTimer", minBatchesPerTimer);
        maxBatchesPerTimer = parseEnvInt("MaxBatchesPerTimer", maxBatchesPerTimer);
        minEventsPerBatch = parseEnvInt("MinEventsPerBatch", minEventsPerBatch);
        maxEventsPerBatch = parseEnvInt("MaxEventsPerBatch", maxEventsPerBatch);
        minValueForEvent = parseEnvInt("MinValueForEvent", minValueForEvent);
        maxValueForEvent = parseEnvInt("MaxValueForEvent", maxValueForEvent);
    }

    @FunctionName("CreateEventBatchMessages")
    public HttpResponseMessage createEventBatchMessages(
            @HttpTrigger(name = "req", methods = { HttpMethod.GET,
                    HttpMethod.POST }, authLevel = AuthorizationLevel.ANONYMOUS) HttpRequestMessage<Optional<String>> request,
            @QueueOutput(name = "eventBatchMessage", queueName = "%MessageQueueName%", connection = "QueueStorage") OutputBinding<int[]> batchMessages,
            final ExecutionContext context) {
        context.getLogger().info("Batch creation request received.");

        // Get the number of batches to produce.
        final String query = request.getQueryParameters().get("batches");
        int batches = randomInt(minBatchesPerTimer, maxBatchesPerTimer);
        if (query != null && !query.isBlank()) {
            try {
                batches = Integer.parseInt(query);
            } catch (NumberFormatException e) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                        .body("Please pass a number on the query string as 'batches'").build();
            }
        }

        // Create a random array of messages.
        // The number is how many events will be generated in the message batch for Event Hubs.
        int[] messages = createRandomIntArray(batches, minEventsPerBatch, maxEventsPerBatch);
        batchMessages.setValue(messages);

        return request.createResponseBuilder(HttpStatus.OK).body("Started " + batches + " event batch producers.")
                .build();
    }

    @FunctionName("ProduceEventBatch")
    public void processEventBatchMessage(
            @QueueTrigger(name = "queueTrigger", queueName = "%MessageQueueName%", connection = "QueueStorage") int eventsInBatch,
            @EventHubOutput(name = "ehOutput", eventHubName = "%EventHubName%", connection = "EventHubConnection") OutputBinding<int[]> eventHubOutput,
            final ExecutionContext context) {
        context.getLogger().info("Producing a batch of " + eventsInBatch + " events.");

        int[] events = createRandomIntArray(eventsInBatch, minValueForEvent, maxValueForEvent);

        eventHubOutput.setValue(events);
    }

    // Creates events every second.
    @FunctionName("CreateEventBatchMessagesTimer")
    public void createEventBatchMessagesTimer(
            @TimerTrigger(
                name = "batchTimerTrigger",
                schedule = "%TimerSchedule%") String timerInfo,
            @QueueOutput(name = "eventBatchMessage", queueName = "%MessageQueueName%", connection = "QueueStorage") OutputBinding<int[]> batchMessages,
            final ExecutionContext context) {
        int batches = randomInt(minBatchesPerTimer, maxBatchesPerTimer);
        int[] messages = createRandomIntArray(batches, minEventsPerBatch, maxEventsPerBatch);
        batchMessages.setValue(messages);
    }

    private int randomInt(int min, int max) {
        return min == max ? min : random.nextInt(max - min) + min;
    }
    
    private int[] createRandomIntArray(int count, int min, int max) {
        int[] array = new int[count];
        for (int i = 0; i < count; i++) {
            array[i] = randomInt(min, max);
        }

        return array;
    }

    private int parseEnvInt(String name, int defaultValue) {
        int value = defaultValue;
        String valueString = System.getenv(name);

        if (valueString == null || valueString.isBlank()) {
            try {
                value = Integer.parseInt(valueString);
                value = value < 1 ? defaultValue : value;
            } catch (NumberFormatException e) {
                System.out.println("Failed to parse environment variable " + name + " as an integer.");
            }
        }
        
        return value;
    }
}
