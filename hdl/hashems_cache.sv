module cache import 
rv32i_types::*;#(
    parameter NUM_WORDS = NUM_WORDS_D,
    parameter NUM_WAYS = NUM_WAYS_D,

    localparam INDEX_BITS = log2(NUM_WORDS),
    localparam TAG_BITS = 27 - INDEX_BITS,
    localparam WAYS_BITS = log2(NUM_WAYS)
)(
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);


    enum integer unsigned { s_reset, 
                            s_idle, 
                            s_hit, 
                            s_wback,
                            s_alloc } state, state_next, state_prev;


    //input regs
    logic   [31:0]  ufp_addr_reg;
    logic   [3:0]   ufp_rmask_reg;
    logic   [3:0]   ufp_wmask_reg;
    logic   [31:0]  ufp_wdata_reg;
    logic   [255:0] dfp_rdata_reg;
    logic           dfp_resp_reg;

    logic      [INDEX_BITS-1:0]  index;   
    // logic      [31:0]   selected_word;
    logic      [2:0]    word_offset;
    // logic      [1:0]    way_to_replace_idx;
    // logic      [2:0]    lru_updater_A;
    // logic      [2:0]    lru_updater_B;
    logic [NUM_WAYS - 1:0]         csb0;
    logic [NUM_WAYS - 1:0]         way_to_replace;
    logic [NUM_WAYS - 1:0]         way_hit;
    logic [NUM_WAYS - 1:0]         way_dirty;
    logic      [31:0]   data_dout0_word;


    logic [NUM_WAYS-1:0]             data_web0;
    logic      [256-1:0]    data_din0;
    logic [NUM_WAYS-1:0][256-1:0]    data_dout0, data_dout1;
    logic      [31:0]        data_wmask;

    logic [NUM_WAYS-1:0]         tag_web0;
    logic      [TAG_BITS-1:0] tag_din0;
    logic [NUM_WAYS-1:0][TAG_BITS-1:0] tag_dout0;

    logic [NUM_WAYS-1:0]         valid_web0;
    logic               valid_din0;
    logic [NUM_WAYS-1:0]         valid_dout0;

    logic [NUM_WAYS-1:0]         dirty_web0;
    logic               dirty_din0;
    logic [NUM_WAYS-1:0]         dirty_dout0;

    logic                   lru_csb0;
    logic                   lru_web0;
    logic [NUM_WAYS-2:0]    lru_din0;
    logic [NUM_WAYS-2:0]    lru_dout0;


    logic      [27-1:0]     line_buf_tag_index;
    logic      [256-1:0]    line_buf_data;
    logic      [31:0]       line_buf_data_word;
    logic [NUM_WAYS -1:0]      way_hit_reg;

    // logic [NUM_WAYS - 1:0]    plru;
    // logic [NUM_WAYS - 1:0]    way_to_replace_test;
    logic [NUM_WAYS -2:0] new_plru;
    logic [WAYS_BITS -1:0] way_hit_idx;
    // logic [1:0] way_hit_idx;

    function automatic logic [WAYS_BITS-1:0] onehot_to_idx
        (input logic [NUM_WAYS-1:0] v);
        logic [WAYS_BITS-1:0] idx;
        idx = '0;
        for (integer unsigned i = 0; i < NUM_WAYS; i++)
            if (v[i]) 
                idx = unsigned'(WAYS_BITS'(i));
        return idx;
    endfunction

    generate for (genvar i = 0; i < NUM_WAYS; i++) begin : arrays
        d_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (csb0[i]),
            .web0       (data_web0[i]),
            .wmask0     (data_wmask),
            .addr0      (index),
            .din0       (data_din0),
            .dout0      (data_dout0[i])
            // .clk1       (clk),
            // .csb1       ('1),
            // .web1       ('1),
            // .wmask1     ('0),
            // .addr1      ('x),
            // .din1       ('x),
            // .dout1      (data_dout1[i])
        );
        d_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (csb0[i]),
            .web0       (tag_web0[i]),
            .addr0      (index),
            .din0       (tag_din0),
            .dout0      (tag_dout0[i])
            // .clk1       (clk),
            // .csb1       ('1),
            // .web1       ('1),
            // .addr1      ('x),
            // .din1       ('x),
            // .dout1      (tag_dout1[i])
        );
        sp_ff_array #(.S_INDEX(INDEX_BITS)) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (csb0[i]),
            .web0       (valid_web0[i]),
            .addr0      (index),
            .din0       (valid_din0),
            .dout0      (valid_dout0[i])
        );
        sp_ff_array #(.S_INDEX(INDEX_BITS)) dirty_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (csb0[i]),
            .web0       (dirty_web0[i]),
            .addr0      (index),
            .din0       (dirty_din0),
            .dout0      (dirty_dout0[i])
        );
    end endgenerate

    sp_ff_array #(
        .S_INDEX(INDEX_BITS),
        .WIDTH      (NUM_WAYS - 1)
    ) lru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (lru_csb0),
        .web0       (lru_web0),
        .addr0      (index),
        .din0       (lru_din0),
        .dout0      (lru_dout0)
    );

    plru_replace  #(.NUM_WAYS(NUM_WAYS)) replacer(
        .plru(lru_dout0),
        .way_to_replace(way_to_replace)
    );

    plru_updater  #(.NUM_WAYS(NUM_WAYS)) updater(
        .plru(lru_dout0),
        .way_hit_idx(way_hit_idx),
        .new_plru(new_plru)
    );

    always_comb begin
        if (way_hit != '0)
            way_hit_idx = onehot_to_idx(way_hit);
        else 
            way_hit_idx = 'x;
    end

    always_ff @(posedge clk) begin
        ufp_addr_reg <= '0; 
        ufp_wdata_reg <= '0;

        ufp_rmask_reg <= ufp_rmask; 
        ufp_wmask_reg <= ufp_wmask; 
        if (((ufp_rmask != '0 ) || (ufp_wmask != '0)) && !ufp_resp) begin
            ufp_addr_reg <= ufp_addr; 
            ufp_wdata_reg <= ufp_wdata;
        end
        dfp_rdata_reg <= dfp_rdata;
        // dfp_resp_reg <= dfp_resp;
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= s_reset;
            way_hit_reg <= '0;
        end
        else begin
            state <= state_next;
            way_hit_reg <= way_hit;
        end
    end


    always_comb begin
        word_offset = ufp_addr_reg[4:2];
        // way_hit = '0;
        // way_dirty = '0;
        data_dout0_word = 'x;
        for (integer i = 0; i < NUM_WAYS; i++) begin
            way_hit[i] = ((valid_dout0[i] == 1) && (tag_dout0[i] == ufp_addr_reg[31:31-TAG_BITS +1])) == 1'b1;
            way_dirty[i] = dirty_dout0[i] == 1'b1;
            if (way_hit[i] == '1)
                data_dout0_word = data_dout0[i][(word_offset * 32) +: 32];
        end 
    end
    // assign way_hit = { ((valid_dout0[3] == 1) && (tag_dout0[3] == ufp_addr_reg[31:9])),
    //                         ((valid_dout0[2] == 1) && (tag_dout0[2] == ufp_addr_reg[31:9])),
    //                         ((valid_dout0[1] == 1) && (tag_dout0[1] == ufp_addr_reg[31:9])),
    //                         ((valid_dout0[0] == 1) && (tag_dout0[0] == ufp_addr_reg[31:9]))};

    // assign way_dirty = {(dirty_dout0[3] == 1'b1),
    //                     (dirty_dout0[2] == 1'b1),
    //                     (dirty_dout0[1] == 1'b1),
    //                     (dirty_dout0[0] == 1'b1)};


    // always_comb begin
    //     case (way_hit)
    //         4'b0001: data_dout0_word = data_dout0[0][(word_offset * 32) +: 32];
    //         4'b0010: data_dout0_word = data_dout0[1][(word_offset * 32) +: 32];
    //         4'b0100: data_dout0_word = data_dout0[2][(word_offset * 32) +: 32];
    //         4'b1000: data_dout0_word = data_dout0[3][(word_offset * 32) +: 32];
    //         default: data_dout0_word = 32'hDEADBEEF; //Should never happen
    //     endcase
    // end
    // // assign data_dout0_word = data_dout0[(word_offset * 32) +: 32];
    assign line_buf_data_word = line_buf_data[(ufp_addr[4:2] * 32) +: 32];

    // always_comb begin
    //     //TODO: FIX update
    //     case (way_hit)
    //         4'b1000: lru_updater_A = 3'b010;
    //         4'b0100: lru_updater_A = 3'b010;
    //         4'b0010: lru_updater_A = 3'b100;
    //         4'b0001: lru_updater_A = 3'b100;
    //         default: lru_updater_A = 3'b111;
    //     endcase
    
    //     case (way_hit)
    //         4'b1000: lru_updater_B = 3'b101;
    //         4'b0100: lru_updater_B = 3'b001;
    //         4'b0010: lru_updater_B = 3'b010;
    //         4'b0001: lru_updater_B = 3'b000;
    //         default: lru_updater_B = 3'b000;
    //     endcase
    // end

    // always_comb begin
    //     unique casez (lru_dout0)
    //         3'b0?0: way_to_replace = 4'b1000; // D
    //         3'b1?0: way_to_replace = 4'b0100; // C
    //         3'b?01: way_to_replace = 4'b0010; // B
    //         3'b?11: way_to_replace = 4'b0001; // A
            
    //     endcase    
    //     unique casez (lru_dout0)
    //         3'b0?0: way_to_replace_idx = 2'd3; // D
    //         3'b1?0: way_to_replace_idx = 2'd2; // C
    //         3'b?01: way_to_replace_idx = 2'd1; // B
    //         3'b?11: way_to_replace_idx = 2'd0; // A
            
    //     endcase    
    // end

    // Line buf setting
    always_ff @(posedge clk) begin
        if (rst) begin
            line_buf_tag_index <= '0;
            line_buf_data <= 'x;
        end
        else if (way_hit != 0 ) begin
            line_buf_tag_index <= ufp_addr_reg[31:5];
            if ((ufp_rmask_reg != 0)) begin
                for (integer i = 0; i < NUM_WAYS; i++) begin
                    if (way_hit[i])
                        line_buf_data <= data_dout0[i];
                end 
                // case (way_hit)
                //     4'b0001:
                //         line_buf_data <= data_dout0[0];
                //     4'b0010:
                //         line_buf_data <= data_dout0[1];
                //     4'b0100:
                //         line_buf_data <= data_dout0[2];
                //     4'b1000:
                //         line_buf_data <= data_dout0[3];
                //     default: //Should never happen
                //         line_buf_data <= 'x;
                // endcase
            end
            else begin
                line_buf_data <= data_din0;
            end
        end
    end

    always_comb begin 
        state_next = state;
        ufp_resp = '0;
        ufp_rdata = 'x;
        
        dfp_addr = 'x;
        dfp_read = '0;
        dfp_write = '0;
        dfp_wdata = 'x;

        csb0 = '1;
        index = 'x;
        data_wmask = 'x;
        data_web0 = '1;
        data_din0 = 'x;
        tag_web0 = '1;
        tag_din0 = 'x;
        valid_web0 = '1;
        valid_din0 = '1;
        dirty_web0 = '1;
        dirty_din0 = 'x;
        lru_csb0 = '1;
        lru_web0 = 1'b1;
        lru_din0 = 'x;
        unique case (state)
            s_reset: begin
                csb0 = '0;

                data_web0 = '0;
                data_din0 = 'x;

                tag_web0 = '0;
                tag_din0 = 'x;

                valid_web0 = '0;
                valid_din0 = '0;

                dirty_web0 = '0;
                dirty_din0 = '0;

                lru_web0 = 1'b0;
                lru_din0 = '0;

                state_next = s_idle;

            end
            s_idle: begin
                ufp_resp = '0;
                if ((ufp_rmask != 0) && (ufp_addr[31:5] == line_buf_tag_index)) begin

                    ufp_rdata = (ufp_rmask[0] ? {24'b0, line_buf_data_word[7:0]}  : 32'b0) |
                                    (ufp_rmask[1] ? {16'b0, line_buf_data_word[15:8], 8'b0} : 32'b0) |
                                    (ufp_rmask[2] ? {8'b0, line_buf_data_word[23:16], 16'b0} : 32'b0) |
                                    (ufp_rmask[3] ? {line_buf_data_word[31:24], 24'b0} : 32'b0);
                    ufp_resp = '1;
                    state_next = s_idle; 
                end
                else if ((ufp_rmask != 0) || (ufp_wmask != 0)) begin
                    csb0 = '0;
                    index = ufp_addr[INDEX_BITS -1 + 5:5];
                    lru_csb0 = '0;
                    
                    state_next = s_hit;
                end
                else begin
                    state_next = s_idle;
                end 

            end
            s_hit: begin
                //HIT
                state_prev = s_hit;
                index = ufp_addr_reg[INDEX_BITS -1 + 5:5];
                if (way_hit != '0) begin
                    if (ufp_rmask_reg != 0)begin
                        csb0 = '1;
                        ufp_rdata = (ufp_rmask_reg[0] ? {24'b0, data_dout0_word[7:0]}  : 32'b0) |
                                    (ufp_rmask_reg[1] ? {16'b0, data_dout0_word[15:8], 8'b0} : 32'b0) |
                                    (ufp_rmask_reg[2] ? {8'b0, data_dout0_word[23:16], 16'b0} : 32'b0) |
                                    (ufp_rmask_reg[3] ? {data_dout0_word[31:24], 24'b0} : 32'b0);
                        data_web0 = '1;
                        data_wmask = 'x;
                        data_din0 = 'x;
                        dirty_web0 = '1;
                        dirty_din0 = 'x;
                    end else if (ufp_wmask_reg != 0) begin
                        csb0 = ~way_hit;
                        ufp_rdata = 'x;
                        data_web0 = ~way_hit;
                        data_wmask = 32'b0;
                        data_wmask[(word_offset * 4) +: 4] = ufp_wmask_reg;
                        data_din0 = '0;
                        for (integer i = 0; i < NUM_WAYS; i++) begin
                            if (way_hit[i])
                                data_din0 = data_dout0[i];
                        end 
                        // case (way_hit)
                        //     4'b0001:
                        //         data_din0 = data_dout0[0];
                        //     4'b0010:
                        //         data_din0 = data_dout0[1];
                        //     4'b0100:
                        //         data_din0 = data_dout0[2];
                        //     4'b1000:
                        //         data_din0 = data_dout0[3];
                        //     default: //Should never happen
                        //         data_din0 = 'x;
                        // endcase
                        // data_din0[(word_offset * 32) +: 32] = ufp_wdata_reg;
                        unique case (ufp_wmask_reg) 
                            4'b0001 : data_din0[(word_offset * 32) +: 8] = ufp_wdata_reg[7:0];  // Byte 0
                            4'b0010 : data_din0[((word_offset * 32) + 8) +: 8] = ufp_wdata_reg[15:8];  // Byte 1
                            4'b0100 : data_din0[((word_offset * 32) + 16) +: 8] = ufp_wdata_reg[23:16];  // Byte 2
                            4'b1000 : data_din0[((word_offset * 32) + 24) +: 8] = ufp_wdata_reg[31:24];  // Byte 3
                            4'b0011 : data_din0[((word_offset * 32)) +: 16] = ufp_wdata_reg[15:0];  // Halfword (Bytes 0-1)
                            4'b1100 : data_din0[((word_offset * 32) + 16) +: 16] = ufp_wdata_reg[31:16];  // Halfword (Bytes 2-3)
                            4'b0110 : data_din0[((word_offset * 32) + 8) +: 16] = ufp_wdata_reg[23:8];  // Halfword (Bytes 2-3)
                            4'b0111 : data_din0[((word_offset * 32)) +: 24] = ufp_wdata_reg[23:0];
                            4'b1110 : data_din0[((word_offset * 32) + 8) +: 24] = ufp_wdata_reg[31:8];
                            4'b1111 : data_din0[(word_offset * 32) +: 32] = ufp_wdata_reg;  // Full word (Bytes 0-3)
                            default : data_din0[(word_offset * 32) +: 32] = '0;  // Shouldn't happen, but default to 0
                        endcase
                        dirty_web0 = ~way_hit;
                        dirty_din0 = '1;
                    end
                    lru_csb0 = '0;
                    lru_din0 = new_plru;//(lru_dout0 & lru_updater_A) | lru_updater_B;
                    lru_web0 = '0;
                    
                    ufp_resp = '1;
                    state_next = s_idle; 
                end
                //DIRTY MISS
                else if ((way_dirty & way_to_replace) != '0) begin
                    ufp_rdata = 'x;
                    csb0 = '1;
                    data_web0 = '1;
                    data_wmask = 'x;
                    data_din0 = 'x;
                    dirty_web0 = '1;
                    dirty_din0 = 'x;
                    lru_csb0 = '1;
                    lru_web0 = '1;
                    lru_din0 = 'x;
                    ufp_resp = '0;
                    state_next = s_wback; 
                end
                //CLEAN MISS
                else begin
                    ufp_rdata = 'x;
                    csb0 = '1;
                    data_web0 = '1;
                    data_wmask = 'x;
                    data_din0 = 'x;
                    dirty_web0 = '1;
                    dirty_din0 = 'x;
                    lru_csb0 = '1;
                    lru_web0 = '1;
                    lru_din0 = 'x;

                    ufp_resp = '0;
                    state_next = s_alloc; 
                end
            end 
            s_wback: begin
                state_prev = s_wback;
                index = ufp_addr_reg[INDEX_BITS -1 + 5:5];
                csb0 = ~way_to_replace;
                dfp_write = '1;
                dfp_addr = {tag_dout0[onehot_to_idx(way_to_replace)], ufp_addr_reg[INDEX_BITS -1 + 5:5], 5'b0};
                dfp_wdata = data_dout0[onehot_to_idx(way_to_replace)];
                if (dfp_resp) begin   
                    state_next = s_alloc;
                end
                else begin       
                    state_next = s_wback;
                end

            end
            s_alloc: begin
                state_prev = s_alloc;
                index = ufp_addr_reg[INDEX_BITS -1 + 5:5];
                dfp_read = '1;
                dfp_addr = {ufp_addr_reg[31:5], 5'b0};

                data_web0 = '1;
                data_wmask = '1;
                data_din0 = dfp_rdata;

                dirty_web0 = '1;
                dirty_din0 = '0;

                valid_web0 = '1;

                tag_web0 = '1;
                tag_din0 = ufp_addr_reg[31:31 - TAG_BITS + 1];
                if (dfp_resp) begin
                    
                    csb0 = ~way_to_replace;
                    data_web0 = ~way_to_replace;
                    dirty_web0 = ~way_to_replace;
                    valid_web0 = ~way_to_replace;
                    tag_web0 = ~way_to_replace;
                    // TA Said turn off but waveform says on
                    dfp_read = '0; 
                    state_next = s_idle;
                end
                else begin
                    state_next = s_alloc;
                end

            end
            default: begin
                state_next = s_idle;
            end
        endcase
    end


endmodule
