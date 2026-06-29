import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def reset_dut(dut, cycles=10):
    dut.rst_n.value = 0
    dut.ena.value   = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    await Timer(2, units="ns")
    dut.rst_n.value = 1
    # extra settle for GL
    for _ in range(5):
        await RisingEdge(dut.clk)
    await Timer(2, units="ns")

async def send(dut, val, sens=1, nshot=0, alimit=0, hold=0):
    dut.ui_in.value  = val
    dut.uio_in.value = (hold << 7) | (sens << 5) | (nshot << 4) | (alimit & 0xF)
    await RisingEdge(dut.clk)
    await Timer(2, units="ns")

@cocotb.test()
async def test_anomaly_detector(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Power pins for GL test
    for attr in ('VPWR','VPB','VNB'):
        if hasattr(dut, attr): getattr(dut, attr).value = 1
    for attr in ('VGND',):
        if hasattr(dut, attr): getattr(dut, attr).value = 0

    await reset_dut(dut, cycles=10)

    # Load 4 samples to fill window
    dut._log.info("Filling window")
    await send(dut, 10)
    await send(dut, 12)
    await send(dut, 11)
    await send(dut, 13)  # ready goes high here

    out = dut.uo_out.value.integer
    assert (out >> 1) & 1, f"READY should be 1 after 4 samples, got uo_out={out}"

    dut._log.info("Normal samples - expect no alert")
    await send(dut, 12)
    out = dut.uo_out.value.integer
    assert (out & 1) == 0, f"False alert on val=12, uo_out={out} (expected ALERT=0)"

    await send(dut, 11)
    out = dut.uo_out.value.integer
    assert (out & 1) == 0, f"False alert on val=11, uo_out={out} (expected ALERT=0)"

    dut._log.info("Injecting anomaly spike")
    await send(dut, 60)
    out = dut.uo_out.value.integer
    assert (out & 1) == 1, f"ALERT should fire on val=60, uo_out={out}"

    dut._log.info("Alert must stay locked")
    await send(dut, 12)
    out = dut.uo_out.value.integer
    assert (out & 1) == 1, f"ALERT should stay locked, uo_out={out}"

    dut._log.info("PASSED")
