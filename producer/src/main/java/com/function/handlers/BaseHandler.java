package com.function.handlers;

import java.util.Random;

public class BaseHandler {
    private Random random = new Random();

    protected int randomInt(int min, int max) {
        return max <= min? min : random.nextInt(max - min) + min;
    }
    
    protected int[] createRandomIntArray(int count, int min, int max) {
        int[] array = new int[count];
        for (int i = 0; i < count; i++) {
            array[i] = randomInt(min, max);
        }

        return array;
    }

    protected static int parseEnvInt(String name, int defaultValue) {
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
