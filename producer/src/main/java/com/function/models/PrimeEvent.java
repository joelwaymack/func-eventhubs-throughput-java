package com.function.models;

import java.util.List;

public class PrimeEvent {
    private int primesToCalculate;
    private List<String> payload;
    
    public int getPrimesToCalculate() {
        return primesToCalculate;
    }

    public void setPrimesToCalculate(int primesToCalculate) {
        this.primesToCalculate = primesToCalculate;
    }
    
    public List<String> getPayload() {
        return payload;
    }

    public void setPayload(List<String> payload) {
        this.payload = payload;
    }
}
