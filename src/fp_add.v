`timescale 1ns/1ps

module fp_add (
    input  wire [63:0] a,
    input  wire [63:0] b,
    output reg  [63:0] result
);

    // Step 1: Unpack
    wire sign_a = a[63];
    wire [10:0] exp_a = a[62:52];
    wire [51:0] frac_a = a[51:0];
    wire sign_b = b[63];
    wire [10:0] exp_b = b[62:52];
    wire [51:0] frac_b = b[51:0];

    wire is_nan_a = (exp_a == 11'h7FF) && (frac_a != 0);
    wire is_nan_b = (exp_b == 11'h7FF) && (frac_b != 0);
    wire is_inf_a = (exp_a == 11'h7FF) && (frac_a == 0);
    wire is_inf_b = (exp_b == 11'h7FF) && (frac_b == 0);
    wire is_zero_a = (exp_a == 0) && (frac_a == 0);
    wire is_zero_b = (exp_b == 0) && (frac_b == 0);

    wire [63:0] quiet_nan = {1'b0, 11'h7FF, 1'b1, 51'b0};

    reg sign_res;
    reg [10:0] exp_res;
    reg [53:0] mant_a, mant_b, mant_res;

    integer shift;

    always @(*) begin
        // Handle Special Cases
        if (is_nan_a || is_nan_b) begin
            result = quiet_nan;
        end else if (is_inf_a && is_inf_b && (sign_a != sign_b)) begin
            result = quiet_nan;
        end else if (is_inf_a) begin
            result = a;
        end else if (is_inf_b) begin
            result = b;
        end else if (is_zero_a && is_zero_b) begin
            result = {sign_a & sign_b, 63'b0};
        end else begin
             
            mant_a = (exp_a == 0) ? {1'b0, frac_a} : {1'b1, frac_a};
            mant_b = (exp_b == 0) ? {1'b0, frac_b} : {1'b1, frac_b};

            // Align exponents 
            if (exp_a > exp_b) begin
                shift = exp_a - exp_b;
                mant_b = mant_b >> shift;
                exp_res = exp_a;
            end else begin
                shift = exp_b - exp_a;
                mant_a = mant_a >> shift;
                exp_res = exp_b;
            end

            // Perform addition or subtraction 
            if (sign_a == sign_b) begin
                mant_res = mant_a + mant_b;
                sign_res = sign_a;
            end else begin
                if (mant_a >= mant_b) begin
                    mant_res = mant_a - mant_b;
                    sign_res = sign_a;
                end else begin
                    mant_res = mant_b - mant_a;
                    sign_res = sign_b;
                end
            end

            // Normalize result
            if (mant_res == 0) begin
                exp_res = 0;
                sign_res = 0;
            end else begin
                while ((mant_res[53] == 0) && (exp_res > 0)) begin
                    mant_res = mant_res << 1;
                    exp_res = exp_res - 1;
                end
                if (mant_res[53]) begin
                    mant_res = mant_res >> 1;
                    exp_res = exp_res + 1;
                end
            end

            // Pack final result 
            result = {sign_res, exp_res[10:0], mant_res[51:0]};
        end
    end
endmodule
