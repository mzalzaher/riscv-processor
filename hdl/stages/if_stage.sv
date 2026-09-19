module if_stage_i
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic   [31:0]  pc,
    input   logic   [63:0]  order,

    input   logic   [31:0]  imem_rdata,
    input   logic           imem_resp,

    input   logic           flush,

    input   logic           stall_fetch_deq,
    output  logic           stall_fetch_enq,

    output  if_id_t         if_id
);      // FETCH

    logic   enqueue;
    logic	dequeue;
    logic   full;
    logic   empty;
    if_id_t   if_data_in;
    if_id_t   if_data_out;
    if_id_t   prev_data_out;

    always_ff @ (posedge clk) begin
        if(rst || flush)
            prev_data_out <= '0;
        else if(dequeue)
            prev_data_out <= if_data_out;
        else if(empty && ~stall_fetch_deq)
            prev_data_out <= '0;
    end

    always_comb begin
        enqueue     = '0;
        dequeue     = '0;
        if_id = '0;
        if_data_in = '0;
        stall_fetch_enq = '0;
        if (full && imem_resp) // handle case where queue is full & received next instr from imem
            stall_fetch_enq = '1;
        
        if (flush) begin
            // inst queue empty and imem hasnt responded yet => stall
            if_id.valid = '0;
        end else begin
            // ENQ
            if (imem_resp && ~full) begin 
                enqueue = '1;
                if_data_in.valid = '1;
                if_data_in.order = order;
                if_data_in.pc    = pc;
                if_data_in.inst  = imem_rdata;
            end
            // DEQ
            if (!(stall_fetch_deq) && ~flush) begin
                if (!empty || (empty && enqueue)) begin
                    dequeue = '1;
                    if_id = if_data_out;
                end
            end 
            else if (stall_fetch_deq) begin
                if_id = prev_data_out;
            end else 
                if_id = '0;
        end
    end

    logic   [INST_IDX_WIDTH-1:0]    temp_din_idx;
    logic   [INST_IDX_WIDTH-1:0]    temp_dout_idx;
    logic   [INST_Q_WIDTH-1:0]      temp_read_data;
    queue_sync_i #(.WIDTH(INST_Q_WIDTH), .DEPTH(INST_Q_DEPTH)) queue (
        .clk        (clk),
        .rst        (rst),
        .rst_head_tail (flush),

        .enqueue    (enqueue),
        .dequeue    (dequeue),
        .data_in    (if_data_in),
        .din_idx    (temp_din_idx),

        .read_idx   ('0),
        .read_data  (temp_read_data),

        .write_en   ('0),
        .write_idx  ('0),
        .write_data ('0),

        .full       (full),
        .empty      (empty),
        .data_out   (if_data_out),
        .dout_idx   (temp_dout_idx)
    );

endmodule : if_stage_i
