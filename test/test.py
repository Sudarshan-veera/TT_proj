import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_anomaly_detector(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Set power pins for GL test
    if hasattr(dut, 'VPWR'):
        dut.VPWR.value = 1
    if hasattr(dut, 'VGND'):
        dut.VGND.value = 0
    if hasattr(dut, 'VPB'):
        dut.VPB.value = 1
    if hasattr(dut, 'VNB'):
        dut.VNB.value = 0

    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0

    # Hold reset long enough for GL sim to initialize
    for _ in range(20):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 1

    # Wait for outputs to resolve from X
    resolved = False
    for _ in range(100):
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")
        try:
            val = dut.uo_out.value
            if val.is_resolvable:
                resolved = True
                break
        except Exception:
            continue

    assert resolved, "uo_out never resolved from X"

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
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    ready = dut.uo_out.value.integer & 0x02
    assert ready != 0, f"READY should be 1, got {dut.uo_out.value}"

    dut._log.info("Normal sample")
    await send(12)
    assert (dut.uo_out.value.integer & 0x01) == 0, "False alert on val=12"

    dut._log.info("Anomaly injection")
    await send(60)
    assert (dut.uo_out.value.integer & 0x01) == 1, \
        f"ALERT should be 1 for val=60, got {dut.uo_out.value}"

    dut._log.info("Lock check")
    await send(12)
    assert (dut.uo_out.value.integer & 0x01) == 1, \
        "ALERT should stay locked after anomaly"

    dut._log.info("All tests PASSED")
