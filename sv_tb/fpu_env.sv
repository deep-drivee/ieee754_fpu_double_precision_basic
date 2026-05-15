`include "uvm_macros.svh"
import uvm_pkg::*;

class fpu_env extends uvm_env;
    `uvm_component_utils(fpu_env)

    fpu_agent agt;
    fpu_scoreboard scb;
    fpu_coverage cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = fpu_agent::type_id::create("agt", this);
        scb = fpu_scoreboard::type_id::create("scb", this);
        cov = fpu_coverage::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.agt_ap.connect(scb.scb_export);
        agt.agt_ap.connect(cov.analysis_export);
    endfunction
endclass

// ============================================================
// Test 1: Base Random Test (original)
// ============================================================
class fpu_base_test extends uvm_test;
    `uvm_component_utils(fpu_base_test)

    fpu_env env;
    fpu_sequence seq;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fpu_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        
        seq = fpu_sequence::type_id::create("seq");
        
        // Wait for reset logically before starting sequence
        #10;
        
        seq.start(env.agt.sqr);
        
        // Let the pipeline flush
        #100;
        
        phase.drop_objection(this);
    endtask
endclass

// ============================================================
// Test 2: Coverage-Driven Test
// Runs directed sequences followed by random noise
// ============================================================
class fpu_coverage_test extends uvm_test;
    `uvm_component_utils(fpu_coverage_test)

    fpu_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fpu_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fpu_special_cases_seq  special_seq;
        fpu_subnormal_seq      subnorm_seq;
        fpu_rounding_tie_seq   rnd_seq;
        fpu_boundary_exp_seq   bnd_seq;
        fpu_div_stress_seq     div_seq;
        fpu_sequence           rand_seq;

        phase.raise_objection(this);
        #10; // Wait for reset

        `uvm_info("TEST", "==== Phase 1: Special Cases ====", UVM_LOW)
        special_seq = fpu_special_cases_seq::type_id::create("special_seq");
        special_seq.start(env.agt.sqr);

        `uvm_info("TEST", "==== Phase 2: Subnormal Stress ====", UVM_LOW)
        subnorm_seq = fpu_subnormal_seq::type_id::create("subnorm_seq");
        subnorm_seq.start(env.agt.sqr);

        `uvm_info("TEST", "==== Phase 3: Rounding Ties ====", UVM_LOW)
        rnd_seq = fpu_rounding_tie_seq::type_id::create("rnd_seq");
        rnd_seq.start(env.agt.sqr);

        `uvm_info("TEST", "==== Phase 4: Boundary Exponents ====", UVM_LOW)
        bnd_seq = fpu_boundary_exp_seq::type_id::create("bnd_seq");
        bnd_seq.start(env.agt.sqr);

        `uvm_info("TEST", "==== Phase 5: Division Stress ====", UVM_LOW)
        div_seq = fpu_div_stress_seq::type_id::create("div_seq");
        div_seq.start(env.agt.sqr);

        `uvm_info("TEST", "==== Phase 6: Random Noise ====", UVM_LOW)
        rand_seq = fpu_sequence::type_id::create("rand_seq");
        rand_seq.repeat_count = 5000;
        rand_seq.start(env.agt.sqr);

        #100;
        phase.drop_objection(this);
    endtask
endclass
