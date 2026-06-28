import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def wait_for_valid_output(dut, signal, timeout_cycles=300):
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")
        val = signal.value
        if not val.is_resolvable:
            continue
        return
    raise AssertionError(f"{signal._name} never resolved from X after {timeout_cycles} cycles")

@cocotb.test()
async def test_anomaly_detector(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Apply power pins if GL test
    if hasattr(dut, 'VPWR'):
        dut.VPWR.value = 1
        dut.VGND.value = 0
    if hasattr(dut, 'VDPWR'):
        dut.VDPWR.value = 1

    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    await wait_for_valid_output(dut, dut.uo_out)

    # sens=1(25pct), one-shot, alimit=0
    async def send(val, sens=1, nshot=0, alimit=0, hold=0):
        dut.ui_in.value  = val
        dut.uio_in.value = (hold << 7) | (sens << 5) | (nshot << 4) | (alimit & 0xF)
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")

    dut._log.info("Loading window")
    await send(10)
    await send(12)
    await send(11)
    await send(13)

    ready = dut.uo_out.value.integer & 0x02
    assert ready != 0, f"READY should be 1 after 4 samples, got {dut.uo_out.value}"

    dut._log.info("Normal samples - no alert")
    await send(12)
    assert (dut.uo_out.value.integer & 0x01) == 0, "False alert on val=12"
    await send(11)
    assert (dut.uo_out.value.integer & 0x01) == 0, "False alert on val=11"

    dut._log.info("Anomaly injection")
    await send(60)
    assert (dut.uo_out.value.integer & 0x01) == 1, \
        f"ALERT should be 1 for val=60, got {dut.uo_out.value}"

    dut._log.info("Alert locked")
    await send(12)
    assert (dut.uo_out.value.integer & 0x01) == 1, \
        f"ALERT should stay locked, got {dut.uo_out.value}"

    dut._log.info("All tests PASSED")
