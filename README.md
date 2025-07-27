# IEEE 754 Double-Precision Floating Point Unit (FPU) – Verilog Implementation

This repository contains a modular implementation of a **64-bit IEEE 754 compliant Floating Point Unit (FPU)**, written in **Verilog HDL**. The design supports four fundamental arithmetic operations: addition, subtraction, multiplication, and division. Each operation is implemented as an independent module and is integrated into a unified top-level FPU module for opcode-based control.

> Designed for academic, research, or digital system design projects involving floating-point arithmetic.

---

## ✔️ Features

- ✅ Supports IEEE 754 **double-precision (64-bit)** format
- ✅ Modular implementation of:
  - `fp_add.v` – Addition
  - `fp_sub.v` – Subtraction
  - `fp_mul.v` – Multiplication
  - `fp_div.v` – Division
- ✅ Unified top-level controller (`fpu.v`) with opcode selection
- ✅ Individual and top-level testbenches for verification
- ✅ Clean directory structure, ready for extension and pipelining

---

## 🗂️ Directory Overview

ieee754_fpu_double_precision_basic/
├── src/ # Verilog source files
│ ├── fp_add.v
│ ├── fp_sub.v
│ ├── fp_mul.v
│ ├── fp_div.v
│ └── fpu.v # Top-level FPU controller
│
├── tb/ # Testbenches
│ ├── tb_fp_add.v
│ ├── tb_fp_sub.v
│ ├── tb_fp_mul.v
│ ├── tb_fp_div.v
│ └── tb_fpu.v # Unified testbench for fpu.v
│
├── .gitignore # Ignores Vivado-generated and temp files
└── README.md 


---

## 🧪 Simulation Instructions

This project was developed and tested using **Xilinx Vivado**.  
Follow the steps below to run simulations:

1. Open Vivado and create a new project.
2. Add all files from the `src/` and `tb/` directories.
3. Set the appropriate testbench as your top module (e.g., `tb_fpu`).
4. Run the behavioral simulation.
5. Use the waveform viewer to verify results.

---

## 🧠 Top-Level FPU Operation (`fpu.v`)

The `fpu.v` module selects the operation based on a 2-bit `opcode`:

| Opcode | Operation     |
|--------  |----------------|
| `00`     | Floating-point addition  |
| `01`     | Floating-point subtraction |
| `10`     | Floating-point multiplication |
| `11`     | Floating-point division     |


---

## 🛠️ Tools & Technologies

- **HDL**: Verilog (IEEE 1364)
- **Simulation Tool**: Vivado Simulator
- **Version Control**: Git + GitHub
- **Target Audience**: Students, researchers, and digital design enthusiasts

---

## 🧭 Roadmap

-  Implement IEEE 754 compliant arithmetic units
-  Create standalone testbenches for each module
-  Integrate with top-level `fpu.v` and verify operation
