import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_not_ready_classification(dut):
    """Test classification of not-ready microgreens (low values)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.ena.value = 1
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: Not ready stage (low values)
    # Height=3 (0011), Color=3 (0011) -> ui_in = 00110011
    dut.ui_in.value = 0b00110011  
    # Density=3 (0011), Texture=3 (0011) -> uio_in = 00110011
    dut.uio_in.value = 0b00110011 
    
    # Wait for classification
    for _ in range(10):
        await RisingEdge(dut.clk)
    
    # Check output
    classification = dut.uo_out.value & 0b1
    ready = (dut.uo_out.value >> 1) & 0b1
    
    assert ready == 1, "Ready flag not set"
    assert classification == 0, f"Expected not-ready (0), got {classification}"
    
    dut._log.info("✓ Not-ready stage correctly classified")

@cocotb.test()
async def test_ready_classification(dut):
    """Test classification of harvest-ready microgreens (high values)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.ena.value = 1
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: Ready stage (high values)
    # All 15 (1111)
    dut.ui_in.value = 0b11111111 
    dut.uio_in.value = 0b11111111 
    
    for _ in range(10):
        await RisingEdge(dut.clk)
    
    classification = dut.uo_out.value & 0b1
    ready = (dut.uo_out.value >> 1) & 0b1
    
    assert ready == 1, "Ready flag not set"
    assert classification == 1, f"Expected ready (1), got {classification}"
    
    dut._log.info("✓ Ready stage correctly classified")

@cocotb.test()
async def test_multiple_samples(dut):
    """Test multiple sequential classifications"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.ena.value = 1
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Test cases: (height, color, density, texture, expected_class)
    test_cases = [
        (2, 3, 2, 3, 0),    # Not ready
        (14, 15, 14, 13, 1), # Ready
        (5, 6, 5, 6, 0),    # Not ready
        (12, 13, 12, 11, 1), # Ready
    ]
    
    for height, color, density, texture, expected in test_cases:
        dut.ui_in.value = (color << 4) | height
        dut.uio_in.value = (texture << 4) | density
        
        for _ in range(10):
            await RisingEdge(dut.clk)
        
        result = dut.uo_out.value & 0b1
        assert result == expected, \
            f"Input ({height},{color},{density},{texture}): Expected {expected}, got {result}"
        
        dut._log.info(f"✓ Test passed: ({height},{color},{density},{texture}) -> {result}")
