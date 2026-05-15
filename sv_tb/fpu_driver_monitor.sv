`include "uvm_macros.svh"
import uvm_pkg::*;

class fpu_driver extends uvm_driver #(fpu_transaction);
    `uvm_component_utils(fpu_driver)
    
    virtual fpu_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fpu_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DRV", "Could not get vif")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        wait(vif.rst_n); // Wait for initialization to clear
        forever begin
            seq_item_port.get_next_item(req);
            
            // Synchronize starting a transaction to the clock
            @(posedge vif.clk);
            vif.DRV.valid_in <= 1'b1;
            vif.DRV.a <= req.a;
            vif.DRV.b <= req.b;
            vif.DRV.c <= req.c;
            vif.DRV.opcode <= req.opcode;
            
            // Wait for FPU to accept it AT a clock edge
            forever begin
                @(posedge vif.clk);
                if (vif.DRV.ready_in === 1'b1) begin
                    break;
                end
            end
            
            // Drop valid_in immediately after the clock edge it was accepted
            vif.DRV.valid_in <= 1'b0;
            
            seq_item_port.item_done();
        end
    endtask
endclass

class fpu_monitor extends uvm_monitor;
    `uvm_component_utils(fpu_monitor)
    
    virtual fpu_if vif;
    uvm_analysis_port #(fpu_transaction) mon_ap;
    
    fpu_transaction pending_q[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_ap = new("mon_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fpu_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MON", "Could not get vif")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        wait(vif.rst_n);
        
        fork
            // Capture Inputs when accepted strictly at posedge
            forever begin
                @(posedge vif.clk);
                if (vif.valid_in && vif.ready_in) begin
                    fpu_transaction trans_in;
                    trans_in = fpu_transaction::type_id::create("trans_in");
                    trans_in.a = vif.a;
                    trans_in.b = vif.b;
                    trans_in.c = vif.c;
                    trans_in.opcode = vif.opcode;
                    pending_q.push_back(trans_in);
                end
            end
            
            // Capture Result when valid strictly at posedge
            forever begin
                @(posedge vif.clk);
                if (vif.valid_out) begin
                    fpu_transaction trans_out;
                    if (pending_q.size() > 0) begin
                        trans_out = pending_q.pop_front();
                        trans_out.actual_result = vif.result;
                        mon_ap.write(trans_out);
                    end else begin
                        `uvm_error("MON", "valid_out asserted but no transaction pending!")
                    end
                end
            end
        join
    endtask
endclass
