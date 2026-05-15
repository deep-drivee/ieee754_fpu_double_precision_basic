`include "uvm_macros.svh"
import uvm_pkg::*;

// ============================================================
// Functional Coverage Collector
// Receives transactions from the monitor via analysis port
// and samples covergroups to track verification completeness.
// ============================================================
class fpu_coverage extends uvm_subscriber #(fpu_transaction);
    `uvm_component_utils(fpu_coverage)

    // Decoded fields for coverage sampling
    logic [2:0]  sampled_opcode;
    logic [10:0] sampled_exp_a, sampled_exp_b;
    logic        sampled_sign_a, sampled_sign_b;
    logic [10:0] sampled_exp_res;

    // ---- Covergroup: Opcode Distribution ----
    covergroup cg_opcode;
        option.per_instance = 1;
        cp_opcode: coverpoint sampled_opcode {
            bins ADD = {3'b000};
            bins SUB = {3'b001};
            bins MUL = {3'b010};
            bins DIV = {3'b011};
            bins FMA = {3'b100};
        }
    endgroup

    // ---- Covergroup: Input A Classification ----
    covergroup cg_input_a;
        option.per_instance = 1;
        cp_exp_class: coverpoint sampled_exp_a {
            bins zero       = {11'h000};
            bins subnormal  = {[11'h000 : 11'h000]} iff (sampled_exp_a == 0);
            bins tiny       = {[11'h001 : 11'h003]};
            bins normal_lo  = {[11'h004 : 11'h3FF]};
            bins normal_hi  = {[11'h400 : 11'h7FC]};
            bins huge_val   = {[11'h7FD : 11'h7FE]};
            bins inf_nan    = {11'h7FF};
        }
        cp_sign: coverpoint sampled_sign_a {
            bins positive = {1'b0};
            bins negative = {1'b1};
        }
    endgroup

    // ---- Covergroup: Input B Classification ----
    covergroup cg_input_b;
        option.per_instance = 1;
        cp_exp_class: coverpoint sampled_exp_b {
            bins zero       = {11'h000};
            bins subnormal  = {[11'h000 : 11'h000]} iff (sampled_exp_b == 0);
            bins tiny       = {[11'h001 : 11'h003]};
            bins normal_lo  = {[11'h004 : 11'h3FF]};
            bins normal_hi  = {[11'h400 : 11'h7FC]};
            bins huge_val   = {[11'h7FD : 11'h7FE]};
            bins inf_nan    = {11'h7FF};
        }
        cp_sign: coverpoint sampled_sign_b {
            bins positive = {1'b0};
            bins negative = {1'b1};
        }
    endgroup

    // ---- Covergroup: Result Classification ----
    covergroup cg_result;
        option.per_instance = 1;
        cp_exp_class: coverpoint sampled_exp_res {
            bins zero       = {11'h000};
            bins tiny       = {[11'h001 : 11'h003]};
            bins normal_lo  = {[11'h004 : 11'h3FF]};
            bins normal_hi  = {[11'h400 : 11'h7FC]};
            bins huge_val   = {[11'h7FD : 11'h7FE]};
            bins inf_nan    = {11'h7FF};
        }
    endgroup

    // ---- Covergroup: Cross Coverage (Opcode × Input Classes) ----
    covergroup cg_cross;
        option.per_instance = 1;
        cp_opcode: coverpoint sampled_opcode {
            bins ADD = {3'b000};
            bins SUB = {3'b001};
            bins MUL = {3'b010};
            bins DIV = {3'b011};
            bins FMA = {3'b100};
        }
        cp_a_class: coverpoint sampled_exp_a {
            bins zero_sub = {11'h000};
            bins normal   = {[11'h001 : 11'h7FE]};
            bins inf_nan  = {11'h7FF};
        }
        cp_b_class: coverpoint sampled_exp_b {
            bins zero_sub = {11'h000};
            bins normal   = {[11'h001 : 11'h7FE]};
            bins inf_nan  = {11'h7FF};
        }
        cp_sign_combo: coverpoint {sampled_sign_a, sampled_sign_b} {
            bins pp = {2'b00};
            bins pn = {2'b01};
            bins np = {2'b10};
            bins nn = {2'b11};
        }
        // Key crosses
        cx_op_x_a_x_b: cross cp_opcode, cp_a_class, cp_b_class;
        cx_op_x_sign:  cross cp_opcode, cp_sign_combo;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_opcode  = new();
        cg_input_a = new();
        cg_input_b = new();
        cg_result  = new();
        cg_cross   = new();
    endfunction

    // Called automatically by the analysis port on every transaction
    virtual function void write(fpu_transaction t);
        sampled_opcode = t.opcode;
        sampled_exp_a  = t.a[62:52];
        sampled_exp_b  = t.b[62:52];
        sampled_sign_a = t.a[63];
        sampled_sign_b = t.b[63];
        sampled_exp_res = t.actual_result[62:52];

        cg_opcode.sample();
        cg_input_a.sample();
        cg_input_b.sample();
        cg_result.sample();
        cg_cross.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", "==================================================", UVM_NONE)
        `uvm_info("COV", "   FUNCTIONAL COVERAGE SUMMARY", UVM_NONE)
        `uvm_info("COV", $sformatf("   Opcode Coverage  : %0.1f%%", cg_opcode.get_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("   Input A Coverage : %0.1f%%", cg_input_a.get_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("   Input B Coverage : %0.1f%%", cg_input_b.get_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("   Result Coverage  : %0.1f%%", cg_result.get_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("   Cross Coverage   : %0.1f%%", cg_cross.get_coverage()), UVM_NONE)
        `uvm_info("COV", "==================================================", UVM_NONE)
    endfunction
endclass
