`timescale 1ns/1ps

module tb_fp_add;

    reg  [63:0] a, b;
    wire [63:0] result;

    // Instantiate the floating point adder
    fp_add dut (
        .a(a),
        .b(b),
        .result(result)
    );

    // Display helper 
    task display_case;
        input [255:0] label;
        begin
            $display("%0t ns | %-30s | A: %h  B: %h  -> Result: %h", $time, label, a, b, result);
        end
    endtask

    initial begin

        // General Cases
        a = 64'h3FF0000000000000; // 1.0
        b = 64'h3FF0000000000000; // 1.0
        #10 display_case("1.0 + 1.0");

        a = 64'h4010000000000000; // 4.0
        b = 64'h4014000000000000; // 5.0
        #10 display_case("4.0 + 5.0");

        a = 64'h4008000000000000; // 3.0
        b = 64'hC008000000000000; // -3.0
        #10 display_case("3.0 + (-3.0)");

        a = 64'h4008000000000000; // 3.0
        b = 64'hBFF0000000000000; // -1.0
        #10 display_case("3.0 + (-1.0)");

        a = 64'h4024000000000000; // 10.0
        b = 64'hC024000000000000; // -10.0
        #10 display_case("10.0 + (-10.0)");

        // Small fraction addition
        a = 64'h3fb999999999999a; // 0.1
        b = 64'h3fc999999999999a; // 0.2
        #10 display_case("0.1 + 0.2");

        // Edge Cases
        a = 64'h0000000000000001; // Smallest subnormal
        b = 64'h3FF0000000000000; // 1.0
        #10 display_case("Subnormal + 1.0");

        a = 64'h7FF0000000000000; // +Inf
        b = 64'h3FF0000000000000; // 1.0
        #10 display_case("Inf + 1.0");

        a = 64'hFFF0000000000000; // -Inf
        b = 64'hFFF0000000000000; // -Inf
        #10 display_case("-Inf + -Inf");

        a = 64'h7FF8000000000000; // NaN
        b = 64'h4000000000000000; // 2.0
        #10 display_case("NaN + 2.0");

        a = 64'h0000000000000000; // +0
        b = 64'h8000000000000000; // -0
        #10 display_case("+0 + -0");

        a = 64'h7FF0000000000000; // +Inf
        b = 64'hFFF0000000000000; // -Inf
        #10 display_case("Inf + -Inf (Expect NaN)");

        $display("\n Testbench Completed ");
        $finish;
    end

endmodule
