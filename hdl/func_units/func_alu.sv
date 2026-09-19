module func_alu_i
import rv32i_types::*;
(   
    input   rs_alu_ent_t        alu_ent,
    input   logic               valid,

    // output  logic           occupied,
    output  logic               done,
    output  rs_alu_ent_t        alu_ent_out,
    output  logic   [31:0]      rd_data_out


);      // ALU FUNC UNIT

    logic           [31:0]  alu_a;
    logic           [31:0]  alu_b;

    logic signed    [31:0]  alu_as;
    logic signed    [31:0]  alu_bs;
    logic unsigned  [31:0]  alu_au;
    logic unsigned  [31:0]  alu_bu;

    logic           [31:0] alu_out;

    logic                  br_en;
    

    //assign done = valid;
    // assign occupied = '0;

    always_comb begin
        if (alu_ent.instr_pkt.i_use_pc)
            alu_a = alu_ent.instr_pkt.i_addr;
        else if (alu_ent.reg_pkt.i_use_rs1)
            alu_a = alu_ent.reg_pkt.rs1_data;
        else 
            alu_a = '0;

        alu_b = 'x;
        if (alu_ent.reg_pkt.i_use_rs2)
            alu_b = alu_ent.reg_pkt.rs2_data;
        else if (alu_ent.instr_pkt.i_use_imm)
            alu_b = alu_ent.instr_pkt.imm_data;
    end 

    always_comb begin
         
        alu_as =   signed'(alu_a);
        alu_bs =   signed'(alu_b);
        alu_au = unsigned'(alu_a);
        alu_bu = unsigned'(alu_b);

        alu_out = '0;
        if (alu_ent.instr_pkt.i_op_type == alu) begin
            unique case (alu_ent.instr_pkt.alu_op)
                alu_op_add: alu_out = alu_au + alu_bu;
                alu_op_sll: alu_out = alu_au <<  alu_bu[4:0];
                alu_op_sra: alu_out = unsigned'(alu_as >>> alu_bu[4:0]);
                alu_op_sub: alu_out = alu_au -   alu_bu;
                alu_op_xor: alu_out = alu_au ^   alu_bu;
                alu_op_srl: alu_out = alu_au >>  alu_bu[4:0];
                alu_op_or:  alu_out = alu_au |   alu_bu;
                alu_op_and: alu_out = alu_au &   alu_bu;
                default:    alu_out = 'x;
            endcase
        end
        else begin
            unique case (alu_ent.instr_pkt.cmp_op)
                cmp_op_eq:  br_en = (alu_au == alu_bu);
                cmp_op_ne:  br_en = (alu_au != alu_bu);
                cmp_op_lt:  br_en = (alu_as <  alu_bs);
                cmp_op_ge:  br_en = (alu_as >= alu_bs);
                cmp_op_ltu: br_en = (alu_au <  alu_bu);
                cmp_op_geu: br_en = (alu_au >= alu_bu);
                default:    br_en = 'x;
            endcase        
            alu_out = {31'd0, br_en};
        end

        // if (alu_ent.i_op_type == alu) begin
        //     unique case (id_ex.instr_pkt.alu_op)
        //         alu_op_add: instr_pkt_out.rd_out = alu_au + alu_bu;
        //         alu_op_sll: instr_pkt_out.rd_out = alu_au <<  alu_bu[4:0];
        //         alu_op_sra: instr_pkt_out.rd_out = unsigned'(alu_as >>> alu_bu[4:0]);
        //         alu_op_sub: instr_pkt_out.rd_out = alu_au -   alu_bu;
        //         alu_op_xor: instr_pkt_out.rd_out = alu_au ^   alu_bu;
        //         alu_op_srl: instr_pkt_out.rd_out = alu_au >>  alu_bu[4:0];
        //         alu_op_or:  instr_pkt_out.rd_out = alu_au |   alu_bu;
        //         alu_op_and: instr_pkt_out.rd_out = alu_au &   alu_bu;
        //         default:    instr_pkt_out.rd_out = 'x;
        //     endcase

    end

    always_comb begin
        rd_data_out = '0;
        alu_ent_out = alu_ent;
        done = alu_ent.instr_pkt.i_valid && valid;
        if (done && alu_ent.reg_pkt.i_use_rd) begin
            alu_ent_out.reg_pkt.rd_valid = '1;
            // alu_ent_out.reg_pkt.rd_data = alu_out;
            rd_data_out                 = alu_out;
        end

    end


endmodule : func_alu_i
