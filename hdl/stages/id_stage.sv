module id_stage_i
import rv32i_types::*;
(
    input   if_id_t         if_id,
    input   logic           flush,

    input   logic           br_pred,
    input   logic   [COUNTER_WIDTH-1:0] br_pht_gs_cntr,
    input   logic   [COUNTER_WIDTH-1:0] br_pht_bi_cntr,
    input   logic   [MODEL_COUNTER_WIDTH-1:0] br_model_cntr,
    input   logic   [GHR_Q_IDX-1:0]     br_ghr_idx,
    input   logic   [31:0]  br_addr,
    input   br_pred_mode_t  br_pred_mode,
    

    output  id_dp_t         id_dp
);      // DECODE


    // initialize instr pkt
    instr_pkt_t     instr_pkt;

    logic   [6:0]   funct7;

    logic           error;

    always_comb begin
        instr_pkt            = '0;

        instr_pkt.order      = if_id.order;
        instr_pkt.i_valid    = if_id.valid;
        instr_pkt.i_addr     = if_id.pc;
        instr_pkt.i_instr    = if_id.inst;
        instr_pkt.i_opcode   = if_id.inst[6:0];
        instr_pkt.i_funct3   = if_id.inst[14:12];
        // instr_pkt.rob_idx    = rob_idx;
        funct7 = if_id.inst[31:25];
        unique case (instr_pkt.i_opcode)
            op_b_reg:   begin
                instr_pkt.i_use_rs1 = 1'b1;
                instr_pkt.i_use_rs2 = 1'b1;

                instr_pkt.rs1_aaddr  = if_id.inst[19:15];
                instr_pkt.rs2_aaddr  = if_id.inst[24:20];
                instr_pkt.rd_aaddr   = if_id.inst[11:7];

                if (instr_pkt.rd_aaddr != '0) begin
                    instr_pkt.i_use_rd  = 1'b1;
                end

                instr_pkt.i_addr_next= instr_pkt.i_addr + 32'd4;

                instr_pkt.i_op_type = alu;

                if (funct7[0]) begin
                    instr_pkt.alu_op = alu_op_sub;
                    instr_pkt.func_unit = MULT;
                end else begin
                    instr_pkt.alu_op = alu_op_add;
                    instr_pkt.func_unit = ALU;
                end

                unique case (instr_pkt.i_funct3)
                    arith_f3_add: begin
                        if (funct7[5]) begin
                            instr_pkt.alu_op = alu_op_sub;
                        end else begin
                            instr_pkt.alu_op = alu_op_add;
                        end
                    end
                    arith_f3_xor: instr_pkt.alu_op = alu_op_xor;
                    arith_f3_or:  instr_pkt.alu_op = alu_op_or;
                    arith_f3_and: instr_pkt.alu_op = alu_op_and;
                    arith_f3_sll: instr_pkt.alu_op = alu_op_sll;
                    arith_f3_sr:  begin
                        if (funct7[5]) begin
                            instr_pkt.alu_op = alu_op_sra;
                        end else begin
                            instr_pkt.alu_op = alu_op_srl;
                        end
                    end
                    arith_f3_slt: begin
                        instr_pkt.cmp_op = cmp_op_lt;
                        instr_pkt.i_op_type = cmp;
                    end
                    arith_f3_sltu: begin
                        instr_pkt.cmp_op = cmp_op_ltu;
                        instr_pkt.i_op_type = cmp;
                    end
                    default: instr_pkt.i_valid   = 1'b0;

                endcase
            end

            op_b_imm:   begin
                instr_pkt.i_use_rs1 = 1'b1;
                instr_pkt.i_use_imm = 1'b1;

                instr_pkt.rs2_rdy = 1'b1;

                instr_pkt.rs1_aaddr  = if_id.inst[19:15];
                instr_pkt.rd_aaddr   = if_id.inst[11:7];
                if (instr_pkt.rd_aaddr != '0) begin
                    instr_pkt.i_use_rd  = 1'b1;
                end

                instr_pkt.imm_data  = {{21{if_id.inst[31]}}, if_id.inst[30:20]};
                instr_pkt.i_addr_next= instr_pkt.i_addr + 32'd4;

                instr_pkt.i_op_type = alu;
                instr_pkt.func_unit = ALU;

                unique case (instr_pkt.i_funct3)
                    arith_f3_add: instr_pkt.alu_op = alu_op_add;
                    arith_f3_xor: instr_pkt.alu_op = alu_op_xor;
                    arith_f3_or:  instr_pkt.alu_op = alu_op_or;
                    arith_f3_and: instr_pkt.alu_op = alu_op_and;
                    arith_f3_sll: instr_pkt.alu_op = alu_op_sll;
                    arith_f3_sr:  begin
                        if (funct7[5]) begin
                            instr_pkt.alu_op = alu_op_sra;
                        end else begin
                            instr_pkt.alu_op = alu_op_srl;
                        end
                    end
                    arith_f3_slt: begin
                        instr_pkt.cmp_op = cmp_op_lt;
                        instr_pkt.i_op_type = cmp;
                    end
                    arith_f3_sltu: begin
                        instr_pkt.cmp_op = cmp_op_ltu;
                        instr_pkt.i_op_type = cmp;
                    end
                    default: instr_pkt.i_valid   = 1'b0;
                endcase
            end

            op_b_lui:   begin
                instr_pkt.i_use_imm = 1'b1;
                instr_pkt.rd_aaddr   = if_id.inst[11:7];

                instr_pkt.rs1_rdy = 1'b1;
                instr_pkt.rs2_rdy = 1'b1;

                if (instr_pkt.rd_aaddr != '0) begin
                    instr_pkt.i_use_rd  = 1'b1;
                end

                instr_pkt.i_addr_next= instr_pkt.i_addr + 32'd4;

                instr_pkt.i_op_type = alu;
                instr_pkt.func_unit = ALU;

                instr_pkt.alu_op = alu_op_add;

                instr_pkt.imm_data  = {if_id.inst[31:12], 12'h000};
            end

            op_b_auipc: begin
                instr_pkt.i_use_pc = 1'b1;
                instr_pkt.i_use_imm = 1'b1;
                instr_pkt.rd_aaddr   = if_id.inst[11:7];

                instr_pkt.rs1_rdy = 1'b1;
                instr_pkt.rs2_rdy = 1'b1;

                if (instr_pkt.rd_aaddr != '0) begin
                    instr_pkt.i_use_rd  = 1'b1;
                end
                instr_pkt.i_addr_next= instr_pkt.i_addr + 32'd4;

                instr_pkt.func_unit = ALU;
                instr_pkt.i_op_type = alu;
                instr_pkt.alu_op = alu_op_add;

                instr_pkt.imm_data  = {if_id.inst[31:12], 12'h000};

            end

            op_b_load:  begin
                instr_pkt.i_use_rs1 = 1'b1;
                instr_pkt.i_use_imm = 1'b1;
                
                instr_pkt.rs2_rdy = 1'b1;

                instr_pkt.rs1_aaddr  = if_id.inst[19:15];
                instr_pkt.rd_aaddr   = if_id.inst[11:7];
                instr_pkt.imm_data  = {{21{if_id.inst[31]}}, if_id.inst[30:20]};

                if (instr_pkt.rd_aaddr != '0) begin
                    instr_pkt.i_use_rd  = 1'b1;
                end

                instr_pkt.i_addr_next= instr_pkt.i_addr + 32'd4;

                instr_pkt.i_op_type = alu; // unused
                instr_pkt.i_mem_op_type = LOAD;

                instr_pkt.func_unit = MEM;

                instr_pkt.alu_op = alu_op_add;
            end

            op_b_store:  begin
                instr_pkt.i_use_rs1 = 1'b1;
                instr_pkt.i_use_rs2 = 1'b1;
                instr_pkt.i_use_imm = 1'b1;
                
                instr_pkt.rs1_aaddr  = if_id.inst[19:15];
                instr_pkt.rs2_aaddr  = if_id.inst[24:20];
                instr_pkt.imm_data  = {{21{if_id.inst[31]}}, if_id.inst[30:25], if_id.inst[11:7]};

                instr_pkt.i_addr_next= instr_pkt.i_addr + 32'd4;

                instr_pkt.i_op_type = alu; // unused

                instr_pkt.i_mem_op_type = STORE;

                instr_pkt.func_unit = MEM;

                instr_pkt.alu_op = alu_op_add;
            end

            op_b_br:  begin
                instr_pkt.i_use_rs1 = 1'b1;
                instr_pkt.i_use_rs2 = 1'b1;
                instr_pkt.i_use_imm = 1'b1;

                instr_pkt.rs1_aaddr = if_id.inst[19:15];
                instr_pkt.rs2_aaddr = if_id.inst[24:20];
                instr_pkt.imm_data  = {{20{if_id.inst[31]}}, if_id.inst[7], if_id.inst[30:25], if_id.inst[11:8], 1'b0};

                instr_pkt.i_op_type = cmp;

                instr_pkt.br_en     = '1;
                instr_pkt.br_pred   = br_pred;
                instr_pkt.br_pht_gs_cntr = br_pht_gs_cntr;
                instr_pkt.br_pht_bi_cntr = br_pht_bi_cntr;
                instr_pkt.br_model_cntr  = br_model_cntr;
                instr_pkt.br_ghr_idx  = br_ghr_idx;
                instr_pkt.br_pred_mode= br_pred_mode;

                if (if_id.pc != br_addr)    // should match
                    error = '1;

                if (br_pred) begin
                    instr_pkt.i_addr_next = instr_pkt.i_addr + instr_pkt.imm_data;
                end else begin
                    instr_pkt.i_addr_next = instr_pkt.i_addr + 32'd4;
                end

                instr_pkt.func_unit = BR;

                unique case (instr_pkt.i_funct3)
                    branch_f3_beq : instr_pkt.cmp_op = cmp_op_eq;
                    branch_f3_bne : instr_pkt.cmp_op = cmp_op_ne;
                    branch_f3_blt : instr_pkt.cmp_op = cmp_op_lt;
                    branch_f3_bge : instr_pkt.cmp_op = cmp_op_ge;
                    branch_f3_bltu: instr_pkt.cmp_op = cmp_op_ltu;
                    branch_f3_bgeu: instr_pkt.cmp_op = cmp_op_geu;
                    default       : instr_pkt.cmp_op = 'x;
                endcase
            end

            op_b_jalr:  begin
                instr_pkt.i_use_rs1 = 1'b1;
                instr_pkt.i_use_imm = 1'b1;

                instr_pkt.rs2_rdy   = 1'b1;

                instr_pkt.rs1_aaddr = if_id.inst[19:15];
                instr_pkt.rd_aaddr  = if_id.inst[11:7];

                instr_pkt.br_en     = '1;
                instr_pkt.br_result = '1;

                instr_pkt.i_is_jump = '1;
                instr_pkt.i_is_jal  = '0;

                instr_pkt.i_addr_next = instr_pkt.i_addr + instr_pkt.imm_data;

                if (instr_pkt.rd_aaddr != '0) begin
                    instr_pkt.i_use_rd  = 1'b1;
                end

                instr_pkt.imm_data  = {{21{if_id.inst[31]}}, if_id.inst[30:20]};

                instr_pkt.func_unit = BR;   // i think? then hardwire br_taken=1?


            end

            op_b_jal:  begin
                instr_pkt.i_use_imm = 1'b1;

                instr_pkt.rs1_rdy   = 1'b1;
                instr_pkt.rs2_rdy   = 1'b1;

                instr_pkt.imm_data  = {{12{if_id.inst[31]}}, if_id.inst[19:12], if_id.inst[20], if_id.inst[30:21], 1'b0};
                instr_pkt.rd_aaddr  = if_id.inst[11:7];

                instr_pkt.br_en     = '1;
                instr_pkt.br_result = '1;

                instr_pkt.i_is_jump = 1'b1;
                instr_pkt.i_is_jal  = 1'b1;

                instr_pkt.i_addr_next = instr_pkt.i_addr + instr_pkt.imm_data;

                if (instr_pkt.rd_aaddr != '0) begin
                    instr_pkt.i_use_rd  = 1'b1;
                end

                instr_pkt.func_unit = BR;

            end

            default:    begin
                instr_pkt.i_valid   = 1'b0;
            end
        endcase

        if (!flush) begin
            id_dp.instr_pkt = instr_pkt;
        end else begin
            id_dp.instr_pkt = '0;
        end
    end


endmodule : id_stage_i
