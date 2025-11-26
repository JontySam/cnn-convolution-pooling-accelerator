# CNN Convolution and Pooling Accelerator

This repository contains the RTL design, synthesis scripts, and performance reports for a high-throughput hardware accelerator for 2D convolution and max-pooling, key operations in Convolutional Neural Networks (CNNs). The project was developed as part of the EE5324 VLSI Design-II course and demonstrates a complete design flow from architectural definition to post-synthesis verification and optimization.

The accelerator is designed in SystemVerilog and optimized for a 16nm ASIC technology.

## Key Features

-   Performs 3x3 convolution and 2x2 max-pooling on a 4x4 image block.
-   Processes three convolution kernels in parallel.
-   Fully pipelined architecture for high throughput (one block per cycle after initial latency).
-   User-configurable dynamic range control via a right-shift operation.
-   Synthesized and optimized for high-frequency performance.

## Architectural Evolution and Optimization

The project was developed in two main stages, evolving from a baseline 4-stage pipeline to a highly optimized 5-stage pipeline.

### Milestone 1: Baseline 4-Stage Pipeline

The initial design featured a 4-stage pipeline that combined convolution and max-pooling logic in a shared stage.

-   **Stage 0:** Request Generation & Alignment
-   **Stage 1:** Input Latching
-   **Stage 2:** Convolution + Pooling
-   **Stage 3:** Output Registration

This architecture successfully implemented the core functionality and was synthesized to meet a **1.00 GHz** clock frequency. However, timing analysis revealed that the combined computation in Stage 2 created a critical path that limited further frequency scaling.

### Milestone 2: Optimized 5-Stage Pipeline

To overcome the limitations of the initial design, the architecture was refactored into a deeper 5-stage pipeline. The key optimization was decoupling the convolution and pooling operations into separate stages and refining the memory access logic.

-   **Stage 0:** Request Generation & Alignment (Optimized to issue one request per cycle)
-   **Stage 1:** Input Data Latching
-   **Stage 2:** Convolution Computation (12 parallel convolution units)
-   **Stage 3:** Max-Pooling Computation
-   **Stage 4:** Output & Memory Interface

This deeper pipelining balanced the logic depth across stages, significantly reducing the critical path delay. This architectural enhancement resulted in a **45% increase in clock frequency** and a **45% reduction in total processing latency**.

## Performance Results Summary

The following table summarizes the key performance metrics and improvements achieved between the two design milestones.

| Feature / Metric                | Milestone 1 (4-Stage)     | Milestone 2 (5-Stage)               | Improvement |
| :------------------------------ | :------------------------ | :---------------------------------- | :---------- |
| **Pipeline Architecture**       | 4-stage pipeline          | 5-stage (decoupled) pipeline        | +1 Stage    |
| **Clock Frequency**             | 1.00 GHz (1.00 ns period) | **1.82 GHz (0.55 ns period)**       | **+82%**    |
| **Total Latency (512x512 image)** | 65.54 µs                  | **36.04 µs**                        | **-45%**    |
| **Critical Path Delay**         | 0.98 ns                   | **0.54 ns**                         | **-45%**    |
| **Total Cell Area**             | 8,756.14 µm²              | 9,408.86 µm²                        | +7.4%       |
| **Total Dynamic Power (DC Est.)** | ~28.85 mW                 | ~28.85 mW                           | Comparable  |
| **Total Power (PrimeTime PX)**    | -                         | ~30.02 mW                           | -           |

The final 5-stage design achieves a significant boost in performance with only a modest increase in area, demonstrating a successful synthesis-driven optimization strategy.

## Repository Structure

The project files are organized into directories for each milestone, containing the reports, RTL source code, simulation outputs, and synthesis reports.

```
.
├── EE5324_VD2__Project3_Report1_5949682.pdf
├── EE5324_VD2__Project3_Report2_5949682.pdf
├── Project_5949682_MS1/
│   ├── tb_conv_pool.sv                 # Testbench for Milestone 1
│   ├── PostSynthesis_simulation/
│   │   └── conv_pool.sv                # Post-synthesis netlist for MS1
│   └── Presynthesis_simulations/
│       └── conv_pool.sv                # Behavioral RTL for MS1
│
├── Project_5949682_MS2/
│   ├── tb_conv_pool.sv                 # Testbench for Milestone 2
│   ├── PostSynthesis_simulation/
│   │   └── conv_pool.sv                # Post-synthesis netlist for MS2
│   ├── PreSynthesis_simulation/
│   │   └── conv_pool.sv                # Behavioral RTL for MS2
│   └── Synthesis Reports/
│       ├── conv_pool.area.rpt
│       ├── conv_pool.PostSynthesis.power.rpt
│       └── conv_pool.PostSynthesis.timing.rpt
│
└── project3_April_27th/
    ├── project3_image_proc.py          # Python script for image processing
    └── *.txt                           # Input/Golden data files for simulation
```

-   **`Project_5949682_MS1/`**: Contains all files related to the initial 4-stage design.
-   **`Project_5949682_MS2/`**: Contains all files related to the final 5-stage optimized design.
    -   `PreSynthesis_simulation/`: Holds the behavioral RTL (`conv_pool.sv`) and testbench (`tb_conv_pool.sv`) for functional simulation.
    -   `PostSynthesis_simulation/`: Holds the gate-level netlist (`conv_pool.sv`) for post-synthesis verification.
    -   `Synthesis Reports/`: Contains area, timing, and power reports from Synopsys Design Compiler and PrimeTime.
-   **`project3_April_27th/`**: Contains input data (image and filter coefficients) and golden reference output files used by the testbenches.

## How to Run Simulations

To run the simulations, you will need a SystemVerilog simulator such as Synopsys VCS, Cadence Xcelium, or Mentor Questa.

1.  **Navigate to the simulation directory:**
    -   For pre-synthesis (RTL) simulation of the final design, go to `Project_5949682_MS2/PreSynthesis_simulation/`.
    -   For post-synthesis (gate-level) simulation, go to `Project_5949682_MS2/PostSynthesis_simulation/`.

2.  **Compile and Simulate:**
    -   The testbench `tb_conv_pool.sv` is the top-level file for simulation. It reads input files from the `project3_April_27th` directory, drives the `conv_pool.sv` module, and compares the output with golden reference files.
    -   A typical command to run the simulation using VCS would be:
        ```sh
        # For RTL Simulation
        vcs -sverilog +v2k -full64 -LDFLAGS -Wl,--no-as-needed -timescale=1ps/1ps tb_conv_pool.sv conv_pool.sv

        # For Post-Synthesis Simulation (assuming you have the netlist and SDF file)
        vcs -sverilog +v2k -full64 -LDFLAGS -Wl,--no-as-needed -timescale=1ps/1ps tb_conv_pool.sv conv_pool.sv +sdfverbose your_sdf_file.sdf
        ```

3.  **Check Results:**
    -   The testbench will print messages to the console, indicating whether each processed block matches the expected "golden" output. A successful run will end with an "All blocks passed for all kernels!" message.
