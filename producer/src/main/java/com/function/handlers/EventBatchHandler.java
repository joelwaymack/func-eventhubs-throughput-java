package com.function.handlers;

import java.util.ArrayList;
import java.util.List;

import com.function.models.PrimeEvent;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

public class EventBatchHandler extends BaseHandler {
    private static int minValueForEvent = 25;
    private static int maxValueForEvent = 25;
    private static int payloadKbSize = 1;
    private static List<String> payload;

    static {
        minValueForEvent = parseEnvInt("MinValueForEvent", minValueForEvent);
        maxValueForEvent = parseEnvInt("MaxValueForEvent", maxValueForEvent);
        payloadKbSize = parseEnvInt("PayloadKbSize", payloadKbSize);

        payload = new ArrayList<String>(payloadKbSize);

        // 16 * 64 = 1024 Bytes
        for (int i = 0; i < payloadKbSize * 16; i++) {
            payload.add("0123456789012345678901234567890123456789012345678901234567890123");
        }
    }
    
    @FunctionName("ProduceEventBatch")
    public void produceEventBatch(
        @QueueTrigger(name = "eventQueueIn", queueName = "%EventBatchQueue%", connection = "QueueStorage") int eventsInBatch,
        @EventHubOutput(name = "eventHubOut", eventHubName = "%EventHubName%", connection = "EventHubConnection") OutputBinding<List<PrimeEvent>> eventHubOutput,
        final ExecutionContext context
    ) {
        List<PrimeEvent> batch = new ArrayList<PrimeEvent>(eventsInBatch);
        for (int i = 0; i < eventsInBatch; i++) {
            PrimeEvent event = new PrimeEvent();
            event.setPrimesToCalculate(randomInt(minValueForEvent, maxValueForEvent));
            event.setPayload(payload);
            batch.add(event);
        }
        eventHubOutput.setValue(batch);
        context.getLogger().info("Produced a batch of " + eventsInBatch + " events.");
    }
}
