`include "uvm_macros.svh"
import uvm_pkg::*;

class fpu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fpu_scoreboard)

    uvm_analysis_imp #(fpu_transaction, fpu_scoreboard) scb_export;

    int pass_count;
    int fail_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        pass_count = 0;
        fail_count = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        scb_export = new("scb_export", this);
    endfunction

    virtual function void write(fpu_transaction trans);
        real expected_real;
        logic [63:0] expected_bits;
        real a_real, b_real, c_real;
        logic is_expected_nan;
        logic is_actual_nan;
        logic match;
        
        a_real = $bitstoreal(trans.a);
        b_real = $bitstoreal(trans.b);
        c_real = $bitstoreal(trans.c);
        
        case(trans.opcode)
            3'b000: expected_real = a_real + b_real;
            3'b001: expected_real = a_real - b_real;
            3'b010: expected_real = a_real * b_real;
            3'b011: expected_real = a_real / b_real;
            3'b100: expected_real = (a_real * b_real) + c_real;
            default: expected_real = 0;
        endcase
        
        expected_bits = $realtobits(expected_real);
        
        is_expected_nan = (expected_bits[62:52] == 11'h7FF) && (expected_bits[51:0] != 0);
        is_actual_nan   = (trans.actual_result[62:52] == 11'h7FF) && (trans.actual_result[51:0] != 0);

        // Mismatch Evaluation
        if (is_expected_nan && is_actual_nan) begin
            match = 1; // Both NaN
        end else if (trans.actual_result === expected_bits) begin
            match = 1; // Perfect bitwise match
        end else begin
            longint diff = trans.actual_result - expected_bits;
            if (diff == 1 || diff == -1) begin
                match = 1; // 1 ULP deviation allowed
            end else begin
                match = 0;
            end
        end
        
        if(match) begin
            pass_count++;
            if (pass_count <= 5 || pass_count % 1000 == 0) begin
                `uvm_info("SCB", $sformatf("PASS #%0d | OP: %b | A: %h | B: %h | C: %h -> RES: %h", pass_count, trans.opcode, trans.a, trans.b, trans.c, trans.actual_result), UVM_LOW)
            end
        end else begin
            `uvm_error("SCB", $sformatf("MISMATCH DETECTED!\nOPCODE: %b\nA     : %h\nB     : %h\nC     : %h\nACTUAL: %h\nEXPECT: %h", trans.opcode, trans.a, trans.b, trans.c, trans.actual_result, expected_bits))
            fail_count++;
        end
    endfunction
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB", "==================================================", UVM_NONE)
        `uvm_info("SCB", "   FPU AUTOMATED UVM VERIFICATION COMPLETED       ", UVM_NONE)
        `uvm_info("SCB", $sformatf("   TOTAL TRANSACTIONS : %0d", pass_count + fail_count), UVM_NONE)
        `uvm_info("SCB", $sformatf("   PASSED: %0d", pass_count), UVM_NONE)
        `uvm_info("SCB", $sformatf("   FAILED: %0d", fail_count), UVM_NONE)
        `uvm_info("SCB", "==================================================", UVM_NONE)
    endfunction
endclass
