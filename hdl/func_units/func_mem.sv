module func_mem1_i
import rv32i_types::*;
(
    input   logic               rst,
    input   logic               clk, 
    input   rs_mem_ent_t       mem_ent,
    input   logic               valid,

    output  logic               occupied,
    output  logic               done,
    output  data_pkt_t          data_out,
    output  rs_mem_ent_t        mem_ent_out
);      // MEM1 FUNC UNIT

    logic instr_ready;
    logic [31:0] mem_shift;
    logic in_progress;
    logic in_progress_next;
    logic [31:0]  temp_addr;

    assign instr_ready = mem_ent.instr_pkt.i_valid && valid;
    assign occupied = instr_ready && !done;
    always_ff @(posedge clk) begin
        if (rst) begin
            in_progress <= '0;
        end
        else begin
            in_progress <= in_progress_next;
        end
    end

    always_comb begin
        mem_shift = '0;
        temp_addr  = '0;
        done = '0;
        data_out = '0;
        mem_ent_out = mem_ent;
        in_progress_next = '0;

        if (instr_ready && (mem_ent.instr_pkt.i_mem_op_type == LOAD)) begin
            // d_mem_addr = mem_ent.instr_pkt.rs1_data + mem_ent.instr_pkt.imm_data;
            // mem_shift = mem_ent.instr_pkt.rs1_data + mem_ent.instr_pkt.imm_data;
            temp_addr = mem_ent.reg_pkt.rs1_data + mem_ent.instr_pkt.imm_data;
            data_out.d_mem_addr = {temp_addr[31:2], 2'b00};
            mem_shift = mem_ent.reg_pkt.rs1_data + mem_ent.instr_pkt.imm_data;
            data_out.mem_shift = mem_shift[1:0];
            data_out.d_mem_wmask = '0;
            unique case (mem_ent.instr_pkt.i_funct3)
                load_f3_lb, load_f3_lbu: data_out.d_mem_rmask = 4'b0001 << mem_shift[1:0];
                load_f3_lh, load_f3_lhu: data_out.d_mem_rmask = 4'b0011 << mem_shift[1:0];
                load_f3_lw             : data_out.d_mem_rmask = 4'b1111;
                default                : data_out.d_mem_rmask = 4'b0000;
            endcase
            // d_mem_addr[1:0] = 2'd0;
            // in_progress_next = '1;
            done = '1;
        end
        else if (instr_ready && (mem_ent.instr_pkt.i_mem_op_type == STORE)) begin
            // Add store logic
            temp_addr = mem_ent.reg_pkt.rs1_data + mem_ent.instr_pkt.imm_data;
            data_out.d_mem_addr = {temp_addr[31:2], 2'b00};
            mem_shift = mem_ent.reg_pkt.rs1_data + mem_ent.instr_pkt.imm_data;
            data_out.mem_shift = mem_shift[1:0];
            data_out.d_mem_rmask = '0;
            unique case (mem_ent.instr_pkt.i_funct3)
                store_f3_sb: data_out.d_mem_wmask = 4'b0001 << mem_shift[1:0];
                store_f3_sh: data_out.d_mem_wmask = 4'b0011 << mem_shift[1:0];
                store_f3_sw: data_out.d_mem_wmask = 4'b1111;
                default    : data_out.d_mem_wmask = 4'b0000;
            endcase
            unique case (mem_ent.instr_pkt.i_funct3)
                store_f3_sb: data_out.d_mem_wdata[8 *mem_shift[1:0] +: 8 ] = mem_ent.reg_pkt.rs2_data[7 :0];
                store_f3_sh: data_out.d_mem_wdata[16*mem_shift[1]   +: 16] = mem_ent.reg_pkt.rs2_data[15:0];
                store_f3_sw: data_out.d_mem_wdata = mem_ent.reg_pkt.rs2_data;
                default    : data_out.d_mem_wdata = '0;
            endcase
            done = '1;
            
        end
    end


endmodule : func_mem1_i
