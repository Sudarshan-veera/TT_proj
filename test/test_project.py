import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_anomaly_detector(dut):
    """Tiny Anomaly Detection Engine - cocotb test"""

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    async def send(val, threshold=5, mode=0):
        dut.ui_in.value  = val
        dut.uio_in.value = (mode << 7) | (threshold & 0x7F)
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")

    dut._log.info("--- Loading window ---")
    await send(10)
    await send(12)
    await send(11)
    await send(13)

    ready = dut.uo_out.value.integer & 0x02
    assert ready != 0, f"READY should be 1 after 4 samples, got {dut.uo_out.value}"

    dut._log.info("--- Normal samples ---")
    await send(12)
    assert (dut.uo_out.value.integer & 0x01) == 0, "False alert on val=12"

    await send(11)
    assert (dut.uo_out.value.integer & 0x01) == 0, "False alert on val=11"

    dut._log.info("--- Anomaly injection ---")
    await send(40, threshold=5)
    assert (dut.uo_out.value.integer & 0x01) == 1, \
        f"ALERT should be 1 for val=40, got {dut.uo_out.value}"

    dut._log.info("--- Hold mode ---")
    await send(40, threshold=5, mode=1)
    assert (dut.uo_out.value.integer & 0x01) == 1, \
        f"ALERT should be 1 in hold mode for val=40"

    dut._log.info("--- Recovery ---")
    await send(12, threshold=5, mode=0)
    await send(11, threshold=5, mode=0)
    await send(13, threshold=5, mode=0)
    assert (dut.uo_out.value.integer & 0x01) == 0, \
        f"ALERT should clear after recovery, got {dut.uo_out.value}"

    dut._log.info("All tests PASSED")
