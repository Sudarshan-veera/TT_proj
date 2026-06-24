import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

async def wait_for_valid_output(dut, signal, timeout_cycles=200):
    """Wait until signal has no X bits, raise if timeout."""
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        try:
            signal.value.to_unsigned()
            return
        except ValueError:
            continue
    raise AssertionError(f"{signal._name} never resolved from X after {timeout_cycles} cycles")

@cocotb.test()
async def test_anomaly_detector(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # reset — hold for 20 cycles in GL to ensure all flops clear
    dut.ena.value   = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 20
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)   # settle after reset de-assert

    # fill window
    dut.ui_in.value = 50
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 52
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 49
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 51
    await ClockCycles(dut.clk, 1)

    # wait until uo_out is free of X bits before reading
    await wait_for_valid_output(dut, dut.uo_out)

    out   = dut.uo_out.value.to_unsigned()
    ready = (out >> 1) & 1
    assert ready == 1, f"Detector not ready (uo_out=0x{out:02x})"

    # send spike
    dut.ui_in.value = 200
    await ClockCycles(dut.clk, 1)

    await wait_for_valid_output(dut, dut.uo_out)

    out   = dut.uo_out.value.to_unsigned()
    alert = out & 1
    assert alert == 1, f"Spike not detected (uo_out=0x{out:02x})"
