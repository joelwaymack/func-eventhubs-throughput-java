package com.function;

import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

public class BatchMessageHandler extends BaseHandler {
    private int minEventsPerBatch = 10;
    private int maxEventsPerBatch = 10;

    public BatchMessageHandler() {
        minEventsPerBatch = parseEnvInt("MinEventsPerBatch", minEventsPerBatch);
        maxEventsPerBatch = parseEnvInt("MaxEventsPerBatch", maxEventsPerBatch);
    }

    @FunctionName("ProduceEventBatchMessages")
    public void produceEventBatchMessages (
        @QueueTrigger(name = "messageQueueIn", queueName = "%TimerElapsedQueue%", connection = "QueueStorage") int batches,
        @QueueOutput(name = "messageQueueOut", queueName = "%EventBatchQueue%", connection = "QueueStorage") OutputBinding<int[]> eventBatchMessages,
        final ExecutionContext context
    ) {
        eventBatchMessages.setValue(createRandomIntArray(batches, minEventsPerBatch, maxEventsPerBatch));
        context.getLogger().info("Created " + batches + " messages for batches of events.");
    }
}
