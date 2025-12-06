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
    dut.ui_in.value = 0b00110011  # height=3, color=3
    dut.uio_in.value = 0b00110011  # density=3, texture=3
    
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
    dut.ui_in.value = 0b11111111  # height=15, color=15
    dut.uio_in.value = 0b11111111  # density=15, texture=15
    
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
        
        dut._log.info(f"✓ Test passed: ({height},{color},{density},{texture}) → {result}")
```

4. **Commit changes:**
   - Message: "Add comprehensive test suite"
   - Click "Commit changes"

---

### ✅ **STEP 6: Wait for GitHub Actions** (10-15 minutes)

**What happens automatically:**

1. **Click "Actions" tab** at top of your repository

2. You'll see a workflow running (yellow dot 🟡)

3. **Wait for it to complete:**
   - 🟢 Green checkmark = SUCCESS! ✅
   - 🔴 Red X = Failed (we'll fix it)

4. **If it fails:**
   - Click on the failed workflow
   - Look at the error message
   - Common issues:
     - Syntax error in Verilog
     - Weights not copied correctly
     - Test expectations wrong

**Take a screenshot when it turns green!** 📸

---

### 🎉 **STEP 7: Submit to TinyTapeout** (10 minutes)

**Once GitHub Actions passes (green checkmark):**

1. **Go to:** https://app.tinytapeout.com/

2. **Click:** "Sign in with GitHub"

3. **Click:** "Submit a new design"

4. **Fill in:**
   - Project name: Select your `tt08-microgreen-classifier`
   - Description: "AI microgreen classifier - 86.7% accuracy"
   - Discord username: (optional but recommended)

5. **Click "Submit for review"**

6. **Pay submission fee:**
   - Standard: $150
   - With priority: $300
   - Choose based on budget

7. **DONE!** 🎊

You'll get an email confirmation and your chip will arrive in ~6 months!

---

## 📝 **QUICK REFERENCE: What Goes Where**

| File | Location | What to Do |
|------|----------|------------|
| **weights.vh** | Your computer | Open, copy weight values |
| **project.v** | GitHub: `src/project.v` | Paste Verilog, update weights |
| **info.yaml** | GitHub: `info.yaml` | Update with your info |
| **test.py** | GitHub: `test/test.py` | Copy test code |

---

## 🆘 **TROUBLESHOOTING**

### Problem: "Can't find weights.vh"
**Solution:** 
```
C:\precision_farming\weights.vh
Open with Notepad, it's there!
