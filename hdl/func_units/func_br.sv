module func_br_i
import rv32i_types::*;
(
    input   rs_br_ent_t     br_ent,
    input   logic           valid,

    // output  logic           occupied,
    output  logic           done,
    output  rs_br_ent_t     br_ent_out,
    output  logic   [31:0]  i_addr_next,
    output  logic   [31:0]  rd_data_out

);      // BRANCH FUNC UNIT
    logic           [31:0]  a;
    logic           [31:0]  b;
    logic signed    [31:0]  as;
    logic signed    [31:0]  bs;
    logic unsigned  [31:0]  au;
    logic unsigned  [31:0]  bu;
    logic           [2:0]   cmpop;
    logic                   br_en;

    always_comb begin
        cmpop = br_ent.instr_pkt.cmp_op;
        a = br_ent.reg_pkt.rs1_data;

        if (br_ent.reg_pkt.i_use_rs2) begin
            b = br_ent.reg_pkt.rs2_data;
        end else begin
            b = br_ent.instr_pkt.imm_data;
        end

        as =   signed'(a);
        bs =   signed'(b);
        au = unsigned'(a);
        bu = unsigned'(b);

        unique case (cmpop)
            cmp_op_eq:  br_en = (au == bu);
            cmp_op_ne:  br_en = (au != bu);
            cmp_op_lt:  br_en = (as <  bs);
            cmp_op_ge:  br_en = (as >= bs);
            cmp_op_ltu: br_en = (au <  bu);
            cmp_op_geu: br_en = (au >= bu);
            default:    br_en = 'x;
        endcase
    end

    always_comb begin
        br_ent_out = br_ent;
        rd_data_out = '0;

        if (br_ent.instr_pkt.i_is_jmp) begin
            br_ent_out.instr_pkt.br_result = '1;
            if (br_ent.reg_pkt.i_use_rs1) begin
                i_addr_next = br_ent.reg_pkt.rs1_data + br_ent.instr_pkt.imm_data;
                i_addr_next[0] = 1'b0;
            end else begin
                i_addr_next = br_ent.instr_pkt.i_addr + br_ent.instr_pkt.imm_data;
            end

            if (br_ent.reg_pkt.i_use_rd) begin
                rd_data_out = br_ent.instr_pkt.i_addr + 32'd4;;
            end
        end else begin

            // set BR packet
            if (br_en) begin
                br_ent_out.instr_pkt.br_result           = '1;
                i_addr_next   = br_ent.instr_pkt.i_addr + br_ent.instr_pkt.imm_data;
            end else begin
                br_ent_out.instr_pkt.br_result           = '0;
                i_addr_next   = br_ent.instr_pkt.i_addr + 32'd4;
            end
        end

        done = br_ent.instr_pkt.i_valid && valid;
    end


endmodule : func_br_i
