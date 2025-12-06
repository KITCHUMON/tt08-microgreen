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
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Wait one cycle
    await ClockCycles(dut.clk, 1)

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

    # Pulse VSYNC (start frame)
    dut.uio_in.value = 0b10000000  # VSYNC high
    await RisingEdge(dut.clk)
    dut.uio_in.value = 0b00000000  # VSYNC low

    # Simulate HREF and PCLK activity (fake 16 pixels)
    for _ in range(16):
        dut.uio_in.value = 0b01100000  # HREF=1, PCLK=0
        dut.ui_in.value = 0b11111111   # green-dominant
        await RisingEdge(dut.clk)

        dut.uio_in.value = 0b01100100  # HREF=1, PCLK=1
        await RisingEdge(dut.clk)

    # End of line/frame (HREF low)
    dut.uio_in.value = 0b00000000
    await ClockCycles(dut.clk, 5)

    # Wait for BNN ready signal
    for cycle in range(5000):
        await RisingEdge(dut.clk)
        ready = (dut.uo_out.value >> 5) & 0b1
        if ready:
            break
    else:
        raise AssertionError("Timeout waiting for bnn_ready signal")

    prediction = (dut.uo_out.value >> 4) & 0b1
    hidden_debug = dut.uo_out.value & 0x0F
    dut._log.info(f"✓ BNN ready. Prediction: {prediction}, Hidden: {bin(hidden_debug)}")
