module top_tb;

    timeunit 1ps;
    timeprecision 1ps;

    import rv32i_types::*;

    int clock_half_period_ps;
    initial begin
        $value$plusargs("CLOCK_PERIOD_PS_ECE411=%d", clock_half_period_ps);
        clock_half_period_ps = clock_half_period_ps / 2;
    end

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;
    bit rst;

    // QUEUE TESTING
    localparam  WIDTH       = 4;
    localparam  DEPTH       = 4;
    localparam  IDX_WIDTH   = $clog2(DEPTH);

    localparam  NUM_TESTS   = 5000;
    int tests_failed = 0;
    int tests_passed = 0;

    typedef struct packed {
        logic                   inverse;    // 1=use inverse queue

        logic                   enqueue;
        logic                   dequeue;
        logic   [WIDTH-1:0]     data_in;
        logic   [IDX_WIDTH-1:0] din_idx;

        logic   [IDX_WIDTH-1:0] read_idx;
        logic   [WIDTH-1:0]     read_data;
        logic                   write_en;
        logic   [IDX_WIDTH-1:0] write_idx;
        logic   [WIDTH-1:0]     write_data;

        logic	                full;
        logic                   empty;
        logic   [WIDTH-1:0]     data_out;
        logic   [IDX_WIDTH-1:0] dout_idx;
    } q_port_t;

    // DUT ports

    // QUEUE
    logic                   enqueue;
    logic	                dequeue;
    logic   [WIDTH-1:0]     data_in;
    logic   [IDX_WIDTH-1:0] din_idx;

    logic   [IDX_WIDTH-1:0] read_idx;
    logic   [WIDTH-1:0]     read_data;

    logic                   write_en;
    logic   [IDX_WIDTH-1:0] write_idx;
    logic   [WIDTH-1:0]     write_data;

    logic	                full;
    logic                   empty;
    logic   [WIDTH-1:0]     data_out;
    logic   [IDX_WIDTH-1:0] dout_idx;

    // INVERSE QUEUE
    logic                   inv_enqueue;
    logic	                inv_dequeue;
    logic   [WIDTH-1:0]     inv_data_in;
    logic   [IDX_WIDTH-1:0] inv_din_idx;

    logic   [IDX_WIDTH-1:0] inv_read_idx;
    logic   [WIDTH-1:0]     inv_read_data;
    logic                   inv_write_en;
    logic   [IDX_WIDTH-1:0] inv_write_idx;
    logic   [WIDTH-1:0]     inv_write_data;

    logic	                inv_full;
    logic                   inv_empty;
    logic   [WIDTH-1:0]     inv_data_out;
    logic   [IDX_WIDTH-1:0] inv_dout_idx;

    assign  inv_read_idx    = '0;
    assign  inv_write_en    = '0;
    assign  inv_write_idx   = '0;
    assign  inv_write_data  = '0;
    assign  read_idx    = '0;
    assign  write_en    = '0;
    assign  write_idx   = '0;
    assign  write_data  = '0;

    q_port_t qp;
    q_port_t qp_inv;
    logic [WIDTH-1:0] expected_q[$:(DEPTH-1)];    // gold queue (dynamic size)
    logic [WIDTH-1:0] expected_q_inv[$:(DEPTH-1)];
    logic [WIDTH-1:0] gold_data_out;
    logic [WIDTH-1:0] rand_n;

    queue_i #(.WIDTH(WIDTH), .DEPTH(DEPTH)) queue (
        .*
    );

    queue_inverted_i #(.WIDTH(WIDTH), .DEPTH(DEPTH)) queue_inv (
            .clk        (clk),
            .rst        (rst),
            .enqueue    (inv_enqueue),
            .dequeue    (inv_dequeue),
            .data_in    (inv_data_in),
            .din_idx    (inv_din_idx),

            .read_idx   (inv_read_idx),
            .read_data  (inv_read_data),
            .write_en   (inv_write_en),
            .write_idx  (inv_write_idx),
            .write_data (inv_write_data),

            .full       (inv_full),
            .empty      (inv_empty),
            .data_out   (inv_data_out),
            .dout_idx   (inv_dout_idx)
        );

    task drive_queue(q_port_t qp, logic en);
        // @(posedge clk);
        if (!qp.inverse) begin  // use NORMAL queue
            if (en) begin
                enqueue  <= qp.enqueue; // non-blocking: enqueue gets CURRENT data
                dequeue  <= qp.dequeue;
                data_in  <= qp.data_in;
            end
            qp.data_out  = data_out;    // blocking: output is combinational, gets queue output before next clk edge
            qp.full      = full;
            qp.empty     = empty;
        end else begin          // use INVERSED queue
            if (en) begin
                inv_enqueue  <= qp.enqueue;
                inv_dequeue  <= qp.dequeue;
                inv_data_in  <= qp.data_in;
            end
            qp.data_out  = inv_data_out;
            qp.full      = inv_full;
            qp.empty     = inv_empty;
        end
        @(posedge clk);
        enqueue <= '0;
        dequeue <= '0;
        inv_enqueue <= '0;
        inv_dequeue <= '0;

    endtask : drive_queue

    task test_check_empty(q_port_t qp);
        if (qp.inverse) begin
            if (inv_full || !inv_empty) begin
                $display("INCORRECT: queue says not empty");
                tests_failed++;
            end else tests_passed++;
        end else begin
            if (full || !empty) begin
                $display("INCORRECT: queue says not empty");
                tests_failed++;
            end else tests_passed++;
        end
    endtask : test_check_empty

    task test_check_full(q_port_t qp);
        if (qp.inverse) begin
            if (!inv_full || inv_empty) begin
                $display("INCORRECT: queue says not full");
                tests_failed++;
            end else tests_passed++;
        end else begin
            if (!full || empty) begin
                $display("INCORRECT: queue says not full");
                tests_failed++;
            end else tests_passed++;
        end
    endtask : test_check_full

    task test_empty_out_queue(q_port_t qp, logic [WIDTH-1:0] expected_queue[$:(DEPTH-1)]);
        // @(posedge clk);
        for (integer i = 0; i < DEPTH; i++) begin
            if (expected_queue.size() == 0) begin
                test_check_empty(qp);
                break;
            end
            qp.enqueue  = '0;
            qp.dequeue  = '1;
            drive_queue(qp, '1);

            // check data_out
            gold_data_out = expected_queue.pop_front();

            if (qp.inverse) begin
                if (inv_data_out != gold_data_out) begin
                    $display("INCORRECT data out: DUT=0x%0h, GOLD=0x%0h", inv_data_out, gold_data_out);
                    tests_failed++;
                end else tests_passed++;
            end else begin
                if (data_out != gold_data_out) begin
                    $display("INCORRECT data out: DUT=0x%0h, GOLD=0x%0h", data_out, gold_data_out);
                    tests_failed++;
                end else tests_passed++;
            end
        end
        @(posedge clk);
    endtask : test_empty_out_queue

    task test_fill_up_queue(q_port_t qp, logic [WIDTH-1:0] expected_queue[$:(DEPTH-1)], integer n);
        // @(posedge clk);
        for (integer i = 0; i < n; i++) begin
            if (expected_queue.size() == DEPTH) begin
                test_check_full(qp);
                break;
            end
            std::randomize(rand_n);
            qp.data_in = WIDTH'(rand_n);
            qp.enqueue  = '1;
            qp.dequeue  = '0;
            drive_queue(qp, '1);

            expected_queue.push_back(qp.data_in);
        end
        @(posedge clk);
    endtask : test_fill_up_queue

    // Test random operations
    int op_count;
    int j;
    task test_random_operations(q_port_t qp, logic [WIDTH-1:0] expected_queue[$:(DEPTH-1)]);

        enqueue = '0;
        dequeue = '0;
        inv_enqueue = '0;
        inv_dequeue = '0;

        // expected queue needs to be set before hand

        op_count = 0;

        while (op_count < NUM_TESTS) begin
            // qp          = '0;
            qp.enqueue  = '0;
            qp.dequeue  = '0;
            qp.write_en = '0;
            // Randomly choose operation
            case ($urandom_range(0, 2))
                0: begin  // Enqueue
                    if (/*!full*/ expected_queue.size() < DEPTH) begin
                        std::randomize(rand_n);
                        qp.data_in = WIDTH'(rand_n);
                        qp.enqueue  = '1;
                        qp.dequeue  = '0;
                        drive_queue(qp, '1);

                        expected_queue.push_back(qp.data_in);
                        op_count++;
                    end
                end
                1: begin  // Dequeue
                    if (/*!empty*/ expected_queue.size() > 0) begin
                        qp.enqueue  = '0;
                        qp.dequeue  = '1;
                        drive_queue(qp, '1);

                        gold_data_out = expected_queue.pop_front();
                        if (data_out !== gold_data_out) begin
                            $display("FAIL: iteration=%0d, data out: DUT=0x%0h, GOLD=0x%0h", op_count, data_out, gold_data_out);
                            $display("data out: DUT=0x%0h, qp=0x%0h", data_out, qp.data_out);
                            tests_failed++;
                            break;
                        end else tests_passed++;
                        op_count++;
                    end
                end
                2: begin  // Enqueue+dequeue
                    std::randomize(rand_n);
                    qp.data_in = WIDTH'(rand_n);
                    qp.enqueue  = '1;
                    qp.dequeue  = '1;
                    drive_queue(qp, '1);
                    if (expected_queue.size() == 0) begin
                        expected_queue.push_back(qp.data_in);
                        gold_data_out = expected_queue.pop_front();
                    end else begin
                        gold_data_out = expected_queue.pop_front();
                        expected_queue.push_back(qp.data_in);
                    end
                    if (data_out !== gold_data_out) begin
                        $display("FAIL: iteration=%0d, data out: DUT=0x%0h, GOLD=0x%0h", op_count, data_out, gold_data_out);
                        $display("data out: DUT=0x%0h, qp=0x%0h", data_out, qp.data_out);
                        tests_failed++;
                        break;
                    end else tests_passed++;
                    op_count++;
                end
            endcase
        end
    endtask : test_random_operations

    task test_simultaneous_en_de(q_port_t qp);
        qp.enqueue  = '1;
        qp.dequeue  = '1;
        drive_queue(qp, '1);

        expected_q.push_back(qp.data_in);
        gold_data_out = expected_q.pop_front();
        if (data_out != gold_data_out) begin
            $display("INCORRECT data out: DUT=0x%0h, GOLD=0x%0h", data_out, gold_data_out);
            tests_failed++;
        end else tests_passed++;
    endtask : test_simultaneous_en_de

    task reset_duts();
        qp      = '0;
        qp_inv  = '0;
        qp_inv.inverse = 1'b1;

        expected_q = {};
        expected_q_inv = {};
        for (integer i = 0; i < DEPTH; i++) begin
            expected_q_inv.push_back(WIDTH'(i));
        end

        rst     = 1'b1;
        repeat (2) @(posedge clk);
        rst     = 1'b0;
        @(posedge clk);
    endtask : reset_duts

    task test_queue();
        reset_duts();
        @(posedge clk);

        std::randomize(rand_n);
        qp.data_in = WIDTH'(rand_n);
        test_simultaneous_en_de(qp);

        std::randomize(rand_n);
        qp.data_in = WIDTH'(rand_n);
        test_simultaneous_en_de(qp);

        /* QUEUE TESTING */

        // check empty
        if (full || !empty) begin
            $display("1INCORRECT: queue says not full");
            tests_failed++;
        end else tests_passed++;

        // FILL QUEUE
        for (integer i = 0; i < DEPTH; i++) begin
            std::randomize(rand_n);
            qp.data_in = WIDTH'(rand_n);
            qp.enqueue  = '1;
            qp.dequeue  = '0;
            drive_queue(qp, '1);

            expected_q.push_back(qp.data_in);
        end
        @(posedge clk);
        // check full
        if (!full || empty) begin
            $display("2INCORRECT: queue says not full");
            tests_failed++;
        end else tests_passed++;

        // enqueue while full, should be a nop
        std::randomize(rand_n);
        qp.data_in = WIDTH'(rand_n);
        qp.enqueue  = '1;
        qp.dequeue  = '0;
        drive_queue(qp, '1);

        // check full
        if (!full || empty) begin
            $display("3INCORRECT: queue says not full");
            tests_failed++;
        end else tests_passed++;

        // EMPTY OUT QUEUE
        for (integer i = 0; i < DEPTH; i++) begin
            qp.enqueue  = '0;
            qp.dequeue  = '1;
            drive_queue(qp, '1);

            // check data_out
            gold_data_out = expected_q.pop_front();
            if (data_out != gold_data_out) begin
                $display("INCORRECT data out: DUT=0x%0h, GOLD=0x%0h", data_out, gold_data_out);
                tests_failed++;
            end else tests_passed++;
        end
        @(posedge clk);
        // check empty
        if (full || !empty) begin
            $display("4INCORRECT: queue says not full");
            tests_failed++;
        end else tests_passed++;

        // FILL QUEUE halfway
        for (integer i = DEPTH/2; i > 0; i--) begin
            std::randomize(rand_n);
            qp.data_in = WIDTH'(rand_n);
            qp.enqueue  = '1;
            qp.dequeue  = '0;
            drive_queue(qp, '1);

            expected_q.push_back(qp.data_in);
        end

        // POP some entries, check them
        for (integer i = DEPTH/4; i > 0; i--) begin
            qp.enqueue  = '0;
            qp.dequeue  = '1;
            drive_queue(qp, '1);

            // check data_out
            gold_data_out = expected_q.pop_front();
            if (data_out != gold_data_out) begin
                $display("INCORRECT data out: DUT=0x%0h, GOLD=0x%0h", data_out, gold_data_out);
                tests_failed++;
            end else tests_passed++;
        end

        // FILL QUEUE halfway
        for (integer i = DEPTH/4; i > 0; i--) begin
            std::randomize(rand_n);
            qp.data_in = WIDTH'(rand_n);
            qp.enqueue  = '1;
            qp.dequeue  = '0;
            drive_queue(qp, '1);

            expected_q.push_back(qp.data_in);
        end 
        std::randomize(rand_n);
        qp.data_in = WIDTH'(rand_n);
        test_simultaneous_en_de(qp);

        std::randomize(rand_n);
        qp.data_in = WIDTH'(rand_n);
        test_simultaneous_en_de(qp);

        // POP remaining entries
        while(!empty) begin
            qp.enqueue  = '0;
            qp.dequeue  = '1;
            drive_queue(qp, '1);

            // check data_out
            gold_data_out = expected_q.pop_front();
            if (data_out != gold_data_out) begin
                $display("INCORRECT data out: DUT=0x%0h, GOLD=0x%0h", data_out, gold_data_out);
                tests_failed++;
            end else tests_passed++;
        end

        reset_duts();
        //expected_q = {};    // reset gold queue
        test_random_operations(qp, expected_q);
        enqueue = '0;
        dequeue = '0;
        repeat (2) @(posedge clk);
    endtask : test_queue

    task test_queue_inverted();
        reset_duts();
        // @(posedge clk);
        test_check_full(qp_inv);

        // enqueue while full, should be a nop
        std::randomize(rand_n);
        qp_inv.data_in = WIDTH'(rand_n);
        qp_inv.enqueue  = '1;
        qp_inv.dequeue  = '0;
        drive_queue(qp_inv, '1);

        // @(posedge clk);

        test_check_full(qp_inv);

        test_empty_out_queue(qp_inv, expected_q_inv);

        test_check_empty(qp_inv);   

        test_fill_up_queue(qp_inv, expected_q_inv, DEPTH);

        test_check_full(qp_inv);

        // reset_duts();
        // test_random_operations(qp_inv, expected_q_inv);
    endtask : test_queue_inverted

    task test_queue_new();
        reset_duts();

        test_check_empty(qp);

        test_fill_up_queue(qp, expected_q, DEPTH);

        test_check_full(qp);

        test_empty_out_queue(qp, expected_q);

        test_check_empty(qp);   

        test_fill_up_queue(qp, expected_q, DEPTH);

        test_check_full(qp);


        reset_duts();
        test_random_operations(qp, expected_q);
    endtask : test_queue_new

    // typedef struct packed {
    //     logic   [63:0]  order;

    //     // logic   [ROB_IDX_WIDTH - 1:0]   rob_idx;
    
    //     logic           i_valid;
    //     logic   [31:0]  i_addr;
    //     logic   [31:0]  i_addr_next;
    //     logic   [31:0]  i_instr;
    //     logic   [6:0]   i_opcode;
    //     logic   [2:0]   i_funct3;

    //     // func_unit_t     func_unit;

    //     // i_op_type_t     i_op_type;      // alu=0 or cmp=1
    //     // i_mem_op_t      i_mem_op;    // use opcode instead
    //     logic   [2:0]   alu_op;     // can condense these
    //     logic   [2:0]   cmp_op;

    //     logic           i_use_rd;
    //     logic           i_use_rs1;
    //     logic           i_use_rs2;
    //     logic           i_use_imm;
    //     // logic           i_use_dmemory;
    //     // logic           i_dmem_response;

    //     // logic           i_is_jump;
    //     // logic           i_is_branch;
    //     // logic           branch_taken;

    //     logic           rd_valid;
    //     // aaddr_t         rd_aaddr;
    //     // paddr_t         rd_paddr;
    //     logic   [31:0]  rd_data;

    //     logic           rs1_rdy;
    //     //logic           rs1_valid;
    //     // aaddr_t         rs1_aaddr;
    //     // paddr_t         rs1_paddr;
    //     logic   [31:0]  rs1_data;

    //     logic           rs2_rdy;
    //     //logic           rs2_valid;
    //     // aaddr_t         rs2_aaddr;
    //     // paddr_t         rs2_paddr;
    //     logic   [31:0]  rs2_data;

    //     logic   [31:0]  imm_data;

    // } instr_pkt_t;
    
    // instr_pkt_t     instr_pkt_in;
    // logic           done;
    // instr_pkt_t       instr_pkt_out;


    // func_mult mult_test(    
    //     .instr_pkt_in(instr_pkt_in),
    //     .done(done),
    //     .instr_pkt_out(instr_pkt_out));

    // task test_mult();
    //     instr_pkt_in.i_valid = '1;
    //     instr_pkt_in.i_funct3 = 3'b000;
    //     instr_pkt_in.i_use_rd = '1;
    //     instr_pkt_in.i_use_rs1 = '1;
    //     instr_pkt_in.i_use_rs2 = '1;
    //     instr_pkt_in.rs1_data = 'd5; // A
    //     instr_pkt_in.rs2_data = 'd7; // B

    //     if (done != '1 || instr_pkt_out.rd_valid != '1 || instr_pkt_out.rd_data != 'd35)
    //         $display("FAILED mult");
    //     else 
    //         $display("PASSED mult");


    // endtask : test_mult
    // comment if NOT testing queue
    // initial begin
    //     $fsdbDumpfile("dump.fsdb");
    //     $fsdbDumpvars(0, "+all");

    //     enqueue = '0;
    //     dequeue = '0;
    //     rst = 1'b1;
    //     repeat (2) @(posedge clk);
    //     rst = 1'b0;
    //     repeat (10) @(posedge clk);
    //     // test_queue();
    //     // test_queue_new();

    //     test_queue_inverted();

    //     // Report results
    //     $display("\n====== QUEUE TEST SUMMARY ======");
    //     $display("Tests Failed: %0d", tests_failed);
    //     $display("Tests Passed: %0d", tests_passed);
    //     if (tests_failed == 0) begin
    //         $display("   ALL TESTS PASSED!   \n");
    //     end

    //     $finish;
    // end


    // comment if testing queue
    initial begin
        $fsdbDumpfile("dump.fsdb");
        if ($test$plusargs("NO_DUMP_ALL_ECE411")) begin
            $fsdbDumpvars(0, dut, "+all");
            $fsdbDumpoff();
        end else begin
            $fsdbDumpvars(0, "+all");
        end
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;

        $display(" RS   BR      WIDTH   = %0d", RS_BR_WIDTH);
        $display(" RS   ALU     WIDTH   = %0d", RS_ALU_WIDTH);
        $display(" RS   MULT    WIDTH   = %0d", RS_ALU_WIDTH);
        $display(" RS   MEM     WIDTH   = %0d", RS_MEM_WIDTH);
        $display();
        $display(" ROB  QUEUE   WIDTH   = %0d", ROB_Q_WIDTH);
        $display(" PRF  WIDTH           = %0d", PRF_WIDTH);
    end
    `include "top_tb.svh"

endmodule
