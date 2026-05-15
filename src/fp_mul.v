`timescale 1ns/1ps

module fp_mul (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [63:0] a,
    input  wire [63:0] b,
    output reg  [63:0] result
);

    wire [63:0] quiet_nan = {1'b0, 11'h7FF, 1'b1, 51'b0};

    // ==========================================
    // STAGE 1: Unpack and Special cases
    // ==========================================
    reg s1_is_special;
    reg [63:0] s1_special_result;
    
    reg s1_sign_res;
    reg signed [13:0] s1_exp_a, s1_exp_b;
    reg [52:0] s1_mant_a, s1_mant_b;

    wire sign_a = a[63];
    wire [10:0] exp_a = a[62:52];
    wire [51:0] frac_a = a[51:0];
    wire sign_b = b[63];
    wire [10:0] exp_b = b[62:52];
    wire [51:0] frac_b = b[51:0];

    wire is_zero_a = (exp_a == 0) && (frac_a == 0);
    wire is_zero_b = (exp_b == 0) && (frac_b == 0);
    wire is_inf_a  = (exp_a == 11'h7FF) && (frac_a == 0);
    wire is_inf_b  = (exp_b == 11'h7FF) && (frac_b == 0);
    wire is_nan_a  = (exp_a == 11'h7FF) && (frac_a != 0);
    wire is_nan_b  = (exp_b == 11'h7FF) && (frac_b != 0);
            
    wire result_sign = sign_a ^ sign_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_is_special <= 0;
            s1_special_result <= 0;
            s1_sign_res <= 0;
            s1_exp_a <= 0; s1_exp_b <= 0;
            s1_mant_a <= 0; s1_mant_b <= 0;
        end else begin

            if (is_nan_a || is_nan_b) begin
                s1_is_special <= 1'b1;
                s1_special_result <= quiet_nan;
            end else if ((is_zero_a && is_inf_b) || (is_inf_a && is_zero_b)) begin
                s1_is_special <= 1'b1;
                s1_special_result <= quiet_nan;
            end else if (is_inf_a || is_inf_b) begin
                s1_is_special <= 1'b1;
                s1_special_result <= {result_sign, 11'h7FF, 52'b0};
            end else if (is_zero_a || is_zero_b) begin
                s1_is_special <= 1'b1;
                s1_special_result <= {result_sign, 63'b0};
            end else begin
                s1_is_special <= 1'b0;
                s1_sign_res <= result_sign;
                
                begin : align_logic
                    reg [52:0] m_a, m_b;
                    reg [10:0] e_a, e_b;
                    m_a = (exp_a == 0) ? {1'b0, frac_a} : {1'b1, frac_a};
                    m_b = (exp_b == 0) ? {1'b0, frac_b} : {1'b1, frac_b};
                    e_a = (exp_a == 0) ? 1 : exp_a;
                    e_b = (exp_b == 0) ? 1 : exp_b;
                    
                    if (exp_a == 0 && frac_a != 0) begin
                        while (m_a[52] == 0) begin
                            m_a = m_a << 1;
                            e_a = e_a - 1; // Wait, shifting left decreases physical exponent equivalent
                            // Since we do exp_math later, let's keep track:
                            // Actually, let's just do shift counters like original fp_mul
                        end
                    end
                end
                // Wait, tracking shift inside the clock block needs distinct vars. 
                // Let's mirror original:
                begin : align_original
                    reg [52:0] m_a, m_b;
                    integer shift_a, shift_b;
                    m_a = (exp_a == 0) ? {1'b0, frac_a} : {1'b1, frac_a};
                    m_b = (exp_b == 0) ? {1'b0, frac_b} : {1'b1, frac_b};
                    shift_a = 0; shift_b = 0;
                    
                    if (exp_a == 0 && frac_a != 0) begin
                        while (m_a[52] == 0) begin
                            m_a = m_a << 1;
                            shift_a = shift_a + 1;
                        end
                    end
                    if (exp_b == 0 && frac_b != 0) begin
                        while (m_b[52] == 0) begin
                            m_b = m_b << 1;
                            shift_b = shift_b + 1;
                        end
                    end
                    
                    s1_exp_a <= (exp_a == 0) ? $signed(14'd1) - shift_a : $signed({3'b0, exp_a}); 
                    s1_exp_b <= (exp_b == 0) ? $signed(14'd1) - shift_b : $signed({3'b0, exp_b});
                    s1_mant_a <= m_a;
                    s1_mant_b <= m_b;
                end
            end
        end
    end

    // ==========================================
    // STAGE 2: Exponent Math & Booth Mantissa Mul
    // ==========================================
    reg s2_is_special;
    reg [63:0] s2_special_result;
    
    reg s2_sign_res;
    reg signed [13:0] s2_exp_res;
    reg [105:0] s2_mant_res;

    // Booth Encoding logic
    // Radix-4 Booth encoding reduces 53 partial products to 27
    wire [54:0] b_booth = {1'b0, s1_mant_b, 1'b0}; // b_ext strictly padded for valid bit 54 access
    
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
            s2_sign_res <= s1_sign_res;
            s2_exp_res <= $signed({3'b0, s1_exp_a}) + $signed({3'b0, s1_exp_b}) - 1023;
            
            begin : booth_multiplication
                reg [105:0] pp [0:26]; // Partial Products
                reg [105:0] sum;
                integer i;
                
                // Partial Product Generation
                for (i = 0; i < 27; i = i + 1) begin
                    case (b_booth[2*i +: 3])
                        3'b001, 3'b010: pp[i] = {53'b0, s1_mant_a} << (2*i);
                        3'b011:         pp[i] = {52'b0, s1_mant_a, 1'b0} << (2*i);
                        3'b100:         pp[i] = -({52'b0, s1_mant_a, 1'b0} << (2*i));
                        3'b101, 3'b110: pp[i] = -({53'b0, s1_mant_a} << (2*i));
                        default:        pp[i] = 106'b0; // Replaces 000/111 & handles explicit X-case simulation overrides safely
                    endcase
                end
                
                // Reduction Tree (Simplified for simulation, synthesis software will optimize)
                sum = 106'b0;
                for (i = 0; i < 27; i = i + 1) begin
                    sum = sum + pp[i];
                end
                s2_mant_res <= sum;
            end
        end
    end

    // ==========================================
    // STAGE 3: Normalization & Underflow Catch
    // ==========================================
    reg s3_is_special;
    reg [63:0] s3_special_result;
    
    reg s3_sign_res;
    reg signed [13:0] s3_exp_res;
    reg [105:0] s3_mant_res;

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
                reg [105:0] m_res;
                reg signed [13:0] e_res;
                integer shift_amt;
                reg sticky;
                
                m_res = s2_mant_res;
                e_res = s2_exp_res;
                
                if (m_res[105] == 1) begin
                    m_res = (m_res >> 1) | {105'b0, m_res[0]};
                    e_res = e_res + 1;
                end
                
                // Deep Underflow Catch
                if (e_res <= 0) begin
                    shift_amt = 1 - e_res;
                    if (shift_amt >= 106) begin
                        m_res = {106'b0, m_res != 0};
                        e_res = 0;
                    end else begin
                        sticky = (m_res << (106 - shift_amt)) != 0;
                        m_res = (m_res >> shift_amt) | {105'b0, sticky};
                        e_res = 0;
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
                reg [105:0] m_res;
                reg signed [13:0] e_res;
                reg round_bit;
                
                m_res = s3_mant_res;
                e_res = s3_exp_res;
                
                if (m_res != 0) begin
                    // m_res[104] is implicit 1. Fraction is 103:52. Guard 51, Round 50, Sticky 49:0
                    round_bit = m_res[51] & (m_res[50] | (|m_res[49:0]) | m_res[52]);
                    if (round_bit) begin
                        m_res = m_res + (106'b1 << 52);
                        if (m_res[105]) begin // Overflowed during rounding
                            m_res = m_res >> 1;
                            e_res = e_res + 1;
                        end
                    end
                end
                
                if (e_res >= 2047) begin
                    result <= {s3_sign_res, 11'h7FF, 52'b0};
                end else begin
                    result <= {s3_sign_res, e_res[10:0], m_res[103:52]};
                end
            end
        end
    end

endmodule
