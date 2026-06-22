import cocotb

from cocotb.clock import Clock
from cocotb.triggers import ClockCycles



@cocotb.test()
async def test_anomaly_detector(dut):


    dut._log.info("Start")


    clock = Clock(dut.clk,10,unit="us")

    cocotb.start_soon(clock.start())



    # reset

    dut.ena.value = 1

    dut.ui_in.value = 0

    dut.uio_in.value = 20


    dut.rst_n.value = 0

    await ClockCycles(dut.clk,10)


    dut.rst_n.value = 1



    # fill window

    dut.ui_in.value = 50
    await ClockCycles(dut.clk,1)


    dut.ui_in.value = 52
    await ClockCycles(dut.clk,1)


    dut.ui_in.value = 49
    await ClockCycles(dut.clk,1)


    dut.ui_in.value = 51
    await ClockCycles(dut.clk,1)



    # ready should be high

    out = dut.uo_out.value.to_unsigned()


    ready = (out >> 1) & 1


    assert ready == 1, "Detector not ready"



    # send spike

    dut.ui_in.value = 200

    await ClockCycles(dut.clk,1)



    out = dut.uo_out.value.to_unsigned()


    alert = out & 1


    assert alert == 1, "Spike not detected"



