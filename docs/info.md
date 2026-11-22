<!--- docs/info.md -->

## How it works

A sliding-window anomaly detector for 8-bit sensor data.

- A four-sample window (shift register) holds the most recent accepted samples.
- A running sum is kept, and the mean is the sum divided by four.
- Each new sample is compared with the mean of the previous four. If the absolute difference is larger than the threshold, the sample is an anomaly.
- The threshold is the mean shifted right by 1, 2, 3 or 4 bits (sensitivity 0 to 3), with a floor of 2.
- `READY` goes high once four samples are in the window. Before that no alert can fire.
- A normal alert latches `ALERT` and `LOCKED` until reset.
- In n-shot mode, an alert needs `anomaly_limit` anomalous samples in a row (a limit of 0 counts as 1). Anomalous samples are kept out of the window while they are being counted.
- In hold mode the window stops updating, so the mean stays fixed.

## Pins

| Pin | Meaning |
|---|---|
| `ui[7:0]` | 8-bit sensor sample |
| `uio[3:0]` | anomaly limit |
| `uio[4]` | n-shot mode |
| `uio[6:5]` | sensitivity |
| `uio[7]` | hold mode |
| `uo[0]` | ALERT |
| `uo[1]` | READY |
| `uo[2]` | LOCKED |
| `uo[7:3]` | top 5 bits of the window mean |

All bidirectional pins are used as inputs.

## How to test

Simulation uses cocotb and Icarus Verilog:

    cd test
    pip install -r requirements.txt
    make

`test/test.py` fills the window with a steady value, checks there is no false alert on small changes, injects a spike and checks that ALERT goes high and stays latched.

## External hardware

None needed. Drive `ui` from switches or a microcontroller, set the mode pins on `uio`, and read the result on LEDs.
