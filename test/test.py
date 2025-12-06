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
    await ClockCycles(dut.clk, 10)  # Give time for logic to drive uio_out

    # Ensure uio_out is driven and doesn't contain 'z'
    # Wait for uio_out to stabilize or timeout
    for _ in range(20):
        binstr = dut.uio_out.value.binstr.lower()
        if 'z' not in binstr and 'x' not in binstr:
            break
        await RisingEdge(dut.clk)
    else:
        dut._log.warning(f"uio_out unresolved: {dut.uio_out.value.binstr}")
        raise AssertionError("uio_out signal contains unresolved 'z' or 'x' bits")


    # Now safe to read uio_out
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
    dut._log.info("XCLK generating correctly (toggling observed)")

    # Simulate a VSYNC pulse to start inference
    dut.uio_in.value = 0b10000000  # VSYNC high
    await RisingEdge(dut.clk)
    dut.uio_in.value = 0b00000000  # VSYNC low
    await RisingEdge(dut.clk)

    dut._log.info("Test 2: Check BNN readiness")

    # Wait for bnn_ready (uo_out[5]) up to a timeout
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if (dut.uo_out.value >> 5) & 0b1:
            break
    else:
        raise AssertionError("Timeout waiting for bnn_ready signal")

    prediction = (dut.uo_out.value >> 4) & 0b1
    hidden = dut.uo_out.value & 0x0F
    dut._log.info(f"✓ BNN Ready | Prediction: {prediction} | Hidden: {bin(hidden)}")
