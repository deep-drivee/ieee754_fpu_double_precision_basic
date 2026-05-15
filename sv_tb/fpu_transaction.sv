`include "uvm_macros.svh"
import uvm_pkg::*;

class fpu_transaction extends uvm_sequence_item;
    
    // Stimulus fields
    rand logic [63:0] a;
    rand logic [63:0] b;
    rand logic [63:0] c;
    rand logic [2:0]  opcode; // 000: add, 001: sub, 010: mul, 011: div, 100: fma

    // Output field to be filled by monitor
    logic [63:0] actual_result;

    // UVM Factory Registration
    `uvm_object_utils_begin(fpu_transaction)
        `uvm_field_int(a, UVM_ALL_ON)
        `uvm_field_int(b, UVM_ALL_ON)
        `uvm_field_int(c, UVM_ALL_ON)
        `uvm_field_int(opcode, UVM_ALL_ON)
        `uvm_field_int(actual_result, UVM_ALL_ON)
    `uvm_object_utils_end

    // Constraints heavily weighted to aggressively test boundary limits along with normals
    constraint full_spectrum_a_c {
        a[62:52] dist {
            11'h000          := 10,  // 10% Subnormals and Zeros
            11'h7FF          := 10,  // 10% Infinities and NaNs
            [11'h001:11'h7FE] := 80  // 80% Normal Numbers
        };
    }
    
    constraint full_spectrum_b_c {
        b[62:52] dist {
            11'h000          := 10,  
            11'h7FF          := 10,  
            [11'h001:11'h7FE] := 80  
        };
    }

    constraint full_spectrum_c_c {
        c[62:52] dist {
            11'h000          := 10,  
            11'h7FF          := 10,  
            [11'h001:11'h7FE] := 80  
        };
    }

    constraint opcode_c {
        opcode inside {[0:4]};
    }

    // Constructor
    function new(string name = "fpu_transaction");
        super.new(name);
    endfunction
    
endclass
