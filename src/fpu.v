`timescale 1ns/1ps

module fpu (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [1:0]  opcode,  // 00: add, 01: sub, 10: mul, 11: div
    output reg  [63:0] result
);

    wire [63:0] add_out, sub_out, mul_out, div_out;

    // Instantiate all operations
    fp_add adder (
        .a(a),
        .b(b),
        .result(add_out)
    );

    fp_sub subtractor (
        .a(a),
        .b(b),
        .result(sub_out)
    );

    fp_mul multiplier (
        .a(a),
        .b(b),
        .result(mul_out)
    );

    fp_div divider (
        .a(a),
        .b(b),
        .result(div_out)
    );

    // Operation select logic
    always @(*) begin
        case (opcode)
            2'b00: result = add_out;
            2'b01: result = sub_out;
            2'b10: result = mul_out;
            2'b11: result = div_out;
            default: result = 64'h0000000000000000;
        endcase
    end
endmodule
