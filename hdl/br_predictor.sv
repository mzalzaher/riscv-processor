module br_predictor_i
import rv32i_types::*;
(   
    input   logic           clk,
    input   logic           rst,

    // input from fetch stage
    input   logic           fetch_valid,
    input   logic   [31:0]  fetch_pc,
    
    // output prediction to decode stage
    output  logic   [COUNTER_WIDTH-1:0] pred_pht_gs_counter,   // put in instr_pkt
    output  logic   [COUNTER_WIDTH-1:0] pred_pht_bi_counter,
    output  logic   [GHR_Q_IDX-1:0]     pred_ghr_idx,
    output  logic   [MODEL_COUNTER_WIDTH-1:0] pred_model_counter,
    output  logic           pred,
    output  br_pred_mode_t  pred_br_pred_mode,
    output  logic   [31:0]  pred_pc,
    // pc of original instruction to confirm at decode for debugging

    // br info from pkt
    input   logic           result_valid,
    input   logic           result_pred,
    input   logic           result_taken,
    input   logic   [COUNTER_WIDTH-1:0] result_pht_gs_counter,
    input   logic   [COUNTER_WIDTH-1:0] result_pht_bi_counter,
    input   logic   [GHR_Q_IDX-1:0]     result_ghr_idx,
    input   br_pred_mode_t  result_br_pred_mode,
    input   logic   [MODEL_COUNTER_WIDTH-1:0] result_model_counter,
    input   logic   [31:0]  result_pc

);
    /*  TODO
        - use same valid array for pht and model
        - choose whether to eliminate one valid array or 
            to not update model valid array 
    */


    // goes high if theres an error somewhere (queue full)
    logic           error;
    logic           result_mispredict;

    logic           gshare_mispredict;
    logic           bimodal_mispredict;
    br_pred_mode_t  starting_model;

    logic           en_predict, en_predict_reg;

    logic   [63:0]  n_incorrect_pred;
    logic   [63:0]  n_correct_pred;
    logic   [63:0]  n_taken;
    logic   [63:0]  n_not_taken;
    logic   [63:0]  n_br_predictions;

    logic   [31:0]  fetch_pc_reg;
    logic           fetch_valid_reg;

    // CONFIG to avoid lint warnings
    always_comb begin
        if (STARTING_PRED_MODEL == 1)
            starting_model = GSHARE;
        else
            starting_model = BIMODAL;
    end


// GSHARE
    logic                       pht_gs_csb0, pht_gs_csb1;
    logic                       pht_gs_web0, pht_gs_web1;
    logic   [PHT_IDX-1:0]       pht_gs_idx0, pht_gs_idx1;
    logic   [COUNTER_WIDTH-1:0] pht_gs_cntr_in0, pht_gs_cntr_in1;
    logic   [COUNTER_WIDTH-1:0] pht_gs_cntr_out0, pht_gs_cntr_out1;

    logic                       pht_gs_cntr_v_in0, pht_gs_cntr_v_in1, pht_gs_cntr_v_out0, pht_gs_cntr_v_out1;

// BIMODAL
    logic                       pht_bi_csb0, pht_bi_csb1;
    logic                       pht_bi_web0, pht_bi_web1;
    logic   [PHT_IDX-1:0]       pht_bi_idx0, pht_bi_idx1;
    logic   [COUNTER_WIDTH-1:0] pht_bi_cntr_in0, pht_bi_cntr_in1;
    logic   [COUNTER_WIDTH-1:0] pht_bi_cntr_out0, pht_bi_cntr_out1;

    logic                       pht_bi_cntr_v_in0, pht_bi_cntr_v_in1, pht_bi_cntr_v_out0, pht_bi_cntr_v_out1;

// MODEL COUNTER
    logic                       model_csb0, model_csb1;
    logic                       model_web0, model_web1;
    logic   [PHT_IDX-1:0]       model_idx0, model_idx1;
    logic   [MODEL_COUNTER_WIDTH-1:0] model_cntr_in0, model_cntr_in1;
    logic   [MODEL_COUNTER_WIDTH-1:0] model_cntr_out0, model_cntr_out1;

    logic                       model_cntr_v_in0, model_cntr_v_in1, model_cntr_v_out0, model_cntr_v_out1;

    logic                       model_cntr_update_en;
    logic                       model_cntr_update_bit;
    
    // GHR
    logic                       ghr_rst;
    logic                       ghr_enq;
    logic                       ghr_deq;
    logic                       ghr_full;
    logic                       ghr_empty;
    logic   [GHR_WIDTH-1:0]     ghr_din;
    logic   [GHR_WIDTH-1:0]     ghr_dout;

    logic   [GHR_WIDTH-1:0]     ghr_reg, ghr_next;

    // GHR QUEUE SIGNALS
    logic   [GHR_WIDTH-1:0]     ghr_q[GHR_Q_DEPTH];
    logic   [GHR_Q_IDX:0]       ghr_tail;
    logic   [GHR_Q_IDX:0]       ghr_head;
    logic	                    full_async;
    logic                       empty_async;


// READ GSHARE PHT
    always_comb begin
        pht_gs_csb0    = fetch_valid && ~ghr_rst;
        pht_gs_web0    = '1;           // always read
        pht_gs_idx0    = hash_pht_idx(fetch_pc, ghr_next);
        pht_gs_cntr_in0= '0;
        pht_gs_cntr_v_in0 = '1;

        ghr_enq     = '0;
        ghr_din     = '0;
        error       = '0;

        if (fetch_valid && ~ghr_rst) begin
            ghr_enq     = '1;
            ghr_din     = ghr_next;
        end

        if ((ghr_full && (ghr_enq && ! ghr_deq)) || (ghr_empty && (ghr_deq && !ghr_enq)))
            error   = '1;
    end


// READ BIMODAL PHT
    always_comb begin
        pht_bi_csb0    = fetch_valid;
        pht_bi_web0    = '1;           // always read
        pht_bi_idx0    = fetch_pc[PHT_IDX+1:2];
        pht_bi_cntr_in0= '0;
        pht_bi_cntr_v_in0 = '1;

    end

// READ MODEL COUNTER
    always_comb begin
        model_csb0    = fetch_valid;
        model_web0    = '1;           // always read
        model_idx0    = fetch_pc[PHT_IDX+1:2];
        model_cntr_in0= '0;
        model_cntr_v_in0 = '1;
    end

    always_comb begin
        en_predict  = '0;
        pred        = '0;
        pred_pc     = '0;
        pred_pht_gs_counter = '0;
        pred_pht_bi_counter = '0;
        pred_model_counter     = '0;
        pred_ghr_idx     = '0;  // temp
        pred_br_pred_mode = starting_model;

        if (fetch_valid_reg) begin
            
            pred_pht_gs_counter = '0;                      // begin as weakly taken
            pred_pht_gs_counter[COUNTER_WIDTH-1] = 1'b1;

            pred_pht_bi_counter = '0;
            pred_pht_bi_counter[COUNTER_WIDTH-1] = 1'b1;

            // pred_model_counter = '0;
            // pred_model_counter[MODEL_COUNTER_WIDTH-1] = '1;
            pred_model_counter[MODEL_COUNTER_WIDTH-2:0] = (MODEL_COUNTER_WIDTH-1)'(~starting_model);
            pred_model_counter[MODEL_COUNTER_WIDTH-1] = starting_model;

            if (pht_gs_cntr_v_out0)
                pred_pht_gs_counter = pht_gs_cntr_out0;
            if (pht_bi_cntr_v_out0)
                pred_pht_bi_counter = pht_bi_cntr_out0;

            if (starting_model == GSHARE)
                pred  = pred_pht_gs_counter[COUNTER_WIDTH-1];
            else if (starting_model == BIMODAL)
                pred  = pred_pht_bi_counter[COUNTER_WIDTH-1];

 
            if (model_cntr_v_out0) begin
                if (model_cntr_out0[MODEL_COUNTER_WIDTH-1] == 1'b1) begin   // use GSHARE
                    pred_br_pred_mode = GSHARE;
        
                    if (pht_gs_cntr_v_out0) begin
                        pred_pht_gs_counter = pht_gs_cntr_out0;
                        // if using ghr_next to hash next pht idx, can use this optimization
                        // if (result_valid && (hash_pht_idx(fetch_pc_reg, ghr_reg) == pht_idx1)) begin
                        //     pred_pht_counter = pht_cntr_in1;
                        // end
                        pred     = pred_pht_gs_counter[COUNTER_WIDTH-1];
                    end
                end else begin  // use BIMODAL
                    pred_br_pred_mode = BIMODAL;

                    if (pht_bi_cntr_v_out0) begin
                        pred_pht_bi_counter = pht_bi_cntr_out0;
                        pred     = pred_pht_bi_counter[COUNTER_WIDTH-1];
                    end
                end
            end
            pred_pc  = fetch_pc_reg;

            en_predict = '1;
        end
        
        // disable br predictor
        // pred     = '1;
    end

// FETCH REGS
    always_ff @(posedge clk) begin
        if (rst) begin
            fetch_pc_reg    <= '0;
            fetch_valid_reg <= '0;
        end else begin
            fetch_pc_reg    <= fetch_pc;
            fetch_valid_reg <= fetch_valid;
        end
    end

// WRITE PHT for GSAHRE
    always_comb begin
        pht_gs_csb1     = result_valid;
        pht_gs_web1     = ~result_valid;
        pht_gs_idx1     = hash_pht_idx(result_pc, ghr_dout);
        pht_gs_cntr_in1 = update_counter(result_pht_gs_counter, result_taken);
        pht_gs_cntr_v_in1 = '1;
    end

// WRITE PHT for BIMODAL
    always_comb begin
        pht_bi_csb1        = result_valid;
        pht_bi_web1        = ~result_valid;
        pht_bi_idx1        = result_pc[PHT_IDX+1:2];
        pht_bi_cntr_in1    = update_counter(result_pht_bi_counter, result_taken);
        pht_bi_cntr_v_in1  = '1;
    end

// WRITE MODEL COUNTER
    always_comb begin
        gshare_mispredict       = '0;
        bimodal_mispredict      = '0;
        model_cntr_update_en    = '0;
        model_cntr_update_bit   = '0;

        if (result_valid) begin
            // ONLY update model cntr if they have different predictions
            model_cntr_update_en    = (result_pht_gs_counter[COUNTER_WIDTH-1] != result_pht_bi_counter[COUNTER_WIDTH-1]);
            if (result_pht_gs_counter[COUNTER_WIDTH-1] == result_taken) begin
                model_cntr_update_bit   = GSHARE;
                bimodal_mispredict      = '0;
            end
            else if (result_pht_bi_counter[COUNTER_WIDTH-1] == result_taken) begin
                model_cntr_update_bit   = BIMODAL;
                gshare_mispredict       = '1;
            end
        end

        model_csb1    = model_cntr_update_en;
        model_web1    = ~model_cntr_update_en;
        model_idx1    = result_pc[PHT_IDX+1:2];
        model_cntr_in1= update_counter_model(result_model_counter, (model_cntr_update_bit));
        model_cntr_v_in1 = '1;
    end


// GHR REG
    always_comb begin
        result_mispredict  = '0;
        ghr_rst     = '0;
        ghr_deq     = '0;
        ghr_next    = ghr_reg;
        if (fetch_valid_reg)
            ghr_next    = {ghr_reg[GHR_WIDTH-2:0], pred};

        if (result_valid) begin
            result_mispredict  = result_pred != result_taken;
            ghr_deq     = '1;
            if (result_mispredict) begin
                ghr_rst = '1;
                ghr_next = {ghr_dout[GHR_WIDTH-2:0], result_taken};
            end
        end
        if (result_ghr_idx != '0) begin // temp
        end
        if (result_br_pred_mode) begin
        end
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            ghr_reg     <= '0;
        end else begin
            ghr_reg     <= ghr_next;
        end
    end

// LOG STATS
    always_ff @(posedge clk) begin
        if (rst) begin
            n_incorrect_pred    <= '0;
            n_correct_pred      <= '0;
            n_taken             <= '0;
            n_not_taken         <= '0;
            n_br_predictions    <= '0;
            en_predict_reg      <= '0;
        end else begin
            en_predict_reg      <= en_predict;

            n_br_predictions    <= n_br_predictions + en_predict_reg;
            if (result_valid) begin
                if (result_taken)
                    n_taken             <= n_taken + 1'b1;
                else 
                    n_not_taken         <= n_not_taken + 1'b1;
                if (result_mispredict)
                    n_incorrect_pred    <= n_incorrect_pred + 1'b1;
                else
                    n_correct_pred      <= n_correct_pred + 1'b1;
            end
        end
    end


    always_comb begin
        ghr_full    = ghr_head[GHR_Q_IDX] != ghr_tail[GHR_Q_IDX] &&
                      ghr_head[GHR_Q_IDX-1:0] == ghr_tail[GHR_Q_IDX-1:0];
        ghr_empty   = ghr_head == ghr_tail;

        full_async  = ghr_full &&
                        !(ghr_deq && !ghr_enq);   // if just dequeueing, queue is NOT full
        empty_async = ghr_empty &&
                        !(ghr_enq && !ghr_deq);   // if just enqueueing, queue is not empty

        if (ghr_enq && ghr_deq && ghr_empty) begin
            ghr_dout = ghr_din;
        end else begin
            ghr_dout = ghr_q[ghr_head[GHR_Q_IDX-1:0]];
        end
	end

	always_ff @(posedge clk) begin
        if(rst || ghr_rst) begin
            // for (integer i = 0; i < GHR_Q_DEPTH; i++) begin
            //     ghr_q[i] <= '0;
            // end
            ghr_tail <= '0;
            ghr_head <= '0;
        end else begin
            // for when we take result br from ex instead of cm
            // if (ghr_rst) begin
            //     ghr_head <= ghr_tail;
            // end

            if (ghr_enq && ghr_deq) begin
                if (empty_async) begin
                    ghr_q[ghr_tail[GHR_Q_IDX-1:0]] <= ghr_din;
                end
                else begin
                    ghr_q[ghr_tail[GHR_Q_IDX-1:0]] <= ghr_din;
                    ghr_tail <= ghr_tail + 1'b1;
                    ghr_head <= ghr_head + 1'b1;
                end
            end else if (ghr_enq && !full_async) begin
                ghr_q[ghr_tail[GHR_Q_IDX-1:0]] <= ghr_din;
                ghr_tail <= ghr_tail + 1'b1;
            end
            else if (ghr_deq && !empty_async) begin
                ghr_head <= ghr_head + 1'b1;
            end
        end
	end

// GSHARE
    gshare_pht_array gs_pht_array (
        .clk0       (clk),
        .csb0       (~pht_gs_csb0),
        .web0       (pht_gs_web0),
        .addr0      (pht_gs_idx0),
        .din0       (pht_gs_cntr_in0),
        .dout0      (pht_gs_cntr_out0),

        .clk1       (clk),
        .csb1       (~pht_gs_csb1),
        .web1       (pht_gs_web1),
        .addr1      (pht_gs_idx1),
        .din1       (pht_gs_cntr_in1),
        .dout1      (pht_gs_cntr_out1)
    );
    dp_ff_array_pht_v #(
        .S_INDEX(PHT_IDX),
        .WIDTH(1)
    ) pht_valid_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (~pht_gs_csb0),
        .web0       (pht_gs_web0),
        .addr0      (pht_gs_idx0),
        .din0       (pht_gs_cntr_v_in0),
        .dout0      (pht_gs_cntr_v_out0),

        .csb1       (~pht_gs_csb1),
        .web1       (pht_gs_web1),
        .addr1      (pht_gs_idx1),
        .din1       (pht_gs_cntr_v_in1),
        .dout1      (pht_gs_cntr_v_out1)
    );

// BIMODAL
    pht_array bi_pht_array (
        .clk0       (clk),
        .csb0       (~pht_bi_csb0),
        .web0       (pht_bi_web0),
        .addr0      (pht_bi_idx0),
        .din0       (pht_bi_cntr_in0),
        .dout0      (pht_bi_cntr_out0),

        .clk1       (clk),
        .csb1       (~pht_bi_csb1),
        .web1       (pht_bi_web1),
        .addr1      (pht_bi_idx1),
        .din1       (pht_bi_cntr_in1),
        .dout1      (pht_bi_cntr_out1)
    );

    // /*  Uses same valid array as
    dp_ff_array_pht_v #(
        .S_INDEX(PHT_IDX),
        .WIDTH(1)
    ) bimodal_pht_valid_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (~pht_bi_csb0),
        .web0       (pht_bi_web0),
        .addr0      (pht_bi_idx0),
        .din0       (pht_bi_cntr_v_in0),
        .dout0      (pht_bi_cntr_v_out0),

        .csb1       (~pht_bi_csb1),
        .web1       (pht_bi_web1),
        .addr1      (pht_bi_idx1),
        .din1       (pht_bi_cntr_v_in1),
        .dout1      (pht_bi_cntr_v_out1)
    );

// BR MODEL COUNTERS
    br_pred_scheme_array br_pred_model_array (
        .clk0       (clk),
        .csb0       (~model_csb0),
        .web0       (model_web0),
        .addr0      (model_idx0),
        .din0       (model_cntr_in0),
        .dout0      (model_cntr_out0),

        .clk1       (clk),
        .csb1       (~model_csb1),
        .web1       (model_web1),
        .addr1      (model_idx1),
        .din1       (model_cntr_in1),
        .dout1      (model_cntr_out1)
    );
    dp_ff_array_pht_v #(
        .S_INDEX(PHT_IDX),
        .WIDTH(1)
    ) br_pred_scheme_valid_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (~model_csb0),
        .web0       (model_web0),
        .addr0      (model_idx0),
        .din0       (model_cntr_v_in0),
        .dout0      (model_cntr_v_out0),

        .csb1       (~model_csb1),
        .web1       (model_web1),
        .addr1      (model_idx1),
        .din1       (model_cntr_v_in1),
        .dout1      (model_cntr_v_out1)
    );

endmodule : br_predictor_i