`include "uvm_macros.svh"
import uvm_pkg::*;

class fpu_agent extends uvm_agent;
    `uvm_component_utils(fpu_agent)

    uvm_sequencer #(fpu_transaction) sqr;
    fpu_driver drv;
    fpu_monitor mon;

    uvm_analysis_port #(fpu_transaction) agt_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        sqr = uvm_sequencer#(fpu_transaction)::type_id::create("sqr", this);
        drv = fpu_driver::type_id::create("drv", this);
        mon = fpu_monitor::type_id::create("mon", this);
        
        agt_ap = new("agt_ap", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect driver to sequencer
        drv.seq_item_port.connect(sqr.seq_item_export);
        
        // Connect monitor analysis port to agent analysis port
        mon.mon_ap.connect(agt_ap);
    endfunction
endclass
