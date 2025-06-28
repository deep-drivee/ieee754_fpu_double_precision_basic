`timescale 1ns/1ps

module fp_sub (
    input  wire [63:0] a,
    input  wire [63:0] b,
    output wire [63:0] result
);
    wire [63:0] b_neg;

    // Flip the sign bit of B to perform A + (-B)
    assign b_neg = {~b[63], b[62:0]};

    fp_add add_unit (
        .a(a),
        .b(b_neg),
        .result(result)
    );

endmodule

