`timescale 1ns/1ps

module fp_fma (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [63:0] c,
    output reg  [63:0] result
);

    wire [63:0] quiet_nan = {1'b0, 11'h7FF, 1'b1, 51'b0};

    // ==========================================
    // STAGE 1: Unpack and Subnormal Alignment
    // ==========================================
    reg s1_is_special;
    reg [63:0] s1_special_result;
    
    reg s1_sign_p, s1_sign_c;
    reg signed [13:0] s1_exp_p, s1_exp_c;
    reg [53:0] s1_mant_a, s1_mant_b, s1_mant_c;
    reg s1_is_zero_p;

    wire sign_a = a[63];
    wire [10:0] exp_a = a[62:52];
    wire [51:0] frac_a = a[51:0];
    wire sign_b = b[63];
    wire [10:0] exp_b = b[62:52];
    wire [51:0] frac_b = b[51:0];
    wire sign_c = c[63];
    wire [10:0] exp_c = c[62:52];
    wire [51:0] frac_c = c[51:0];

    wire sign_p = sign_a ^ sign_b;
    wire is_nan_a = (exp_a == 11'h7FF && frac_a != 0);
    wire is_nan_b = (exp_b == 11'h7FF && frac_b != 0);
    wire is_nan_c = (exp_c == 11'h7FF && frac_c != 0);
    wire is_inf_a = (exp_a == 11'h7FF && frac_a == 0);
    wire is_inf_b = (exp_b == 11'h7FF && frac_b == 0);
    wire is_inf_c = (exp_c == 11'h7FF && frac_c == 0);
    wire is_zero_a = (exp_a == 0 && frac_a == 0);
    wire is_zero_b = (exp_b == 0 && frac_b == 0);
    wire is_inf_p  = is_inf_a || is_inf_b;
    wire is_zero_p = is_zero_a || is_zero_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_is_special <= 0; s1_special_result <= 0;
            s1_sign_p <= 0; s1_sign_c <= 0;
            s1_exp_p <= 0; s1_exp_c <= 0;
            s1_mant_a <= 0; s1_mant_b <= 0; s1_mant_c <= 0;
            s1_is_zero_p <= 0;
        end else begin

            if (is_nan_a || is_nan_b || is_nan_c) begin
                s1_is_special <= 1'b1; s1_special_result <= quiet_nan;
            end else if ((is_inf_a && is_zero_b) || (is_inf_b && is_zero_a)) begin
                s1_is_special <= 1'b1; s1_special_result <= quiet_nan;
            end else if (is_inf_p && is_inf_c && sign_p != sign_c) begin
                s1_is_special <= 1'b1; s1_special_result <= quiet_nan;
            end else if (is_inf_p) begin
                s1_is_special <= 1'b1; s1_special_result <= {sign_p, 11'h7FF, 52'b0};
            end else if (is_inf_c) begin
                s1_is_special <= 1'b1; s1_special_result <= {sign_c, 11'h7FF, 52'b0};
            end else begin
                s1_is_special <= 1'b0;
                s1_sign_p <= sign_p;
                s1_sign_c <= sign_c;
                s1_is_zero_p <= is_zero_p;
                
                begin : align_loop
                    reg [53:0] m_a, m_b, m_c;
                    reg [10:0] e_a, e_b;
                    reg signed [13:0] e_c;
                    integer sa, sb;
                    
                    m_a = (exp_a == 0) ? {1'b0, frac_a} : {1'b1, frac_a};
                    m_b = (exp_b == 0) ? {1'b0, frac_b} : {1'b1, frac_b};
                    m_c = (exp_c == 0) ? {1'b0, frac_c} : {1'b1, frac_c};
                    sa = 0; sb = 0; e_c = (exp_c == 0) ? 14'd1 : {3'b000, exp_c};
                    
                    if (exp_a == 0 && frac_a != 0) begin while(m_a[52]==0) begin m_a=m_a<<1; sa=sa+1; end end
                    if (exp_b == 0 && frac_b != 0) begin while(m_b[52]==0) begin m_b=m_b<<1; sb=sb+1; end end
                    if (exp_c == 0 && frac_c != 0) begin while(m_c[52]==0) begin m_c=m_c<<1; e_c=e_c-1; end end

                    e_a = (exp_a == 0) ? 11'd1 : exp_a;
                    e_b = (exp_b == 0) ? 11'd1 : exp_b;
                    
                    s1_exp_p <= $signed({3'b000, e_a}) + $signed({3'b000, e_b}) - 1023 - sa - sb;
                    s1_exp_c <= e_c;
                    s1_mant_a <= m_a; s1_mant_b <= m_b; s1_mant_c <= m_c;
                end
            end
        end
    end

    // ==========================================
    // STAGE 2: Multiplier & Exponent Math Align
    // ==========================================
    reg s2_is_special;
    reg [63:0] s2_special_result;
    
    reg s2_sign_p, s2_sign_c;
    reg signed [13:0] s2_exp_res;
    reg [110:0] s2_mant_p;
    reg [110:0] s2_mant_c_wide;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_is_special <= 0; s2_special_result <= 0;
            s2_sign_p <= 0; s2_sign_c <= 0;
            s2_exp_res <= 0; s2_mant_p <= 0; s2_mant_c_wide <= 0;
        end else if (s1_is_special) begin
            s2_is_special <= 1'b1; s2_special_result <= s1_special_result;
        end else begin
            s2_is_special <= 1'b0;
            s2_sign_p <= s1_sign_p; s2_sign_c <= s1_sign_c;
            
            begin : mul_logic
                reg [105:0] raw_p;
                reg [110:0] p_aligned, c_aligned;
                integer shift;
                reg sticky_norm;
                
                raw_p = s1_mant_a * s1_mant_b;
                p_aligned = 111'b0;
                c_aligned = 111'b0;
                
                if (!s1_is_zero_p) p_aligned[107:2] = raw_p;
                if (s1_mant_c != 0) c_aligned[106:54] = s1_mant_c;
                
                if (p_aligned != 0 && c_aligned != 0) begin
                    if (s1_exp_p > s1_exp_c) begin
                        shift = s1_exp_p - s1_exp_c;
                        if (shift >= 110) begin
                            c_aligned = {110'b0, c_aligned != 0};
                        end else begin
                            sticky_norm = (c_aligned << (111 - shift)) != 0;
                            c_aligned = (c_aligned >> shift) | {110'b0, sticky_norm};
                        end
                        s2_exp_res <= s1_exp_p;
                    end else begin
                        shift = s1_exp_c - s1_exp_p;
                        if (shift >= 110) begin
                            p_aligned = {110'b0, p_aligned != 0};
                        end else begin
                            sticky_norm = (p_aligned << (111 - shift)) != 0;
                            p_aligned = (p_aligned >> shift) | {110'b0, sticky_norm};
                        end
                        s2_exp_res <= s1_exp_c;
                    end
                end else if (p_aligned != 0) begin
                    s2_exp_res <= s1_exp_p;
                end else begin
                    s2_exp_res <= s1_exp_c;
                end
                
                s2_mant_p <= p_aligned;
                s2_mant_c_wide <= c_aligned;
            end
        end
    end

    // ==========================================
    // STAGE 3: Addition & Normalization Prep
    // ==========================================
    reg s3_is_special;
    reg [63:0] s3_special_result;
    
    reg s3_sign_res;
    reg signed [13:0] s3_exp_res;
    reg [110:0] s3_mant_res;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_is_special <= 0; s3_special_result <= 0;
            s3_sign_res <= 0; s3_exp_res <= 0; s3_mant_res <= 0;
        end else if (s2_is_special) begin
            s3_is_special <= 1'b1; s3_special_result <= s2_special_result;
        end else begin
            s3_is_special <= 1'b0;
            s3_exp_res <= s2_exp_res;
            
            begin : add_logic
                reg [110:0] m_res;
                reg sign_res;
                
                if (s2_sign_p == s2_sign_c) begin
                    m_res = s2_mant_p + s2_mant_c_wide;
                    sign_res = s2_sign_p;
                end else begin
                    if (s2_mant_p >= s2_mant_c_wide) begin
                        m_res = s2_mant_p - s2_mant_c_wide;
                        sign_res = s2_sign_p;
                    end else begin
                        m_res = s2_mant_c_wide - s2_mant_p;
                        sign_res = s2_sign_c;
                    end
                end
                s3_mant_res <= m_res;
                
                if (m_res == 0) s3_sign_res <= s2_sign_p & s2_sign_c; // Exact cancellation
                else s3_sign_res <= sign_res;
            end
        end
    end

    // ==========================================
    // STAGE 4: Normalize, Underflow, Round, Pack
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
        end else if (s3_is_special) begin
            result <= s3_special_result;
        end else begin
            begin : pack_logic
                reg [110:0] m_res;
                reg signed [13:0] e_res;
                integer k, shift;
                reg sticky_norm, round_bit;
                
                m_res = s3_mant_res;
                e_res = s3_exp_res;
                
                if (m_res != 0) begin
                    k = 0;
                    for (int i = 110; i >= 0; i--) begin
                        if (m_res[i] && k == 0) k = i;
                    end
                    
                    if (k > 106) begin
                        shift = k - 106;
                        sticky_norm = (m_res << (111 - shift)) != 0;
                        m_res = (m_res >> shift) | {110'b0, sticky_norm};
                        e_res = e_res + shift;
                    end else if (k < 106) begin
                        shift = 106 - k;
                        m_res = m_res << shift;
                        e_res = e_res - shift;
                    end
                    
                    // Deep underflow
                    if (e_res <= 0) begin
                        shift = 1 - e_res;
                        if (shift >= 110) begin
                            m_res = {110'b0, m_res != 0};
                        end else begin
                            sticky_norm = (m_res << (111 - shift)) != 0;
                            m_res = (m_res >> shift) | {110'b0, sticky_norm};
                        end
                        e_res = 0;
                    end
                    
                    // RNTE
                    round_bit = m_res[53] & (m_res[52] | (|m_res[51:0]) | m_res[54]);
                    if (round_bit) begin
                        m_res = m_res + (111'h1 << 54);
                        if (m_res[107]) begin
                            m_res = m_res >> 1;
                            e_res = e_res + 1;
                        end
                    end
                    
                    if (e_res >= 2047) begin
                        result <= {s3_sign_res, 11'h7FF, 52'b0};
                    end else begin
                        result <= {s3_sign_res, e_res[10:0], m_res[105:54]};
                    end
                end else begin
                    result <= {s3_sign_res, 63'b0};
                end
            end
        end
    end

endmodule
