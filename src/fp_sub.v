`timescale 1ns/1ps

module fp_sub (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [63:0] a,
    input  wire [63:0] b,
    output wire [63:0] result
);

    wire [63:0] neg_b;
    assign neg_b = {~b[63], b[62:0]};

    fp_add adder (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(neg_b),
        .result(result)
    );

endmodule
