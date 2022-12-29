package com.function;

import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

public class Function {
    @FunctionName("ConsumeEvents")
    public void run(
            @EventHubTrigger(
                name = "events",
                eventHubName = "%EventHubName%",
                connection = "EventHubConnection",
                consumerGroup = "%EventHubConsumerGroup%",
                dataType = "string",
                cardinality = Cardinality.MANY)
                String[] events,
            final ExecutionContext context) {
        context.getLogger().info("Java Event Hub trigger function executed with " + events.length + " events.");
        for (String numberOfPrimesString : events) {
            try
            {
                int numberOfPrimes = Integer.parseInt(numberOfPrimesString);
                calculatePrimes(numberOfPrimes);
            } catch (NumberFormatException e) {
                context.getLogger().info("Could not parse " + numberOfPrimesString + " as an integer");
            }
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

    private boolean isPrimeNumber(int number){
            
        for(int i=2; i<=number/2; i++){
            if(number % i == 0){
                return false;
            }
        }
        return true;
    }
}
