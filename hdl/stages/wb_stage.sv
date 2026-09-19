module wb_stage_i
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   dp_iss_t        dp_iss,
    input   ex_wb_t         ex_wb, 

    output  logic           bus_valid,
    output  logic  [31:0]   bus_data,
    output  paddr_t         bus_paddr,

    input   logic           d_mem_resp_reg,
    input   logic   [31:0]  d_mem_rdata_reg, 
    output  logic   [31:0]  d_mem_addr, 
    output  logic   [3:0]   d_mem_rmask,
    output  logic   [3:0]   d_mem_wmask,
    output  logic   [31:0]  d_mem_wdata,


    output  logic           rob_commit,
    output  rob_entry_t     rob_out,
    output  logic           rob_full,
    output  logic   [ROB_IDX_WIDTH - 1:0]   rob_index,
    input   logic           flush_br,
    input   logic           rs_full,
    output  wb_cm_t         wb_cm

);     

    logic                       rob_q_enq;
    logic                       rob_q_deq;
    logic [ROB_IDX_WIDTH-1:0]   rob_q_write_idx;
    logic                       rob_q_write_en;
    rob_entry_t                 rob_q_write_data;

    logic [ROB_IDX_WIDTH-1:0]   rob_q_read_idx;
    rob_entry_t                 rob_q_read_data;


    rob_entry_t           rob_q_write_data_read;    


    logic                 rob_q_full;
    logic                 rob_q_empty;
    logic [ROB_IDX_WIDTH-1:0] rob_din_idx;
    logic [ROB_IDX_WIDTH-1:0] rob_dout_idx;
    rob_entry_t rob_q_din;
    rob_entry_t rob_q_dout;

    // hard reset rob signal
    logic reset_rob;

        // Post-Commit Store buffer 
    logic [3:0]     store_buf_valid;
    logic [31:0]    store_buf_addr;
    logic [31:0]    store_buf_data;
    logic store_busy_next;
    logic buf_resp;
    data_pkt_t      write_pkt;
    logic [3:0] update_write_pkt;
    logic update_write_busy;
    logic rst_store_buf;
    logic store_busy;
    always_ff @ (posedge clk) begin
        if(rst || rst_store_buf) begin
            write_pkt <= '0;
            write_pkt.store_busy <= '0;
            store_buf_addr <= '0;
            store_buf_data <= '0;
            store_buf_valid <= '0;
        end 
        else if (update_write_pkt != '0) begin
            store_buf_addr <= d_mem_addr;
            store_buf_valid <= update_write_pkt;
            unique case (d_mem_wmask) 
                4'b0001 : store_buf_data[0 +: 8] <= d_mem_wdata[7:0];  // Byte 0
                4'b0010 : store_buf_data[8 +: 8] <= d_mem_wdata[15:8];  // Byte 1
                4'b0100 : store_buf_data[16 +: 8] <= d_mem_wdata[23:16];  // Byte 2
                4'b1000 : store_buf_data[24 +: 8] <= d_mem_wdata[31:24];  // Byte 3
                4'b0011 : store_buf_data[0 +: 16] <= d_mem_wdata[15:0];  // Halfword (Bytes 0-1)
                4'b1100 : store_buf_data[16 +: 16] <= d_mem_wdata[31:16];  // Halfword (Bytes 2-3)
                4'b0110 : store_buf_data[8 +: 16] <= d_mem_wdata[23:8];  // Halfword (Bytes 2-3)
                4'b0111 : store_buf_data[0 +: 24] <= d_mem_wdata[23:0];
                4'b1110 : store_buf_data[8 +: 24] <= d_mem_wdata[31:8];
                4'b1111 : store_buf_data[0 +: 32] <= d_mem_wdata;  // Full word (Bytes 0-3)
                default : store_buf_data[0 +: 32] <= 'hBABECAFE;  // Shouldn't happen, but default to 0
            endcase
            write_pkt.d_mem_wmask <= d_mem_wmask;
            write_pkt.d_mem_wdata <= d_mem_wdata;
            write_pkt.d_mem_addr <= d_mem_addr;
            write_pkt.store_busy <= store_busy_next;
        end 
        else if (update_write_busy)
            write_pkt.store_busy <= store_busy_next;

    end
    assign store_busy = (store_busy_next == '0) ? '0 : write_pkt.store_busy;
    
    always_comb begin
        rst_store_buf = '0;
        store_busy_next = '0;
        update_write_busy = '0;
        update_write_pkt = '0;
        buf_resp = '0;
        rob_q_deq = '0;
        rob_q_enq = '0;
        rob_out = '0;
        rob_commit = '0;
        rob_q_din = '0;
        wb_cm = '0;
        bus_valid = '0;
        bus_paddr = '0;
        bus_data = '0;
        rob_full = '0;
        reset_rob = '0;

        // default queue write/read signals.
        rob_q_write_en = '0;
        rob_q_write_idx = '0; 
        rob_q_write_data = 'X;
        rob_q_read_idx = rob_dout_idx;
        
        d_mem_rmask = '0;
        d_mem_wmask = '0;
        d_mem_wdata = 'x;
        d_mem_addr = 'x;

        // stall if rob is full.
        if (rob_q_full && dp_iss.instr_pkt.i_valid && !flush_br) begin
            rob_full = '1;
        end

    // 1. RECEIVING EXECUTE PACKET LOGIC. ------------------------------------------------------------------------

        // if packet is valid and isn't flushed, recieve.
        if(ex_wb.instr_pkt.i_valid) begin

            // bus writeback logic
            if (ex_wb.instr_pkt.i_use_rd && ex_wb.instr_pkt.rd_valid && ex_wb.data_pkt.d_mem_rmask == '0) begin
                bus_valid = '1;
                bus_paddr   = ex_wb.instr_pkt.rd_paddr;
                bus_data = ex_wb.instr_pkt.rd_data;
            end

            // Check if packet is mem or not.
            if((ex_wb.data_pkt.d_mem_wmask != 0 || ex_wb.data_pkt.d_mem_rmask != 0)) begin
                // write logic formalities.
                // rob_q_write_data = rob_q_write_data_read;
                rob_q_write_data = '0;
                rob_q_write_en = '1;
                rob_q_write_idx = ex_wb.instr_pkt.rob_idx;
                rob_q_write_data.status = '0; // dont set to done, since we still have to request mem.
                rob_q_write_data.v = '1;

                // stays the same after dispatch.
                rob_q_write_data.instr_pkt.order       = rob_q_write_data_read.instr_pkt.order;
                rob_q_write_data.instr_pkt.i_valid     = rob_q_write_data_read.instr_pkt.i_valid;
                rob_q_write_data.instr_pkt.i_addr      = rob_q_write_data_read.instr_pkt.i_addr;
                rob_q_write_data.instr_pkt.i_addr_next = rob_q_write_data_read.instr_pkt.i_addr_next;
                rob_q_write_data.instr_pkt.i_instr     = rob_q_write_data_read.instr_pkt.i_instr;
                rob_q_write_data.instr_pkt.i_funct3    = rob_q_write_data_read.instr_pkt.i_funct3;
                rob_q_write_data.instr_pkt.i_use_rd    = rob_q_write_data_read.instr_pkt.i_use_rd;
                rob_q_write_data.instr_pkt.br_pred     = rob_q_write_data_read.instr_pkt.br_pred;
                rob_q_write_data.instr_pkt.br_pht_gs_cntr = rob_q_write_data_read.instr_pkt.br_pht_gs_cntr;
                rob_q_write_data.instr_pkt.br_pht_bi_cntr = rob_q_write_data_read.instr_pkt.br_pht_bi_cntr;
                rob_q_write_data.instr_pkt.br_model_cntr = rob_q_write_data_read.instr_pkt.br_model_cntr;
                rob_q_write_data.instr_pkt.br_ghr_idx  = rob_q_write_data_read.instr_pkt.br_ghr_idx;
                rob_q_write_data.instr_pkt.i_is_jump   = rob_q_write_data_read.instr_pkt.i_is_jump;
                rob_q_write_data.instr_pkt.i_is_jal    = rob_q_write_data_read.instr_pkt.i_is_jal;
                rob_q_write_data.instr_pkt.func_unit   = rob_q_write_data_read.instr_pkt.func_unit;
                rob_q_write_data.instr_pkt.rd_aaddr    = rob_q_write_data_read.instr_pkt.rd_aaddr;
                rob_q_write_data.instr_pkt.rd_paddr    = rob_q_write_data_read.instr_pkt.rd_paddr;
                rob_q_write_data.instr_pkt.rs1_aaddr   = rob_q_write_data_read.instr_pkt.rs1_aaddr;
                rob_q_write_data.instr_pkt.rs1_paddr   = rob_q_write_data_read.instr_pkt.rs1_paddr;
                rob_q_write_data.instr_pkt.rs2_aaddr   = rob_q_write_data_read.instr_pkt.rs2_aaddr;
                rob_q_write_data.instr_pkt.rs2_paddr   = rob_q_write_data_read.instr_pkt.rs2_paddr;
                rob_q_write_data.instr_pkt.br_en       = rob_q_write_data_read.instr_pkt.br_en;
                
                // changes after dispatch for me instrs.
                rob_q_write_data.instr_pkt.rd_valid    = ex_wb.instr_pkt.rd_valid;
                rob_q_write_data.instr_pkt.rd_data     = ex_wb.instr_pkt.rd_data;
                rob_q_write_data.instr_pkt.rs1_data    = ex_wb.instr_pkt.rs1_data;
                rob_q_write_data.instr_pkt.rs2_data    = ex_wb.instr_pkt.rs2_data;
                rob_q_write_data.data_pkt              = ex_wb.data_pkt;

                rob_q_write_data.data_pkt.mask_ready = '1;
            end
            else begin
                // write done if instruction is not mem.
                rob_q_write_data = rob_q_write_data_read;
                rob_q_write_en = '1;
                rob_q_write_data.v = '1;
                rob_q_write_idx = ex_wb.instr_pkt.rob_idx;
                rob_q_write_data.status = '1; // 1 == done

                // changes after dispatch.
                if(ex_wb.instr_pkt.func_unit == BR) begin
                    rob_q_write_data.instr_pkt.i_addr_next = ex_wb.instr_pkt.i_addr_next;
                    rob_q_write_data.instr_pkt.br_en       = ex_wb.instr_pkt.br_en;
                    rob_q_write_data.instr_pkt.br_result   = ex_wb.instr_pkt.br_result;
                end 

                rob_q_write_data.instr_pkt.rd_valid    = ex_wb.instr_pkt.rd_valid ;
                rob_q_write_data.instr_pkt.rd_data     = ex_wb.instr_pkt.rd_data ;
                rob_q_write_data.instr_pkt.rs1_data    = ex_wb.instr_pkt.rs1_data;
                rob_q_write_data.instr_pkt.rs2_data    = ex_wb.instr_pkt.rs2_data;
            end
        end

    // -----------------------------------------------------------------------------------------------------------------
        
    // 2. REQUEST DMEM LOGIC. ------------------------------------------------------------------------------------------
        if (write_pkt.store_busy && ~d_mem_resp_reg) begin
            d_mem_wmask = write_pkt.d_mem_wmask;
            d_mem_wdata = write_pkt.d_mem_wdata;
            d_mem_addr = write_pkt.d_mem_addr;
        end
        else if(write_pkt.store_busy && d_mem_resp_reg) begin
            store_busy_next = '0;
            update_write_busy = '1;
        end

        if (flush_br && (rob_q_read_data.data_pkt.d_mem_wmask == '1) && (rob_q_read_data.data_pkt.mask_ready != '0) && (!rob_q_empty) && (write_pkt.store_busy))
            reset_rob ='1;
        // i. if we haven't set the flushed signals but we recieve the flush request, we can reset the rob. We haven't requested memory yet so we can not set them.
        else if(flush_br && (rob_q_read_data.data_pkt.d_mem_rmask != '0 || (rob_q_read_data.data_pkt.d_mem_wmask != '0)) && (rob_q_read_data.data_pkt.mask_ready != '0) ) begin
            reset_rob = '1;
        end 
        // ii. If we recieve the flush request, and we aren't using mem, then we can reset the rob. 
        else if(flush_br && (rob_q_read_data.data_pkt.d_mem_rmask == '0 || (rob_q_read_data.data_pkt.d_mem_wmask == '0))) begin
            reset_rob = '1;
        end 
        else if ((rob_q_read_data.data_pkt.d_mem_rmask != '0) && (rob_q_read_data.data_pkt.d_mem_addr == store_buf_addr) && ((store_buf_valid & rob_q_read_data.data_pkt.d_mem_rmask) == rob_q_read_data.data_pkt.d_mem_rmask) && (rob_q_read_data.data_pkt.mask_ready != '0) && (!rob_q_empty) && (write_pkt.store_busy)) begin
            buf_resp ='1;
            // d_mem_rmask = rob_q_read_data.data_pkt.d_mem_rmask;
            // d_mem_addr = rob_q_read_data.data_pkt.d_mem_addr;
            
        end
        // iii. if we request memory and our rob isn't reset, then we have to set dmem_signals and wait for d_mem_resp.
        else if((rob_q_read_data.data_pkt.d_mem_rmask != '0) && (rob_q_read_data.data_pkt.mask_ready != '0) && (!rob_q_empty) && (!write_pkt.store_busy)) begin 
            // TODO: send request logic 
            d_mem_rmask = rob_q_read_data.data_pkt.d_mem_rmask;
            d_mem_addr = rob_q_read_data.data_pkt.d_mem_addr;
        end
        // iv. write request.
        // else if ((rob_q_read_data.data_pkt.d_mem_wmask == '1) && (rob_q_read_data.data_pkt.mask_ready != '0) && (!rob_q_empty) && (!write_pkt.store_busy)) begin
        //     d_mem_wmask = rob_q_read_data.data_pkt.d_mem_wmask;
        //     d_mem_wdata = rob_q_read_data.data_pkt.d_mem_wdata;
        //     d_mem_addr = rob_q_read_data.data_pkt.d_mem_addr;
        //     store_busy_next = '1;
        //     update_write_pkt = '1;
        //     // update_write_busy = '1;
        // end
        else if ((rob_q_read_data.data_pkt.d_mem_wmask != '0) && (rob_q_read_data.data_pkt.mask_ready != '0) && (!rob_q_empty) && (!write_pkt.store_busy)) begin
            d_mem_wmask = rob_q_read_data.data_pkt.d_mem_wmask;
            d_mem_wdata = rob_q_read_data.data_pkt.d_mem_wdata;
            d_mem_addr = rob_q_read_data.data_pkt.d_mem_addr;
            if (rob_q_read_data.data_pkt.d_mem_addr != store_buf_addr) begin
                store_busy_next = '1;
                update_write_pkt = rob_q_read_data.data_pkt.d_mem_wmask;
            end
            else if (rob_q_read_data.data_pkt.d_mem_addr == store_buf_addr) begin
                store_busy_next = '1;
                update_write_pkt = store_buf_valid | rob_q_read_data.data_pkt.d_mem_wmask;
            end


            // if (rob_q_read_data.data_pkt.d_mem_addr == store_buf_addr)
            //     rst_store_buf = '1;
        end

    // -----------------------------------------------------------------------------------------------------------------

    // 3. RECIEVING DMEM DATA ------------------------------------------------------------------------------------------
        if(buf_resp) begin
            if (!rob_q_empty) begin
                rob_q_deq = '1;
                rob_commit = '1;
                wb_cm = rob_q_dout;

                wb_cm.data_pkt.mask_ready = '0;

                unique case (rob_q_read_data.data_pkt.d_mem_rmask) 
                    4'b0000 : wb_cm.data_pkt.d_mem_rdata = 32'h00000000;  // No bytes selected
                    4'b0001 : wb_cm.data_pkt.d_mem_rdata = {24'h000000, store_buf_data[7:0]  | 8'h00} ;  // Byte 0
                    4'b0010 : wb_cm.data_pkt.d_mem_rdata = {16'h0000, store_buf_data[15:8]  | 8'h00, 8'h00} ;  // Byte 1
                    4'b0100 : wb_cm.data_pkt.d_mem_rdata = {8'h00, store_buf_data[23:16]  | 8'h00, 16'h0000} ;  // Byte 2
                    4'b1000 : wb_cm.data_pkt.d_mem_rdata = {store_buf_data[31:24]  | 8'h00, 24'h000000}  ;  // Byte 3
                    4'b0011 : wb_cm.data_pkt.d_mem_rdata = {16'h0000, store_buf_data[15:0]  | 16'h0000} ;  // Halfword (Bytes 0-1)
                    4'b1100 : wb_cm.data_pkt.d_mem_rdata = {store_buf_data[31:16]  | 16'h0000, 16'h0000} ;  // Halfword (Bytes 2-3)
                    4'b0110 : wb_cm.data_pkt.d_mem_rdata = {8'h00, store_buf_data[23:8]  | 16'h0000, 8'h00} ;  // Halfword (Bytes 2-3)
                    4'b0111 : wb_cm.data_pkt.d_mem_rdata = {8'h00, store_buf_data[23:0] | 24'h000000}  ;
                    4'b1110 : wb_cm.data_pkt.d_mem_rdata = {store_buf_data[31:8] | 24'h000000, 8'h00} ;
                    4'b1111 : wb_cm.data_pkt.d_mem_rdata = store_buf_data;  // Full word (Bytes 0-3)
                    default : wb_cm.data_pkt.d_mem_rdata = 32'hBABECAFE;  // Shouldn't happen, but default to 0
                endcase

                // check if it rd isn't x0, if not, set rd_data.
                if (rob_q_read_data.instr_pkt.i_use_rd) begin
                    wb_cm.instr_pkt.rd_valid = '1;
                    unique case (rob_q_read_data.instr_pkt.i_funct3)
                            load_f3_lb : wb_cm.instr_pkt.rd_data = ({{24{store_buf_data[7 +8 *(rob_q_read_data.data_pkt.mem_shift[1:0])]}}, store_buf_data[8 *(rob_q_read_data.data_pkt.mem_shift[1:0]) +: 8 ]}) ;
                            load_f3_lbu: wb_cm.instr_pkt.rd_data = ({{24{1'b0}}                          , store_buf_data[8 *(rob_q_read_data.data_pkt.mem_shift[1:0]) +: 8 ]}); 
                            load_f3_lh : wb_cm.instr_pkt.rd_data = ({{16{store_buf_data[15+16*rob_q_read_data.data_pkt.mem_shift[1]  ]}}, store_buf_data[16*rob_q_read_data.data_pkt.mem_shift[1]   +: 16]}); 
                            load_f3_lhu: wb_cm.instr_pkt.rd_data = {{16{1'b0}}                          , store_buf_data[16*rob_q_read_data.data_pkt.mem_shift[1]   +: 16]}; 
                            load_f3_lw : wb_cm.instr_pkt.rd_data = store_buf_data ;
                            default    : wb_cm.instr_pkt.rd_data = 32'hBABECAFE;
                    endcase
                end
                else begin
                    // invalidate rd == x0.
                    wb_cm.instr_pkt.rd_valid = '0;
                    wb_cm.instr_pkt.rd_data = '0;
                end
                rob_out = wb_cm;// CHECK WITH MOHANED
            end 
        end

        else 
        if((rob_q_read_data.data_pkt.d_mem_wmask != '0) && (rob_q_read_data.data_pkt.mask_ready != '0) && (!rob_q_empty) && (!write_pkt.store_busy) && (flush_br == 0)) begin
            if (!rob_q_empty) begin
                rob_q_deq = '1;
                rob_commit = '1;

                wb_cm = rob_q_dout;

                wb_cm.data_pkt.mask_ready = '0;
                rob_out = wb_cm; // CHECK WITH MOHANED
            end
        end
        else 
        if(d_mem_resp_reg && ((rob_q_read_data.data_pkt.d_mem_rmask != '0) || (rob_q_read_data.data_pkt.d_mem_wmask != '0)) && (!write_pkt.store_busy)) begin


            // i. if we don't flush, then just dequeue normally and deal with the incoming data
            if (!rob_q_empty) begin
                rob_q_deq = '1;
                rob_commit = '1;
                wb_cm = rob_q_dout;

                wb_cm.data_pkt.mask_ready = '0;
                d_mem_rmask = '0;
                d_mem_wmask = '0;

                unique case (rob_q_read_data.data_pkt.d_mem_rmask) 
                    4'b0000 : wb_cm.data_pkt.d_mem_rdata = 32'h00000000;  // No bytes selected
                    4'b0001 : wb_cm.data_pkt.d_mem_rdata = {24'h000000, d_mem_rdata_reg[7:0]  | 8'h00} ;  // Byte 0
                    4'b0010 : wb_cm.data_pkt.d_mem_rdata = {16'h0000, d_mem_rdata_reg[15:8]  | 8'h00, 8'h00} ;  // Byte 1
                    4'b0100 : wb_cm.data_pkt.d_mem_rdata = {8'h00, d_mem_rdata_reg[23:16]  | 8'h00, 16'h0000} ;  // Byte 2
                    4'b1000 : wb_cm.data_pkt.d_mem_rdata = {d_mem_rdata_reg[31:24]  | 8'h00, 24'h000000}  ;  // Byte 3
                    4'b0011 : wb_cm.data_pkt.d_mem_rdata = {16'h0000, d_mem_rdata_reg[15:0]  | 16'h0000} ;  // Halfword (Bytes 0-1)
                    4'b1100 : wb_cm.data_pkt.d_mem_rdata = {d_mem_rdata_reg[31:16]  | 16'h0000, 16'h0000} ;  // Halfword (Bytes 2-3)
                    4'b0110 : wb_cm.data_pkt.d_mem_rdata = {8'h00, d_mem_rdata_reg[23:8]  | 16'h0000, 8'h00} ;  // Halfword (Bytes 2-3)
                    4'b0111 : wb_cm.data_pkt.d_mem_rdata = {8'h00, d_mem_rdata_reg[23:0] | 24'h000000}  ;
                    4'b1110 : wb_cm.data_pkt.d_mem_rdata = {d_mem_rdata_reg[31:8] | 24'h000000, 8'h00} ;
                    4'b1111 : wb_cm.data_pkt.d_mem_rdata = d_mem_rdata_reg;  // Full word (Bytes 0-3)
                    default : wb_cm.data_pkt.d_mem_rdata = 32'h00000000;  // Shouldn't happen, but default to 0
                endcase

                // check if it rd isn't x0, if not, set rd_data.
                if (rob_q_read_data.instr_pkt.i_use_rd) begin
                    wb_cm.instr_pkt.rd_valid = '1;
                    unique case (rob_q_read_data.instr_pkt.i_funct3)
                            load_f3_lb : wb_cm.instr_pkt.rd_data = ({{24{d_mem_rdata_reg[7 +8 *(rob_q_read_data.data_pkt.mem_shift[1:0])]}}, d_mem_rdata_reg[8 *(rob_q_read_data.data_pkt.mem_shift[1:0]) +: 8 ]}) ;
                            load_f3_lbu: wb_cm.instr_pkt.rd_data = ({{24{1'b0}}                          , d_mem_rdata_reg[8 *(rob_q_read_data.data_pkt.mem_shift[1:0]) +: 8 ]}); 
                            load_f3_lh : wb_cm.instr_pkt.rd_data = ({{16{d_mem_rdata_reg[15+16*rob_q_read_data.data_pkt.mem_shift[1]  ]}}, d_mem_rdata_reg[16*rob_q_read_data.data_pkt.mem_shift[1]   +: 16]}); 
                            load_f3_lhu: wb_cm.instr_pkt.rd_data = {{16{1'b0}}                          , d_mem_rdata_reg[16*rob_q_read_data.data_pkt.mem_shift[1]   +: 16]}; 
                            load_f3_lw : wb_cm.instr_pkt.rd_data = d_mem_rdata_reg ;
                            default    : wb_cm.instr_pkt.rd_data = 32'h00000000;
                    endcase
                end
                else begin
                    // invalidate rd == x0.
                    wb_cm.instr_pkt.rd_valid = '0;
                    wb_cm.instr_pkt.rd_data = '0;
                end

                // default rob_out.
                rob_out = wb_cm;
            end 
        end
    // -----------------------------------------------------------------------------------------------------------------

    // 4. CHECK IF HEAD IS DONE ----------------------------------------------------------------------------------------

        // if head is done and we aren't flushing, then recieve it.
        if (rob_q_read_data.status && (flush_br == 0)) begin 
            if (!rob_q_empty) begin
                rob_q_deq = '1;
                rob_commit = '1;
                rob_out = rob_q_dout;
                wb_cm = rob_out;
            end 
        end

    // -----------------------------------------------------------------------------------------------------------------

    // 5. WRITING INTO THE ROB FROM DISPATCH ---------------------------------------------------------------------------
    
        // if dispatch packet is valid and we aren't flushing, then recieve it.
        // if (dp_iss.instr_pkt.i_valid && !flush_br && ~rs_full) begin
        if (!rob_q_full && ~rs_full && dp_iss.instr_pkt.i_valid) begin
            rob_q_enq = '1;
            rob_q_din.v = '1; 
            rob_q_din.status = '0; 
            
            // stays the same after dispatch.
            rob_q_din.instr_pkt.order       = dp_iss.instr_pkt.order;
            rob_q_din.instr_pkt.i_valid     = dp_iss.instr_pkt.i_valid;
            rob_q_din.instr_pkt.i_addr      = dp_iss.instr_pkt.i_addr;
            rob_q_din.instr_pkt.i_instr     = dp_iss.instr_pkt.i_instr;
            rob_q_din.instr_pkt.i_funct3    = dp_iss.instr_pkt.i_funct3;
            rob_q_din.instr_pkt.i_use_rd    = dp_iss.instr_pkt.i_use_rd;
            rob_q_din.instr_pkt.br_pred     = dp_iss.instr_pkt.br_pred;
            rob_q_din.instr_pkt.br_pht_gs_cntr = dp_iss.instr_pkt.br_pht_gs_cntr;
            rob_q_din.instr_pkt.br_pht_bi_cntr = dp_iss.instr_pkt.br_pht_bi_cntr;
            rob_q_din.instr_pkt.br_model_cntr = dp_iss.instr_pkt.br_model_cntr;
            rob_q_din.instr_pkt.br_ghr_idx  = dp_iss.instr_pkt.br_ghr_idx;
            rob_q_din.instr_pkt.i_is_jump   = dp_iss.instr_pkt.i_is_jump;
            rob_q_din.instr_pkt.i_is_jal    = dp_iss.instr_pkt.i_is_jal;
            rob_q_din.instr_pkt.br_pred_mode= dp_iss.instr_pkt.br_pred_mode;
            rob_q_din.instr_pkt.func_unit   = dp_iss.instr_pkt.func_unit;
            rob_q_din.instr_pkt.rd_aaddr    = dp_iss.instr_pkt.rd_aaddr;
            rob_q_din.instr_pkt.rd_paddr    = dp_iss.instr_pkt.rd_paddr;
            rob_q_din.instr_pkt.rs1_aaddr   = dp_iss.instr_pkt.rs1_aaddr;
            rob_q_din.instr_pkt.rs1_paddr   = dp_iss.instr_pkt.rs1_paddr;
            rob_q_din.instr_pkt.rs2_aaddr   = dp_iss.instr_pkt.rs2_aaddr;
            rob_q_din.instr_pkt.rs2_paddr   = dp_iss.instr_pkt.rs2_paddr;

            // changes after dispatch.
            rob_q_din.instr_pkt.i_addr_next = dp_iss.instr_pkt.i_addr_next; // on branch
            rob_q_din.instr_pkt.br_en       = dp_iss.instr_pkt.br_en;
            rob_q_din.instr_pkt.br_result   = dp_iss.instr_pkt.br_result;
            rob_q_din.instr_pkt.rd_valid    = '0;
            rob_q_din.instr_pkt.rd_data     = '0;
            rob_q_din.instr_pkt.rs1_data    = '0;
            rob_q_din.instr_pkt.rs2_data    = '0;
            rob_q_din.data_pkt    = '0;
        end

    // -----------------------------------------------------------------------------------------------------------------

    end
    
    queue_rob #(
        .WIDTH(ROB_Q_WIDTH),
        .DEPTH(ROB_Q_DEPTH)
    ) rob_q (
        .clk        (clk),
        .rst        (rst),
        .rst_head_tail (reset_rob),

        .enqueue    (rob_q_enq),
        .dequeue    (rob_q_deq),
        .data_in    (rob_q_din),

        .read_idx   (rob_q_read_idx),
        .read_data  (rob_q_read_data),
        
        .write_en   (rob_q_write_en),
        .write_idx  (rob_q_write_idx),
        .write_data_read(rob_q_write_data_read),
        .write_data (rob_q_write_data),

        .din_idx    (rob_index),            // output into dispatch
        .dout_idx   (rob_dout_idx),

        .full       (rob_q_full),
        .empty      (rob_q_empty),
        .data_out   (rob_q_dout)
    );

endmodule : wb_stage_i