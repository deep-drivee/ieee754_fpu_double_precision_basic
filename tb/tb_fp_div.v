`timescale 1ns/1ps

module tb_fp_div;
    reg  [63:0] a, b;
    wire [63:0] result;

    fp_div uut (
        .a(a),
        .b(b),
        .result(result)
    );
    
    // Output formatting task
    task display_case;
        input [255:0] label;
        begin
        $display("%0t ns | %-24s | A: %h  B: %h  -> Result: %h", $time, label, a, b, result);
        end
    endtask

    initial begin
        $display("\n Running Division Testbench \n");

        // 1. Basic division
        a = 64'h4024000000000000; b = 64'h4000000000000000; // 10.0 / 2.0
        #10 display_case("10.0 / 2.0");

        a = 64'h4018000000000000; b = 64'h4008000000000000; // 6.0 / 3.0
        #10 display_case("6.0 / 3.0");

        a = 64'h4008000000000000; b = 64'h3ff0000000000000; // 3.0 / 1.0
        #10 display_case("3.0 / 1.0");

        // 2. Fractional division
        a = 64'h3fe0000000000000; b = 64'h3fd0000000000000; // 0.5 / 0.25 = 2.0
        #10 display_case("0.5 / 0.25");

        a = 64'h3fd0000000000000; b = 64'h3fe0000000000000; // 0.25 / 0.5 = 0.5
        #10 display_case("0.25 / 0.5");

        a = 64'h3ff0000000000000; b = 64'h4008000000000000; // 1.0 / 3.0 = repeating
        #10 display_case("1.0 / 3.0");

        // 3. Subnormals
        a = 64'h0000000000000001; b = 64'h3ff0000000000000; // min_subnormal / 1.0
        #10 display_case("subnormal / 1.0");

        a = 64'h0010000000000000; b = 64'h3ff0000000000000; // min_normal / 1.0
        #10 display_case("min_normal / 1.0");

        // 4. Infinity and Zero
        a = 64'h7ff0000000000000; b = 64'h4000000000000000; // inf / 2.0 = inf
        #10 display_case("inf / 2.0");

        a = 64'h0000000000000000; b = 64'h7ff0000000000000; // 0 / inf = 0
        #10 display_case("0 / inf");

        a = 64'h7ff0000000000000; b = 64'h7ff0000000000000; // inf / inf = NaN
        #10 display_case("inf / inf (NaN)");

        a = 64'h0000000000000000; b = 64'h0000000000000000; // 0 / 0 = NaN
        #10 display_case("0 / 0 (NaN)");

        a = 64'h7ff8000000000000; b = 64'h4000000000000000; // NaN / 2.0 = NaN
        #10 display_case("NaN / 2.0");

        // 5. Edge rounding case
        a = 64'h0000000000000001; b = 64'h0000000000000002; // ~0.5
        #10 display_case("denorm / denorm");

        // 6. Negative division
        a = 64'hc010000000000000; b = 64'h4000000000000000; // -4.0 / 2.0 = -2.0
        #10 display_case("-4.0 / 2.0");

        $display("\n Testbench Completed \n");
        $finish;
    end

endmodule
