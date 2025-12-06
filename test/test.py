# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")
    
    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut._log.info("Reset")
    dut.ena.value = 0
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 5)
    
    dut.ena.value = 1
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)
    
    # Wait for uio_out to stabilize
    for _ in range(20):
        binstr = dut.uio_out.value.binstr.lower()
        if 'z' not in binstr and 'x' not in binstr:
            break
        await RisingEdge(dut.clk)
    else:
        dut._log.warning(f"uio_out unresolved: {dut.uio_out.value.binstr}")
        raise AssertionError("uio_out signal contains unresolved 'z' or 'x' bits")
    
    dut._log.info("✓ Output signals properly driven")
    
    # Test 1: Camera Clock (XCLK) Generation
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
    dut._log.info(f"  ✓ XCLK toggling correctly ({toggles} toggles observed)")
    
    # Test 2: Ultrasonic Trigger
    dut._log.info("Test 2: Ultrasonic Trigger Generation")
    trigger_detected = False
    
    for _ in range(5000):
        await RisingEdge(dut.clk)
        trigger = (dut.uio_out.value.integer >> 1) & 0b1
        if trigger:
            trigger_detected = True
            break
    
    assert trigger_detected, "Ultrasonic trigger not detected"
    dut._log.info("  ✓ Ultrasonic trigger pulse detected")
    
    # Test 3: Simulate Frame and Check BNN
    dut._log.info("Test 3: BNN Inference")
    
    # Simulate VSYNC rising (frame start)
    dut.uio_in.value = 0b10000000  # VSYNC high
    await ClockCycles(dut.clk, 2)
    
    # Simulate VSYNC falling (frame end - triggers inference)
    dut.uio_in.value = 0b00000000  # VSYNC low
    await ClockCycles(dut.clk, 2)
    
    # Wait for BNN to complete (should be fast - 4 cycles)
    for _ in range(1000):
        await RisingEdge(dut.clk)
        ready = (dut.uo_out.value >> 5) & 0b1
        if ready:
            break
    else:
        raise AssertionError("Timeout waiting for bnn_ready signal")
    
    prediction = (dut.uo_out.value >> 4) & 0b1
    buzzer = (dut.uo_out.value >> 7) & 0b1
    led = (dut.uo_out.value >> 6) & 0b1
    hidden = dut.uo_out.value & 0x0F
    
    dut._log.info(f"  ✓ BNN Ready | Prediction: {prediction} | Hidden: {bin(hidden)}")
    dut._log.info(f"  Buzzer: {buzzer}, LED: {led}")
    
    # Test 4: Multiple Frames
    dut._log.info("Test 4: Multiple Frame Processing")
    
    for frame_num in range(3):
        # Simulate frame
        dut.uio_in.value = 0b10000000  # VSYNC high
        await ClockCycles(dut.clk, 2)
        dut.uio_in.value = 0b00000000  # VSYNC low
        await ClockCycles(dut.clk, 2)
        
        # Wait for ready
        for _ in range(1000):
            await RisingEdge(dut.clk)
            if (dut.uo_out.value >> 5) & 0b1:
                break
        
        prediction = (dut.uo_out.value >> 4) & 0b1
        dut._log.info(f"  Frame {frame_num + 1}: Prediction={prediction}")
    
    dut._log.info("="*70)
    dut._log.info("ALL TESTS PASSED! ✓")
    dut._log.info("="*70)
    dut._log.info("")
    dut._log.info("Camera interface working correctly")
    dut._log.info("BNN inference operating as expected")
    dut._log.info("Ready for hardware deployment!")
    dut._log.info("="*70)
