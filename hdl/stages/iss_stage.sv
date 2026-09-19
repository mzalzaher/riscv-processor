module iss_stage_i
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   dp_iss_t        dp_iss,
    input   logic           dp_rename_rd,
    input   paddr_t         dp_rd_paddr,

    input   logic           br_flush,

    input   prf_t           prf_in,
    input   paddr_t         prf_in_paddr,
    input   logic           prf_in_en,

    input   cdb_t           cdb, 
    input   cdb_t           cdb1, 
    input   cdb_t           cdb2, 
    input   cdb_t           cdb3, 

    input   logic           func_unit_busy[FUNC_UNITS_MAX],
    output  logic           rs_full,
    input   logic           rob_full,
    input   rob_idx_t       rob_idx,

    output  rs_br_ent_t     iss_ex_br,
    output  rs_alu_ent_t    iss_ex_alu,
    output  rs_alu_ent_t    iss_ex_alu2,
    output  rs_mult_ent_t   iss_ex_mult,
    output  rs_mult_ent_t   iss_ex_div,
    output  rs_mem_ent_t    iss_ex_mem

);      // ISSUE

    prf_t                   prf[PRF_DEPTH];

    rs_br_ent_t             rs_br[RS_Q_DEPTH-1:0];
    rs_alu_ent_t            rs_alu[RS_Q_DEPTH-1:0];
    rs_mult_ent_t           rs_mult[RS_Q_DEPTH-1:0];
    rs_mem_ent_t            rs_mem[RS_Q_DEPTH-1:0];
    
    rs_idx_t                dequeued_idx_br;
    rs_idx_t                dequeued_idx_alu;
    rs_idx_t                dequeued_idx_alu2;
    rs_idx_t                dequeued_idx_mult;
    rs_idx_t                dequeued_idx_div;
    rs_idx_t                dequeued_idx_mem;
    
    logic                   dequeued_en_br;
    logic                   dequeued_en_alu;
    logic                   dequeued_en_alu2;
    logic                   dequeued_en_mult;
    logic                   dequeued_en_div;
    logic                   dequeued_en_mem;

    rs_idx_t                enqueued_idx;
    logic                   enqueued_en;
    func_unit_t             enqueued_fu;

    rs_br_ent_t             enqueued_br;
    rs_alu_ent_t            enqueued_alu;
    rs_mult_ent_t           enqueued_mult;
    rs_mem_ent_t            enqueued_mem;

    logic                   rs_br_full;
    logic                   rs_alu_full;
    logic                   rs_mult_full;
    logic                   rs_mem_full;


// PRF
    always_ff @(posedge clk) begin
        if (!(rst || br_flush)) begin
  
            if (prf_in_en)
                prf[prf_in_paddr] <= prf_in;
            if (dp_rename_rd)
                prf[dp_rd_paddr].v <= '0;
        end
    end

    always_comb begin
        enqueued_fu = dp_iss.instr_pkt.func_unit;
        if (rs_br_full || rs_alu_full || rs_mult_full || rs_mem_full)
            rs_full = '1;
        else
            rs_full = '0;
    end

// BR
    always_ff @(posedge clk) begin
        // RS ENQ
        if (enqueued_en && (enqueued_fu == BR)) begin
            rs_br[enqueued_idx]   <= enqueued_br;
        end
        // RS DEQ
        if (dequeued_en_br) begin
            rs_br[dequeued_idx_br].v <= '0;
        end

        for (integer i = 0; i < RS_Q_DEPTH; i++) begin
            if (rst || br_flush) begin  // RESET RS
                rs_br[i].v <= '0;
            end else begin
                if (rs_br[i].v) begin   // might not need

                    // CHECK WB bus, then PRF for rs1/rs2
                    if (!rs_br[i].instr_pkt.rs1_rdy) begin
                        if (cdb.bus_wb_valid && (cdb.bus_wb_paddr == rs_br[i].reg_pkt.rs1_paddr)) begin
                            rs_br[i].reg_pkt.rs1_data  <= cdb.bus_wb_data;
                            rs_br[i].instr_pkt.rs1_rdy   <= '1;

                        end 
                        else if (cdb1.bus_wb_valid && (cdb1.bus_wb_paddr == rs_br[i].reg_pkt.rs1_paddr)) begin
                            rs_br[i].reg_pkt.rs1_data  <= cdb1.bus_wb_data;
                            rs_br[i].instr_pkt.rs1_rdy   <= '1;
                        end
                        else if (cdb2.bus_wb_valid && (cdb2.bus_wb_paddr == rs_br[i].reg_pkt.rs1_paddr)) begin
                            rs_br[i].reg_pkt.rs1_data  <= cdb2.bus_wb_data;
                            rs_br[i].instr_pkt.rs1_rdy   <= '1;
                        end 
                        else if (cdb3.bus_wb_valid && (cdb3.bus_wb_paddr == rs_br[i].reg_pkt.rs1_paddr)) begin
                            rs_br[i].reg_pkt.rs1_data  <= cdb3.bus_wb_data;
                            rs_br[i].instr_pkt.rs1_rdy   <= '1;
                        end                                                         
                        else if (prf[rs_br[i].reg_pkt.rs1_paddr].v) begin
                            rs_br[i].reg_pkt.rs1_data  <= prf[rs_br[i].reg_pkt.rs1_paddr].data;
                            rs_br[i].instr_pkt.rs1_rdy   <= '1;
                        end
                    end
                    if (!rs_br[i].instr_pkt.rs2_rdy) begin
                        if (cdb.bus_wb_valid && (cdb.bus_wb_paddr == rs_br[i].reg_pkt.rs2_paddr)) begin
                            rs_br[i].reg_pkt.rs2_data  <= cdb.bus_wb_data;
                            rs_br[i].instr_pkt.rs2_rdy   <= '1;

                        end 
                        else if (cdb1.bus_wb_valid && (cdb1.bus_wb_paddr == rs_br[i].reg_pkt.rs2_paddr)) begin
                            rs_br[i].reg_pkt.rs2_data  <= cdb1.bus_wb_data;
                            rs_br[i].instr_pkt.rs2_rdy   <= '1;
                        end
                        else if (cdb2.bus_wb_valid && (cdb2.bus_wb_paddr == rs_br[i].reg_pkt.rs2_paddr)) begin
                            rs_br[i].reg_pkt.rs2_data  <= cdb2.bus_wb_data;
                            rs_br[i].instr_pkt.rs2_rdy   <= '1;
                        end 
                        else if (cdb3.bus_wb_valid && (cdb3.bus_wb_paddr == rs_br[i].reg_pkt.rs2_paddr)) begin
                            rs_br[i].reg_pkt.rs2_data  <= cdb3.bus_wb_data;
                            rs_br[i].instr_pkt.rs2_rdy   <= '1;
                        end                                 
                        else if (prf[rs_br[i].reg_pkt.rs2_paddr].v) begin
                            rs_br[i].reg_pkt.rs2_data  <= prf[rs_br[i].reg_pkt.rs2_paddr].data;
                            rs_br[i].instr_pkt.rs2_rdy   <= '1;
                        end
                    end
                end 
            end
        end
    end

// ALU
    always_ff @(posedge clk) begin
        // RS ENQ
        if (enqueued_en && (enqueued_fu == ALU)) begin
            rs_alu[enqueued_idx]   <= enqueued_alu;
        end
        // RS DEQ
        if (dequeued_en_alu) begin
            rs_alu[dequeued_idx_alu].v <= '0;
        end

        if (dequeued_en_alu2) begin
            rs_alu[dequeued_idx_alu2].v <= '0;
        end

        for (integer i = 0; i < RS_Q_DEPTH; i++) begin
            if (rst || br_flush) begin  // RESET RS
                rs_alu[i].v <= '0;
            end else begin
                if (rs_alu[i].v) begin

                    // CHECK WB bus, then PRF for rs1/rs2
                    if (!rs_alu[i].instr_pkt.rs1_rdy) begin
                        if (cdb.bus_wb_valid && (cdb.bus_wb_paddr == rs_alu[i].reg_pkt.rs1_paddr)) begin
                            rs_alu[i].reg_pkt.rs1_data  <= cdb.bus_wb_data;
                            rs_alu[i].instr_pkt.rs1_rdy   <= '1;

                        end 
                        else if (cdb1.bus_wb_valid && (cdb1.bus_wb_paddr == rs_alu[i].reg_pkt.rs1_paddr)) begin
                            rs_alu[i].reg_pkt.rs1_data  <= cdb1.bus_wb_data;
                            rs_alu[i].instr_pkt.rs1_rdy   <= '1;

                        end 
                        else if (cdb2.bus_wb_valid && (cdb2.bus_wb_paddr == rs_alu[i].reg_pkt.rs1_paddr)) begin
                            rs_alu[i].reg_pkt.rs1_data  <= cdb2.bus_wb_data;
                            rs_alu[i].instr_pkt.rs1_rdy   <= '1;

                        end 
                        else if (cdb3.bus_wb_valid && (cdb3.bus_wb_paddr == rs_alu[i].reg_pkt.rs1_paddr)) begin
                            rs_alu[i].reg_pkt.rs1_data  <= cdb3.bus_wb_data;
                            rs_alu[i].instr_pkt.rs1_rdy   <= '1;

                        end 
                        else if (prf[rs_alu[i].reg_pkt.rs1_paddr].v) begin
                            rs_alu[i].reg_pkt.rs1_data  <= prf[rs_alu[i].reg_pkt.rs1_paddr].data;
                            rs_alu[i].instr_pkt.rs1_rdy   <= '1;
                        end
                    end
                    if (!rs_alu[i].instr_pkt.rs2_rdy) begin
                        if (cdb.bus_wb_valid && (cdb.bus_wb_paddr == rs_alu[i].reg_pkt.rs2_paddr)) begin
                            rs_alu[i].reg_pkt.rs2_data  <= cdb.bus_wb_data;
                            rs_alu[i].instr_pkt.rs2_rdy   <= '1;

                        end 
                        else if (cdb1.bus_wb_valid && (cdb1.bus_wb_paddr == rs_alu[i].reg_pkt.rs2_paddr)) begin
                            rs_alu[i].reg_pkt.rs2_data  <= cdb1.bus_wb_data;
                            rs_alu[i].instr_pkt.rs2_rdy   <= '1;

                        end 
                        else if (cdb2.bus_wb_valid && (cdb2.bus_wb_paddr == rs_alu[i].reg_pkt.rs2_paddr)) begin
                            rs_alu[i].reg_pkt.rs2_data  <= cdb2.bus_wb_data;
                            rs_alu[i].instr_pkt.rs2_rdy   <= '1;

                        end 
                        else if (cdb3.bus_wb_valid && (cdb3.bus_wb_paddr == rs_alu[i].reg_pkt.rs2_paddr)) begin
                            rs_alu[i].reg_pkt.rs2_data  <= cdb3.bus_wb_data;
                            rs_alu[i].instr_pkt.rs2_rdy   <= '1;

                        end 
                        else if (prf[rs_alu[i].reg_pkt.rs2_paddr].v) begin
                            rs_alu[i].reg_pkt.rs2_data  <= prf[rs_alu[i].reg_pkt.rs2_paddr].data;
                            rs_alu[i].instr_pkt.rs2_rdy   <= '1;
                        end
                    end
                end 
            end
        end
    end
    

// MULT
    always_ff @(posedge clk) begin
        // RS ENQ
        if (enqueued_en && (enqueued_fu == MULT)) begin
            rs_mult[enqueued_idx]   <= enqueued_mult;
        end
        // RS DEQ
        if (dequeued_en_mult) begin
            rs_mult[dequeued_idx_mult].v <= '0;
        end
        if (dequeued_en_div) begin
            rs_mult[dequeued_idx_div].v <= '0;
        end

        for (integer i = 0; i < RS_Q_DEPTH; i++) begin
            if (rst || br_flush) begin  // RESET RS
                rs_mult[i].v <= '0;
            end else begin
                if (rs_mult[i].v) begin

                    // CHECK WB bus, then PRF for rs1/rs2
                    if (!rs_mult[i].instr_pkt.rs1_rdy) begin
                        if (cdb.bus_wb_valid && (cdb.bus_wb_paddr == rs_mult[i].reg_pkt.rs1_paddr)) begin
                            rs_mult[i].reg_pkt.rs1_data  <= cdb.bus_wb_data;
                            rs_mult[i].instr_pkt.rs1_rdy   <= '1;

                        end 
                        else if (cdb1.bus_wb_valid && (cdb1.bus_wb_paddr == rs_mult[i].reg_pkt.rs1_paddr)) begin
                            rs_mult[i].reg_pkt.rs1_data  <= cdb1.bus_wb_data;
                            rs_mult[i].instr_pkt.rs1_rdy   <= '1;

                        end
                        else if (cdb2.bus_wb_valid && (cdb2.bus_wb_paddr == rs_mult[i].reg_pkt.rs1_paddr)) begin
                            rs_mult[i].reg_pkt.rs1_data  <= cdb2.bus_wb_data;
                            rs_mult[i].instr_pkt.rs1_rdy   <= '1;

                        end
                        else if (cdb3.bus_wb_valid && (cdb3.bus_wb_paddr == rs_mult[i].reg_pkt.rs1_paddr)) begin
                            rs_mult[i].reg_pkt.rs1_data  <= cdb3.bus_wb_data;
                            rs_mult[i].instr_pkt.rs1_rdy   <= '1;

                        end
                        else if (prf[rs_mult[i].reg_pkt.rs1_paddr].v) begin
                            rs_mult[i].reg_pkt.rs1_data  <= prf[rs_mult[i].reg_pkt.rs1_paddr].data;
                            rs_mult[i].instr_pkt.rs1_rdy   <= '1;
                        end
                    end
                    if (!rs_mult[i].instr_pkt.rs2_rdy) begin
                        if (cdb.bus_wb_valid && (cdb.bus_wb_paddr == rs_mult[i].reg_pkt.rs2_paddr)) begin
                            rs_mult[i].reg_pkt.rs2_data  <= cdb.bus_wb_data;
                            rs_mult[i].instr_pkt.rs2_rdy   <= '1;

                        end 
                        else if (cdb1.bus_wb_valid && (cdb1.bus_wb_paddr == rs_mult[i].reg_pkt.rs2_paddr)) begin
                            rs_mult[i].reg_pkt.rs2_data  <= cdb1.bus_wb_data;
                            rs_mult[i].instr_pkt.rs2_rdy   <= '1;

                        end 
                        else if (cdb2.bus_wb_valid && (cdb2.bus_wb_paddr == rs_mult[i].reg_pkt.rs2_paddr)) begin
                            rs_mult[i].reg_pkt.rs2_data  <= cdb2.bus_wb_data;
                            rs_mult[i].instr_pkt.rs2_rdy   <= '1;

                        end 
                        else if (cdb3.bus_wb_valid && (cdb3.bus_wb_paddr == rs_mult[i].reg_pkt.rs2_paddr)) begin
                            rs_mult[i].reg_pkt.rs2_data  <= cdb3.bus_wb_data;
                            rs_mult[i].instr_pkt.rs2_rdy   <= '1;

                        end                             
                        else if (prf[rs_mult[i].reg_pkt.rs2_paddr].v) begin
                            rs_mult[i].reg_pkt.rs2_data  <= prf[rs_mult[i].reg_pkt.rs2_paddr].data;
                            rs_mult[i].instr_pkt.rs2_rdy   <= '1;
                        end
                    end
                end 
            end
        end
    end

// MEM
    always_ff @(posedge clk) begin
        // RS ENQ
        if (enqueued_en && (enqueued_fu == MEM)) begin
            rs_mem[enqueued_idx]   <= enqueued_mem;
        end
        // RS DEQ
        if (dequeued_en_mem) begin
            rs_mem[dequeued_idx_mem].v <= '0;
        end

        for (integer i = 0; i < RS_Q_DEPTH; i++) begin
            if (rst || br_flush) begin  // RESET RS
                rs_mem[i].v <= '0;
            end else begin
                if (rs_mem[i].v) begin

                    // CHECK WB bus, then PRF for rs1/rs2
                    if (!rs_mem[i].instr_pkt.rs1_rdy) begin
                        if (cdb.bus_wb_valid && (cdb.bus_wb_paddr == rs_mem[i].reg_pkt.rs1_paddr)) begin
                            rs_mem[i].reg_pkt.rs1_data  <= cdb.bus_wb_data;
                            rs_mem[i].instr_pkt.rs1_rdy   <= '1;

                        end 
                        else if (cdb1.bus_wb_valid && (cdb1.bus_wb_paddr == rs_mem[i].reg_pkt.rs1_paddr)) begin
                            rs_mem[i].reg_pkt.rs1_data  <= cdb1.bus_wb_data;
                            rs_mem[i].instr_pkt.rs1_rdy   <= '1;

                        end
                        else if (cdb2.bus_wb_valid && (cdb2.bus_wb_paddr == rs_mem[i].reg_pkt.rs1_paddr)) begin
                            rs_mem[i].reg_pkt.rs1_data  <= cdb2.bus_wb_data;
                            rs_mem[i].instr_pkt.rs1_rdy   <= '1;

                        end
                        else if (cdb3.bus_wb_valid && (cdb3.bus_wb_paddr == rs_mem[i].reg_pkt.rs1_paddr)) begin
                            rs_mem[i].reg_pkt.rs1_data  <= cdb3.bus_wb_data;
                            rs_mem[i].instr_pkt.rs1_rdy   <= '1;

                        end
                        else if (prf[rs_mem[i].reg_pkt.rs1_paddr].v) begin
                            rs_mem[i].reg_pkt.rs1_data  <= prf[rs_mem[i].reg_pkt.rs1_paddr].data;
                            rs_mem[i].instr_pkt.rs1_rdy   <= '1;
                        end
                    end
                    if (!rs_mem[i].instr_pkt.rs2_rdy) begin
                        if (cdb.bus_wb_valid && (cdb.bus_wb_paddr == rs_mem[i].reg_pkt.rs2_paddr)) begin
                            rs_mem[i].reg_pkt.rs2_data  <= cdb.bus_wb_data;
                            rs_mem[i].instr_pkt.rs2_rdy   <= '1;

                        end
                        else if (cdb1.bus_wb_valid && (cdb1.bus_wb_paddr == rs_mem[i].reg_pkt.rs2_paddr)) begin
                            rs_mem[i].reg_pkt.rs2_data  <= cdb1.bus_wb_data;
                            rs_mem[i].instr_pkt.rs2_rdy   <= '1;

                        end 
                        else if (cdb2.bus_wb_valid && (cdb2.bus_wb_paddr == rs_mem[i].reg_pkt.rs2_paddr)) begin
                            rs_mem[i].reg_pkt.rs2_data  <= cdb2.bus_wb_data;
                            rs_mem[i].instr_pkt.rs2_rdy   <= '1;

                        end 
                        else if (cdb3.bus_wb_valid && (cdb3.bus_wb_paddr == rs_mem[i].reg_pkt.rs2_paddr)) begin
                            rs_mem[i].reg_pkt.rs2_data  <= cdb3.bus_wb_data;
                            rs_mem[i].instr_pkt.rs2_rdy   <= '1;

                        end  
                        else if (prf[rs_mem[i].reg_pkt.rs2_paddr].v) begin
                            rs_mem[i].reg_pkt.rs2_data  <= prf[rs_mem[i].reg_pkt.rs2_paddr].data;
                            rs_mem[i].instr_pkt.rs2_rdy   <= '1;
                        end
                    end
                end 
            end
        end
    end


// BR
    always_comb begin
        iss_ex_br = 'x;
        iss_ex_br.v           = '0;

        dequeued_idx_br     = '0;
        dequeued_en_br      = '0;
        // DEQUEUE NEXT INST
        if (!func_unit_busy[BR] && !br_flush) begin
            for (integer i = 0; i < RS_Q_DEPTH; i++) begin
                if (rs_br[i].v && rs_br[i].instr_pkt.rs1_rdy && rs_br[i].instr_pkt.rs2_rdy) begin
                    dequeued_idx_br      = unsigned'(RS_IDX_WIDTH'(i));
                    dequeued_en_br       = '1;
                    iss_ex_br            = rs_br[i];
                    iss_ex_br.rdy_status = '1;
                    break;
                end
            end
        end
    end

// ALU
    always_comb begin
        iss_ex_alu = 'x;
        iss_ex_alu2 = 'x;

        iss_ex_alu.v          = '0;
        iss_ex_alu2.v         = '0;

        dequeued_idx_alu    = '0;
        dequeued_en_alu     = '0;
        dequeued_idx_alu2   = '0;
        dequeued_en_alu2    = '0;
    
        // DEQUEUE NEXT INST
        if (!func_unit_busy[ALU] && !br_flush) begin
            for (integer i = 0; i < RS_Q_DEPTH; i++) begin
                if (rs_alu[i].v && rs_alu[i].instr_pkt.rs1_rdy && rs_alu[i].instr_pkt.rs2_rdy) begin
                    dequeued_idx_alu        = unsigned'(RS_IDX_WIDTH'(i));
                    dequeued_en_alu         = '1;
                    iss_ex_alu              = rs_alu[i];
                    iss_ex_alu.rdy_status   = '1;
                    break;
                end
            end
        end

        if (!func_unit_busy[ALU2] && !br_flush && dequeued_en_alu) begin
            for (integer i = 0; i < RS_Q_DEPTH; i++) begin
                if (rs_alu[i].v && rs_alu[i].instr_pkt.rs1_rdy && rs_alu[i].instr_pkt.rs2_rdy && (unsigned'(RS_IDX_WIDTH'(i)) != dequeued_idx_alu)) begin
                    dequeued_idx_alu2       = unsigned'(RS_IDX_WIDTH'(i));
                    dequeued_en_alu2        = '1;
                    iss_ex_alu2             = rs_alu[i];
                    iss_ex_alu2.rdy_status  = '1;
                    break;
                end
            end
        end
    end

// MULT
    always_comb begin
        iss_ex_mult = 'x;
        iss_ex_mult.v         = '0;

        dequeued_idx_mult   = '0;
        dequeued_en_mult    = '0;
        // DEQUEUE NEXT INST
        if (!func_unit_busy[MULT] && !br_flush) begin
            for (integer i = 0; i < RS_Q_DEPTH; i++) begin
                if (rs_mult[i].v && (rs_mult[i].instr_pkt.i_funct3[2] == '0) && rs_mult[i].instr_pkt.rs1_rdy && rs_mult[i].instr_pkt.rs2_rdy) begin
                    dequeued_idx_mult       = unsigned'(RS_IDX_WIDTH'(i));
                    dequeued_en_mult        = '1;
                    iss_ex_mult             = rs_mult[i];
                    iss_ex_mult.rdy_status  = '1;
                    break;
                end
            end
        end
        iss_ex_div = 'x;
        iss_ex_div.v          = '0;

        dequeued_idx_div    = '0;
        dequeued_en_div     = '0;
        // DEQUEUE NEXT INST
        if (!func_unit_busy[DIV] && !br_flush) begin
            for (integer i = 0; i < RS_Q_DEPTH; i++) begin
                if (rs_mult[i].v && (rs_mult[i].instr_pkt.i_funct3[2] == '1) && rs_mult[i].instr_pkt.rs1_rdy && rs_mult[i].instr_pkt.rs2_rdy) begin
                    dequeued_idx_div        = unsigned'(RS_IDX_WIDTH'(i));
                    dequeued_en_div         = '1;
                    iss_ex_div              = rs_mult[i];
                    iss_ex_div.rdy_status   = '1;
                    break;
                end
            end
        end
    end

// MEM
    always_comb begin
        iss_ex_mem = 'x;
        iss_ex_mem.v          = '0;

        dequeued_idx_mem    = '0;
        dequeued_en_mem     = '0;
        // DEQUEUE NEXT INST
        if (!func_unit_busy[MEM] && !br_flush) begin
            for (integer i = 0; i < RS_Q_DEPTH; i++) begin
                if (rs_mem[i].v && rs_mem[i].instr_pkt.rs1_rdy && rs_mem[i].instr_pkt.rs2_rdy) begin
                    dequeued_idx_mem        = unsigned'(RS_IDX_WIDTH'(i));
                    dequeued_en_mem         = '1;
                    iss_ex_mem              = rs_mem[i];
                    iss_ex_mem.rdy_status   = '1;
                    break;
                end
            end
        end
    end

    // RS ENQ LOGIC
    always_comb begin
        enqueued_en     = '0;
        enqueued_idx    = '0;

        enqueued_br = 'x;
        enqueued_mult = 'x;
        enqueued_alu = 'x;
        enqueued_mem = 'x;

        enqueued_br.v     = '0;
        enqueued_mult.v   = '0;
        enqueued_alu.v    = '0;
        enqueued_mem.v    = '0;

        rs_br_full      = '0;
        rs_alu_full     = '0;
        rs_mult_full    = '0;
        rs_mem_full     = '0;

        if (dp_iss.instr_pkt.i_valid && !rob_full) begin
            case (enqueued_fu)
                BR: begin
                    for (integer i = RS_Q_DEPTH-1; i >= 0; i--) begin
                        if (!rs_br[i].v) begin
                            enqueued_idx    = unsigned'(RS_IDX_WIDTH'(i));
                            enqueued_en     = 1'b1;
                            enqueued_br.v   = '1;

                            enqueued_br.instr_pkt.rob_idx       = rob_idx;
                            enqueued_br.instr_pkt.i_valid       = dp_iss.instr_pkt.i_valid;
                            enqueued_br.instr_pkt.rs1_rdy       = dp_iss.instr_pkt.rs1_rdy;
                            enqueued_br.instr_pkt.rs2_rdy       = dp_iss.instr_pkt.rs2_rdy;
                            enqueued_br.instr_pkt.cmp_op        = dp_iss.instr_pkt.cmp_op;
                            enqueued_br.instr_pkt.i_addr        = dp_iss.instr_pkt.i_addr;
                            enqueued_br.instr_pkt.i_is_jmp      = dp_iss.instr_pkt.i_is_jump;
                            enqueued_br.instr_pkt.imm_data      = dp_iss.instr_pkt.imm_data;
                            enqueued_br.instr_pkt.br_en         = dp_iss.instr_pkt.br_en;
                            enqueued_br.instr_pkt.br_pred       = dp_iss.instr_pkt.br_pred;
                            enqueued_br.instr_pkt.is_jal        = dp_iss.instr_pkt.i_is_jal;
                            enqueued_br.instr_pkt.br_pht_gs_cntr= dp_iss.instr_pkt.br_pht_gs_cntr;
                            enqueued_br.instr_pkt.br_pht_bi_cntr= dp_iss.instr_pkt.br_pht_bi_cntr;
                            enqueued_br.instr_pkt.br_model_cntr= dp_iss.instr_pkt.br_model_cntr;
                            enqueued_br.instr_pkt.br_ghr_idx    = dp_iss.instr_pkt.br_ghr_idx;
                            enqueued_br.instr_pkt.br_pred_mode  = dp_iss.instr_pkt.br_pred_mode;

                            enqueued_br.reg_pkt.rd_valid        = dp_iss.instr_pkt.rd_valid;
                            enqueued_br.reg_pkt.rd_paddr        = dp_iss.instr_pkt.rd_paddr;
                            enqueued_br.reg_pkt.i_use_rd        = dp_iss.instr_pkt.i_use_rd;
                            enqueued_br.reg_pkt.i_use_rs1       = dp_iss.instr_pkt.i_use_rs1;
                            enqueued_br.reg_pkt.i_use_rs2       = dp_iss.instr_pkt.i_use_rs2;
                            enqueued_br.reg_pkt.rs1_paddr       = dp_iss.instr_pkt.rs1_paddr;
                            enqueued_br.reg_pkt.rs1_data        = dp_iss.instr_pkt.rs1_data;
                            enqueued_br.reg_pkt.rs2_paddr       = dp_iss.instr_pkt.rs2_paddr;
                            enqueued_br.reg_pkt.rs2_data        = dp_iss.instr_pkt.rs2_data;
                            break;
                        end
                        else if (i == 0) begin
                            rs_br_full = '1;
                        end
                    end
                end
                ALU: begin
                    for (integer i = RS_Q_DEPTH-1; i >= 0; i--) begin
                        if (!rs_alu[i].v) begin
                            enqueued_idx = unsigned'(RS_IDX_WIDTH'(i));
                            enqueued_en = '1;
                            enqueued_alu.v = '1;

                            enqueued_alu.instr_pkt.rob_idx      = rob_idx;
                            enqueued_alu.instr_pkt.i_valid      = dp_iss.instr_pkt.i_valid;
                            enqueued_alu.instr_pkt.i_addr       = dp_iss.instr_pkt.i_addr;
                            enqueued_alu.instr_pkt.i_op_type    = dp_iss.instr_pkt.i_op_type;
                            enqueued_alu.instr_pkt.alu_op       = dp_iss.instr_pkt.alu_op;
                            enqueued_alu.instr_pkt.cmp_op       = dp_iss.instr_pkt.cmp_op;
                            enqueued_alu.instr_pkt.i_use_imm    = dp_iss.instr_pkt.i_use_imm;
                            enqueued_alu.instr_pkt.i_use_pc     = dp_iss.instr_pkt.i_use_pc;
                            enqueued_alu.instr_pkt.imm_data     = dp_iss.instr_pkt.imm_data;

                            enqueued_alu.reg_pkt.rd_paddr       = dp_iss.instr_pkt.rd_paddr;

                            enqueued_alu.reg_pkt.i_use_rd       = dp_iss.instr_pkt.i_use_rd;
                            enqueued_alu.reg_pkt.i_use_rs1      = dp_iss.instr_pkt.i_use_rs1;
                            enqueued_alu.reg_pkt.i_use_rs2      = dp_iss.instr_pkt.i_use_rs2;
                            enqueued_alu.instr_pkt.rs1_rdy      = dp_iss.instr_pkt.rs1_rdy;
                            enqueued_alu.instr_pkt.rs2_rdy      = dp_iss.instr_pkt.rs2_rdy;

                            enqueued_alu.reg_pkt.rs1_paddr      = dp_iss.instr_pkt.rs1_paddr;
                            enqueued_alu.reg_pkt.rs1_data       = dp_iss.instr_pkt.rs1_data;

                            enqueued_alu.reg_pkt.rs2_paddr      = dp_iss.instr_pkt.rs2_paddr;
                            enqueued_alu.reg_pkt.rs2_data       = dp_iss.instr_pkt.rs2_data;
                            break;
                        end
                        else if (i == 0) begin
                            rs_alu_full = '1;
                        end
                    end
                end
                MULT: begin
                    for (integer i = RS_Q_DEPTH-1; i >= 0; i--) begin
                        if (!rs_mult[i].v) begin
                            enqueued_idx    = unsigned'(RS_IDX_WIDTH'(i));
                            enqueued_en     = '1;
                            enqueued_mult.v = '1;

                            enqueued_mult.instr_pkt.rob_idx  = rob_idx;
                            enqueued_mult.instr_pkt.i_valid  = dp_iss.instr_pkt.i_valid;
                            enqueued_mult.instr_pkt.i_funct3 = dp_iss.instr_pkt.i_funct3;
                            enqueued_mult.instr_pkt.rs1_rdy  = dp_iss.instr_pkt.rs1_rdy;
                            enqueued_mult.instr_pkt.rs2_rdy  = dp_iss.instr_pkt.rs2_rdy;

                            enqueued_mult.reg_pkt.rd_valid   = dp_iss.instr_pkt.rd_valid;
                            enqueued_mult.reg_pkt.rd_paddr   = dp_iss.instr_pkt.rd_paddr;
                            enqueued_mult.reg_pkt.i_use_rd   = dp_iss.instr_pkt.i_use_rd;
                            enqueued_mult.reg_pkt.i_use_rs1  = dp_iss.instr_pkt.i_use_rs1;
                            enqueued_mult.reg_pkt.i_use_rs2  = dp_iss.instr_pkt.i_use_rs2;
                            enqueued_mult.reg_pkt.rs1_paddr  = dp_iss.instr_pkt.rs1_paddr;
                            enqueued_mult.reg_pkt.rs1_data   = dp_iss.instr_pkt.rs1_data;
                            enqueued_mult.reg_pkt.rs2_paddr  = dp_iss.instr_pkt.rs2_paddr;
                            enqueued_mult.reg_pkt.rs2_data   = dp_iss.instr_pkt.rs2_data;
                            break;
                        end
                        else if (i == 0) begin
                            rs_mult_full = '1;
                        end
                    end
                end
                MEM: begin
                    for (integer i = RS_Q_DEPTH-1; i >= 0; i--) begin
                        if (!rs_mem[i].v) begin
                            enqueued_idx    = unsigned'(RS_IDX_WIDTH'(i));
                            enqueued_en     = '1;
                            enqueued_mem.v  = '1;

                            enqueued_mem.instr_pkt.rob_idx          = rob_idx;
                            enqueued_mem.instr_pkt.i_valid          = dp_iss.instr_pkt.i_valid;
                            enqueued_mem.instr_pkt.i_mem_op_type    = dp_iss.instr_pkt.i_mem_op_type;
                            enqueued_mem.instr_pkt.i_funct3         = dp_iss.instr_pkt.i_funct3;
                            enqueued_mem.instr_pkt.imm_data         = dp_iss.instr_pkt.imm_data;
                            enqueued_mem.instr_pkt.rs1_rdy          = dp_iss.instr_pkt.rs1_rdy;
                            enqueued_mem.instr_pkt.rs2_rdy          = dp_iss.instr_pkt.rs2_rdy;
                            enqueued_mem.reg_pkt.i_use_rd           = dp_iss.instr_pkt.i_use_rd;
                            enqueued_mem.reg_pkt.i_use_rs1          = dp_iss.instr_pkt.i_use_rs1;
                            enqueued_mem.reg_pkt.i_use_rs2          = dp_iss.instr_pkt.i_use_rs2;

                            enqueued_mem.reg_pkt.rd_paddr           = dp_iss.instr_pkt.rd_paddr;
                            enqueued_mem.reg_pkt.rs1_paddr          = dp_iss.instr_pkt.rs1_paddr;
                            enqueued_mem.reg_pkt.rs1_data           = dp_iss.instr_pkt.rs1_data;
                            enqueued_mem.reg_pkt.rs2_paddr          = dp_iss.instr_pkt.rs2_paddr;
                            enqueued_mem.reg_pkt.rs2_data           = dp_iss.instr_pkt.rs2_data;
                            break;
                        end
                        else if (i == 0) begin
                            rs_mem_full = '1;
                        end
                    end
                end
            endcase
        end
    end

endmodule : iss_stage_i
