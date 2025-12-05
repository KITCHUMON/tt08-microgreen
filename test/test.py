import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_growth_classification(dut):
    """Test growth stage classification"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.ena.value = 1
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Simulate growth stage inputs (low values)
    dut.ui_in.value = 0b00110011  # height=3, color=3
    dut.uio_in.value = 0b00110011  # density=3, texture=3
    
    # Wait for classification
    for _ in range(20):
        await RisingEdge(dut.clk)
    
    # Check result
    classification = dut.uo_out.value & 0b1
    ready = (dut.uo_out.value >> 1) & 0b1
    
    assert ready == 1, "Classification not ready"
    assert classification == 0, f"Expected growth (0), got {classification}"
    
    dut._log.info("✓ Growth stage test passed")

@cocotb.test()
async def test_harvest_classification(dut):
    """Test harvest-ready classification"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.ena.value = 1
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Simulate harvest-ready inputs (high values)
    dut.ui_in.value = 0b11111111
    dut.uio_in.value = 0b11111111
    
    for _ in range(20):
        await RisingEdge(dut.clk)
    
    classification = dut.uo_out.value & 0b1
    assert classification == 1, f"Expected harvest (1), got {classification}"
    
    dut._log.info("✓ Harvest stage test passed")

@cocotb.test()
async def test_optimal_parameters(dut):
    """Test environmental parameter monitoring"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Simulate optimal conditions
    # This would connect to parameter monitor module
    # Check that no alert flags are raised
    
    await Timer(100, units="ns")
    
    temp_alert = (dut.uo_out.value >> 4) & 0b1
    humid_alert = (dut.uo_out.value >> 5) & 0b1
    
    assert temp_alert == 0, "False temperature alert"
    assert humid_alert == 0, "False humidity alert"
    
    dut._log.info("✓ Parameter monitoring test passed")

@cocotb.test()
async def test_sensor_fault_detection(dut):
    """Test fault detection with out-of-range values"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.ena.value = 1
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Inject fault (all zeros - sensor disconnected)
    dut.ui_in.value = 0b00000000
    dut.uio_in.value = 0b00000000
    
    for _ in range(20):
        await RisingEdge(dut.clk)
    
    sensor_fault = (dut.uo_out.value >> 2) & 0b1
    assert sensor_fault == 1, "Fault not detected"
    
    dut._log.info("✓ Fault detection test passed")
