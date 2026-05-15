`timescale 1ns/1ps

// ============================================================
// SVA Assertions Module for FPU
// Bind this to the DUT to enforce protocol and safety checks.
// ============================================================
module fpu_assertions (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire        ready_in,
    input  wire        valid_out,
    input  wire [63:0] result,
    input  wire [2:0]  opcode
);

    // --------------------------------------------------------
    // A1: No X/Z on result when valid_out is asserted
    // --------------------------------------------------------
    property p_no_xz_result;
        @(posedge clk) disable iff (!rst_n)
        valid_out |-> !$isunknown(result);
    endproperty
    a_no_xz_result: assert property (p_no_xz_result)
        else $error("[SVA] FAIL A1: Result contains X/Z while valid_out is high! result=%h", result);

    // --------------------------------------------------------
    // A2: No X/Z on valid_out after reset
    // --------------------------------------------------------
    property p_no_xz_valid_out;
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(valid_out);
    endproperty
    a_no_xz_valid_out: assert property (p_no_xz_valid_out)
        else $error("[SVA] FAIL A2: valid_out is X/Z!");

    // --------------------------------------------------------
    // A3: No X/Z on ready_in after reset
    // --------------------------------------------------------
    property p_no_xz_ready_in;
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(ready_in);
    endproperty
    a_no_xz_ready_in: assert property (p_no_xz_ready_in)
        else $error("[SVA] FAIL A3: ready_in is X/Z!");

    // --------------------------------------------------------
    // A4: valid_out must eventually deassert (no stuck high)
    // --------------------------------------------------------
    property p_valid_out_pulse;
        @(posedge clk) disable iff (!rst_n)
        valid_out |=> !valid_out;
    endproperty
    a_valid_out_pulse: assert property (p_valid_out_pulse)
        else $error("[SVA] FAIL A4: valid_out held high for >1 cycle!");

    // --------------------------------------------------------
    // A5: Every accepted transaction must produce a valid_out
    //     (within 70 cycles for div, 5 for fast ops)
    // --------------------------------------------------------
    property p_transaction_completes;
        @(posedge clk) disable iff (!rst_n)
        (valid_in && ready_in) |-> ##[1:70] valid_out;
    endproperty
    a_transaction_completes: assert property (p_transaction_completes)
        else $error("[SVA] FAIL A5: Transaction accepted but no valid_out within 70 cycles!");

    // --------------------------------------------------------
    // A6: Fast operations (add/sub/mul/fma) must complete in
    //     exactly 5 cycles (4 pipeline + 1 sequencer)
    // --------------------------------------------------------
    property p_fast_latency;
        @(posedge clk) disable iff (!rst_n)
        (valid_in && ready_in && opcode != 3'b011) |-> ##5 valid_out;
    endproperty
    a_fast_latency: assert property (p_fast_latency)
        else $error("[SVA] FAIL A6: Fast operation did not complete in 5 cycles! opcode=%b", opcode);

    // --------------------------------------------------------
    // A7: ready_in must be high when valid_out is asserted
    //     (both are true when state == IDLE)
    // --------------------------------------------------------
    property p_ready_when_valid_out;
        @(posedge clk) disable iff (!rst_n)
        valid_out |-> ready_in;
    endproperty
    a_ready_when_valid_out: assert property (p_ready_when_valid_out)
        else $error("[SVA] FAIL A7: ready_in not asserted while valid_out is high!");

    // --------------------------------------------------------
    // A8: ready_in must drop after accepting a transaction
    // --------------------------------------------------------
    property p_ready_drops;
        @(posedge clk) disable iff (!rst_n)
        (valid_in && ready_in) |=> !ready_in;
    endproperty
    a_ready_drops: assert property (p_ready_drops)
        else $error("[SVA] FAIL A8: ready_in did not drop after accepting transaction!");

    // --------------------------------------------------------
    // Cover properties (for coverage tracking)
    // --------------------------------------------------------
    c_add_complete: cover property (@(posedge clk) disable iff (!rst_n)
        (valid_in && ready_in && opcode == 3'b000) ##5 valid_out);

    c_sub_complete: cover property (@(posedge clk) disable iff (!rst_n)
        (valid_in && ready_in && opcode == 3'b001) ##5 valid_out);

    c_mul_complete: cover property (@(posedge clk) disable iff (!rst_n)
        (valid_in && ready_in && opcode == 3'b010) ##5 valid_out);

    c_div_complete: cover property (@(posedge clk) disable iff (!rst_n)
        (valid_in && ready_in && opcode == 3'b011) ##[1:70] valid_out);

    c_fma_complete: cover property (@(posedge clk) disable iff (!rst_n)
        (valid_in && ready_in && opcode == 3'b100) ##5 valid_out);

endmodule
