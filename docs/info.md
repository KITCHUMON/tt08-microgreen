## How it works

The system uses a pre-trained Binarized Neural Network (BNN) accelerator for precision farming. 
The weights are trained in Python and baked directly into the Verilog hardware logic. 

1. **Input Processing:** The system accepts 4 binary feature inputs representing Height, Greenness, Density, and Texture.
2. **Hidden Layer:** These inputs are multiplied by signed weights (1 or -1) and accumulated in 4 hidden neurons. A step function (ReLU equivalent for BNN) activates the neuron if the sum is positive.
3. **Output Layer:** The hidden neuron outputs are weighted and summed into two output scores: "Growth" and "Harvest".
4. **Decision:** The system compares the two scores. If the "Harvest" score is higher, the Harvest LED turns on. Otherwise, the Growth LED turns on.

## How to test

1. **Reset:** Pulse the `rst_n` pin low for at least one clock cycle to reset the internal registers.
2. **Set Inputs:** Apply binary signals to the input pins:
    * `ui[0]`: Height feature
    * `ui[1]`: Greenness feature
    * `ui[2]`: Density feature
    * `ui[3]`: Texture feature
3. **Observe Outputs:** Check the LEDs:
    * `uo[0]` (Growth) should light up for "young" plant features (e.g., all inputs 0).
    * `uo[1]` (Harvest) should light up for "mature" plant features (e.g., all inputs 1).

## External hardware

* No external hardware is required for the logic to function.
* For a real-world demo, connect 4 simple toggle switches to inputs `ui[0..3]` and LEDs to outputs `uo[0..1]`.
