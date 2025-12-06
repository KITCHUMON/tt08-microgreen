import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test_microgreen_classifier(dut):
    """Test the BNN microgreen classifier"""
    
    # 1. Start Clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # 2. Reset
    dut.rst_n.value = 0
    dut.ena.value = 1
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # --- TEST CASE 1: Growth Stage (Low inputs) ---
    dut._log.info("Testing Growth Stage...")
    dut.ui_in.value = 0b00110011 
    dut.uio_in.value = 0b00110011 

    # Polling Loop: Wait up to 20 cycles for bit 3 (Ready) to go High
    ready_detected = False
    for _ in range(20):
        await RisingEdge(dut.clk)
        # Check if Bit 3 is high
        if (dut.uo_out.value >> 3) & 1:
            ready_detected = True
            break
    
    assert ready_detected, "Timeout: Ready signal never went high!"
    
    # Now check the classification bits (Bits 0-2)
    classification = dut.uo_out.value & 0b111
    assert classification == 0, f"Expected Growth (0), got {classification}" # Note: Your Verilog outputs 0 for growth
    dut._log.info("✓ Growth stage correctly classified")

    # --- TEST CASE 2: Harvest Stage (High inputs) ---
    dut._log.info("Testing Harvest Stage...")
    dut.ui_in.value = 0b11111111 
    dut.uio_in.value = 0b11111111 
    
    # Wait a cycle to ensure FSM resets from previous state if needed
    await RisingEdge(dut.clk)

    # Polling Loop again
    ready_detected = False
    for _ in range(20):
        await RisingEdge(dut.clk)
        if (dut.uo_out.value >> 3) & 1:
            ready_detected = True
            break

    assert ready_detected, "Timeout: Ready signal never went high!"
    
    classification = dut.uo_out.value & 0b111
    assert classification == 1, f"Expected Harvest (1), got {classification}" # Note: Your Verilog outputs 1 for harvest
    dut._log.info("✓ Harvest stage correctly classified")
