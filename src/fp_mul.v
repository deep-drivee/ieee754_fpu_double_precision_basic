`timescale 1ns/1ps

module fp_mul (
    input  wire [63:0] a,
    input  wire [63:0] b,
    output reg  [63:0] result
);

    // Input Decode 
    wire sign_a     = a[63];
    wire [10:0] exp_a = a[62:52];
    wire [51:0] frac_a = a[51:0];

    wire sign_b     = b[63];
    wire [10:0] exp_b = b[62:52];
    wire [51:0] frac_b = b[51:0];

    wire result_sign = sign_a ^ sign_b;

    wire is_zero_a = (exp_a == 0 && frac_a == 0);
    wire is_zero_b = (exp_b == 0 && frac_b == 0);
    wire is_inf_a  = (exp_a == 11'h7FF && frac_a == 0);
    wire is_inf_b  = (exp_b == 11'h7FF && frac_b == 0);
    wire is_nan_a  = (exp_a == 11'h7FF && frac_a != 0);
    wire is_nan_b  = (exp_b == 11'h7FF && frac_b != 0);

    wire [63:0] quiet_nan = {1'b0, 11'h7FF, 1'b1, 51'b0};

    // Internal Registers 
    reg [53:0] mant_a, mant_b;
    reg [105:0] mant_res;
    reg [10:0] exp_a_fixed, exp_b_fixed, exp_r;
    reg [51:0] final_mant;
    reg [10:0] final_exp;
    reg [103:0] shifted;
    integer shift_amt;

    // Main Multiply Logic 
    always @(*) begin
        if (is_nan_a || is_nan_b) begin
            result = quiet_nan;
        end else if ((is_inf_a && is_zero_b) || (is_inf_b && is_zero_a)) begin
            result = quiet_nan;
        end else if (is_inf_a || is_inf_b) begin
            result = {result_sign, 11'h7FF, 52'b0};
        end else if (is_zero_a || is_zero_b) begin
            result = {result_sign, 63'b0};
        end else begin
            // Step 1: Normalize inputs
            mant_a = (exp_a == 0) ? {1'b0, frac_a} : {1'b1, frac_a};
            mant_b = (exp_b == 0) ? {1'b0, frac_b} : {1'b1, frac_b};

            // Step 2: Multiply mantissas
            mant_res = mant_a * mant_b;

            // Step 3: Fix exponent bias
            exp_a_fixed = (exp_a == 0) ? 11'd1 : exp_a;
            exp_b_fixed = (exp_b == 0) ? 11'd1 : exp_b;
            exp_r = exp_a_fixed + exp_b_fixed - 1023;

            // Step 4: Normalize result
            if (mant_res[105]) begin
                final_mant = mant_res[104:53];
                final_exp  = exp_r + 1;
            end else begin
                final_mant = mant_res[103:52];
                final_exp  = exp_r;
            end

            // Step 5: Handle special exponent cases
            if (final_exp >= 11'h7FF) begin
                // Overflow
                result = {result_sign, 11'h7FF, 52'b0};
            end else if (final_exp <= 0) begin
                // Subnormal / Underflow
                shift_amt = 1 - final_exp;
                if (shift_amt < 53) begin
                    shifted = {1'b1, final_mant, 50'b0} >> shift_amt;
                    result = {result_sign, 11'b0, shifted[101:50]};
                end else begin
                    result = {result_sign, 63'b0}; // Underflow to zero
                end
            end else begin
                // Normal number
                result = {result_sign, final_exp, final_mant};
            end
        end
    end
endmodule
