import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test_microgreen_classifier(dut):
    """Test the BNN microgreen classifier"""
    # Create a clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.ena.value = 1
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

        # Example test case: low values for growth stage
    dut.ui_in.value = 0b00110011  # height=3, color=3
    dut.uio_in.value = 0b00110011  # width=3, stem=3

    # Wait a few clock cycles for the computation to complete
    for _ in range(10):
        await RisingEdge(dut.clk)

    # Check the output
    classification = dut.uo_out.value & 0b111  # 3-bit classification
    ready = (dut.uo_out.value >> 3) & 0b1  # Ready bit is the 4th bit

    assert ready == 1, "Ready signal not asserted"
    assert classification == 1, "Expected growth stage (1), got {}".format(classification)

    dut._log.info("Growth stage correctly classified.")

    # Example test case: high values for harvest-ready stage
    dut.ui_in.value = 0b11111111  # height=15, color=15
    dut.uio_in.value = 0b11111111  # width=15, stem=15

    # Wait for computation
    for _ in range(10):
        await RisingEdge(dut.clk)

    classification = dut.uo_out.value & 0b111
    ready = (dut.uo_out.value >> 3) & 0b1

    assert ready == 1, "Ready signal not asserted"
    assert classification == 2, "Expected harvest stage (2), got {}".format(classification)

    dut._log.info("Harvest stage correctly classified.")

    # You can add more test cases similarly
