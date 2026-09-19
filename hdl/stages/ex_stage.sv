module ex_stage_i
import rv32i_types::*;
(
    input   logic           rst,
    input   logic           clk, 

    input   rs_br_ent_t     iss_ex_br,
    input   rs_alu_ent_t    iss_ex_alu,
    input   rs_alu_ent_t    iss_ex_alu2,
    input   rs_mult_ent_t   iss_ex_mult,
    input   rs_mult_ent_t   iss_ex_div,
    input   rs_mem_ent_t    iss_ex_mem,

    input   logic           flush,

    // cache signals for mem
    // input   logic           d_mem_resp_reg,
    // input   logic [31:0]    d_mem_rdata_reg,
    // output  logic [31:0]    d_mem_addr,
    // output  logic [3:0]     d_mem_rmask,
    output cdb_t cdb1,
    output cdb_t cdb2,
    output cdb_t cdb3,

    // tell iss to not send another instr on next cycle
    output  logic           func_unit_busy[FUNC_UNITS_MAX],
    output  br_pkt_t        execute_br_pkt,

    output  ex_wb_t         ex_wb

);      // EXECUTE

    logic mem_done;
    logic mult_done;
    logic div_done;
    logic br_done;
    logic alu_done;
    logic alu2_done;

    // instr_pkt_t mem2_instr_out;
    // ex_wb_t mem_instr_out;
    // instr_pkt_t mult_instr_out;
    // instr_pkt_t div_instr_out;
    // instr_pkt_t br_instr_out;
    

    rs_br_ent_t  br_ent_out;
    rs_alu_ent_t alu_ent_out;
    rs_alu_ent_t alu2_ent_out;
    data_pkt_t   data_out;
    rs_mem_ent_t mem_ent_out;
    rs_mult_ent_t mult_ent_out;
    rs_mult_ent_t div_ent_out;

    logic   [31:0]  alu_rd_data_out;
    logic   [31:0]  alu2_rd_data_out;
    logic   [31:0]  br_rd_data_out;
    logic   [31:0]  mult_rd_data_out;
    logic   [31:0]  div_rd_data_out;

    logic   [31:0]  br_i_addr_next;
    
    logic occupied_mult;
    logic occupied_div;
    logic occupied_mem;


    always_comb begin
        ex_wb = '0;
        func_unit_busy[ALU] = '0;
        func_unit_busy[ALU2] = '0;
        func_unit_busy[BR] = '0;
        func_unit_busy[MEM] = occupied_mem;
        func_unit_busy[MULT] = occupied_mult ;
        func_unit_busy[DIV] = occupied_div;

        // div_done    = '0;
        // occupied_div = '0;
        // div_instr_out = '0;
        // div_done    = '0;
        // occupied_div = '0;
        // div_instr_out = '0;

        if (!flush) begin
            if (mult_done) begin
                ex_wb.instr_pkt.func_unit   = MULT;

                ex_wb.instr_pkt.rob_idx     = mult_ent_out.instr_pkt.rob_idx;
                ex_wb.instr_pkt.i_valid     = mult_ent_out.instr_pkt.i_valid;

                ex_wb.instr_pkt.i_use_rd    = mult_ent_out.reg_pkt.i_use_rd;
                ex_wb.instr_pkt.rd_valid    = mult_ent_out.reg_pkt.rd_valid;
                ex_wb.instr_pkt.rd_paddr    = mult_ent_out.reg_pkt.rd_paddr;
                ex_wb.instr_pkt.rs1_data    = mult_ent_out.reg_pkt.rs1_data;
                ex_wb.instr_pkt.rs2_data    = mult_ent_out.reg_pkt.rs2_data;
                ex_wb.instr_pkt.rd_data     = mult_rd_data_out;
    
                func_unit_busy[ALU] = alu_done;
                func_unit_busy[ALU2] = alu2_done;
                func_unit_busy[BR] = br_done;
                func_unit_busy[MEM] = mem_done ;
                func_unit_busy[MULT] = '0;
                func_unit_busy[DIV] = div_done;
            end
            else if (div_done) begin
                ex_wb.instr_pkt.func_unit   = MULT;

                ex_wb.instr_pkt.rob_idx     = div_ent_out.instr_pkt.rob_idx;
                ex_wb.instr_pkt.i_valid     = div_ent_out.instr_pkt.i_valid;

                ex_wb.instr_pkt.i_use_rd    = div_ent_out.reg_pkt.i_use_rd;
                ex_wb.instr_pkt.rd_valid    = div_ent_out.reg_pkt.rd_valid;
                ex_wb.instr_pkt.rd_paddr    = div_ent_out.reg_pkt.rd_paddr;
                ex_wb.instr_pkt.rs1_data    = div_ent_out.reg_pkt.rs1_data;
                ex_wb.instr_pkt.rs2_data    = div_ent_out.reg_pkt.rs2_data;
                ex_wb.instr_pkt.rd_data     = div_rd_data_out;

                func_unit_busy[ALU] = alu_done;
                func_unit_busy[ALU2] = alu2_done;
                func_unit_busy[BR] = br_done;
                func_unit_busy[MEM] = mem_done;
                func_unit_busy[MULT] = mult_done;
                func_unit_busy[DIV] = '0;
            end
            else if (br_done) begin
                ex_wb.instr_pkt.func_unit   = BR;

                ex_wb.instr_pkt.rob_idx     = br_ent_out.instr_pkt.rob_idx;
                ex_wb.instr_pkt.i_valid     = br_ent_out.instr_pkt.i_valid;

                ex_wb.instr_pkt.i_addr_next = br_i_addr_next;
                ex_wb.instr_pkt.br_en       = br_ent_out.instr_pkt.br_en;
                ex_wb.instr_pkt.br_result   = br_ent_out.instr_pkt.br_result;
                ex_wb.instr_pkt.br_pred_mode= br_ent_out.instr_pkt.br_pred_mode;

                ex_wb.instr_pkt.i_use_rd    = br_ent_out.reg_pkt.i_use_rd;
                ex_wb.instr_pkt.rd_valid    = br_ent_out.reg_pkt.rd_valid;
                ex_wb.instr_pkt.rd_paddr    = br_ent_out.reg_pkt.rd_paddr;
                ex_wb.instr_pkt.rs1_data    = br_ent_out.reg_pkt.rs1_data;
                ex_wb.instr_pkt.rs2_data    = br_ent_out.reg_pkt.rs2_data;
                ex_wb.instr_pkt.rd_data     = br_rd_data_out;

                func_unit_busy[ALU] = alu_done;
                func_unit_busy[ALU2] = alu2_done;
                func_unit_busy[BR] = '0;
                func_unit_busy[MEM] = mem_done;
                func_unit_busy[MULT] = mult_done;
                func_unit_busy[DIV] = div_done;
            end
            else if (mem_done) begin // giving priority to mult over mem for now becuase no stall logic implemented for mult yet
                ex_wb.data_pkt = data_out; 

                ex_wb.instr_pkt.rob_idx     = mem_ent_out.instr_pkt.rob_idx;

                ex_wb.instr_pkt.i_valid     = mem_ent_out.instr_pkt.i_valid;
                ex_wb.instr_pkt.i_use_rd    = mem_ent_out.reg_pkt.i_use_rd;
                ex_wb.instr_pkt.rd_valid    = mem_ent_out.reg_pkt.rd_valid;
                ex_wb.instr_pkt.rd_paddr    = mem_ent_out.reg_pkt.rd_paddr;
                ex_wb.instr_pkt.rs1_data    = mem_ent_out.reg_pkt.rs1_data;
                ex_wb.instr_pkt.rs2_data    = mem_ent_out.reg_pkt.rs2_data;

                func_unit_busy[ALU] = alu_done;
                func_unit_busy[ALU2] = alu2_done;
                func_unit_busy[BR] = br_done;
                func_unit_busy[MEM] = '0;
                func_unit_busy[MULT] = mult_done;
                func_unit_busy[DIV] = div_done;
            end
            else if (alu_done) begin
                // ex_wb = 'X;
                ex_wb.instr_pkt.func_unit   = ALU;

                ex_wb.instr_pkt.rob_idx     = alu_ent_out.instr_pkt.rob_idx;
                ex_wb.instr_pkt.i_valid     = alu_ent_out.instr_pkt.i_valid;

                ex_wb.instr_pkt.i_use_rd    = alu_ent_out.reg_pkt.i_use_rd;
                ex_wb.instr_pkt.rd_valid    = alu_ent_out.reg_pkt.rd_valid;
                ex_wb.instr_pkt.rd_paddr    = alu_ent_out.reg_pkt.rd_paddr;

                ex_wb.instr_pkt.rs1_data    = alu_ent_out.reg_pkt.rs1_data;
                ex_wb.instr_pkt.rs2_data    = alu_ent_out.reg_pkt.rs2_data;
                ex_wb.instr_pkt.rd_data     = alu_rd_data_out;

                func_unit_busy[ALU] = '0;
                func_unit_busy[ALU2] = alu2_done;
                func_unit_busy[BR] = br_done;
                func_unit_busy[MEM] = mem_done;
                func_unit_busy[MULT] = mult_done;
                func_unit_busy[DIV] = div_done;
            end
            else if (alu2_done) begin
                // ex_wb = 'X;
                ex_wb.instr_pkt.func_unit   = ALU;

                ex_wb.instr_pkt.rob_idx     = alu2_ent_out.instr_pkt.rob_idx;
                ex_wb.instr_pkt.i_valid     = alu2_ent_out.instr_pkt.i_valid;

                ex_wb.instr_pkt.i_use_rd    = alu2_ent_out.reg_pkt.i_use_rd;
                ex_wb.instr_pkt.rd_valid    = alu2_ent_out.reg_pkt.rd_valid;
                ex_wb.instr_pkt.rd_paddr    = alu2_ent_out.reg_pkt.rd_paddr;

                ex_wb.instr_pkt.rs1_data    = alu2_ent_out.reg_pkt.rs1_data;
                ex_wb.instr_pkt.rs2_data    = alu2_ent_out.reg_pkt.rs2_data;
                ex_wb.instr_pkt.rd_data     = alu2_rd_data_out;

                func_unit_busy[ALU] = alu_done;
                func_unit_busy[ALU2] = '0;
                func_unit_busy[BR] = br_done;
                func_unit_busy[MEM] = mem_done;
                func_unit_busy[MULT] = mult_done;
                func_unit_busy[DIV] = div_done;
            end
        end
    end

    always_comb begin
        execute_br_pkt = '0;
        // if (br_done && ~func_unit_busy[BR]) begin
        //     execute_br_pkt.v         = br_ent_out.instr_pkt.br_en;
        //     execute_br_pkt.order     = br_ent_out.instr_pkt.order;
        //     execute_br_pkt.pred      = br_ent_out.instr_pkt.br_pred;
        //     execute_br_pkt.result    = br_ent_out.instr_pkt.br_result;
        //     execute_br_pkt.pht_cntr  = br_ent_out.instr_pkt.br_pht_cntr;
        //     execute_br_pkt.ghr_idx   = br_ent_out.instr_pkt.br_ghr_idx;
        //     execute_br_pkt.addr      = br_ent_out.instr_pkt.i_addr;
        //     execute_br_pkt.addr_next = br_ent_out.instr_pkt.i_addr_next;
        //     execute_br_pkt.is_jmp    = br_ent_out.instr_pkt.i_is_jump;
        //     execute_br_pkt.is_jal    = br_ent_out.instr_pkt.i_is_jal;
        // end
    end

    always_comb begin
        cdb1 = '0;
        cdb2 = '0;
        cdb3 = '0;
        if (alu_done && alu_ent_out.reg_pkt.i_use_rd && alu_ent_out.instr_pkt.i_valid) begin
            
            cdb1.bus_wb_valid = '1;
            cdb1.bus_wb_data = alu_rd_data_out;
            cdb1.bus_wb_paddr = alu_ent_out.reg_pkt.rd_paddr;
        end

        if (alu2_done && alu2_ent_out.reg_pkt.i_use_rd && alu2_ent_out.instr_pkt.i_valid) begin
            
            cdb2.bus_wb_valid = '1;
            cdb2.bus_wb_data = alu2_rd_data_out;
            cdb2.bus_wb_paddr = alu2_ent_out.reg_pkt.rd_paddr;
        end

        if (mult_done && mult_ent_out.reg_pkt.i_use_rd && mult_ent_out.instr_pkt.i_valid) begin
            
            cdb3.bus_wb_valid = '1;
            cdb3.bus_wb_data = mult_rd_data_out;
            cdb3.bus_wb_paddr = mult_ent_out.reg_pkt.rd_paddr;
        end
        else if (div_done && div_ent_out.reg_pkt.i_use_rd && div_ent_out.instr_pkt.i_valid) begin
            cdb3.bus_wb_valid = '1;
            cdb3.bus_wb_data = div_rd_data_out;
            cdb3.bus_wb_paddr = div_ent_out.reg_pkt.rd_paddr;
        end
    end
    
    func_alu_i alu_ex(    
        .alu_ent(iss_ex_alu),
        .valid(iss_ex_alu.rdy_status && iss_ex_alu.v),
        // .occupied(),
        .done(alu_done),
        .alu_ent_out(alu_ent_out),
        .rd_data_out(alu_rd_data_out)
    );

    func_alu_i alu2_ex(    
        .alu_ent(iss_ex_alu2),
        .valid(iss_ex_alu2.rdy_status && iss_ex_alu2.v),
        // .occupied(),
        .done(alu2_done),
        .alu_ent_out(alu2_ent_out),
        .rd_data_out(alu2_rd_data_out)
    );

    func_br_i  br(
        .br_ent(iss_ex_br),
        .valid(iss_ex_br.rdy_status && iss_ex_br.v),

        .done(br_done),
        .br_ent_out(br_ent_out),
        .rd_data_out(br_rd_data_out),
        .i_addr_next(br_i_addr_next)
    );

    func_mult_i mult_ex(
        .rst(rst || flush),
        .clk(clk),
        .mult_ent(iss_ex_mult),
        .valid(iss_ex_mult.rdy_status && iss_ex_mult.v),
        .occupied(occupied_mult),
        .done(mult_done),
        .mult_ent_out(mult_ent_out),
        .rd_data_out(mult_rd_data_out)
    );

    func_div_i div_ex(
        .rst(rst || flush),
        .clk(clk),
        .div_ent(iss_ex_div),
        .valid(iss_ex_div.rdy_status && iss_ex_div.v),
        .stall(func_unit_busy[DIV]),

        .occupied(occupied_div),
        .done(div_done),
        .div_ent_out(div_ent_out),
        .rd_data_out(div_rd_data_out)
    );

    func_mem1_i mem(
        .rst(rst || flush),
        .clk(clk),
        .mem_ent(iss_ex_mem),
        .valid(iss_ex_mem.rdy_status && iss_ex_mem.v),

        // .d_mem_resp_reg(d_mem_resp_reg),
        // .d_mem_rdata_reg(d_mem_rdata_reg),
        // .d_mem_addr(d_mem_addr),
        // .d_mem_rmask(d_mem_rmask),

        .occupied(occupied_mem),
        .done(mem_done),
        .mem_ent_out (mem_ent_out),
        .data_out(data_out)
    );

endmodule : ex_stage_i
