`timescale 1ns/1ps

module fp_div (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [63:0] a,
    input  wire [63:0] b,
    output reg         valid_out,
    output reg  [63:0] result
);

    wire [63:0] quiet_nan = {1'b0, 11'h7FF, 1'b1, 51'b0};

    // FSM States
    localparam IDLE    = 2'd0;
    localparam DIVIDE  = 2'd1;
    localparam PACK    = 2'd2;

    reg [1:0] state;

    // Registers for mathematical tracking
    reg s_sign_res;
    reg signed [13:0] s_exp_res;
    
    // Division Loop Registers
    reg [53:0]  D;         // Divisor
    reg [54:0]  PR;        // Partial Remainder
    reg [56:0]  Q;         // 57-bit Quotient
    reg [6:0]   count;     // 57 iterations

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
            state <= IDLE;
            valid_out <= 1'b0;
            result <= 64'b0;
            s_sign_res <= 0;
            s_exp_res <= 0;
            D <= 0; PR <= 0; Q <= 0; count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    if (valid_in) begin
                        if (is_nan_a || is_nan_b) begin
                            result <= quiet_nan;
                            valid_out <= 1'b1;
                        end else if (is_zero_a && is_zero_b) begin
                            result <= quiet_nan;
                            valid_out <= 1'b1;
                        end else if (is_inf_a && is_inf_b) begin
                            result <= quiet_nan;
                            valid_out <= 1'b1;
                        end else if (is_inf_a) begin
                            result <= {result_sign, 11'h7FF, 52'b0};
                            valid_out <= 1'b1;
                        end else if (is_inf_b) begin
                            result <= {result_sign, 63'b0};
                            valid_out <= 1'b1;
                        end else if (is_zero_a) begin
                            result <= {result_sign, 63'b0};
                            valid_out <= 1'b1;
                        end else if (is_zero_b) begin
                            result <= {result_sign, 11'h7FF, 52'b0};
                            valid_out <= 1'b1;
                        end else begin
                            s_sign_res <= result_sign;
                            begin : align_original
                                reg [53:0] m_a, m_b;
                                integer shift_a, shift_b;
                                m_a = (exp_a == 0) ? {1'b0, frac_a, 1'b0} : {1'b1, frac_a, 1'b0};
                                m_b = (exp_b == 0) ? {1'b0, frac_b, 1'b0} : {1'b1, frac_b, 1'b0};
                                shift_a = 0; shift_b = 0;
                                
                                if (exp_a == 0 && frac_a != 0) begin
                                    while (m_a[53] == 0) begin m_a = m_a << 1; shift_a = shift_a + 1; end
                                end
                                if (exp_b == 0 && frac_b != 0) begin
                                    while (m_b[53] == 0) begin m_b = m_b << 1; shift_b = shift_b + 1; end
                                end
                                
                                s_exp_res <= ($signed((exp_a == 0) ? 14'd1 - shift_a : {3'b0, exp_a}))
                                           - ($signed((exp_b == 0) ? 14'd1 - shift_b : {3'b0, exp_b}))
                                           + 1023;
                                
                                // Division initialization for 57 iterations
                                D       <= m_b;
                                PR      <= {1'b0, m_a[53:0]};
                                Q       <= 57'b0;
                                count   <= 7'd57;
                            end
                            state <= DIVIDE;
                        end
                    end
                end
                
                DIVIDE: begin
                    begin : div_logic
                        if (PR >= {1'b0, D}) begin
                            PR <= (PR - {1'b0, D}) << 1;
                            Q  <= {Q[55:0], 1'b1};
                        end else begin
                            PR <= PR << 1;
                            Q  <= {Q[55:0], 1'b0};
                        end
                        count <= count - 1;
                        
                        if (count == 1) begin
                            state <= PACK;
                        end
                    end
                end

                PACK: begin
                    begin : pack_logic
                        reg [56:0] m_res;
                        reg signed [13:0] e_res;
                        reg round_bit;
                        
                        m_res = Q;
                        e_res = s_exp_res;
                        
                        if (m_res == 0) begin
                            e_res = 0;
                        end else begin
                            if (m_res[56] == 0) begin // Output is 0.1xxx (m_a < m_b)
                                m_res = m_res << 1;
                                e_res = e_res - 1;
                            end
                            // Subnormal deep underflow catch
                            while ((m_res[56] == 0) && (e_res > 1)) begin
                                m_res = m_res << 1;
                                e_res = e_res - 1;
                            end
                            if (e_res == 1 && m_res[56] == 0) begin
                                e_res = 0;
                            end
                            
                            // Deep Underflow Catch
                            if (e_res <= 0) begin
                                integer shift_amt;
                                reg sticky_udf;
                                shift_amt = 1 - e_res;
                                if (shift_amt >= 57) begin
                                    m_res = {56'b0, (m_res != 0)};
                                    e_res = 0;
                                end else begin
                                    sticky_udf = (m_res << (57 - shift_amt)) != 0;
                                    m_res = (m_res >> shift_amt) | {56'b0, sticky_udf};
                                    e_res = 0;
                                end
                            end
                        end
                        
                        // Rounding logic properly aligned to the 57-bit precision Q format!
                        // Bit 56 is Implicit 1. Fractional bits are 55:4.
                        // Guard=3, Round=2, Sticky=1:0.
                        if (m_res != 0) begin
                            round_bit = m_res[3] & (m_res[2] | m_res[1] | m_res[0] | m_res[4]);
                            if (round_bit) begin
                                begin : rnd_overflow
                                    reg [57:0] m_wide;
                                    m_wide = {1'b0, m_res} + 16; // Add to bit 4 in 58-bit space
                                    if (m_wide[57]) begin // Overflowed during rounding
                                        m_res = m_wide[57:1];
                                        e_res = e_res + 1;
                                    end else begin
                                        m_res = m_wide[56:0];
                                    end
                                end
                            end
                        end
                        
                        if (e_res >= 2047) begin
                            result <= {s_sign_res, 11'h7FF, 52'b0};
                        end else begin
                            result <= {s_sign_res, e_res[10:0], m_res[55:4]};
                        end
                    end
                    
                    valid_out <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
