import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


@cocotb.test()
async def test_camera_interface(dut):
    """Test 1: Camera Clock and BNN Inference Triggering"""

    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())  # 25MHz clock

    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut._log.info("Test 1: Camera Clock (XCLK) Generation")
    prev_val = dut.uio_out.value.integer & (1 << 4)
    toggles = 0
    for _ in range(50):
        await RisingEdge(dut.clk)
        current_val = dut.uio_out.value.integer & (1 << 4)
        if current_val != prev_val:
            toggles += 1
            prev_val = current_val

    assert toggles > 2, "XCLK not toggling as expected"
    dut._log.info("✓ XCLK generating correctly (toggling observed)")

    # Simulate a single VSYNC pulse (frame complete)
    dut.uio_in.value = 0b10000000  # Set VSYNC high
    await RisingEdge(dut.clk)
    dut.uio_in.value = 0b00000000  # Set VSYNC low
    await RisingEdge(dut.clk)

    dut._log.info("Test 2: Early Growth Stage")

    # Wait for bnn_ready (uo_out[5])
    for cycle in range(5000):
        await RisingEdge(dut.clk)
        ready = (dut.uo_out.value >> 5) & 0b1
        if ready:
            break
    else:
        raise AssertionError("Timeout waiting for bnn_ready signal")

    prediction = (dut.uo_out.value >> 4) & 0b1
    dut._log.info(f"Prediction: {prediction}, Hidden: {bin(dut.uo_out.value & 0x0F)}")
