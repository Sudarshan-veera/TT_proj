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

## Pins

- `ui[7:0]`: 8-bit sensor sample
- `uio[3:0]`: anomaly limit, `uio[4]`: n-shot mode, `uio[6:5]`: sensitivity, `uio[7]`: hold mode
- `uo[0]`: ALERT, `uo[1]`: READY, `uo[2]`: LOCKED, `uo[7:3]`: top bits of the window mean

## How to test

Simulation uses cocotb and Icarus Verilog: `cd test && pip install -r requirements.txt && make`.
The testbench (`test/test.py`) feeds a steady signal, then a spike, and checks ALERT.

## External hardware

None needed. Drive `ui` with switches or a microcontroller and read the outputs on LEDs.
