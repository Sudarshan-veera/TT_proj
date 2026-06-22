<!--- docs/info.md -->

## How it works

A **sliding window anomaly detector** that monitors 8-bit sensor data in real time.

- Maintains a 4-sample shift register (circular buffer)
- Computes the mean of the window using a running sum + right-shift (÷4)
- On every clock cycle, computes |new_sample − mean|
- If the deviation exceeds the programmable threshold (set via `uio` pins), raises **ALERT**

### Algorithm 
### mean = (w[0] + w[1] + w[2] + w[3]) >> 2
### if |input - mean| > threshold: ALERT=1
