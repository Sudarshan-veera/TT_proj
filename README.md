![](https://github.com/Sudarshan-veera/TT_proj/workflows/gds/badge.svg) ![](https://github.com/Sudarshan-veera/TT_proj/workflows/docs/badge.svg) ![](https://github.com/Sudarshan-veera/TT_proj/workflows/test/badge.svg) ![](https://github.com/Sudarshan-veera/TT_proj/workflows/fpga/badge.svg)

# Tiny Anomaly Detection Engine

A small Verilog design for Tiny Tapeout. It watches an 8-bit sensor value and raises an alert when a new sample jumps too far from the average of the last four. It runs at 10 MHz and fits in a single 1x1 tile.

I built it to see how much useful sensor logic fits in a very small amount of silicon. There is no CPU and no memory block: just a four-sample window, a running sum, and a comparator.

## How it works

1. Every clock cycle the chip takes the 8-bit sample on `ui[7:0]`.
2. It keeps the last four accepted samples and their running sum. The mean is the sum divided by four.
3. It compares the new sample with that mean. If the difference is bigger than the threshold, the sample is an anomaly.
4. The threshold is the mean shifted right by 1, 2, 3 or 4 bits, depending on the sensitivity pins, and never smaller than 2.
5. Nothing is flagged until the window holds four samples (`READY` goes high).

Once `ALERT` goes high it stays high until the chip is reset.

## Pins

| Pin | Direction | Meaning |
|---|---|---|
| `ui[7:0]` | in | 8-bit sensor sample |
| `uio[3:0]` | in | anomaly limit (used in n-shot mode, 0 counts as 1) |
| `uio[4]` | in | n-shot mode on or off |
| `uio[6:5]` | in | sensitivity: 0 = threshold mean/2 (least sensitive), 3 = mean/16 |
| `uio[7]` | in | hold mode: freeze the window so the mean stops following the input |
| `uo[0]` | out | ALERT |
| `uo[1]` | out | READY |
| `uo[2]` | out | LOCKED (an alert has been latched) |
| `uo[7:3]` | out | top 5 bits of the window mean |

In n-shot mode an alert needs as many anomalous samples in a row as the limit says. A normal sample resets the count, and anomalous samples are kept out of the window while they are being counted.

## Test it

The testbench uses cocotb with Icarus Verilog:

    cd test
    pip install -r requirements.txt
    make

It fills the window with a steady value, checks that normal wobble does not trigger an alert, injects a spike and checks that `ALERT` goes high and stays latched. The gate-level run happens in GitHub Actions.

## More

- Design notes and pin details: [docs/info.md](docs/info.md)
- Source: [src/project.v](src/project.v)
- Built from the [Tiny Tapeout](https://tinytapeout.com) template, so the GitHub Actions produce the GDS, the docs page and an FPGA bitstream on every push.
