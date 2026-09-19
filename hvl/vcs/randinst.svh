// This class generates random valid RISC-V instructions to test your
// RISC-V cores.

class RandInst;
    // You will increment this number as you generate more random instruction
    // types. Once finished, NUM_TYPES should be 9, for each opcode type in
    // rv32i_opcode.
    localparam NUM_TYPES = 9;

    // Note that the 'instr_t' type is from ../pkg/types.sv, there are TODOs
    // you must complete there to fully define 'instr_t'.
    rand rand_instr_t instr;
    rand bit [NUM_TYPES-1:0] instr_type;

    // Make sure we have an even distribution of instruction types.
    constraint solve_order_c { 
        solve instr_type before instr; 
    }
    rand bit ALU_or_MULT;
    constraint solve_order_mult { 
        solve ALU_or_MULT before instr; 
    }
    // // Hint/TODO: you will need another solve_order constraint for funct3
    // // to get 100% coverage with 500 calls to .randomize().
    rand bit [2:0] funct3;
    constraint solve_order_funct3_c {  
        // solve instr_type before funct_3;
        solve funct3 before instr;
        instr.i_type.funct3 == funct3;
    }

    // Pick one of the instruction types.
    constraint instr_type_c {
        $countones(instr_type) == 1; // Ensures one-hot.
    }

    // Constraints for actually generating instructions, given the type.
    // Again, see the instruction set listings to see the valid set of
    // instructions, and constrain to meet it. Refer to ../pkg/types.sv
    // to see the typedef enums.

    constraint instr_c {
        // Reg-imm instructions
        instr_type[0] -> {
            instr.i_type.opcode == op_b_imm;
            // instr.i_type.funct3 inside {arith_f3_add, arith_f3_sll, arith_f3_xor, arith_f3_sr, arith_f3_or, arith_f3_and};
            // Implies syntax: if funct3 is arith_f3_sr, then funct7 must be
            // one of two possibilities.
            instr.i_type.funct3 == arith_f3_sr -> {
                // Use r_type here to be able to constrain funct7.
                instr.r_type.funct7 inside {base, variant_ALU};
            }

            // This if syntax is equivalent to the implies syntax above
            // but also supports an else { ... } clause.
            if (instr.i_type.funct3 == arith_f3_sll) {
                instr.r_type.funct7 == base;
            }
        }

        // Reg-reg instructions
        instr_type[1] -> {
            // TODO: Fill this out!
            instr.i_type.opcode == op_b_reg;
            if (ALU_or_MULT == '1) {               
                 instr.r_type.funct7 == variant_MULT;
                //  instr.r_type.funct3 inside { mult_f3_mulhsu }; 
            } else { 
                // For add and SR, determine funct7.
                if ((instr.i_type.funct3 == arith_f3_add) || (instr.i_type.funct3 == arith_f3_sr)) 
                    instr.r_type.funct7 inside {base, variant_ALU};
                // else, check if funct7 is 0000000
                else
                    instr.r_type.funct7 == base;
            }
        

        }

        // Store instructions -- these are easy to constrain!
        instr_type[2] -> {
            instr.i_type.opcode == op_b_store;
            instr.i_type.funct3 inside {store_f3_sb, store_f3_sh, store_f3_sw};
        }

        // Load instructions
        instr_type[3] -> {
            instr.i_type.opcode == op_b_load;
            // TODO: Constrain funct3 as well.
            instr.i_type.funct3 inside {load_f3_lb, load_f3_lh, load_f3_lw, load_f3_lbu, load_f3_lhu};
        }

        // TODO: Do all 9 types!
        
        // branch instructions
        instr_type[4] -> {
            instr.i_type.opcode == op_b_br;
            instr.i_type.funct3 inside {branch_f3_beq, branch_f3_bne, branch_f3_blt, branch_f3_bge, branch_f3_bltu, branch_f3_bgeu};
        }

        // jump and link reg
        instr_type[5] -> {
            instr.i_type.opcode == op_b_jalr;
            instr.i_type.funct3 == 3'b000;
        }

        // jump and link 
        instr_type[6] -> {
            instr.i_type.opcode == op_b_jal;
        }

        // add upper immediate PC
        instr_type[7] -> {
            instr.i_type.opcode == op_b_auipc;
        }

        // load upper immediate PC
        instr_type[8] -> {
            instr.i_type.opcode == op_b_lui ;
        }
    }

    `include "instr_cg.svh"

    // Constructor, make sure we construct the covergroup.
    function new();
        instr_cg = new();
    endfunction : new

    // Whenever randomize() is called, sample the covergroup. This assumes
    // that every generated random instruction are send it into the CPU.
    function void post_randomize();
        instr_cg.sample(this.instr);
    endfunction : post_randomize

    // A nice part of writing constraints is that we get constraint checking
    // for free -- this function will check if a bitvector is a valid RISC-V
    // instruction (assuming you have written all the relevant constraints).
    function bit verify_valid_instr(rand_instr_t inp);
        bit valid = 1'b0;
        this.instr = inp;
        for (int i = 0; i < NUM_TYPES; ++i) begin
            this.instr_type = NUM_TYPES'(1 << i);
            if (this.randomize(null)) begin
                valid = 1'b1;
                break;
            end
        end
        return valid;
    endfunction : verify_valid_instr

endclass : RandInst
