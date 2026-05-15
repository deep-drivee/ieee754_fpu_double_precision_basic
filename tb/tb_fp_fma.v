`timescale 1ns/1ps

module tb_fp_fma;

    reg [63:0] a, b, c;
    wire [63:0] result;

    fp_fma uut (
        .a(a),
        .b(b),
        .c(c),
        .result(result)
    );

    task display_case(input string name);
        begin
            #1; // allow delta cycle propagation
            $display("%0t ns | %-30s | A: %16h  B: %16h  C: %16h  -> Result: %16h", $time, name, a, b, c, result);
        end
    endtask

    initial begin
        $display("\n Running Fused Multiply-Add Testbench \n");

        // 1.0 * 2.0 + 3.0 = 5.0
        a = 64'h3ff0000000000000; // 1.0
        b = 64'h4000000000000000; // 2.0
        c = 64'h4008000000000000; // 3.0
        #10 display_case("1.0 * 2.0 + 3.0 = 5.0");

        // 2.5 * 1.5 - 2.0 = 1.75
        a = 64'h4004000000000000; // 2.5
        b = 64'h3ff8000000000000; // 1.5 (2.5 * 1.5 = 3.75)
        c = 64'hc000000000000000; // -2.0
        #10 display_case("2.5 * 1.5 - 2.0 = 1.75");

        // FMA RNTE Accuracy check (Catastrophic Cancellation test)
        // a = 1.0+eps, b = 1.0-eps, c = -1.0 -> result = -eps^2
        // a = 1.0 + 2^-52 (3FF0 0000 0000 0001)
        // b = 1.0 - 2^-52 (3FEF FFFF FFFF FFFF)
        // c = -1.0        (BFF0 0000 0000 0000)
        // Exact: (1+eps)(1-eps) - 1 = 1 - eps^2 - 1 = -eps^2 = -2^-104 (Deep subnormal)
        a = 64'h3ff0000000000001; 
        b = 64'h3fefffffffffffff; 
        c = 64'hbff0000000000000; 
        #10 display_case("FMA Exact Cancellation");

        $display("\n Testbench Completed \n");
        $finish;
    end

endmodule
