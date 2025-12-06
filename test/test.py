import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test_microgreen_classifier(dut):
    """Test the BNN microgreen classifier"""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    dut.rst_n.value = 0
    dut.ena.value = 1
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # --- Test case 1: Growth stage (low values) ---
    dut.ui_in.value = 0b00110011  # height=3, color=3
    dut.uio_in.value = 0b00110011  # width=3, stem=3

    # Wait for ready signal
    ready = 0
    for _ in range(10):
        await RisingEdge(dut.clk)
        if int(dut.uo_out.value) & 0b1000:
            ready = 1
            break

    assert ready == 1, "Ready signal not asserted (growth test)"
    classification = int(dut.uo_out.value) & 0b111
    assert classification == 1, f"Expected growth stage (1), got {classification}"
    dut._log.info("✓ Growth stage correctly classified.")

    # --- Test case 2: Harvest stage (high values) ---
    dut.ui_in.value = 0b11111111  # height=15, color=15
    dut.uio_in.value = 0b11111111  # width=15, stem=15

    ready = 0
    for _ in range(10):
        await RisingEdge(dut.clk)
        if int(dut.uo_out.value) & 0b1000:
            ready = 1
            break

    assert ready == 1, "Ready signal not asserted (harvest test)"
    classification = int(dut.uo_out.value) & 0b111
    assert classification == 2, f"Expected harvest stage (2), got {classification}"
    dut._log.info("✓ Harvest stage correctly classified.")
