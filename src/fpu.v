`timescale 1ns/1ps

module fpu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [63:0] c,       // Added for FMA
    input  wire [2:0]  opcode,  // Expanded to 3 bits for FMA support
    input  wire        valid_in,
    output wire        ready_in,
    output reg         valid_out,
    output reg  [63:0] result
);

    // Global Instruction Sequencer FSM
    localparam IDLE = 2'd0;
    localparam FAST = 2'd1;
    localparam SLOW = 2'd2;

    reg [1:0] state;
    reg [2:0] fast_counter;
    
    // Handshake signals for Divider
    reg  div_valid_in;
    wire div_valid_out;
    
    wire [63:0] add_out, sub_out, mul_out, div_out, fma_out;

    assign ready_in = (state == IDLE);

    // Register opcodes dynamically locally to route the mux upon finishing
    reg [2:0] active_opcode;

    // Instantiate all operations
    fp_add adder (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .result(add_out)
    );

    fp_sub subtractor (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .result(sub_out)
    );

    fp_mul multiplier (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .result(mul_out)
    );

    fp_div divider (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(div_valid_in),
        .a(a),
        .b(b),
        .valid_out(div_valid_out),
        .result(div_out)
    );

    fp_fma fma_unit (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .c(c),
        .result(fma_out)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            fast_counter <= 0;
            valid_out <= 0;
            div_valid_in <= 0;
            active_opcode <= 3'b000;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    div_valid_in <= 1'b0;
                    if (valid_in) begin
                        active_opcode <= opcode;
                        if (opcode == 3'b011) begin // Division
                            div_valid_in <= 1'b1;
                            state <= SLOW;
                        end else begin // Fast 4-stage modules
                            fast_counter <= 3'd3; // Count 4 cycles including execution cycle natively
                            state <= FAST;
                        end
                    end
                end
                
                FAST: begin
                    if (fast_counter == 0) begin
                        valid_out <= 1'b1;
                        state <= IDLE;
                    end else begin
                        fast_counter <= fast_counter - 1;
                    end
                end
                
                SLOW: begin
                    div_valid_in <= 1'b0; // Pulse for 1 cycle only statically
                    if (div_valid_out) begin
                        valid_out <= 1'b1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Result routing multiplexer functionally bound to active sequencer path
    always @(*) begin
        case (active_opcode)
            3'b000:  result = add_out;
            3'b001:  result = sub_out;
            3'b010:  result = mul_out;
            3'b011:  result = div_out;
            3'b100:  result = fma_out;
            default: result = 64'h0000000000000000;
        endcase
    end
endmodule
