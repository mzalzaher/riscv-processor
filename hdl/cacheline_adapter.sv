module cacheline_adapter_i
(
    input clk,
    input rst, 

    input logic     arb_valid,
    output logic    adp_busy,
    output logic    read_sent,
    // stream buffer
    input  logic           i_stream_rvalid,
    input  logic   [255:0] i_stream_buf_data,

    // cache signals
    input logic [31:0] dfp_addr,
    input logic dfp_read,
    input logic dfp_write,
    input logic [255:0] dfp_wdata,
    output logic dfp_resp, // modify in order for cache to change states
    output logic [255:0] dfp_rdata,
    // dram signals
    output logic [31:0] bmem_addr,
    output logic bmem_read,
    output logic bmem_write,
    input logic [63:0] bmem_rdata,
    output logic [63:0] bmem_wdata,
    input logic bmem_rvalid,
    input logic other_adp_busy
    // [31:0] bmem_raddr ???
    // input logic bmem_ready,
);

logic [255:0] dfp_rdata_next;
logic dfp_resp_next;
logic [31:0] bmem_addr_next;
logic bmem_read_next;
logic bmem_write_next;
logic adp_busy_next;

enum integer unsigned {
    s_idle,
    s_read0,
    s_read1,
    s_read2,
    s_read3,
    s_read4,
    s_write0,
    s_write1,
    s_write2,
    s_write3,
    s_write4,
    s_read_busy,
    s_read_valid
} state, state_next;

logic other_adp_busy_reg;

always_ff @(posedge clk) begin
    other_adp_busy_reg <= other_adp_busy;
end

// state logic 
always_ff @(posedge clk) begin
    if (rst) begin
        state <= s_idle;
        dfp_rdata <= '0;
        dfp_resp <= '0;
        bmem_addr <= '0;
        bmem_read <= '0;
        bmem_write <= '0;
        // adp_busy <= '0;
    end else begin
        state <= state_next;
        dfp_rdata <= dfp_rdata_next;
        dfp_resp <= dfp_resp_next;
        bmem_addr <= bmem_addr_next;
        bmem_read <= bmem_read_next;
        bmem_write <= bmem_write_next;
        // adp_busy <= adp_busy_next;
    end
end

always_comb begin
    // default signals
    // adp_busy_next = adp_busy;
    read_sent = '0;
    adp_busy = '0;
    bmem_read_next = bmem_read;
    bmem_write_next = bmem_write;
    bmem_addr_next = bmem_addr;
    dfp_resp_next = '0;
    bmem_wdata = 'X;
    state_next = state;
    dfp_rdata_next = dfp_rdata;
    // adp_busy = bmem_rvalid;
    unique case (state)
        // wait for a read or write request from our cache.
        s_idle: begin
            if(i_stream_rvalid) begin
                // adp_busy = '1;
                dfp_rdata_next = i_stream_buf_data;
                dfp_resp_next = '1;
                state_next = s_idle;
            end
            else if(dfp_read && ~other_adp_busy) begin
                // adp_busy = '1;
                bmem_read_next = '1;
                bmem_addr_next = dfp_addr;
                state_next = s_read0;
            end
            else if(dfp_write && ~other_adp_busy) begin
                // adp_busy = '1;
                bmem_write_next = '1;
                state_next = s_write0;
                bmem_addr_next = dfp_addr;
            end
        end
        // read logic, 4 cycles, wait for bmem_rvalid to recieve 4 bursts of bmem_rdata.
        s_read0: begin

            if(~other_adp_busy)
                bmem_read_next = '0;

            if(other_adp_busy) begin
                state_next = s_read_busy;
                bmem_read_next = '0;
            end

            if(i_stream_rvalid) begin
                // adp_busy = '1;
                dfp_rdata_next = i_stream_buf_data;
                dfp_resp_next = '1;
                state_next = s_idle;
            end else if(bmem_rvalid) begin
                bmem_read_next = '0;
                adp_busy = '1;
                dfp_rdata_next[63:0] = bmem_rdata;
                state_next = s_read1;
            end 

        end
        s_read_busy: begin
            read_sent = '1;
            if(~other_adp_busy) begin
                state_next = s_read0;
            end else
                bmem_read_next = '1;
            if(bmem_rvalid) begin
                bmem_read_next = '0;
                adp_busy = '1;
                dfp_rdata_next[63:0] = bmem_rdata;
                state_next = s_read1;
            end
        end
        s_read1: begin
            adp_busy = '1;
            dfp_rdata_next[127:64] = bmem_rdata;
            state_next = s_read2;
        end
        s_read2: begin
            adp_busy = '1;
            dfp_rdata_next[191:128] = bmem_rdata;
            state_next = s_read3;
        end
        s_read3: begin
            adp_busy = '1;
            dfp_rdata_next[255:192] = bmem_rdata;
            dfp_resp_next = '1;
            state_next = s_read4;
        end
        s_read4: begin
            state_next = s_idle;
        end
        // write logic, 4 cycles, send dfp_wdata in bursts of 64 bits.
        s_write0: begin
            if(arb_valid) begin
                bmem_write_next = '1;
                // adp_busy = '1;
                bmem_wdata = dfp_wdata[63:0];
                state_next = s_write1;
            end
        end
        s_write1: begin
            // adp_busy = '1;
            bmem_wdata = dfp_wdata[127:64];
            state_next = s_write2;
        end
        s_write2: begin
            // adp_busy = '1;
            bmem_wdata = dfp_wdata[191:128];
            state_next = s_write3;
        end
        s_write3: begin
            // adp_busy = '1;
            bmem_wdata = dfp_wdata[255:192];
            bmem_write_next = '0;
            dfp_resp_next = '1;
            state_next = s_write4;
        end
        s_write4: begin
            adp_busy = '0;
            bmem_write_next = '0;
            state_next = s_idle;
        end
        default: begin
            state_next = s_idle;
            dfp_rdata_next = 'X;
        end
    endcase
end

endmodule : cacheline_adapter_i
