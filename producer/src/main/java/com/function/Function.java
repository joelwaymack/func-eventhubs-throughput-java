package com.function;

import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

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

    // Creates a message for the number of batches to create.
    @FunctionName("BatchTimer")
    public void batchTimer(
        @TimerTrigger(name = "timer", schedule = "%TimerSchedule%") String timerInfo,
        @QueueOutput(name = "timerQueueOut", queueName = "%TimerElapsedQueue%", connection = "QueueStorage") OutputBinding<Integer> message,
        final ExecutionContext context
    ) {
        int batches = randomInt(minBatchesPerTimer, maxBatchesPerTimer);
        message.setValue(batches);
        context.getLogger().info("New message to create " + batches + " batches.");
    }
    
    // Creates a message for the number of events to create in each batch.
    @FunctionName("ProduceEventBatchMessages")
    public void produceEventBatchMessages (
        @QueueTrigger(name = "messageQueueIn", queueName = "%TimerElapsedQueue%", connection = "QueueStorage") int batches,
        @QueueOutput(name = "messageQueueOut", queueName = "%EventBatchQueue%", connection = "QueueStorage") OutputBinding<int[]> eventBatchMessages,
        final ExecutionContext context
    ) {
        eventBatchMessages.setValue(createRandomIntArray(batches, minEventsPerBatch, maxEventsPerBatch));
        context.getLogger().info("Created " + batches + " messages for batches of events.");
    }
    
    // Creates each batch of events.
    @FunctionName("ProduceEventBatch")
    public void produceEventBatch(
        @QueueTrigger(name = "eventQueueIn", queueName = "%EventBatchQueue%", connection = "QueueStorage") int eventsInBatch,
        @EventHubOutput(name = "eventHubOut", eventHubName = "%EventHubName%", connection = "EventHubConnection") OutputBinding<int[]> eventHubOutput,
        final ExecutionContext context
    ) {
        int[] events = createRandomIntArray(eventsInBatch, minValueForEvent, maxValueForEvent);
        eventHubOutput.setValue(events);
        context.getLogger().info("Produced a batch of " + eventsInBatch + " events.");
    }

    private int randomInt(int min, int max) {
        return max <= min? min : random.nextInt(max - min) + min;
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

        if (valueString != null && !valueString.isBlank()) {
            try {
                value = Integer.parseInt(valueString);
                value = value < 1 ? defaultValue : value;
            } catch (NumberFormatException e) {
                System.out.println("Failed to parse environment variable " + name + " as an integer.");
            }
        } else {
            System.out.println("Environment variable " + name + " not set.");
        }
        
        System.out.println("Using " + name + " = " + value);
        return value;
    }
}
