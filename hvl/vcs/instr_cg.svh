covergroup instr_cg with function sample(rand_instr_t instr);
    // Easy covergroup to see that we're at least exercising
    // every opcode. Since opcode is an enum, this makes bins
    // for all its members.
    all_opcodes : coverpoint instr.i_type.opcode {
        bins imm_bin = {op_b_imm};
        bins reg_bin = {op_b_reg};
        bins lui_bin = {op_b_lui};
        // ignore_bins non_alu = {op_b_jal, op_b_jalr, op_b_auipc, op_b_br, op_b_load, op_b_store};
    }

    // opcode_cross : cross instr.i_type.opcode, instr {
    //     ignore_bins IGNORE_NON_ARITH = opcode_cross with (instr.i_type.opcode inside {
    //         op_b_jal, op_b_jalr, op_b_auipc, op_b_br, op_b_load, op_b_store
    //     });
    // }


    // Some simple coverpoints on various instruction fields.
    // Recognize that these coverpoints are inherently less useful
    // because they really make sense in the context of the opcode itself.
    all_funct7 : coverpoint funct7_t'(instr.r_type.funct7);

    // TODO: Write the following coverpoints:

    // Check that funct3 takes on all possible values.
    all_funct3 : coverpoint instr.i_type.funct3 {
        bins range[] = {[0:7]};
    }

    // Check that the rs1 and rs2 fields across instructions take on
    // all possible values (each register is touched).
    all_regs_rs1 : coverpoint instr.r_type.rs1 { bins all_rs1[] = {[0:31]}; }
    all_regs_rs2 : coverpoint instr.r_type.rs2 { bins all_rs2[] = {[0:31]}; }

    // Now, cross coverage takes in the opcode context to correctly
    // figure out the /actual/ coverage.

    // Coverpoint to make separate bins for funct7.
    coverpoint instr.r_type.funct7 {
        bins range[] = {[0:$]};
        ignore_bins not_in_spec = {[2:31], [33:127]}; // CHANGED FROM  {[2:31], [33:127]} to add mul and div
    }

    funct3_cross : cross instr.r_type.opcode, instr.r_type.funct3 {

        ignore_bins FUNCT3_OTHER_INSTS = funct3_cross with
        (!(instr.r_type.opcode inside {op_b_reg, op_b_imm}));

        // We want to ignore the cases where funct3 isn't relevant.
    
        // For example, for JAL, funct3 doesn't exist. Put it in an ignore_bins.
        ignore_bins JAL_FUNCT3 = funct3_cross with (instr.r_type.opcode == op_b_jal);

        // TODO:    What other opcodes does funct3 not exist for? Put those in
        // ignore_bins.
        ignore_bins LUI_FUNCT3 = funct3_cross with (instr.r_type.opcode == op_b_lui);
        ignore_bins AUIPC_FUNCT3 = funct3_cross with (instr.r_type.opcode == op_b_auipc);


        // Branch instructions use funct3, but only 6 of the 8 possible values
        // are valid. Ignore the other two -- don't add them into the coverage
        // report. In fact, if they're generated, that's an illegal instruction.
        illegal_bins BR_FUNCT3 = funct3_cross with
        (instr.r_type.opcode == op_b_br
        && !(instr.r_type.funct3 inside {branch_f3_beq, branch_f3_bne, branch_f3_blt, branch_f3_bge, branch_f3_bltu, branch_f3_bgeu}));

        // TODO: You'll also have to ignore some funct3 cases in JALR, LOAD, and
        // STORE. Write the illegal_bins/ignore_bins for those cases.

        // for jalr: funct3 is hardwired to 0x0, so we ignore the bins where funct3 != 0x0
        ignore_bins JALR_FUNCT3 = funct3_cross with 
        (instr.r_type.opcode == op_b_jalr 
        && !(instr.r_type.funct3 inside {3'b000}));

        ignore_bins LOAD_FUNCT3 = funct3_cross with
        (instr.r_type.opcode == op_b_load 
        && !(instr.r_type.funct3 inside {load_f3_lb, load_f3_lh, load_f3_lw, load_f3_lbu, load_f3_lhu}));

        ignore_bins STORE_FUNCT3 = funct3_cross with
        (instr.r_type.opcode == op_b_store
        && !(instr.r_type.funct3 inside {store_f3_sb, store_f3_sh, store_f3_sw}));
    }

    // CHANGED funct7_cross to Adams code

    // Cross coverage for funct7.
    funct7_cross : cross instr.r_type.opcode, instr.r_type.funct3, instr.r_type.funct7 {

        // No opcodes except op_b_reg and op_b_imm use funct7, so ignore the rest.
        ignore_bins FUNCT7_OTHER_INSTS = funct7_cross with
        (!(instr.r_type.opcode inside {op_b_reg, op_b_imm}));

        // TODO: Get rid of all the other cases where funct7 isn't necessary, or cannot
        // take on certain values.

        // all imm and reg opcodes need to be filtered here


        // // Arith add + arith sr instr require funct7 = base or variant
        ignore_bins OPREG_ARITH_ADD_SR_FUNCT7 = funct7_cross with
        (instr.r_type.opcode == op_b_reg                            // opcode = reg
        && (instr.r_type.funct7 != variant_MULT)                                                // ADDED TO ACCOUNT FOR MUL and DIV
        && (instr.r_type.funct3 inside {arith_f3_sr, arith_f3_add}) // funct3 = sr/add
        && !(instr.r_type.funct7 inside {base, variant_ALU}));          // funct7 NOT base/var 



        // all other arith instr require funct7 = base only
        ignore_bins OPREG_ARITH_OTHER_FUNCT7 = funct7_cross with
        (instr.r_type.opcode == op_b_reg                            // opcode = reg
        && (instr.r_type.funct7 != variant_MULT)                                                // ADDED TO ACCOUNT FOR MUL and DIV
        && !(instr.r_type.funct3 inside {arith_f3_sr, arith_f3_add})// funct3 != sr/add
        && !(instr.r_type.funct7 inside {base}));                   // funct7 NOT base

        // arith srl + sra instr require funct7 = base or variant
        ignore_bins OPIMM_ARITH_SR_FUNCT7 = funct7_cross with
        (instr.r_type.opcode == op_b_imm                            // opcode = imm
        // && (instr.r_type.funct7 != variant_MULT)                                                // ADDED TO ACCOUNT FOR MUL and DIV
        && (instr.r_type.funct3 inside {arith_f3_sr})               // funct3 = sr
        && !(instr.r_type.funct7 inside {base, variant_ALU}));          // funct7 NOT base/var

        // arith sll instr requires funct7 = base
        ignore_bins OPIMM_ARITH_SLL_FUNCT7 = funct7_cross with          
        (instr.r_type.opcode == op_b_imm                            // opcode = imm
        // && (instr.r_type.funct7 != variant_MULT)                                                // ADDED TO ACCOUNT FOR MUL and DIV
        && (instr.r_type.funct3 inside {arith_f3_sll})              // funct3 is sll
        && !(instr.r_type.funct7 inside {base}));                   // funct7 NOT base

        // opcode imm has funct3 defined only for sr and sll. 
        // so funct7 is undefined for all other funct3s. ignore those bins.
        ignore_bins OPIMM_ARITH_OTHER_FUNCT7 = funct7_cross with          
        (instr.r_type.opcode == op_b_imm                            // opcode = imm
        // && (instr.r_type.funct7 != variant_MULT)                                                // ADDED TO ACCOUNT FOR MUL and DIV
        && !(instr.r_type.funct3 inside {arith_f3_sll, arith_f3_sr}));  // funct3 NOT sll/sr

        // now for op_reg and op_imm, funct7 should restricted to 
        // base/variant values only for instr with funct7 defined.
        // all other bins are ignored

    }

endgroup : instr_cg
