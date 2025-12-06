# AI Microgreen Growth Stage Classifier

## Overview

This project implements a Binarized Neural Network (BNN) for real-time microgreen growth stage classification in precision agriculture applications.

## Model Performance

- **Training Accuracy:** 89.4%
- **Test Accuracy:** 86.7%
- **Dataset:** 123 real images (87 not-ready, 36 ready) + 1000 synthetic samples
- **Classes:** 2 (Not Ready, Ready to Harvest)

## Architecture

### Neural Network Structure
- **Input Layer:** 4 features (height, color, density, texture) - 4 bits each
- **Hidden Layer:** 4 neurons with sign activation
- **Output Layer:** 2 neurons (binary classification)
- **Method:** XNOR-popcount operations for efficient binary computation

### Hardware Specifications
- **Technology:** TinyTapeout tt08 (Skywater 130nm)
- **Clock Frequency:** 50 MHz
- **Latency:** 4 clock cycles (~80ns per classification)
- **Estimated Gates:** ~1200
- **Estimated Power:** <2mW

## How It Works

1. **Input Binarization:** 4-bit sensor values are thresholded at midpoint (8)
2. **Hidden Layer:** XNOR-popcount computes weighted sums with learned weights
3. **Activation:** Sign function produces binary hidden activations
4. **Output Layer:** Computes final classification scores
5. **Decision:** Winner-take-all selects highest scoring class

## Pin Configuration

### Inputs
- `ui_in[3:0]` - Height sensor (0-15 scale)
- `ui_in[7:4]` - Color/greenness sensor (0-15 scale)
- `uio_in[3:0]` - Density sensor (0-15 scale)
- `uio_in[7:4]` - Texture/temperature sensor (0-15 scale)

### Outputs
- `uo_out[0]` - Classification (0=not ready, 1=ready to harvest)
- `uo_out[1]` - Ready flag (1=new result available)
- `uo_out[2]` - Processing complete indicator
- `uo_out[3]` - Input sanity check
- `uo_out[7:4]` - Hidden layer state (debug)

## Testing

### Test Vectors

**Not Ready (Growing):**
