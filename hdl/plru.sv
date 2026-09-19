
module plru_replace 
import rv32i_types::*;#(
    parameter NUM_WAYS = NUM_WAYS_I,
    localparam WAYS_BITS = log2(NUM_WAYS)
)(
    input logic [NUM_WAYS - 2:0]    plru,
    output logic [NUM_WAYS - 1:0]   way_to_replace
);

    localparam integer unsigned WAY_IDX_W = (NUM_WAYS > 1) ? log2(NUM_WAYS) : 1;


    function automatic logic [WAY_IDX_W-1:0] sel_plru_idx
        (input logic [NUM_WAYS-2:0] bits);
        integer unsigned idx    = 0;  
        integer unsigned offset = 0;
        integer unsigned size   = NUM_WAYS;

        while (size > 1) begin
            integer unsigned half = size >> 1;
            if (bits[idx] == 1'b0) begin
                idx    = 2*idx + 2; 
                offset = offset + half;
            end else begin
                idx    = 2*idx + 1;           
            end
            size = half;
        end
        return unsigned'(WAY_IDX_W'(offset));         
    endfunction

    logic [WAY_IDX_W-1:0] victim_idx;

    assign victim_idx = sel_plru_idx(plru);

    always_comb begin
        way_to_replace            = '0;
        way_to_replace[victim_idx] = 1'b1;
    end
endmodule




module plru_updater 
import rv32i_types::*;#(    
    parameter NUM_WAYS = NUM_WAYS_I,
    localparam WAYS_BITS = log2(NUM_WAYS)

)(
    input logic [NUM_WAYS - 2:0]    plru,
    input logic [WAYS_BITS - 1:0]    way_hit_idx, 
    output logic [NUM_WAYS - 2:0]   new_plru
);

    function automatic logic [NUM_WAYS-2:0] update_plru
        (input logic [NUM_WAYS-2:0] bits,
         input logic [WAYS_BITS-1:0]    hit_idx);

        logic [NUM_WAYS-2:0] res;
        integer unsigned         idx, size, way, half;

        res  = bits;
        idx  = 0;         
        size = NUM_WAYS;
        way  = integer'(hit_idx);

        while (size > 1) begin
            half = size >> 1;
            if (way < half) begin

                res[idx] = 1'b0;
                idx      = 2*idx + 1;      
            end
            else begin

                res[idx] = 1'b1;
                idx      = 2*idx + 2;       
                way      = way - half;      
            end
            size = half;
        end
        return res;
    endfunction

    assign new_plru = update_plru(plru, way_hit_idx);

endmodule
