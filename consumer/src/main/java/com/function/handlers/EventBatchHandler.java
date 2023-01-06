package com.function.handlers;

import com.function.models.PrimeEvent;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;
import com.google.gson.*;

public class EventBatchHandler {
    @FunctionName("ConsumeEvents")
    public void run(
            @EventHubTrigger(
                name = "events",
                eventHubName = "%EventHubName%",
                connection = "EventHubConnection",
                consumerGroup = "%EventHubConsumerGroup%",
                dataType = "string",
                cardinality = Cardinality.MANY)
                String[] stringEvents,
            final ExecutionContext context) {
        context.getLogger().info("Java Event Hub trigger function executed with " + stringEvents.length + " events.");
        Gson gson = new Gson();

        for (String stringEvent : stringEvents) {
            PrimeEvent event  = gson.fromJson(stringEvent, PrimeEvent.class);
            calculatePrimes(event.getPrimesToCalculate());
        }
    }
    
    private int calculatePrimes(int numberOfPrimes) {
        int number = 2;
        int count = 0;
        while (count < numberOfPrimes) {
            if (isPrimeNumber(number)) {
                count++;
            }
            number++;
        }
        
        return number;
    }

    private boolean isPrimeNumber(int number) {
        for (int i = 2; i <= number / 2; i++) {
            if (number % i == 0) {
                return false;
            }
        }
        
        return true;
    }
}
