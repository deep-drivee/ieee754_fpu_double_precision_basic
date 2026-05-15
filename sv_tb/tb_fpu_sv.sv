`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

module tb_fpu_sv;

    logic clk;
    logic rst_n;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset sequence integration
    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;
    end

    // Interface instantiation
    fpu_if vif(clk, rst_n);

    // DUT instantiation
    fpu dut (
        .clk(clk),
        .rst_n(rst_n),
        .a(vif.a),
        .b(vif.b),
        .c(vif.c),
        .opcode(vif.opcode),
        .valid_in(vif.valid_in),
        .ready_in(vif.ready_in),
        .valid_out(vif.valid_out),
        .result(vif.result)
    );

    // Bind SVA assertions to DUT
    fpu_assertions fpu_sva (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(vif.valid_in),
        .ready_in(vif.ready_in),
        .valid_out(vif.valid_out),
        .result(vif.result),
        .opcode(vif.opcode)
    );

    // Environment and execution
    initial begin
        // Pass the interface to the UVM configuration database globally
        uvm_config_db#(virtual fpu_if)::set(null, "*", "vif", vif);
        
        // Launch UVM test (select via +UVM_TESTNAME on command line)
        run_test("fpu_base_test");
    end

endmodule
