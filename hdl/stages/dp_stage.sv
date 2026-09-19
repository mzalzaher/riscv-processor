module dp_stage_i
import rv32i_types::*;
(
    input   id_dp_t         id_dp,

    input   logic           flush,

    // freelist queue ports
    input   paddr_t         fl_paddr_out,
    input   logic           fl_empty,     // 0 if freelist empty
    output  logic           fl_deq,

    // RAT table ports
    input   rat_t           rat_rs1,
    input   rat_t           rat_rs2,

    input   rrf_t           rrf_rs1,
    input   rrf_t           rrf_rs2,

    output  logic           rename_rd,
    output  aaddr_t         rd_aaddr,
    output  paddr_t         rd_paddr,

    output  dp_iss_t        dp_iss
);      // DISPATCH

    // Lecture pseudocode
// for each instr in dispatch stage:
//     if all reservation stations (RS) for instr.opcode are full:
//         do nothing for instr this cycle
//     else fill an available reservation station with:
//         valid = 1, instr = instr
//         rs1_rdy = instr.rs1_ready
//         if (instr.rs1_ready):
//             rs1 = instr.rs1_data
//         else:
//             rs1 = instr.rs1_paddr


    always_comb begin
        fl_deq      = '0;
        rename_rd   = '0;
        rd_paddr    = '0;
        rd_aaddr     = '0;
        dp_iss      = '0;
        if (fl_empty) begin     // remove lint warning
        end

        // dp_iss.instr_pkt = id_dp.instr_pkt;

        if (!flush && id_dp.instr_pkt.i_valid) begin
            dp_iss.instr_pkt = id_dp.instr_pkt;

            // handle rd
            if (id_dp.instr_pkt.i_use_rd) begin
                fl_deq = '1;
                rename_rd = '1;
                dp_iss.instr_pkt.rd_paddr = fl_paddr_out;
                rd_paddr = fl_paddr_out;
                rd_aaddr = id_dp.instr_pkt.rd_aaddr;
            end

            // handle rs1/rs2 rename
            if (id_dp.instr_pkt.i_use_rs1) begin
                if (rat_rs1.renamed) begin
                    dp_iss.instr_pkt.rs1_paddr = rat_rs1.paddr;
                end else begin
                    dp_iss.instr_pkt.rs1_data = rrf_rs1.data;
                    dp_iss.instr_pkt.rs1_rdy  = '1;
                end
            end
            if (id_dp.instr_pkt.i_use_rs2) begin
                if (rat_rs2.renamed) begin
                    dp_iss.instr_pkt.rs2_paddr = rat_rs2.paddr;
                end else begin
                    dp_iss.instr_pkt.rs2_data = rrf_rs2.data;
                    dp_iss.instr_pkt.rs2_rdy  = '1;
                end
            end
        end
    end


endmodule : dp_stage_i
