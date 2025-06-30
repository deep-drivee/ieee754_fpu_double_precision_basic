`timescale 1ns/1ps

module tb_fpu;

    reg  [63:0] a, b;
    reg  [1:0]  opcode;  // 00: add, 01: sub, 10: mul, 11: div
    wire [63:0] result;

    fpu uut (
        .a(a),
        .b(b),
        .opcode(opcode),
        .result(result)
    );

    // Display helper
    task display_case;
        input [255:0] label;
        begin
            $display("%0t ns | %-30s | A: %h  B: %h  -> Result: %h",
                     $time, label, a, b, result);
        end
    endtask

    initial begin
        $display("\n IEEE754 FPU Testbench ");

        // General Addition 
        a = 64'h3FF0000000000000; b = 64'h3FF0000000000000; opcode = 2'b00; #10 display_case("1.0 + 1.0");
        a = 64'h4010000000000000; b = 64'h4014000000000000; opcode = 2'b00; #10 display_case("4.0 + 5.0");
        a = 64'h4008000000000000; b = 64'hBFF0000000000000; opcode = 2'b00; #10 display_case("3.0 + (-1.0)");
        
        // General Subtraction 
        a = 64'h4059000000000000; b = 64'h4040800000000000; opcode = 2'b01; #10 display_case("100 - 33");
        a = 64'h4023800000000000; b = 64'h3FE8000000000000; opcode = 2'b01; #10 display_case("9.75 - 0.75");
        a = 64'h3FF0000000000001; b = 64'h3FF0000000000000; opcode = 2'b01; #10 display_case("1.000...1 - 1.0");

        // General Multiplication 
        a = 64'h3FF8000000000000; b = 64'h4000000000000000; opcode = 2'b10; #10 display_case("1.5 * 2.0");
        a = 64'h3FB999999999999A; b = 64'h3FC999999999999A; opcode = 2'b10; #10 display_case("0.1 * 0.2");
        a = 64'h400C000000000000; b = 64'h4000000000000000; opcode = 2'b10; #10 display_case("3.5 * 2.0");

        // General Division 
        a = 64'h4024000000000000; b = 64'h4000000000000000; opcode = 2'b11; #10 display_case("10.0 / 2.0");
        a = 64'h3FF0000000000000; b = 64'h4008000000000000; opcode = 2'b11; #10 display_case("1.0 / 3.0");
        a = 64'h4008000000000000; b = 64'h3FF0000000000000; opcode = 2'b11; #10 display_case("3.0 / 1.0");

        // Mixed + Rounding 
        a = 64'h3FFFFFCCCCCCCCCD; b = 64'h3FF000199999999A; opcode = 2'b00; #10 display_case("1.999999 + 1.000001");
        a = 64'h3F70624DD2F1A9FC; b = 64'h3F80C49BA5E353F8; opcode = 2'b00; #10 display_case("0.0001 + 0.0002");

        // Subnormal Operations 
        a = 64'h0000000000000001; b = 64'h3FF0000000000000; opcode = 2'b00; #10 display_case("subnormal + 1.0");
        a = 64'h0000000000000001; b = 64'h0000000000000001; opcode = 2'b01; #10 display_case("denorm - denorm");
        a = 64'h0000000000000001; b = 64'h3FF0000000000000; opcode = 2'b11; #10 display_case("denorm / 1.0");

        // Infinity and NaN 
        a = 64'h7FF0000000000000; b = 64'h3FF0000000000000; opcode = 2'b00; #10 display_case("Inf + 1.0");
        a = 64'hFFF0000000000000; b = 64'hFFF0000000000000; opcode = 2'b00; #10 display_case("-Inf + -Inf");
        a = 64'h7FF0000000000000; b = 64'hFFF0000000000000; opcode = 2'b00; #10 display_case("Inf + -Inf (NaN)");
        a = 64'h7FF8000000000000; b = 64'h4000000000000000; opcode = 2'b00; #10 display_case("NaN + 2.0");
        a = 64'h0000000000000000; b = 64'h0000000000000000; opcode = 2'b11; #10 display_case("0.0 / 0.0 (NaN)");

        $display("\n Testbench Completed ");
        $finish;
    end

endmodule
