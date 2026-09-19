module cache_arbiter_i
import rv32i_types::*;
(
    input clk,
    input rst, 

    // inst cache signals
    input   logic   [31:0]  i_bmem_addr,
    input   logic           i_bmem_read,
    output  logic   [63:0]  i_bmem_rdata,
    output  logic           i_bmem_rvalid,
    output  logic           i_stream_rvalid,
    output  logic   [255:0] i_stream_buf_data,
    input  logic            i_read_sent,

    // data cache signals
    input   logic   [31:0]  d_bmem_addr,
    input   logic           d_bmem_read,
    input   logic           d_bmem_write,
    input   logic   [63:0]  d_bmem_wdata,
    output  logic   [63:0]  d_bmem_rdata,
    output  logic           d_bmem_rvalid,
    output  logic           d_arb_valid,

    // dram signals
    input   logic   [31:0]  bmem_raddr,             // will use to check response is what address.
    input   logic           bmem_rvalid,
    input   logic   [63:0]  bmem_rdata,
    // input   logic           bmem_ready,
    output  logic   [31:0]  out_bmem_addr,
    output  logic           out_bmem_read,
    output  logic           out_bmem_write,
    output  logic   [63:0]  out_bmem_wdata,

    input logic i_adp_busy
    // input logic d_adp_busy
);

logic i_adp_busy_reg;

// STREAM BUFFER PREFETCH
logic pf_read;
logic pf_sent, pf_sent_next;
logic pf_busy;
logic pf_busy_next;
logic stream_reset_next;
logic [26:0] pf_addr, pf_addr_next;
// stream_ent_t stream_buffer;
stream_ent_t [STREAM_Q_DEPTH-1:0] stream_buffer;
// logic [STREAM_IDX_WIDTH:0] stream_idx, stream_idx_next;
logic stream_reset, stream_match;
logic [31:0] sel_base;
logic no_hit, no_hit_next;
// logic  stream_flush, stream_flush_next;
// pf_adapter
logic p_dfp_resp, p_bmem_rvalid;
logic [63:0] p_bmem_rdata;
logic [255:0] p_dfp_rdata;
logic [STREAM_Q_DEPTH - 1:0] stream_buffer_hit, stream_buffer_hit_ready;
logic [STREAM_IDX_WIDTH - 1:0] stream_buf_resp_idx, stream_buf_resp_idx_next, stream_buffer_hit_idx;
logic [255:0] stream_buffer_hit_data; 
logic [STREAM_IDX_WIDTH - 1:0] curr_pf_idx;
logic stream_wait, stream_wait_next;
// logic p_dfp_resp_raddr;
logic stream_buf_recieve_next, stream_buf_recieve;

pf_adapter_i prefetch_adapter(
    .clk        (clk),
    .rst        (rst),

    // .arb_valid    ('0),
    // .adp_busy     (i_adp_busy),
    // .bmem_addr  (i_bmem_addr),
    // .bmem_read  (i_bmem_read),
    // .bmem_write (i_bmem_write),
    // .bmem_wdata (i_bmem_wdata),
    // .bmem_ready(bmem_ready),
    // .bmem_raddr(bmem_raddr),
    .bmem_rdata (p_bmem_rdata),
    .bmem_rvalid(p_bmem_rvalid),
    // .other_adp_busy(d_adp_busy),
    // .dfp_addr   (i_dfp_addr),
    // .dfp_read   (i_dfp_read),
    // .dfp_write  (i_dfp_write),
    .dfp_rdata  (p_dfp_rdata),
    // .dfp_wdata  (i_dfp_wdata),
    .dfp_resp   (p_dfp_resp)
);

enum integer unsigned { pf_reset, 
                        pf_idle,
                        pf_set_addr,
                        pf_hit,
                        pf_wait,
                        pf_posthit,
                        pf_alloc } pf, pf_next;

always_ff @(posedge clk) begin
    i_adp_busy_reg <= i_adp_busy;
    if(rst) begin
        stream_buf_resp_idx <= '0;
        pf <= pf_reset;
        pf_busy <= '0;
        stream_reset <= '0;
        pf_addr <= '0;
        pf_sent <= '0;
        stream_wait <= '0;
        // stream_buf_recieve <= '0;
    end
    else begin
        // stream_buf_recieve <= stream_buf_recieve_next;
        stream_buf_resp_idx <= stream_buf_resp_idx_next;
        pf <= pf_next;
        pf_busy <= pf_busy_next;
        pf_sent <= pf_sent_next;
        stream_reset <= stream_reset_next;
        pf_addr <= pf_addr_next;
        stream_wait <= stream_wait_next;
    end
end

always_ff @(posedge clk) begin
    // stream_buf_recieve <= stream_buf_recieve_next;
    if (rst) begin
        stream_buffer <= '0;
        stream_buf_recieve <= '0;
    end else if (stream_reset) begin
        for (integer i = '0; i < STREAM_Q_DEPTH; i ++) begin
            stream_buffer[i] <= {2'b0, pf_addr + unsigned'(STREAM_IDX_WIDTH'(i)) , 256'b0};
        end
        // UNCOMMENT FOR NEXT LINE PREFETCHER.
        // stream_buffer[0] <= {1'b0, pf_addr, 256'b0};
    end else if(p_dfp_resp && stream_buffer[stream_buf_resp_idx].sent && stream_buf_recieve) begin
        stream_buffer[stream_buf_resp_idx].data <= p_dfp_rdata;
        stream_buffer[stream_buf_resp_idx].v <= '1;
    end
    if(pf_sent) begin
        stream_buffer[curr_pf_idx].sent <= '1;
    end

    if(p_dfp_resp) begin
        stream_buf_recieve <= '0;
    end else begin
        stream_buf_recieve <= stream_buf_recieve_next;
    end
end
always_comb begin
    stream_buffer_hit = '0;
    stream_buffer_hit_ready = '0;
    stream_buffer_hit_data = 256'hDEADBEEF;
    stream_buffer_hit_idx = '0;
    curr_pf_idx = '0;
    for (integer i = '0; i < STREAM_Q_DEPTH; i++) begin
        if(stream_buffer[i].addr == i_bmem_addr[31:5]) begin
            // stream_buffer_hit[i] = 1'b1;
            stream_buffer_hit[i] = stream_buffer[i].sent;
            stream_buffer_hit_idx = unsigned'(STREAM_IDX_WIDTH'(i));
        end
        if(stream_buffer[i].addr == pf_addr) begin
            curr_pf_idx = unsigned'(STREAM_IDX_WIDTH'(i));
        end
    end

    stream_buffer_hit_ready[stream_buffer_hit_idx] = stream_buffer[stream_buffer_hit_idx].v;
    stream_buffer_hit_data = stream_buffer[stream_buffer_hit_idx].data;
end

always_comb begin
    i_stream_rvalid = '0;
    i_stream_buf_data = '0;
    out_bmem_addr   = '0;
    out_bmem_read   = '0;
    out_bmem_wdata  = '0;
    out_bmem_write  = '0;
    d_bmem_rvalid = '0;
    d_bmem_rdata = '0;
    d_arb_valid = '0;
    i_bmem_rvalid = '0;
    i_bmem_rdata = '0;

    // prefetcher:
    // stream_idx_next = '0;
    stream_buf_recieve_next = stream_buf_recieve;
    stream_reset_next = '0;
    stream_match = '0;
    pf_next = pf;
    pf_busy_next = pf_busy;
    pf_addr_next = pf_addr;
    pf_read = '0;
    pf_sent_next = '0;
    p_bmem_rvalid = '0;
    p_bmem_rdata = '0;
    stream_buf_resp_idx_next = stream_buf_resp_idx;
    stream_wait_next = stream_wait;
    unique case (pf)
        pf_reset: begin
            pf_next = pf_alloc;
        end
        // pf_idle: begin
        // end
        pf_alloc: begin
            if(stream_buffer[curr_pf_idx].sent != 1) begin
                pf_read = pf_busy;
                pf_addr_next = pf_addr; 
                pf_next = pf_alloc;
            // pf_busy_next = '1;
                if(pf_sent) begin
                    pf_read = '0;
                    pf_addr_next = pf_addr + 1'b1; 
                    pf_next = pf_alloc;
                end
            end else if (pf_busy && ~stream_reset) begin
                pf_next = pf_wait;
            end else begin
                pf_next = pf_alloc;
            end
        end
        pf_set_addr: begin
            pf_next = pf_alloc;
        end
        pf_wait: begin
            pf_busy_next = '0;
            pf_next = pf_alloc;
        end
        default:
            pf_next = pf;
    endcase

    // 1.   check bmem_raddr and see which instruction it belongs to.
    //      current issue is the bmem_rvalid is don't care.
    if(bmem_rvalid) begin
        for (integer i = '0; i < STREAM_Q_DEPTH; i ++) begin
            if (bmem_raddr == {stream_buffer[i].addr, 5'b0}) begin
                p_bmem_rdata = bmem_rdata;
                p_bmem_rvalid = '1;
                stream_buf_recieve_next = stream_buffer[i].sent;
                stream_buf_resp_idx_next = unsigned'(STREAM_IDX_WIDTH'(i));;
            end
        end

        if((bmem_raddr == d_bmem_addr) && ~p_bmem_rvalid) begin
            d_bmem_rdata  = bmem_rdata;
            d_bmem_rvalid = '1;   
        end else if ((bmem_raddr == i_bmem_addr) && ~p_bmem_rvalid) begin
            i_bmem_rdata  = bmem_rdata;
            i_bmem_rvalid = '1;
        end
    end

    // 2.   if dmem is reading or writing, send dmem request regardless of i_bmem_read
    if((d_bmem_read) && ~i_adp_busy_reg) begin
        out_bmem_addr   = d_bmem_addr;
        out_bmem_read   = d_bmem_read;  // due to adapter logic
    end 
    else if (d_bmem_write) begin
        out_bmem_addr   = d_bmem_addr;
        out_bmem_write  = d_bmem_write;
        out_bmem_wdata  = d_bmem_wdata;
        d_arb_valid     = d_bmem_write; // signals valid write request
    end
    else if((i_bmem_read && (stream_buffer_hit != 0)) || stream_wait) begin 
        if(stream_buffer_hit_ready[stream_buffer_hit_idx]) begin
            i_stream_rvalid = '1;
            i_stream_buf_data = stream_buffer_hit_data;
            stream_wait_next = '0;
        end else begin
            stream_wait_next = '1;
        end
    end
    else if(~i_adp_busy_reg && i_bmem_read && ~i_read_sent) begin 
        // 3.   if only i_bmem_read is reading, send request of i_bmem_read.
        if(stream_buffer_hit == '0) begin
            out_bmem_addr = i_bmem_addr;
            out_bmem_read = i_bmem_read;
            pf_addr_next = i_bmem_addr[31:5] + 1'b1;
            pf_busy_next = '1;
            stream_reset_next = '1;
            stream_wait_next = '0;
        end
    end else if (pf_read) begin
        out_bmem_addr = {pf_addr, 5'b0};
        out_bmem_read = '1;
        pf_sent_next = '1;
    end
end

endmodule : cache_arbiter_i
