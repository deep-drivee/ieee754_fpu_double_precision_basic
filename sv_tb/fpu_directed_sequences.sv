`include "uvm_macros.svh"
import uvm_pkg::*;

// ============================================================
// Sequence 1: IEEE 754 Special Cases (NaN, Inf, Zero)
// Exhaustively tests all special-value permutations per opcode
// ============================================================
class fpu_special_cases_seq extends uvm_sequence #(fpu_transaction);
    `uvm_object_utils(fpu_special_cases_seq)

    function new(string name = "fpu_special_cases_seq");
        super.new(name);
    endfunction

    virtual task body();
        logic [63:0] specials[];
        string       labels[];

        // Canonical special values
        specials = new[8];
        labels   = new[8];
        specials[0] = 64'h0000000000000000; labels[0] = "+Zero";
        specials[1] = 64'h8000000000000000; labels[1] = "-Zero";
        specials[2] = 64'h7FF0000000000000; labels[2] = "+Inf";
        specials[3] = 64'hFFF0000000000000; labels[3] = "-Inf";
        specials[4] = 64'h7FF8000000000001; labels[4] = "QNaN";
        specials[5] = 64'hFFF0000000000001; labels[5] = "SNaN";
        specials[6] = 64'h3FF0000000000000; labels[6] = "+1.0";
        specials[7] = 64'hBFF0000000000000; labels[7] = "-1.0";

        // Test every (a, b) special combination for each opcode
        for (int op = 0; op <= 4; op++) begin
            for (int i = 0; i < specials.size(); i++) begin
                for (int j = 0; j < specials.size(); j++) begin
                    req = fpu_transaction::type_id::create("req");
                    start_item(req);
                    req.a.rand_mode(0);
                    req.b.rand_mode(0);
                    req.c.rand_mode(0);
                    req.opcode.rand_mode(0);
                    req.a      = specials[i];
                    req.b      = specials[j];
                    req.c      = specials[(i+j) % specials.size()]; // Vary C for FMA
                    req.opcode = op[2:0];
                    finish_item(req);
                end
            end
        end
        `uvm_info("SEQ", $sformatf("Special cases sequence completed: %0d transactions", 5 * 8 * 8), UVM_LOW)
    endtask
endclass

// ============================================================
// Sequence 2: Subnormal Stress
// Forces exponents into [0:1] to stress underflow/normalization
// ============================================================
class fpu_subnormal_seq extends uvm_sequence #(fpu_transaction);
    `uvm_object_utils(fpu_subnormal_seq)

    int repeat_count = 2000;

    function new(string name = "fpu_subnormal_seq");
        super.new(name);
    endfunction

    virtual task body();
        for (int i = 0; i < repeat_count; i++) begin
            req = fpu_transaction::type_id::create("req");
            start_item(req);
            if (!req.randomize() with {
                a[62:52] inside {[11'h000 : 11'h002]};
                b[62:52] inside {[11'h000 : 11'h002]};
                a[51:0]  != 0;  // Ensure non-zero mantissa (true subnormal, not zero)
                b[51:0]  != 0;
            }) begin
                `uvm_fatal("SEQ", "Subnormal randomization failed")
            end
            finish_item(req);
        end
        `uvm_info("SEQ", $sformatf("Subnormal sequence completed: %0d transactions", repeat_count), UVM_LOW)
    endtask
endclass

// ============================================================
// Sequence 3: Rounding Tie Stress
// Constructs mantissas that land on exact RNTE tie boundaries
// ============================================================
class fpu_rounding_tie_seq extends uvm_sequence #(fpu_transaction);
    `uvm_object_utils(fpu_rounding_tie_seq)

    int repeat_count = 1000;

    function new(string name = "fpu_rounding_tie_seq");
        super.new(name);
    endfunction

    virtual task body();
        for (int i = 0; i < repeat_count; i++) begin
            req = fpu_transaction::type_id::create("req");
            start_item(req);
            if (!req.randomize() with {
                // Normal exponents, constrained mantissa LSBs to create tie scenarios
                a[62:52] inside {[11'h001 : 11'h7FE]};
                b[62:52] inside {[11'h001 : 11'h7FE]};
                // Force mantissa patterns that create rounding ties:
                // Bit pattern ending in ...1000 (exact tie) for addition results
                a[2:0] == 3'b000;
                b[2:0] == 3'b000;
            }) begin
                `uvm_fatal("SEQ", "Rounding tie randomization failed")
            end
            finish_item(req);
        end
        `uvm_info("SEQ", $sformatf("Rounding tie sequence completed: %0d transactions", repeat_count), UVM_LOW)
    endtask
endclass

// ============================================================
// Sequence 4: Boundary Exponent Stress
// Tests extreme exponent values (near overflow/underflow)
// ============================================================
class fpu_boundary_exp_seq extends uvm_sequence #(fpu_transaction);
    `uvm_object_utils(fpu_boundary_exp_seq)

    int repeat_count = 1000;

    function new(string name = "fpu_boundary_exp_seq");
        super.new(name);
    endfunction

    virtual task body();
        for (int i = 0; i < repeat_count; i++) begin
            req = fpu_transaction::type_id::create("req");
            start_item(req);
            if (!req.randomize() with {
                a[62:52] inside {11'h001, 11'h002, 11'h003,
                                 11'h7FC, 11'h7FD, 11'h7FE};
                b[62:52] inside {11'h001, 11'h002, 11'h003,
                                 11'h7FC, 11'h7FD, 11'h7FE};
            }) begin
                `uvm_fatal("SEQ", "Boundary exponent randomization failed")
            end
            finish_item(req);
        end
        `uvm_info("SEQ", $sformatf("Boundary exponent sequence completed: %0d transactions", repeat_count), UVM_LOW)
    endtask
endclass

// ============================================================
// Sequence 5: Division-Focused Stress
// Targets division-specific corner cases
// ============================================================
class fpu_div_stress_seq extends uvm_sequence #(fpu_transaction);
    `uvm_object_utils(fpu_div_stress_seq)

    int repeat_count = 500;

    function new(string name = "fpu_div_stress_seq");
        super.new(name);
    endfunction

    virtual task body();
        // Part 1: Force division opcode with special values
        for (int i = 0; i < repeat_count; i++) begin
            req = fpu_transaction::type_id::create("req");
            start_item(req);
            if (!req.randomize() with {
                opcode == 3'b011; // Division only
            }) begin
                `uvm_fatal("SEQ", "Div stress randomization failed")
            end
            finish_item(req);
        end

        // Part 2: Division with subnormal dividends/divisors
        for (int i = 0; i < repeat_count; i++) begin
            req = fpu_transaction::type_id::create("req");
            start_item(req);
            if (!req.randomize() with {
                opcode == 3'b011;
                a[62:52] inside {[11'h000 : 11'h003]};
                b[62:52] inside {[11'h001 : 11'h7FE]};
                a[51:0]  != 0;
                b[51:0]  != 0;
            }) begin
                `uvm_fatal("SEQ", "Div subnormal randomization failed")
            end
            finish_item(req);
        end

        // Part 3: Near-equal dividend and divisor (result ≈ 1.0)
        for (int i = 0; i < 200; i++) begin
            req = fpu_transaction::type_id::create("req");
            start_item(req);
            if (!req.randomize() with {
                opcode == 3'b011;
                a[62:52] == b[62:52]; // Same exponent
                a[62:52] inside {[11'h001 : 11'h7FE]};
            }) begin
                `uvm_fatal("SEQ", "Div near-equal randomization failed")
            end
            finish_item(req);
        end

        `uvm_info("SEQ", $sformatf("Division stress sequence completed: %0d transactions", repeat_count*2 + 200), UVM_LOW)
    endtask
endclass
