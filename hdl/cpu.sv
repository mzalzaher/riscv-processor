module cpu
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    output  logic   [31:0]      bmem_addr,
    output  logic               bmem_read,
    output  logic               bmem_write,
    output  logic   [63:0]      bmem_wdata,
    input   logic               bmem_ready,

    input   logic   [31:0]      bmem_raddr,
    input   logic   [63:0]      bmem_rdata,
    input   logic               bmem_rvalid
);
    
    // unused signals
    logic [31:0] temp_bmem_raddr;
    logic temp_bmem_ready;
    always_comb begin
        temp_bmem_raddr = bmem_raddr;
        temp_bmem_ready = bmem_ready;
    end
    paddr_t         temp_fl_read_data;
    paddr_t         temp_fl_din_idx;
    logic   [PRF_IDX_WIDTH-1:0] fl_q_dout_idx;

    // instruction cache signals
    logic   [31:0]  i_mem_addr, i_mem_addr_reg_next;
    logic   [3:0]   i_mem_rmask;
    logic           i_mem_resp;
    logic   [31:0]  i_mem_rdata;
    logic   [31:0]  i_dfp_addr;
    logic           i_dfp_read;
    logic           i_dfp_write;
    logic   [255:0] i_dfp_rdata;
    logic   [255:0] i_dfp_wdata;
    logic           i_dfp_resp;

    logic   [31:0]  i_bmem_addr;
    logic           i_bmem_read;
    logic           i_bmem_write;
    logic   [63:0]  i_bmem_wdata;
    logic   [63:0]  i_bmem_rdata;
    logic           i_bmem_rvalid;
    logic           i_stream_rvalid;
    logic   [255:0] i_stream_buf_data;
    logic           i_read_sent;

    // data cache signals
    logic   [31:0]  d_mem_addr_reg, d_mem_addr_reg_next;
    logic   [3:0]   d_mem_rmask_reg, d_mem_rmask_reg_next;
    logic           d_mem_resp;
    logic   [31:0]  d_mem_rdata;
    logic   [31:0]  d_dfp_addr;
    logic           d_dfp_read;
    logic           d_dfp_write;
    logic   [255:0] d_dfp_rdata;
    logic   [255:0] d_dfp_wdata;
    logic           d_dfp_resp;

    logic   [31:0]  d_bmem_addr;
    logic           d_bmem_read;
    logic           d_bmem_write;
    logic   [63:0]  d_bmem_wdata;
    logic   [63:0]  d_bmem_rdata;
    logic           d_bmem_rvalid;

    logic   [3:0]   d_mem_wmask_reg, d_mem_wmask_reg_next;
    logic   [31:0]  d_mem_wdata_reg, d_mem_wdata_reg_next;

    // memory side signals, dfp -> downward facing port
    logic   [31:0]  dfp_addr;
    logic           dfp_read;
    logic           dfp_write;
    logic   [255:0] dfp_rdata;
    logic   [255:0] dfp_wdata;
    logic           dfp_resp;

    logic           d_arb_valid;
    logic           d_adp_busy;
    logic           i_adp_busy;

    logic   [63:0]  order, order_next;
    logic   [31:0]  pc, pc_next;

    logic           inst_q_full;
    logic           inst_q_empty;

    // FREELIST SIGNALS
    logic           fl_q_enq;
    logic           fl_q_deq;
    paddr_t         fl_q_paddr_in;
    logic           fl_q_full;
    logic           fl_q_empty;
    paddr_t         fl_q_paddr_out;

    logic           func_unit_busy[FUNC_UNITS_MAX];

    cdb_t           cdb;
    cdb_t           cdb1;
    cdb_t           cdb2;
    cdb_t           cdb3;

    rat_t           rat_arr[32];    // always 32 arch regs
    logic           rat_din_en;
    aaddr_t         rat_din_aaddr;
    rat_t           rat_din_data;

    logic           dp_rename_rd;
    aaddr_t         dp_rd_aaddr;
    paddr_t         dp_rd_paddr;

    rrf_t           rrf_arr[32];    // always 32 arch regs
    logic           rrf_din_en;
    aaddr_t         rrf_din_aaddr;
    rrf_t           rrf_din_data;

    aaddr_t         prf_aaddr;
    paddr_t         prf_paddr;
    prf_t           prf_in;
    logic           prf_in_en;

    if_id_t         if_id_reg,  if_id_reg_next;
    id_dp_t         id_dp_reg,  id_dp_reg_next;
    dp_iss_t        dp_iss_reg, dp_iss_reg_next;
    ex_wb_t         ex_wb_reg,  ex_wb_reg_next;
    wb_cm_t         wb_cm_reg,  wb_cm_reg_next;

    rs_br_ent_t     iss_ex_br_reg, iss_ex_br_reg_next;
    rs_alu_ent_t    iss_ex_alu_reg, iss_ex_alu_reg_next;
    rs_alu_ent_t    iss_ex_alu2_reg, iss_ex_alu2_reg_next;
    rs_mult_ent_t   iss_ex_mult_reg, iss_ex_mult_reg_next;
    rs_mult_ent_t   iss_ex_div_reg, iss_ex_div_reg_next;
    rs_mem_ent_t    iss_ex_mem_reg, iss_ex_mem_reg_next;

    rob_idx_t       rob_idx;
    logic           rob_commit;
    rob_entry_t     rob_out;
    logic           rat_commit_rename;

    br_pkt_t        commit_br_pkt;
    br_pkt_t        execute_br_pkt;

    logic   [63:0]  n_jal_instructions;

    logic           br_pred;
    logic   [COUNTER_WIDTH-1:0] br_pht_gs_cntr;
    logic   [COUNTER_WIDTH-1:0] br_pht_bi_cntr;
    logic   [MODEL_COUNTER_WIDTH-1:0] br_model_cntr;
    logic   [GHR_Q_IDX-1:0]     br_ghr_idx;
    logic   [31:0]  br_addr;
    br_pred_mode_t  br_pred_mode;

    logic           flush_br;

    logic           fetch_full, fetch_full_prev;
    logic           rs_full;
    logic           rob_full;

    logic           stall_fetch_enq;
    logic           stall_fetch_deq;

    logic           stall_imem_fetch;



    logic           flushed;
    logic           all_flushes, flush_mispredict, flush_taken;
    logic   [31:0]  pc_next_saved;
    logic   [63:0]  order_next_saved;

    logic           flush_br_pred; 
    logic           br_pred_taken;
    logic           br_pred_taken_reg;
    logic           br_pred_taken_done;
    br_pkt_t        pred_br_pkt;




    logic   flushed_done;
    logic   insta_flush;
    logic   [31:0] pc_next_insta;
    logic   [63:0] order_next_insta;
    
    // BRANCH FLUSH LOGIC
    always_ff @(posedge clk) begin
        flushed_done <= '0;
        br_pred_taken_done  <= '0;
        fetch_full_prev <= fetch_full;
        if (rst) begin
            br_pred_taken_reg   <= '0;
            flushed             <= '0;
            pc_next_saved       <= '0;    
            order_next_saved    <= '0;
        end
        else if (flush_br_pred && i_mem_resp && ~(fetch_full || fetch_full_prev)) begin
            flushed             <= '0;
            pc_next_saved       <= commit_br_pkt.addr_next;
            order_next_saved    <= commit_br_pkt.order + 1'd1;
        end
        else if (flush_br_pred && i_mem_resp && (fetch_full || fetch_full_prev)) begin
            flushed             <= '1;
            pc_next_saved       <= commit_br_pkt.addr_next;
            order_next_saved    <= commit_br_pkt.order + 1'd1;
        end
        else if (flush_br_pred && fetch_full) begin
            flushed <= '1;
            pc_next_saved       <= commit_br_pkt.addr_next;
            order_next_saved    <= commit_br_pkt.order + 1'd1;
        end
        else if (flush_br_pred && ~i_mem_resp) begin
            flushed             <= '1;
            pc_next_saved       <= commit_br_pkt.addr_next;
            order_next_saved    <= commit_br_pkt.order + 1'd1;
        end 
        else if (flushed && i_mem_resp) begin
            flushed             <= '0;
            flushed_done        <= '1;
            pc_next_saved       <= pc_next_saved;
            order_next_saved    <= order_next_saved;
        end 
        else if (flushed && ~i_mem_resp) begin
            flushed             <= '1;
            pc_next_saved       <= pc_next_saved;
            order_next_saved    <= order_next_saved;
        end 
        // PREDICT TAKEN
        else if (br_pred_taken && i_mem_resp && ~(fetch_full || fetch_full_prev)) begin
            br_pred_taken_reg   <= '0;
            pc_next_saved       <= pred_br_pkt.addr_next;
            order_next_saved    <= pred_br_pkt.order + 1'd1;
        end
        else if (br_pred_taken && i_mem_resp && (fetch_full || fetch_full_prev)) begin
            br_pred_taken_reg   <= '1;
            pc_next_saved       <= pred_br_pkt.addr_next;
            order_next_saved    <= pred_br_pkt.order + 1'd1;
        end
        else if (br_pred_taken && fetch_full) begin
            br_pred_taken_reg <= '1;
            pc_next_saved       <= pred_br_pkt.addr_next;
            order_next_saved    <= pred_br_pkt.order + 1'd1;
        end
        else if (br_pred_taken && ~i_mem_resp) begin
            br_pred_taken_reg             <= '1;
            pc_next_saved       <= pred_br_pkt.addr_next;
            order_next_saved    <= pred_br_pkt.order + 1'd1;
        end 
        else if (br_pred_taken_reg && i_mem_resp) begin
            br_pred_taken_reg   <= '0;
            br_pred_taken_done  <= '1;
            pc_next_saved       <= pc_next_saved;
            order_next_saved    <= order_next_saved;
        end 
        else if (br_pred_taken_reg && ~i_mem_resp) begin
            br_pred_taken_reg   <= '1;
            pc_next_saved       <= pc_next_saved;
            order_next_saved    <= order_next_saved;
        end 
    end 

    always_comb begin
        pc_next     = pc;
        order_next  = order;
        stall_imem_fetch    = !(i_mem_resp);
        stall_fetch_deq     = rs_full || rob_full;
        
        if(flush_br_pred && i_mem_resp && ~(fetch_full || fetch_full_prev)) begin
            pc_next         = commit_br_pkt.addr_next;
            order_next      = commit_br_pkt.order + 1'd1;
        end else if (flushed) begin
            pc_next         = pc;
            order_next      = order;
        end else if ((flushed_done) && ~stall_imem_fetch) begin 
            pc_next         = pc_next_saved;
            order_next      = order_next_saved;
        end else if (br_pred_taken && i_mem_resp && ~(fetch_full || fetch_full_prev)) begin
            pc_next         = pred_br_pkt.addr_next;
            order_next      = pred_br_pkt.order + 1'd1;
        end 
        else if (br_pred_taken_reg) begin
            pc_next = pc;
            order_next = order;
        end
        else if(br_pred_taken_done && ~stall_imem_fetch) begin
            pc_next = pc_next_saved;
            order_next = order_next_saved;
        end
        else if (!stall_imem_fetch) begin
            pc_next     = pc + 32'd4;
            order_next  = order + 1'd1;
        end 
        i_mem_addr_reg_next = pc_next;
        i_mem_rmask = 4'b1111;
    end

    always_ff @(posedge clk) begin

        if (flush_mispredict) begin
            for (integer i = 0; i < 32; i++) begin
                rat_arr[i] <= '0;
                rat_arr[i].v <= '1;
            end
        end

        if (rst) begin
            pc          <= START_PC;
            order       <= '0;

            n_jal_instructions <= '0;

            // d_mem_resp_reg <= '0;
            // d_mem_rdata_reg <= '0;
            i_mem_addr     <= '0;
            if_id_reg   <= '0;
            id_dp_reg   <= '0;
            dp_iss_reg  <= '0;
            ex_wb_reg   <= '0;
            wb_cm_reg   <= '0;

            iss_ex_br_reg <= '0;
            iss_ex_mem_reg <= '0;
            iss_ex_alu_reg <= '0;
            iss_ex_alu2_reg <= '0;
            iss_ex_mult_reg <= '0;

            for (integer i = 0; i < 32; i++) begin
                rat_arr[i] <= '0;
                rat_arr[i].v <= '1;
            end
            for (integer i = 0; i < 32; i++) begin
                rrf_arr[i] <= '0;
                rrf_arr[i].v <= '1;
            end
        end
        // else if (stall_iss_enq && fetch_full) begin
        //     pc          <= pc_next;
        //     order       <= order_next;
        //     i_mem_resp <= i_mem_resp;
        //     i_mem_rdata <= i_mem_rdata;

        //     if_id_reg <= if_id_reg_next;
        // end
        // else if (fetch_full && stall_imem_fetch) begin
        //     pc          <= pc_next;
        //     order       <= order_next;
        //     i_mem_resp <= i_mem_resp;
        //     i_mem_rdata <= i_mem_rdata;

        //     if_id_reg <= if_id_reg_next;
        // end
        else if((flush_mispredict) && fetch_full) begin
            pc          <= pc_next;
            order       <= order_next;
            i_mem_addr     <= i_mem_addr_reg_next;

            if_id_reg   <= if_id_reg_next;
            id_dp_reg   <= id_dp_reg_next;
            dp_iss_reg  <= dp_iss_reg_next;
        end 

        else if ((flush_mispredict) && stall_fetch_deq) begin
            pc          <= pc_next;
            order       <= order_next;
            i_mem_addr     <= i_mem_addr_reg_next;

            if_id_reg   <= if_id_reg_next;
            id_dp_reg   <= id_dp_reg_next;
            dp_iss_reg  <= dp_iss_reg_next;
        end 

        else if(fetch_full && ~stall_fetch_deq) begin
            pc          <= pc;
            order       <= order;

            i_mem_addr     <= i_mem_addr;
            if_id_reg <= if_id_reg_next;
            id_dp_reg <= id_dp_reg_next;
            dp_iss_reg <= dp_iss_reg_next;
        end 

        else if(fetch_full) begin
            pc          <= pc;
            order       <= order;

            i_mem_addr     <= i_mem_addr;
            if_id_reg <= if_id_reg_next;
        end 

        else if (stall_fetch_deq) begin
            pc          <= pc_next;
            order       <= order_next;

            i_mem_addr     <= i_mem_addr_reg_next;
            if_id_reg <= if_id_reg_next;
        end 

        else begin
            pc          <= pc_next;
            order       <= order_next;

            if_id_reg       <= if_id_reg_next;
            id_dp_reg       <= id_dp_reg_next;
            dp_iss_reg      <= dp_iss_reg_next;
            i_mem_addr     <= i_mem_addr_reg_next;
        end

        if(~rst) begin
            if (rrf_din_en) begin
                rrf_arr[rrf_din_aaddr] <= rrf_din_data;
                rat_arr[rrf_din_aaddr].renamed <= (rrf_din_data.paddr  != rat_arr[rrf_din_aaddr].paddr);
            end

            if (rat_din_en) begin
                rat_arr[rat_din_aaddr] <= rat_din_data;
            end

            if (!func_unit_busy[BR]) begin
                iss_ex_br_reg   <= iss_ex_br_reg_next;
            end
            if (!func_unit_busy[ALU]) begin
                iss_ex_alu_reg  <= iss_ex_alu_reg_next;
            end
            if (!func_unit_busy[ALU2]) begin
                iss_ex_alu2_reg <= iss_ex_alu2_reg_next;
            end
            if (!func_unit_busy[MULT]) begin
                iss_ex_mult_reg <= iss_ex_mult_reg_next;
            end
            if (!func_unit_busy[DIV]) begin
                iss_ex_div_reg  <= iss_ex_div_reg_next;
            end
            if (!func_unit_busy[MEM]) begin
                iss_ex_mem_reg  <= iss_ex_mem_reg_next;
            end

            ex_wb_reg       <= ex_wb_reg_next;
            wb_cm_reg       <= wb_cm_reg_next;
            d_mem_addr_reg <= d_mem_addr_reg_next;
            d_mem_rmask_reg <= d_mem_rmask_reg_next;
            d_mem_wmask_reg <= d_mem_wmask_reg_next;
            d_mem_wdata_reg <= d_mem_wdata_reg_next;

            if (commit_br_pkt.v && commit_br_pkt.is_jal)
                n_jal_instructions  <= n_jal_instructions + 1'b1;
        end

    end

    logic   if_flush;
    logic   id_flush;
    logic   dp_flush;
    logic   iss_flush;
    logic   ex_flush;
    logic   wb_flush;

    // StAGE FLUSH SIGNALS
    always_comb begin
        flush_mispredict = flush_br_pred || flushed || flushed_done;
        flush_taken =  br_pred_taken || br_pred_taken_reg || br_pred_taken_done;
        all_flushes  = flush_mispredict;

        if_flush    = flush_mispredict || flush_taken;
        id_flush    = flush_mispredict || stall_fetch_deq || flush_taken;
        dp_flush    = flush_mispredict || stall_fetch_deq;
        iss_flush   = flush_mispredict;
        ex_flush    = flush_mispredict;
        wb_flush    = flush_mispredict;
    end

    always_comb begin
        // INITIAL SIGNAL VALUES

        rat_din_en      = '0;
        rat_din_aaddr   = 'X;
        rat_din_data    = 'X;

        rrf_din_en      = '0;
        rrf_din_aaddr   = '0;
        rrf_din_data    = '0;
        rat_commit_rename = '0;

        prf_paddr   = '0;
        prf_in      = '0;
        prf_in_en   = '0;

        cdb.bus_mem_valid   = '0;
        cdb.bus_mem_paddr   = '0;
        cdb.bus_mem_data    = '0;

        if (dp_rename_rd) begin
            rat_din_en              = '1;
            rat_din_aaddr           = dp_rd_aaddr;
            rat_din_data.renamed    = '1;
            rat_din_data.paddr      = dp_rd_paddr;
            rat_din_data.v          = '1;
        end

        if (rob_commit) begin
            rat_commit_rename       = (rob_out.instr_pkt.rd_paddr != rat_arr[rrf_din_aaddr].paddr);

            rrf_din_en              = rob_out.instr_pkt.i_use_rd;
            rrf_din_aaddr           = rob_out.instr_pkt.rd_aaddr;
            rrf_din_data.renamed    = '1;
            rrf_din_data.paddr      = rob_out.instr_pkt.rd_paddr;
            rrf_din_data.data       = rob_out.instr_pkt.rd_data;
            rrf_din_data.v          = '1;

            prf_paddr   = rob_out.instr_pkt.rd_paddr;
            prf_in.data = rob_out.instr_pkt.rd_data;
            prf_in.v    = '1;
            prf_in_en   = rrf_din_en;
        end

        if ((wb_cm_reg.instr_pkt.func_unit == MEM) && wb_cm_reg.instr_pkt.i_use_rd && wb_cm_reg.instr_pkt.i_valid) begin
            cdb.bus_mem_valid   = '1;
            cdb.bus_mem_paddr   = wb_cm_reg.instr_pkt.rd_paddr;
            cdb.bus_mem_data    = wb_cm_reg.instr_pkt.rd_data;
        end

    end

    always_comb begin
        flush_br_pred = '0;
        flush_br      = '0;

        commit_br_pkt = '0;
        pred_br_pkt   = '0;
        br_pred_taken = '0;
        
        if(id_dp_reg.instr_pkt.i_valid && id_dp_reg.instr_pkt.func_unit == BR) begin
            pred_br_pkt.v         = id_dp_reg.instr_pkt.br_en;
            pred_br_pkt.order     = id_dp_reg.instr_pkt.order;
            pred_br_pkt.pred      = id_dp_reg.instr_pkt.br_pred;
            pred_br_pkt.result    = id_dp_reg.instr_pkt.br_result;
            pred_br_pkt.pht_gs_cntr  = id_dp_reg_next.instr_pkt.br_pht_gs_cntr;
            pred_br_pkt.pht_bi_cntr  = id_dp_reg_next.instr_pkt.br_pht_bi_cntr;
            pred_br_pkt.model_cntr  = id_dp_reg_next.instr_pkt.br_model_cntr;
            pred_br_pkt.ghr_idx   = id_dp_reg_next.instr_pkt.br_ghr_idx;
            pred_br_pkt.addr      = id_dp_reg_next.instr_pkt.i_addr;
            pred_br_pkt.addr_next = id_dp_reg.instr_pkt.i_addr_next;
            pred_br_pkt.is_jmp    = id_dp_reg.instr_pkt.i_is_jump;
            pred_br_pkt.is_jal    = id_dp_reg.instr_pkt.i_is_jal;
            pred_br_pkt.br_pred_mode    = id_dp_reg.instr_pkt.br_pred_mode;
        end

        commit_br_pkt.v         = wb_cm_reg.instr_pkt.br_en;
        commit_br_pkt.order     = wb_cm_reg.instr_pkt.order;
        commit_br_pkt.pred      = wb_cm_reg.instr_pkt.br_pred;
        commit_br_pkt.result    = wb_cm_reg.instr_pkt.br_result;
        commit_br_pkt.pht_gs_cntr  = wb_cm_reg.instr_pkt.br_pht_gs_cntr;
        commit_br_pkt.pht_bi_cntr  = wb_cm_reg.instr_pkt.br_pht_bi_cntr;
        commit_br_pkt.model_cntr  = wb_cm_reg.instr_pkt.br_model_cntr;
        commit_br_pkt.ghr_idx   = wb_cm_reg.instr_pkt.br_ghr_idx;
        commit_br_pkt.addr      = wb_cm_reg.instr_pkt.i_addr;
        commit_br_pkt.addr_next = wb_cm_reg.instr_pkt.i_addr_next;
        commit_br_pkt.is_jmp    = wb_cm_reg.instr_pkt.i_is_jump;
        commit_br_pkt.is_jal    = wb_cm_reg.instr_pkt.i_is_jal;
        commit_br_pkt.br_pred_mode      = wb_cm_reg.instr_pkt.br_pred_mode;


        if (wb_cm_reg.instr_pkt.i_valid && wb_cm_reg.instr_pkt.func_unit == BR) begin
            if (commit_br_pkt.pred != commit_br_pkt.result)
                flush_br = '1;
        end
        if (commit_br_pkt.is_jmp)
            flush_br = '1;

        flush_br_pred = flush_br;

        if (pred_br_pkt.v && (pred_br_pkt.is_jal || pred_br_pkt.pred))
            br_pred_taken   = '1;
    end

    if_stage_i if_stage (
        .clk        (clk),
        .rst        (rst),

        .pc         (pc),
        .order      (order),

        .imem_rdata (i_mem_rdata),
        .imem_resp  (i_mem_resp),

        .flush      (if_flush),

        .stall_fetch_deq(stall_fetch_deq),
        .stall_fetch_enq(fetch_full),

        
        .if_id      (if_id_reg_next)
    );

    id_stage_i id_stage (
        .if_id      (if_id_reg),
        .flush      (id_flush),

        .br_pred    (br_pred),
        .br_pht_gs_cntr(br_pht_gs_cntr),
        .br_pht_bi_cntr(br_pht_bi_cntr),
        .br_model_cntr(br_model_cntr),
        .br_ghr_idx (br_ghr_idx),
        .br_addr    (br_addr),
        .br_pred_mode(br_pred_mode),

        .id_dp      (id_dp_reg_next)
    );

    dp_stage_i dp_stage (
        .id_dp      (id_dp_reg),

        .flush      (dp_flush),

        .fl_paddr_out(fl_q_paddr_out),
        .fl_empty   (fl_q_empty), // check if queue empty first, send valid=0 if no free p regs
        .fl_deq     (fl_q_deq),

        .rat_rs1    (rat_arr[id_dp_reg.instr_pkt.rs1_aaddr]),
        .rat_rs2    (rat_arr[id_dp_reg.instr_pkt.rs2_aaddr]),

        .rrf_rs1    (rrf_arr[id_dp_reg.instr_pkt.rs1_aaddr]),
        .rrf_rs2    (rrf_arr[id_dp_reg.instr_pkt.rs2_aaddr]),

        .rename_rd  (dp_rename_rd),
        .rd_aaddr   (dp_rd_aaddr),
        .rd_paddr   (dp_rd_paddr),

        .dp_iss     (dp_iss_reg_next)
    );

    iss_stage_i iss_stage (
        .clk            (clk),
        .rst            (rst),

        .dp_iss         (dp_iss_reg),
        .dp_rename_rd   (dp_rename_rd),
        .dp_rd_paddr    (dp_rd_paddr),

        .br_flush       (iss_flush),
        .rs_full        (rs_full),
        .prf_in         (prf_in),   // data + valid signal
        .prf_in_paddr   (prf_paddr),
        .prf_in_en      (prf_in_en),

        .cdb            (cdb),
        .cdb1           (cdb1),
        .cdb2           (cdb2),
        .cdb3           (cdb3),

        .func_unit_busy (func_unit_busy),
        .rob_idx        (rob_idx),
        .rob_full       (rob_full),

        .iss_ex_br      (iss_ex_br_reg_next),
        .iss_ex_alu     (iss_ex_alu_reg_next),
        .iss_ex_alu2     (iss_ex_alu2_reg_next),
        .iss_ex_mult    (iss_ex_mult_reg_next),
        .iss_ex_div    (iss_ex_div_reg_next),
        .iss_ex_mem     (iss_ex_mem_reg_next)

    );

    ex_stage_i ex_stage (
        .rst(rst),
        .clk(clk),

        .iss_ex_br  (iss_ex_br_reg),
        .iss_ex_alu (iss_ex_alu_reg),
        .iss_ex_alu2(iss_ex_alu2_reg),
        .iss_ex_mult(iss_ex_mult_reg),
        .iss_ex_div(iss_ex_div_reg),
        .iss_ex_mem(iss_ex_mem_reg),
        .flush(ex_flush),
        
        // cache signals for mem
        // .d_mem_resp_reg(d_mem_resp_reg),
        // .d_mem_rdata_reg(d_mem_rdata_reg),
        // .d_mem_addr(d_mem_addr),
        // .d_mem_rmask(d_mem_rmask),
        .cdb1(cdb1),
        .cdb2(cdb2),
        .cdb3(cdb3),

        // async signals: if a func unit will be busy for another cycle, 
        // tell iss stage to not send another instr from the RS
        .func_unit_busy(func_unit_busy),
        .execute_br_pkt(execute_br_pkt),

        .ex_wb      (ex_wb_reg_next)
    );

    wb_stage_i wb_stage (
        .clk        (clk),
        .rst        (rst),
        .dp_iss      (dp_iss_reg),
        .ex_wb      (ex_wb_reg),

        .bus_valid  (cdb.bus_wb_valid),
        .bus_data   (cdb.bus_wb_data),
        .bus_paddr  (cdb.bus_wb_paddr),
        
        .flush_br   (wb_flush),

        // cache signals for mem
        .d_mem_resp_reg(d_mem_resp),
        .d_mem_rdata_reg(d_mem_rdata),
        .d_mem_addr(d_mem_addr_reg_next),
        .d_mem_rmask(d_mem_rmask_reg_next),
        .d_mem_wmask(d_mem_wmask_reg_next),   
        .d_mem_wdata(d_mem_wdata_reg_next),

        .rob_commit (rob_commit),
        .rob_out    (rob_out),
        .rob_index  (rob_idx),
        .rob_full   (rob_full),
        .wb_cm      (wb_cm_reg_next),

        .rs_full    (rs_full)
    );

    br_predictor_i br_predictor (
        .clk            (clk),
        .rst            (rst),

        .fetch_valid    (if_id_reg_next.valid && (if_id_reg_next.inst[6:0] == op_b_br)),
        .fetch_pc       (if_id_reg_next.pc),

        .pred           (br_pred),
        .pred_pht_gs_counter(br_pht_gs_cntr),
        .pred_pht_bi_counter(br_pht_bi_cntr),
        .pred_model_counter(br_model_cntr),
        .pred_ghr_idx   (br_ghr_idx),
        .pred_pc        (br_addr),
        .pred_br_pred_mode(br_pred_mode),

        .result_valid   (commit_br_pkt.v && !commit_br_pkt.is_jmp),
        .result_pred    (commit_br_pkt.pred),
        .result_taken   (commit_br_pkt.result),
        .result_pht_gs_counter(commit_br_pkt.pht_gs_cntr),
        .result_pht_bi_counter(commit_br_pkt.pht_bi_cntr),
        .result_model_counter(commit_br_pkt.model_cntr),
        .result_ghr_idx (commit_br_pkt.ghr_idx),
        .result_br_pred_mode(commit_br_pkt.br_pred_mode),
        .result_pc      (commit_br_pkt.addr)
        // .result_valid   (execute_br_pkt.v && !execute_br_pkt.is_jmp),
        // .result_pred    (execute_br_pkt.pred),
        // .result_taken   (execute_br_pkt.result),
        // .result_pht_counter(execute_br_pkt.pht_cntr),
        // .result_ghr_idx (execute_br_pkt.ghr_idx),
        // .result_pc      (execute_br_pkt.addr)
    );

    // QUEUES
    queue_inverted_i #(.WIDTH(PRF_IDX_WIDTH), .DEPTH(PRF_DEPTH)) freelist_q (
        .clk        (clk),
        .rst        (rst || flush_mispredict),
        .enqueue    (prf_in_en),
        .dequeue    (fl_q_deq),
        .data_in    (prf_paddr),
        .din_idx    (temp_fl_din_idx),

        .read_idx   ('0),
        .read_data  (temp_fl_read_data),

        .write_en   ('0),           // FIX: keep it 0 if we never write here.
        .write_idx  ('0),
        .write_data ('0),

        .full       (fl_q_full),
        .empty      (fl_q_empty),
        .data_out   (fl_q_paddr_out),
        .dout_idx   (fl_q_dout_idx)
    );

    cacheline_adapter_i cacheline_adapter_inst (
        .clk        (clk),
        .rst        (rst),

        .arb_valid    ('0),
        .adp_busy     (i_adp_busy),
        .read_sent    (i_read_sent),
        .bmem_addr  (i_bmem_addr),
        .bmem_read  (i_bmem_read),
        .bmem_write (i_bmem_write),
        .bmem_wdata (i_bmem_wdata),
        .i_stream_rvalid(i_stream_rvalid),
        .i_stream_buf_data(i_stream_buf_data),
        // .bmem_ready(bmem_ready),
        // .bmem_raddr(bmem_raddr),
        .bmem_rdata (i_bmem_rdata),
        .bmem_rvalid(i_bmem_rvalid),
        .other_adp_busy(d_adp_busy),
        .dfp_addr   (i_dfp_addr),
        .dfp_read   (i_dfp_read),
        .dfp_write  (i_dfp_write),
        .dfp_rdata  (i_dfp_rdata),
        .dfp_wdata  (i_dfp_wdata),
        .dfp_resp   (i_dfp_resp)
    );

    cache_inst cache_inst (
        .clk        (clk),
        .rst        (rst),

        // cpu side signals, ufp -> upward facing port
        .ufp_addr   (i_mem_addr),
        .ufp_rmask  (i_mem_rmask),
        .ufp_wmask  (4'b0000),
        .ufp_rdata  (i_mem_rdata),
        .ufp_wdata  ('0),
        .ufp_resp   (i_mem_resp),

        // memory side signals, dfp -> downward facing port
        .dfp_addr   (i_dfp_addr),
        .dfp_read   (i_dfp_read),
        .dfp_write  (i_dfp_write),
        .dfp_rdata  (i_dfp_rdata),
        .dfp_wdata  (i_dfp_wdata),
        .dfp_resp   (i_dfp_resp)
    );

    // TODO: connect to mem execute.
    cacheline_adapter_i cacheline_adapter_data (
        .clk        (clk),
        .rst        (rst),

        .i_stream_rvalid('0),
        .i_stream_buf_data('0),

        .arb_valid  (d_arb_valid),
        .adp_busy   (d_adp_busy),
        .bmem_addr  (d_bmem_addr),
        .bmem_read  (d_bmem_read),
        .bmem_write (d_bmem_write),
        .bmem_wdata (d_bmem_wdata),
        .bmem_rdata (d_bmem_rdata),
        .bmem_rvalid(d_bmem_rvalid),
        .other_adp_busy(i_adp_busy),
        .dfp_addr   (d_dfp_addr),
        .dfp_read   (d_dfp_read),
        .dfp_write  (d_dfp_write),
        .dfp_rdata  (d_dfp_rdata),
        .dfp_wdata  (d_dfp_wdata),
        .dfp_resp   (d_dfp_resp)
    );

    // TODO: connect to mem execute.
    cache cache_data (
        .clk        (clk),
        .rst        (rst),

        // cpu side signals, ufp -> upward facing port
        .ufp_addr   (d_mem_addr_reg),
        .ufp_rmask  (d_mem_rmask_reg),
        .ufp_wmask  (d_mem_wmask_reg),  
        .ufp_rdata  (d_mem_rdata),
        .ufp_wdata  (d_mem_wdata_reg),
        .ufp_resp   (d_mem_resp),

        // memory side signals, dfp -> downward facing port
        .dfp_addr   (d_dfp_addr),
        .dfp_read   (d_dfp_read),
        .dfp_write  (d_dfp_write),
        .dfp_rdata  (d_dfp_rdata),
        .dfp_wdata  (d_dfp_wdata),
        .dfp_resp   (d_dfp_resp)
    );

    cache_arbiter_i cache_arbiter (
        .clk(clk),
        .rst(rst),

        .i_read_sent(i_read_sent),
        .i_bmem_addr(i_bmem_addr),
        .i_bmem_read(i_bmem_read),
        .i_bmem_rdata(i_bmem_rdata),
        .i_bmem_rvalid(i_bmem_rvalid),
        .i_stream_rvalid(i_stream_rvalid),
        .i_stream_buf_data(i_stream_buf_data),
        // TODO: connect to mem execute.
        // .d_bmem_addr('0),
        // .d_bmem_read('0),
        // .d_bmem_write('0),
        // .d_bmem_wdata('0),
        .d_bmem_addr(d_bmem_addr),
        .d_bmem_read(d_bmem_read),
        .d_bmem_write(d_bmem_write),
        .d_bmem_wdata(d_bmem_wdata),
        // .d_adp_busy(d_adp_busy),
        // .i_adp_busy(i_adp_busy),
        .d_arb_valid(d_arb_valid),
        .d_bmem_rdata(d_bmem_rdata),
        .d_bmem_rvalid(d_bmem_rvalid),
        .i_adp_busy(i_adp_busy),
        // .bmem_ready(bmem_ready),
        .bmem_raddr(bmem_raddr),
        .bmem_rdata(bmem_rdata),
        .bmem_rvalid(bmem_rvalid),
        .out_bmem_addr(bmem_addr),
        .out_bmem_read(bmem_read),
        .out_bmem_write(bmem_write),
        .out_bmem_wdata(bmem_wdata)
    );

endmodule : cpu