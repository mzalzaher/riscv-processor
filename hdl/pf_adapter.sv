module pf_adapter_i
(
    input clk,
    input rst, 

    output logic dfp_resp, 
    output logic [255:0] dfp_rdata,
    input logic [63:0] bmem_rdata,
    input logic bmem_rvalid
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


// state logic 
always_ff @(posedge clk) begin
    if (rst) begin
        state <= s_read0;
        dfp_rdata <= '0;
        dfp_resp <= '0;
    end else begin
        state <= state_next;
        dfp_rdata <= dfp_rdata_next;
        dfp_resp <= dfp_resp_next;
    end
end

always_comb begin
    // default signals
    dfp_resp_next = '0;
    state_next = state;
    dfp_rdata_next = dfp_rdata;
    unique case (state)
        s_read0: begin
            if(bmem_rvalid) begin
                dfp_rdata_next[63:0] = bmem_rdata;
                state_next = s_read1;
            end 
        end
        s_read1: begin
            dfp_rdata_next[127:64] = bmem_rdata;
            state_next = s_read2;
        end
        s_read2: begin
            dfp_rdata_next[191:128] = bmem_rdata;
            state_next = s_read3;
        end
        s_read3: begin
            // adp_busy = '1;
            dfp_rdata_next[255:192] = bmem_rdata;
            dfp_resp_next = '1;
            state_next = s_read0;
        end
        default: begin
            state_next = s_read0;
            dfp_rdata_next = 'X;
        end
    endcase
end

endmodule : pf_adapter_i
