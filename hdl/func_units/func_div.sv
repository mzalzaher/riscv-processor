module func_div_i
import rv32i_types::*;
(
    input   logic           rst,
    input   logic           clk,
    input   rs_mult_ent_t   div_ent,
    input   logic           valid,
    input   logic           stall,

    output  logic           occupied,
    output  logic           done,
    output  rs_mult_ent_t   div_ent_out,
    output  logic   [31:0]  rd_data_out

);      // MULT FUNC UNIT

    // module parameters
    parameter num_stages  = N_DIV_STAGES;
    parameter latency = num_stages - 1;

    // mult parameters
    parameter inst_a_width = 33;
    parameter inst_b_width = 33;
    parameter inst_num_stages = num_stages;
    parameter inst_stall_mode = 0;
    parameter inst_rst_mode = 0;
    parameter inst_op_iso_mode = 0;

    // div parameters
    parameter     inst_rem_mode = 1;

    

    logic [inst_a_width-1 : 0] inst_a;
    logic [inst_b_width-1 : 0] inst_b;
    logic  inst_TC;
    logic  inst_CLK;
    logic  [inst_a_width+inst_b_width-1 : 0] PRODUCT_inst;
    logic [31:0] result;
    logic [inst_a_width-1 : 0] signed_rs1;
    logic [inst_b_width-1 : 0] signed_rs2;
    logic [inst_a_width-1 : 0] unsigned_rs1;
    logic [inst_b_width-1 : 0] unsigned_rs2;

    logic [inst_a_width-1 : 0] signed_rs1_out;
    logic [inst_b_width-1 : 0] signed_rs2_out;

    logic inst_rst_n;
    logic inst_en;
    // logic  [31:0] counter;

    // div signals
    // logic [inst_a_width-1 : 0] quotient_X;
    // logic [inst_a_width-1 : 0] remainder_X;
    // logic               divide_by_0_X;

    logic [inst_a_width-1 : 0] quotient_Y;
    logic [inst_a_width-1 : 0] remainder_Y;
    logic               divide_by_0_Y;
    logic               result_v;
    logic overflow;
    logic instr_ready;

    // stage registers
 

    rs_mult_ent_t   instr_pkt_in_stage_regs [num_stages - 1];

    assign inst_en = !stall;
    assign inst_rst_n = '0;
    assign instr_ready = div_ent.instr_pkt.i_valid && valid;
    // assign done = (counter >= latency);
    // assign occupied = !done and ;

    // always_ff @(posedge clk) begin
    //     if (rst)
    //         counter <= 0;
    //     else if (valid)
    //         counter <= 4;
    //     else if (counter > 0)
    //         counter <= counter - 1;
    // end 

    always_ff @(posedge clk) begin
        if (rst) begin
            for(integer i = 0; i < num_stages -1; i++) begin
                instr_pkt_in_stage_regs[i] <= '0;
            end
        end
        else begin
            if (instr_ready)
                instr_pkt_in_stage_regs[0] <= div_ent; 
            else 
                instr_pkt_in_stage_regs[0] <= '0;

            for(integer i = 0; i < num_stages -2; i++) begin
            
                instr_pkt_in_stage_regs[i + 1] <= instr_pkt_in_stage_regs[i];
            end
        end
    end

    always_comb begin
        // Default values
        signed_rs1 = ({{{div_ent.reg_pkt.rs1_data[31]}}, div_ent.reg_pkt.rs1_data});
        signed_rs2 = ({{{div_ent.reg_pkt.rs2_data[31]}}, div_ent.reg_pkt.rs2_data});
        unsigned_rs1 = ({{1'b0}, div_ent.reg_pkt.rs1_data});
        unsigned_rs2 = ({{1'b0}, div_ent.reg_pkt.rs2_data});

        inst_TC = '0;
        inst_a = '0;
        inst_b = '0;

        if (instr_ready) begin
            unique case (div_ent.instr_pkt.i_funct3)
                div_f3_div: begin // DIV (signed // signed)
                    inst_a = signed_rs1;
                    inst_b = signed_rs2;
                    // instr_pkt_in.overflow = (inst_a[31:0] == 32'h80000000) && (inst_b[31:0] == '1);
                    // inst_TC = 1'b1;
                end
                div_f3_rem: begin // REM (signed % signed)
                    inst_a = signed_rs1;
                    inst_b = signed_rs2;
                    // overflow = (inst_a[31:0] == 32'h80000000) && (inst_b[31:0] == '1);
                    // inst_TC = 1'b1;
                end
                div_f3_divu: begin // DIVU (unsigned // unsigned)
                    inst_a = unsigned_rs1;
                    // inst_b = unsigned'(unsigned_rs2);
                    inst_b[31:0] = div_ent.reg_pkt.rs2_data;
                    inst_b[32] = '0;
                    // inst_TC = 1'b1;
                end
                div_f3_remu: begin // REMU (unsigned % unsigned)
                    inst_a = unsigned_rs1;
                    inst_b[31:0] = div_ent.reg_pkt.rs2_data;
                    inst_b[32] = '0;
                    // inst_TC = 1'b1;
                end

                default: begin
                    inst_a = '0;
                    inst_b = '0;
                    inst_TC = '0;
                end
            endcase
        end
     
    end


always_comb begin 

        div_ent_out = instr_pkt_in_stage_regs[num_stages - 2];

        signed_rs1_out = ({{{div_ent_out.reg_pkt.rs1_data[31]}}, div_ent_out.reg_pkt.rs1_data});
        signed_rs2_out = ({{{div_ent_out.reg_pkt.rs2_data[31]}}, div_ent_out.reg_pkt.rs2_data});
        result = '0;
        result_v = '1;
        if (div_ent_out.instr_pkt.i_valid) begin
            unique case (div_ent_out.instr_pkt.i_funct3)
                div_f3_div: begin // DIV (signed // signed)
                    result_v = '1;
                    overflow = (signed_rs1_out[31:0] == 32'h80000000) && (signed_rs2_out[31:0] == '1);
                    if (overflow)
                        result = signed_rs1_out[31:0];
                    else if (!divide_by_0_Y)
                        result = quotient_Y[31:0];
                    else 
                        result = '1;
                end
                div_f3_rem: begin // REM (signed % signed)
                    result_v = '1;
                    overflow = (signed_rs1_out[31:0] == 32'h80000000) && (signed_rs2_out[31:0] == '1);
                    if (overflow)
                        result = '0;
                    else if (!divide_by_0_Y)
                        result = remainder_Y[31:0];
                    else 
                        result = signed_rs1_out[31:0];
                end
                div_f3_divu: begin // DIVU (unsigned // unsigned)
                    result_v = '1;
                    if (!divide_by_0_Y)
                        result = quotient_Y[31:0];
                    else 
                        result = '1;
                end
                div_f3_remu: begin // REMU (unsigned % unsigned)
                    result_v = '1;
                    if (!divide_by_0_Y)
                        result = remainder_Y[31:0];
                    else 
                        result = signed_rs1_out[31:0];
                end

                default: begin
                    result = '0;
                    result_v = '0;
                end
            endcase
        end 
        done = div_ent_out.instr_pkt.i_valid; //&& (counter >= latency);

        occupied = '0;
        if (done && div_ent_out.reg_pkt.i_use_rd) begin
            div_ent_out.reg_pkt.rd_valid = result_v;
            rd_data_out     = result;
        end
        else begin
            div_ent_out.reg_pkt.rd_valid = '0;
            rd_data_out     = '0;
        end
    end


    // // Instance of DW02_mult
    // DW02_mult #(inst_a_width, inst_b_width)
    //     MUL1 ( .A(inst_a), .B(inst_b), .TC(inst_TC), .PRODUCT(PRODUCT_inst) );



    // Instance of DW_mult_pipe
    // DW_mult_pipe #(inst_a_width, inst_b_width, inst_num_stages,
    //                 inst_stall_mode, inst_rst_mode, inst_op_iso_mode) 
    //     U1 (.clk(clk),   .rst_n(!rst),   .en(inst_en),
    //         .tc(inst_TC),   .a(inst_a),   .b(inst_b), 
    //         .product(PRODUCT_inst) );


    // // instance of DW_div with TC=0
    // DW_div #(inst_a_width, inst_b_width, 0, 1)
    //     DIV_X (.a(inst_a), .b(inst_b),
    //         .quotient(quotient_X), .remainder(remainder_X),
    //         .divide_by_0(divide_by_0_X));

    // // instance of DW_div with TC=1
    // DW_div #(inst_a_width, inst_b_width, 1, 1)
    //     DIV_Y (.a(inst_a), .b(inst_b),
    //         .quotient(quotient_Y), .remainder(remainder_Y),
    //         .divide_by_0(divide_by_0_Y));



    // Instance of DW_div_pipe
    // DW_div_pipe #(inst_a_width,
    // inst_b_width,
    // 0, inst_rem_mode,
    // inst_num_stages,
    // inst_stall_mode,
    // inst_rst_mode,
    // inst_op_iso_mode)
    // DIV_X (.clk(clk),
    // .rst_n(!rst),
    // .en(inst_en),
    // .a(inst_a),
    // .b(inst_b),
    // .quotient(quotient_X), .remainder(remainder_X),
    // .divide_by_0(divide_by_0_X) );

    // Instance of DW_div_pipe
    DW_div_pipe #(inst_a_width,
    inst_b_width,
    1, inst_rem_mode,
    inst_num_stages,
    inst_stall_mode,
    inst_rst_mode,
    inst_op_iso_mode)
    DIV_Y (.clk(clk),
    .rst_n(!rst),
    .en(inst_en),
    .a(inst_a),
    .b(inst_b),
    .quotient(quotient_Y), .remainder(remainder_Y),
    .divide_by_0(divide_by_0_Y) );

endmodule : func_div_i