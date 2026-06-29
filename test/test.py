import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

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

    for attr in ('VPWR','VPB','VNB'):
        if hasattr(dut, attr): getattr(dut, attr).value = 1
    for attr in ('VGND',):
        if hasattr(dut, attr): getattr(dut, attr).value = 0

    # Reset
    dut.rst_n.value  = 0
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    for _ in range(10):
        await RisingEdge(dut.clk)
    await Timer(2, units="ns")
    dut.rst_n.value = 1
    await Timer(2, units="ns")

    # Fill window — send 8 identical samples so mean is rock-solid at 12
    # and no anomaly can fire during fill
    dut._log.info("Filling window with stable value 12")
    for _ in range(8):
        await send(dut, 12)

    # Poll until READY=1 (GL may need extra cycles)
    for _ in range(20):
        out = dut.uo_out.value.integer
        if (out >> 1) & 1:
            break
        await send(dut, 12)
    else:
        raise AssertionError(f"READY never went high, uo_out={dut.uo_out.value.integer:#010b}")

    dut._log.info("Window ready, checking no false alerts on normal values")
    for val in [12, 11, 13, 12]:
        await send(dut, val)
        out = dut.uo_out.value.integer
        assert (out & 1) == 0, \
            f"False alert on val={val}, uo_out={out:#010b} (expected ALERT=0)"

    dut._log.info("Injecting spike — expect ALERT=1")
    await send(dut, 60)
    out = dut.uo_out.value.integer
    assert (out & 1) == 1, \
        f"ALERT should fire on val=60, uo_out={out:#010b}"

    dut._log.info("Alert must stay locked")
    await send(dut, 12)
    out = dut.uo_out.value.integer
    assert (out & 1) == 1, \
        f"ALERT should stay locked, uo_out={out:#010b}"

    dut._log.info("ALL TESTS PASSED")
