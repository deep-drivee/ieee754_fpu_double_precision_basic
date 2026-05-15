`include "uvm_macros.svh"
import uvm_pkg::*;

class fpu_sequence extends uvm_sequence #(fpu_transaction);
    `uvm_object_utils(fpu_sequence)
    
    int repeat_count = 10000; // Will be driven by test

    function new(string name = "fpu_sequence");
        super.new(name);
    endfunction

    virtual task body();
        for(int i = 0; i < repeat_count; i++) begin
            req = fpu_transaction::type_id::create("req");
            start_item(req);
            if(!req.randomize()) begin
                `uvm_fatal("SEQ", "Randomization failed")
            end
            finish_item(req);
        end
    endtask
endclass
