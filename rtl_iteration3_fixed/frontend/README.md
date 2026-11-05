# Frontend

## Description
The frontend subsystem is responsible for fetching and decoding instructions, and predicting branches.

## Working
It consists of the instruction fetch unit (rv_fetch), branch predictor (rv_bpu), decode unit (rv_decode), and instruction cache (rv_icache). It fetches instructions from memory, aligns them, decodes them into micro-ops, and passes them to the backend.

## Need
Critical for keeping the execution pipeline fed with instructions. High performance requires accurate branch prediction and efficient caching.

## Steps to Use / Integrate
1. Instantiate rv_fetch and rv_decode.
2. Connect to the instruction cache and memory interfaces.
3. Verify branch prediction accuracy and fetch bandwidth.
