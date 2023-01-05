package com.function;

import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

public class EventBatchHandler extends BaseHandler {
    private int minValueForEvent = 5000;
    private int maxValueForEvent = 5000;

    public EventBatchHandler() {
        minValueForEvent = parseEnvInt("MinValueForEvent", minValueForEvent);
        maxValueForEvent = parseEnvInt("MaxValueForEvent", maxValueForEvent);
    }
    
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
}
