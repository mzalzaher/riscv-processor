package rv32i_types;

    localparam  START_PC = 32'haaaaa000;


// CONFIG
    // all depth values  must be 2^n
    
    localparam  STREAM_Q_DEPTH  = 4;
    localparam  INST_Q_DEPTH    = 8;
    localparam  RS_Q_DEPTH      = 4;
    localparam  RS_Q_DEPTH_MULT = 4;

    localparam  ROB_Q_DEPTH     = 16;
    localparam  PRF_DEPTH       = 32;

    localparam  N_MULT_STAGES   = 5;
    localparam  N_DIV_STAGES    = 13;


    // Cache Parameters
    localparam NUM_WAYS_I = 2; // Power of two only
    localparam NUM_WAYS_D = 2; // Power of two only

    localparam NUM_WORDS_I = 16; //Power of two only, minimum 16
    localparam NUM_WORDS_D = 16; //Power of two only, minimum 16
    
    // localparam OFFSET_BITS = 5;

    // GSHARE BR PREDICTOR
    // modify SRAM config as well

    localparam  MODEL_COUNTER_WIDTH = 2;
    localparam  STARTING_PRED_MODEL = 0;    // 1=gshare, 0=bimodal

    // localparam  STARTING_BR_PRED    = 1;    // 1=taken,  0=not taken
    localparam  COUNTER_WIDTH   = 2;

    localparam  GHR_WIDTH       = 10;
    localparam  PHT_DEPTH       = 1024;
    localparam  PHT_IDX         = log2(PHT_DEPTH);

    localparam  GHR_Q_DEPTH     = ROB_Q_DEPTH;
    localparam  GHR_Q_IDX       = log2(ROB_Q_DEPTH);


    localparam  STREAM_IDX_WIDTH  = log2(STREAM_Q_DEPTH);
    localparam  INST_IDX_WIDTH  = log2(INST_Q_DEPTH);
    localparam  RS_IDX_WIDTH    = log2(RS_Q_DEPTH);
    localparam  ROB_IDX_WIDTH   = log2(ROB_Q_DEPTH);
    localparam  PRF_IDX_WIDTH   = log2(PRF_DEPTH);

    localparam  FUNC_UNITS_MAX  = 6;   // max number of func units
    localparam  FUNC_N_BITS     = 3;

    typedef logic [4:0] aaddr_t;
    typedef logic [PRF_IDX_WIDTH-1:0]   paddr_t;

    typedef logic [RS_IDX_WIDTH-1:0]    rs_idx_t;
    typedef logic [ROB_IDX_WIDTH-1:0]   rob_idx_t;

    typedef enum logic {
        alu  = 1'b0,
        cmp  = 1'b1
    } i_op_type_t;

    typedef enum logic {
        LOAD    = 1'b0,
        STORE   = 1'b1
    } i_mem_op_type_t;

    typedef enum logic {
        BIMODAL = 1'b0,
        GSHARE  = 1'b1
    } br_pred_mode_t;

    typedef enum logic [FUNC_N_BITS-1:0] {
        BR             = 3'b000,
        ALU            = 3'b001,
        ALU2           = 3'b010,
        MULT           = 3'b011,
        DIV            = 3'b100,
        MEM            = 3'b101   // may want to add both mem stages idk yet
    } func_unit_t;

    typedef struct packed {
        logic           v;
        logic   [63:0]  order;

        logic           pred;       // 1=take
        logic           result;
        logic   [COUNTER_WIDTH-1:0] pht_gs_cntr;
        logic   [COUNTER_WIDTH-1:0] pht_bi_cntr;
        logic   [GHR_Q_IDX-1:0]     ghr_idx;
        br_pred_mode_t  br_pred_mode;
        logic   [MODEL_COUNTER_WIDTH-1:0] model_cntr;
        
        logic   [31:0]  addr;
        logic   [31:0]  addr_next;  // holds predicted addr until result is known

        logic           is_jmp;
        logic           is_jal;
    } br_pkt_t;

    typedef struct packed {
        logic   [31:0]  d_mem_addr;
        logic   [3:0]   d_mem_rmask;
        logic   [3:0]   d_mem_wmask;
        logic   [31:0]  d_mem_rdata;    // condense to one signal?
        logic   [31:0]  d_mem_wdata;
        logic   [1:0]   mem_shift;
        logic           mask_ready;
        logic           store_busy;
    } data_pkt_t;

    typedef struct packed {
        logic           v;
        logic           sent;
        logic   [26:0]   addr;
        logic   [255:0]  data;
    } stream_ent_t;

    // INSTR PACKET
    typedef struct packed {
        logic   [63:0]  order;

        logic   [ROB_IDX_WIDTH - 1:0]   rob_idx;
    
        logic           i_valid;
        logic   [31:0]  i_addr;
        logic   [31:0]  i_addr_next;
        logic   [31:0]  i_instr;
        logic   [6:0]   i_opcode;
        logic   [2:0]   i_funct3;

        func_unit_t     func_unit;

        i_op_type_t     i_op_type;      // alu=0 or cmp=1
        logic   [2:0]   alu_op;     // can condense these
        logic   [2:0]   cmp_op;

        logic           i_use_rd;
        logic           i_use_rs1;
        logic           i_use_rs2;
        logic           i_use_imm;
        logic           i_use_pc;

        i_mem_op_type_t i_mem_op_type;

        logic           i_is_jump;
        logic           i_is_jal;

        logic           br_en;
        logic           br_pred;
        logic           br_result;
        logic   [COUNTER_WIDTH-1:0] br_pht_gs_cntr;
        logic   [COUNTER_WIDTH-1:0] br_pht_bi_cntr;
        logic   [GHR_Q_IDX-1:0]     br_ghr_idx;
        br_pred_mode_t  br_pred_mode;
        logic   [MODEL_COUNTER_WIDTH-1:0] br_model_cntr;


        logic           rd_valid;
        aaddr_t         rd_aaddr;
        paddr_t         rd_paddr;
        logic   [31:0]  rd_data;

        logic           rs1_rdy;
        aaddr_t         rs1_aaddr;
        paddr_t         rs1_paddr;
        logic   [31:0]  rs1_data;

        logic           rs2_rdy;
        aaddr_t         rs2_aaddr;
        paddr_t         rs2_paddr;
        logic   [31:0]  rs2_data;

        logic   [31:0]  imm_data;

    } instr_pkt_t;

    typedef struct packed {
        logic   [63:0]  order;

        logic           i_valid;
        logic   [31:0]  i_addr;
        logic   [31:0]  i_addr_next;
        logic   [31:0]  i_instr;
        logic   [2:0]   i_funct3;
        logic           i_use_rd;
        func_unit_t     func_unit;

        logic           br_en;
        logic           br_pred;
        logic           br_result;
        logic   [COUNTER_WIDTH-1:0] br_pht_gs_cntr;
        logic   [COUNTER_WIDTH-1:0] br_pht_bi_cntr;
        logic   [GHR_Q_IDX-1:0]     br_ghr_idx;
        br_pred_mode_t  br_pred_mode;
        logic   [MODEL_COUNTER_WIDTH-1:0] br_model_cntr;

        logic           i_is_jump;
        logic           i_is_jal;

        logic           rd_valid;
        aaddr_t         rd_aaddr;
        paddr_t         rd_paddr;
        logic   [31:0]  rd_data;

        aaddr_t         rs1_aaddr;
        paddr_t         rs1_paddr;
        logic   [31:0]  rs1_data;
        aaddr_t         rs2_aaddr;
        paddr_t         rs2_paddr;
        logic   [31:0]  rs2_data;

    } rob_pkt_t;

    typedef struct packed {
        logic           v;
        logic           status;
        rob_pkt_t       instr_pkt; 
        data_pkt_t      data_pkt;
    } rob_entry_t;

    // RESERVATION STATION STRUCTS -----------------------------------
    typedef struct packed {
        logic           v;
        logic           rdy_status;
        instr_pkt_t     instr_pkt;
    } rs_entry_t;

    typedef struct packed {
        logic           rd_valid;
        paddr_t         rd_paddr;

        logic           i_use_rd;
        logic           i_use_rs1;
        logic           i_use_rs2;

        paddr_t         rs1_paddr;
        logic   [31:0]  rs1_data;
        paddr_t         rs2_paddr;
        logic   [31:0]  rs2_data;
    } reg_pkt_t;

// BR
    typedef struct packed {
        rob_idx_t       rob_idx;
        logic           i_valid;
        logic   [31:0]  i_addr;
        logic   [2:0]   cmp_op;
        logic   [31:0]  imm_data;
        
        logic           br_pred;
        logic   [COUNTER_WIDTH-1:0] br_pht_gs_cntr;
        logic   [COUNTER_WIDTH-1:0] br_pht_bi_cntr;
        logic   [GHR_Q_IDX-1:0]     br_ghr_idx;
        logic           br_en;
        logic           br_result;
        logic           i_is_jmp;
        logic           is_jal;
        br_pred_mode_t  br_pred_mode;
        logic   [MODEL_COUNTER_WIDTH-1:0] br_model_cntr;

        logic           rs1_rdy;
        logic           rs2_rdy;
    } br_inst_pkt_t;

    typedef struct packed {
        logic           v;
        logic           rdy_status;
        br_inst_pkt_t   instr_pkt;
        reg_pkt_t       reg_pkt;
    } rs_br_ent_t;

// ALU
    typedef struct packed {
        rob_idx_t       rob_idx;

        logic           rs1_rdy;
        logic           rs2_rdy;
        logic           i_valid;
        logic   [31:0]  i_addr;
        i_op_type_t     i_op_type;      // alu=0 or cmp=1
        logic   [2:0]   alu_op;     // can condense these
        logic   [2:0]   cmp_op;
        logic           i_use_imm;
        logic           i_use_pc;
        logic   [31:0]  imm_data;
    } alu_pkt_t;

    typedef struct packed {
        logic           v;
        logic           rdy_status;
        alu_pkt_t       instr_pkt;
        reg_pkt_t       reg_pkt;
    } rs_alu_ent_t;

// MULT
    typedef struct packed {
        rob_idx_t       rob_idx;

        logic           rs1_rdy;
        logic           rs2_rdy;
        logic           i_valid;
        logic   [2:0]   i_funct3;
    } mult_pkt_t;

    typedef struct packed {
        logic           v;
        logic           rdy_status;
        mult_pkt_t      instr_pkt;
        reg_pkt_t       reg_pkt;
    } rs_mult_ent_t;

// MEM
    typedef struct packed {
        rob_idx_t       rob_idx;
    
        logic           i_valid;
        i_mem_op_type_t i_mem_op_type;
        logic   [2:0]   i_funct3;

        logic   [31:0]  imm_data;
        logic   [31:0]  i_instr;

        logic           rs1_rdy;
        logic           rs2_rdy;
    } mem_inst_pkt_t;

    typedef struct packed {
        logic           v;
        logic           rdy_status;
        mem_inst_pkt_t  instr_pkt;
        reg_pkt_t       reg_pkt;
    } rs_mem_ent_t;
    // ---------------------------------------------------------------

    // STAGE REGISTERS
    typedef struct packed {
        logic   [63:0]      order;
        logic               valid;
        logic   [31:0]      inst;
        logic   [31:0]      pc;

    } if_id_t;

    typedef struct packed {
        instr_pkt_t     instr_pkt;

    } id_dp_t;

    typedef struct packed {
        instr_pkt_t     instr_pkt;

    } dp_iss_t;

    typedef struct packed {
        rs_entry_t [FUNC_UNITS_MAX-1:0] rs_entry;

    } iss_ex_t;

    // for each rs/fu
    typedef struct packed {
        rs_entry_t rs_entry;

    } iss_ex_i_t;

    typedef struct packed {
        instr_pkt_t       instr_pkt;
        data_pkt_t      data_pkt;
    } ex_wb_t;

    typedef struct packed {
        logic           v;
        logic           status;
        rob_pkt_t     instr_pkt;
        data_pkt_t    data_pkt;
    } wb_cm_t;

    typedef struct packed { 
        logic           v;
        logic           renamed;
        paddr_t         paddr;
        logic   [31:0]  data;
    } freelist_ports_t;

    // TABLE STRUCTS
    typedef struct packed { // indexed by aaddr
        logic           v;  // redundant i think
        logic           renamed;
        paddr_t         paddr;
    } rat_t;

    typedef struct packed { // indexed by paddr
        logic   [31:0]  data;
        logic           v;
    } prf_t;

    typedef struct packed { // indexed by aaddr
        logic           v;
        logic           renamed;    // 1=yes renamed
        paddr_t         paddr;
        logic   [31:0]  data;
    } rrf_t;

    typedef struct packed {
        logic           bus_wb_valid;
        logic  [31:0]   bus_wb_data;
        paddr_t         bus_wb_paddr;

        logic           bus_mem_valid;
        logic  [31:0]   bus_mem_data;
        paddr_t         bus_mem_paddr;

        // ...
    } cdb_t;

    localparam  STREAM_Q_WIDTH  = $bits(stream_ent_t);
    localparam  INST_Q_WIDTH    = $bits(if_id_t);
    localparam  RS_Q_WIDTH      = $bits(rs_entry_t);
    localparam  RS_BR_WIDTH     = $bits(rs_br_ent_t);
    localparam  RS_ALU_WIDTH    = $bits(rs_alu_ent_t);
    localparam  RS_MULT_WIDTH   = $bits(rs_mult_ent_t);
    localparam  RS_MEM_WIDTH    = $bits(rs_mem_ent_t);
    localparam  ROB_Q_WIDTH     = $bits(rob_entry_t);
    localparam  PRF_WIDTH       = $bits(prf_t);

// MP_VERIF TYPES
    typedef enum logic [6:0] { 
        base           = 7'b0000000,
        variant_ALU    = 7'b0100000,
        variant_MULT   = 7'b0000001 // New variant for mul and div
    } funct7_t;
    
    typedef enum logic [6:0] {
        op_b_lui       = 7'b0110111, // load upper immediate (U type)
        op_b_auipc     = 7'b0010111, // add upper immediate PC (U type)
        op_b_jal       = 7'b1101111, // jump and link (J type)
        op_b_jalr      = 7'b1100111, // jump and link register (I type)
        op_b_br        = 7'b1100011, // branch (B type)
        op_b_load      = 7'b0000011, // load (I type)
        op_b_store     = 7'b0100011, // store (S type)
        op_b_imm       = 7'b0010011, // arith ops with register/immediate operands (I type)
        op_b_reg       = 7'b0110011  // arith ops with register operands (R type)
    } rv32i_opcode;

    // ALU and CMP ops do NOT equal funct3/7 vals ***
    typedef enum logic [2:0] {
        alu_op_add     = 3'b000,
        alu_op_sll     = 3'b001,
        alu_op_sra     = 3'b010,
        alu_op_sub     = 3'b011,
        alu_op_xor     = 3'b100,
        alu_op_srl     = 3'b101,
        alu_op_or      = 3'b110,
        alu_op_and     = 3'b111
    } alu_ops;

    typedef enum logic [2:0] {
        cmp_op_eq      = 3'b000,
        cmp_op_ne      = 3'b001,
        cmp_op_lt      = 3'b010,
        cmp_op_ge      = 3'b011,
        cmp_op_ltu     = 3'b100,
        cmp_op_geu     = 3'b101
    } cmp_ops;

    typedef enum logic [2:0] {
        arith_f3_add   = 3'b000, // check logic 30 for sub if op_reg op
        arith_f3_sll   = 3'b001,
        arith_f3_slt   = 3'b010,
        arith_f3_sltu  = 3'b011,
        arith_f3_xor   = 3'b100,
        arith_f3_sr    = 3'b101, // check logic 30 for logical/arithmetic
        arith_f3_or    = 3'b110,
        arith_f3_and   = 3'b111
    } arith_f3_t;

    typedef enum logic [2:0] {
        load_f3_lb     = 3'b000,
        load_f3_lh     = 3'b001,
        load_f3_lw     = 3'b010,
        load_f3_lbu    = 3'b100,
        load_f3_lhu    = 3'b101
    } load_f3_t;

    typedef enum logic [2:0] {
        store_f3_sb    = 3'b000,
        store_f3_sh    = 3'b001,
        store_f3_sw    = 3'b010
    } store_f3_t;

    typedef enum logic [2:0] {
        branch_f3_beq  = 3'b000,
        branch_f3_bne  = 3'b001,
        branch_f3_blt  = 3'b100,
        branch_f3_bge  = 3'b101,
        branch_f3_bltu = 3'b110,
        branch_f3_bgeu = 3'b111
    } branch_f3_t;

    typedef enum logic [2:0] {
        mult_f3_mul     = 3'b000, // MUL: signed × signed → lower 32 bits
        mult_f3_mulh    = 3'b001, // MULH: signed × signed → upper 32 bits
        mult_f3_mulhsu  = 3'b010, // MULHSU: signed × unsigned → upper 32 bits
        mult_f3_mulhu   = 3'b011  // MULHU: unsigned × unsigned → upper 32 bits
    } mult_f3_t;   
    
    typedef enum logic [2:0] {
        div_f3_div     = 3'b100, 
        div_f3_divu  = 3'b101, 
        div_f3_rem    = 3'b110, 
        div_f3_remu   = 3'b111  
    } div_f3_t; 

// INSTR FOR RANDOM TEST COVERAGE

    typedef union packed {
        logic [31:0] word;

        struct packed {
            logic [11:0] i_imm;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } i_type;

        struct packed {
            logic [6:0]  funct7;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } r_type;

        struct packed {
            logic [11:5] imm_s_top;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  imm_s_bot;
            rv32i_opcode opcode;
        } s_type;


        // struct packed {
        //
        // } b_type;

        struct packed {
            logic [31:12] imm;
            logic [4:0]   rd;
            rv32i_opcode  opcode;
        } j_type;

    } rand_instr_t;


    // FUNCTIONS
    function automatic integer log2(integer i);
        integer i_copy;
        integer log_out;
        log_out = 0;

        i_copy = i;
        while(i_copy > 0)begin
            i_copy = i_copy >> 1;
            log_out = log_out + 1;
        end

        log_out = log_out - 1;

        if(i != (1 << log_out)) begin
            log_out = log_out + 1;
        end

        return log_out;
    endfunction : log2

// GSHARE
    function automatic logic [PHT_IDX-1:0] hash_pht_idx(
        input   logic   [31:0]          pc,
        input   logic   [GHR_WIDTH-1:0] ghr
    );
        logic   [PHT_IDX-1:0]   pc_bits;
        logic   [PHT_IDX-1:0]   idx;

        pc_bits = pc[PHT_IDX+1:2];

        // either zero-ext GHR or use lower bits
        // if (GHR_WIDTH <= PHT_IDX) begin
            idx = pc_bits ^ {{(PHT_IDX-GHR_WIDTH){1'b0}}, ghr};
        // end else begin
            // idx = pc_bits ^ ghr[GHR_WIDTH-1:(GHR_WIDTH-PHT_IDX)];
        // end

        return idx;
    endfunction

    function automatic logic [COUNTER_WIDTH-1:0] update_counter(
        input   logic   [COUNTER_WIDTH-1:0] counter,
        input   logic   taken
    );
        logic           [COUNTER_WIDTH-1:0] counter_next;
        counter_next = counter;
        if (taken) begin
            if (counter != '1) begin
                counter_next = counter + 1'b1;
            end
        end else begin
            if (counter != '0) begin
                counter_next = counter - 1'b1;
            end
        end
        return counter_next;
    endfunction

    function automatic logic [MODEL_COUNTER_WIDTH-1:0] update_counter_model(
        input   logic   [MODEL_COUNTER_WIDTH-1:0] counter,
        input   logic   taken
    );
        logic           [MODEL_COUNTER_WIDTH-1:0] counter_next;
        counter_next = counter;
        if (taken) begin
            if (counter != '1) begin
                counter_next = counter + 1'b1;
            end
        end else begin
            if (counter != '0) begin
                counter_next = counter - 1'b1;
            end
        end
        return counter_next;
    endfunction

endpackage
