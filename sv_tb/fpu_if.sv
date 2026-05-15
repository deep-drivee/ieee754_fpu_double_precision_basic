`timescale 1ns/1ps

interface fpu_if(input logic clk, input logic rst_n);
    logic [63:0] a;
    logic [63:0] b;
    logic [63:0] c;
    logic [2:0]  opcode;
    logic [63:0] result;
    
    // Handshake signals
    logic        valid_in;
    logic        ready_in;
    logic        valid_out;

    // Driver modport
    modport DRV (
        output a,
        output b,
        output c,
        output opcode,
        output valid_in,
        input  ready_in
    );

    // Monitor modport 
    modport MON (
        input  a,
        input  b,
        input  c,
        input  opcode,
        input  result,
        input  valid_out
    );

endinterface
