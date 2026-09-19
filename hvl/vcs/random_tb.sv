//-----------------------------------------------------------------------------
// Title                 : random_tb
// Project               : ECE 411 mp_verif
//-----------------------------------------------------------------------------
// File                  : random_tb.sv
// Author                : ECE 411 Course Staff
//-----------------------------------------------------------------------------
// IMPORTANT: If you don't change the random seed, every time you do a `make run`
// you will run the /same/ random test. SystemVerilog calls this "random stability",
// and it's to ensure you can reproduce errors as you try to fix the DUT. Make sure
// to change the random seed or run more instructions if you want more extensive
// coverage.
//------------------------------------------------------------------------------
module random_tb
import rv32i_types::*;
(
    mem_itf_banked.mem itf
);

    initial itf.rvalid = 1'b0;

    `include "randinst.svh"

    RandInst gen = new();
    // rand_instr_t instr[8];
    logic [31:0] gen_instr[8];
    logic [31:0] raddr;
    // logic [4:0] rd_idx;
    // logic [31:0] temp;
    // Do a bunch of LUIs to get useful register state.
    task init_register_state();
        repeat (500) begin

            @(posedge itf.clk iff |itf.read);
            // generate 8 instructions
            // rand_instr_t instr;
            raddr = itf.addr;
            for (int j = 0; j < 8; ++j) begin
                gen.randomize() with {
                    instr.i_type.opcode == op_b_imm;
                    instr.i_type.funct3 == arith_f3_add;
                };
                gen_instr[j] = gen.instr.word;
            end

            // send the data in bursts of 4.
            for (int k = 0; k < 4; ++k) begin
                itf.rdata[31:0]  <= gen_instr[k];
                itf.rdata[63:32] <= gen_instr[7-k];  
                itf.rvalid       <= 1'b1;
                itf.raddr        <= raddr;
                @(posedge itf.clk);
            end

            // deassert rvalid after the burst
            itf.rdata  <= 'X;
            itf.raddr  <= 'X;
            itf.rvalid <= 1'b0;
        end
    endtask

    task run_alu_instrs();
        repeat (500) begin
            for (int i = 0; i < 64; i += 4) begin
                @(posedge itf.clk iff |itf.read);

                // generate 8 instructions
                // rand_instr_t instr;
                for (int j = 0; j < 8; ++j) begin
                    gen.randomize() with {
                        (instr.i_type.opcode == op_b_imm)
                        ||
                        (instr.i_type.opcode == op_b_reg)
                        || 
                        (instr.i_type.opcode == op_b_lui);
                    };
                    gen_instr[j] = gen.instr.word;
                    raddr = itf.addr;
                end

                // send the data in bursts of 4.
                for (int k = 0; k < 4; ++k) begin
                    itf.rdata[31:0]  <= gen_instr[k];
                    itf.rdata[63:32] <= gen_instr[7-k];  
                    itf.rvalid       <= 1'b1;
                    itf.raddr        <= raddr;
                    @(posedge itf.clk);
                end

                // deassert rvalid after the burst
                itf.rdata  <= 'X;
                itf.raddr  <= 'X;
                itf.rvalid <= 1'b0;
            end
        end
    endtask : run_alu_instrs

    always @(posedge itf.clk iff !itf.rst) begin
        if ($isunknown(itf.read) || $isunknown(itf.write)) begin
            $error("Memory Error: mask containes 1'bx");
            itf.error <= 1'b1;
        end
        if ((|itf.read) && (|itf.write)) begin
            $error("Memory Error: Simultaneous memory read and write");
            itf.error <= 1'b1;
        end
        if ((|itf.read) || (|itf.write)) begin
            if ($isunknown(itf.addr[0])) begin
                $error("Memory Err        repeat (50) @(posedge itf.clk) or: Address contained 'x");
                itf.error <= 1'b1;
            end
            // Only check for 16-bit alignment since instructions are
            // allowed to be at 16-bit boundaries due to JALR.
            if (itf.addr[0] != 1'b0) begin
                $error("Memory Error: Address is not 16-bit aligned");
                itf.error <= 1'b1;
            end
        end
    end

    // A single initial block ensures random stability.
    initial begin

        // Wait for reset.
        @(posedge itf.clk iff itf.rst == 1'b0);

        // Get some useful state into the processor by loading in a bunch of state.

        init_register_state();

        // Run!
        run_alu_instrs();

        // Finish up
        $display("Random testbench finished!");
        $finish;
    end

endmodule : random_tb
