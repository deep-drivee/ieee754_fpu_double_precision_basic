`timescale 1ns/1ps

module tb_fp_mul;
    reg  [63:0] a, b;
    wire [63:0] result;

    fp_mul uut (
        .a(a),
        .b(b),
        .result(result)
    );
    
    // Output formatting
    task display_case;
        input [255:0] label;
        begin
        $display("%0t ns | %-20s | A: %h  B: %h  -> Result: %h", $time, label, a, b, result);
        end
    endtask

    initial begin
    
        $display("\n Running Multiply Testbench \n");

        // 1. Basic cases
        a = 64'h3ff0000000000000; b = 64'h3ff0000000000000; // 1.0 * 1.0
        #10  
        display_case("1.0 * 1.0");

        a = 64'h4010000000000000; b = 64'h4014000000000000; // 4.0 * 5.0
        #10  
        display_case("4.0 * 5.0");

        a = 64'h3ff8000000000000; b = 64'h4000000000000000; // 1.5 * 2.0
        #10  
        display_case("1.5 * 2.0");

        // 2. Fractional
        a = 64'h3fb999999999999a; b = 64'h3fc999999999999a; // 0.1 * 0.2
        #10  
        display_case("0.1 * 0.2");

        a = 64'h3fe0000000000000; b = 64'h3fe0000000000000; // 0.5 * 0.5
        #10  
        display_case("0.5 * 0.5");

        // 3. Subnormals
        a = 64'h0000000000000001; b = 64'h3ff0000000000000; // min subnormal * 1.0
        #10 
        display_case("subnormal * 1.0");

        // 4. Infinity and NaN
        a = 64'h7ff0000000000000; b = 64'h3ff0000000000000; // inf * 1.0
        #10  
        display_case("inf * 1.0");

        a = 64'h0000000000000000; b = 64'h7ff0000000000000; // 0 * inf (NaN)
        #10  
        display_case("0 * inf (NaN)");

        a = 64'h7ff8000000000000; b = 64'h4000000000000000; // NaN * 2.0
        #10  
        display_case("NaN * 2.0");

        // 5. Overflow and underflow
        a = 64'h7fefffffffffffff; b = 64'h4000000000000000; // near-max * 2 (overflow)
        #10  
        display_case("overflow case");

        $display("\n Testbench Completed \n");
        $finish;
    end

endmodule
