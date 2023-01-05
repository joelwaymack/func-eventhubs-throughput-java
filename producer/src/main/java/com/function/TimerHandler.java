package com.function;

import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

public class TimerHandler extends BaseHandler {
    private int minBatchesPerTimer = 1;
    private int maxBatchesPerTimer = 1;

    public TimerHandler() {
        minBatchesPerTimer = parseEnvInt("MinBatchesPerTimer", minBatchesPerTimer);
        maxBatchesPerTimer = parseEnvInt("MaxBatchesPerTimer", maxBatchesPerTimer);
    }

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
}
