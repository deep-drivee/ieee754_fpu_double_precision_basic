`timescale 1ns/1ps

module fp_add (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [63:0] a,
    input  wire [63:0] b,
    output reg  [63:0] result
);

    wire [63:0] quiet_nan = {1'b0, 11'h7FF, 1'b1, 51'b0};

    // ==========================================
    // STAGE 1: Unpack and check special cases
    // ==========================================
    reg s1_is_special;
    reg [63:0] s1_special_result;
    
    reg s1_sign_a, s1_sign_b;
    reg [10:0] s1_exp_a, s1_exp_b;
    reg [56:0] s1_mant_a, s1_mant_b;

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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_is_special <= 0;
            s1_special_result <= 0;
            s1_sign_a <= 0; s1_sign_b <= 0;
            s1_exp_a <= 0;  s1_exp_b <= 0;
            s1_mant_a <= 0; s1_mant_b <= 0;
        end else begin

            if (is_nan_a || is_nan_b) begin
                s1_is_special <= 1'b1;
                s1_special_result <= quiet_nan;
            end else if (is_inf_a && is_inf_b && (sign_a != sign_b)) begin
                s1_is_special <= 1'b1;
                s1_special_result <= quiet_nan;
            end else if (is_inf_a) begin
                s1_is_special <= 1'b1;
                s1_special_result <= a;
            end else if (is_inf_b) begin
                s1_is_special <= 1'b1;
                s1_special_result <= b;
            end else if (is_zero_a && is_zero_b) begin
                s1_is_special <= 1'b1;
                s1_special_result <= {sign_a & sign_b, 63'b0};
            end else begin
                s1_is_special <= 1'b0;
                s1_sign_a <= sign_a;
                s1_sign_b <= sign_b;
                s1_exp_a <= (exp_a == 0) ? 11'd1 : exp_a;
                s1_exp_b <= (exp_b == 0) ? 11'd1 : exp_b;
                s1_mant_a <= (exp_a == 0) ? {1'b0, frac_a, 3'b000} : {1'b1, frac_a, 3'b000};
                s1_mant_b <= (exp_b == 0) ? {1'b0, frac_b, 3'b000} : {1'b1, frac_b, 3'b000};
            end
        end
    end

    // ==========================================
    // STAGE 2: Align exponents and compute Math
    // ==========================================
    reg s2_is_special;
    reg [63:0] s2_special_result;
    
    reg s2_sign_res;
    reg [10:0] s2_exp_res;
    reg [56:0] s2_mant_res;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_is_special <= 0;
            s2_special_result <= 0;
            s2_sign_res <= 0;
            s2_exp_res <= 0;
            s2_mant_res <= 0;
        end else if (s1_is_special) begin
            s2_is_special <= 1'b1;
            s2_special_result <= s1_special_result;
        end else begin
            s2_is_special <= 1'b0;
            begin : add_logic
                reg [56:0] m_a, m_b;
                integer shift;
                
                m_a = s1_mant_a;
                m_b = s1_mant_b;
                
                if (s1_exp_a > s1_exp_b) begin
                    shift = s1_exp_a - s1_exp_b;
                    if (shift >= 56) begin
                        m_b = {56'b0, m_b != 0};
                    end else begin
                        m_b = (m_b >> shift) | {56'b0, (m_b & ((64'b1 << shift) - 1)) != 0};
                    end
                    s2_exp_res <= s1_exp_a;
                end else begin
                    shift = s1_exp_b - s1_exp_a;
                    if (shift >= 56) begin
                        m_a = {56'b0, m_a != 0};
                    end else begin
                        m_a = (m_a >> shift) | {56'b0, (m_a & ((64'b1 << shift) - 1)) != 0};
                    end
                    s2_exp_res <= s1_exp_b;
                end

                if (s1_sign_a == s1_sign_b) begin
                    s2_mant_res <= m_a + m_b;
                    s2_sign_res <= s1_sign_a;
                end else begin
                    if (m_a >= m_b) begin
                        s2_mant_res <= m_a - m_b;
                        s2_sign_res <= s1_sign_a;
                    end else begin
                        s2_mant_res <= m_b - m_a;
                        s2_sign_res <= s1_sign_b;
                    end
                end
            end
        end
    end

    // ==========================================
    // STAGE 3: Normalization
    // ==========================================
    reg s3_is_special;
    reg [63:0] s3_special_result;
    
    reg s3_sign_res;
    reg [10:0] s3_exp_res;
    reg [56:0] s3_mant_res;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_is_special <= 0;
            s3_special_result <= 0;
            s3_sign_res <= 0;
            s3_exp_res <= 0;
            s3_mant_res <= 0;
        end else if (s2_is_special) begin
            s3_is_special <= 1'b1;
            s3_special_result <= s2_special_result;
        end else begin
            s3_is_special <= 1'b0;
            s3_sign_res <= s2_sign_res;
            begin : norm_logic
                reg [56:0] m_res;
                reg [10:0] e_res;
                m_res = s2_mant_res;
                e_res = s2_exp_res;
                
                if (m_res == 0) begin
                    e_res = 0;
                    s3_sign_res <= 0;
                end else begin
                    if (m_res[56]) begin // Overflow from add
                        m_res = (m_res >> 1) | {56'b0, m_res[0] | m_res[1]};
                        e_res = e_res + 1;
                    end else begin
                        while ((m_res[55] == 0) && (e_res > 1)) begin
                            m_res = m_res << 1;
                            e_res = e_res - 1;
                        end
                        if (e_res == 1 && m_res[55] == 0) begin
                            e_res = 0; // Drop into subnormal
                        end
                    end
                end
                s3_mant_res <= m_res;
                s3_exp_res <= e_res;
            end
        end
    end

    // ==========================================
    // STAGE 4: Rounding and Packing
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
        end else if (s3_is_special) begin
            result <= s3_special_result;
        end else begin
            begin : pack_logic
                reg [56:0] m_res;
                reg [10:0] e_res;
                reg round_bit;
                
                m_res = s3_mant_res;
                e_res = s3_exp_res;
                
                if (m_res != 0) begin
                    round_bit = m_res[2] & (m_res[1] | m_res[0] | m_res[3]);
                    if (round_bit) begin
                        m_res = m_res + 8;
                        if (m_res[56]) begin 
                            m_res = m_res >> 1;
                            e_res = e_res + 1;
                        end
                    end
                end
                
                if (e_res >= 2047) begin
                    result <= {s3_sign_res, 11'h7FF, 52'b0};
                end else begin
                    result <= {s3_sign_res, e_res[10:0], m_res[54:3]};
                end
            end
        end
    end

endmodule
