`timescale 1ns/1ps

module tb_fp_sub;

    reg [63:0] a, b;
    wire [63:0] result;

    // Instantiate the FPU subtractor
    fp_sub uut (
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
        $display("\n Starting Subtraction Testbench \n");

        // 1. Normal Numbers 
        a = 64'h4059000000000000; b = 64'h4040800000000000; #10; // 100 - 33
        display_case("Normal: 100 - 33");

        a = 64'h4023800000000000; b = 64'h3fe8000000000000; #10; // 9.75 - 0.75
        display_case("Normal: 9.75 - 0.75");

        a = 64'h4008000000000000; b = 64'h4000000000000000; #10; // 3.0 - 2.0
        display_case("Normal: 3.0 - 2.0");

        a = 64'h3ff0000000000001; b = 64'h3ff0000000000000; #10; // 1.000...1 - 1.0
        display_case("Normal: 1.000...1 - 1.0");

        // 2. Fractional
        a = 64'h3fc999999999999a; b = 64'h3fb999999999999a; #10; // 0.2 - 0.1
        display_case("Fractional: 0.2 - 0.1");

        // 3. Denormal 
        a = 64'h0000000000000001; b = 64'h0000000000000001; #10;
        display_case("Denorm: min_sub - min_sub");

        a = 64'h0000000000000001; b = 64'h3ff0000000000000; #10;
        display_case("Denorm - Normal: min_sub - 1.0");

        // 4. Zero Handling
        a = 64'h3ff0000000000000; b = 64'h3ff0000000000000; #10; // 1.0 - 1.0
        display_case("Zero Result: 1.0 - 1.0");

        // 5. Infinity 
        a = 64'h7ff0000000000000; b = 64'h4000000000000000; #10;
        display_case("Inf - Normal: Inf - 2.0");

        a = 64'h7ff0000000000000; b = 64'h7ff0000000000000; #10;
        display_case("Edge: Inf - Inf (NaN)");

        a = 64'hfff0000000000000; b = 64'h7ff0000000000000; #10;
        display_case("Edge: -Inf - Inf");

        // 6. NaN 
        a = 64'h7ff8000000000000; b = 64'h3ff0000000000000; #10;
        display_case("NaN - 1.0");

        $display("\n Testbench Completed \n");
        $finish;
    end

endmodule
