    longint timeout;
    initial begin
        $value$plusargs("TIMEOUT_ECE411=%d", timeout);
        $display(timeout);
    end

    mem_itf_banked mem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(mem_itf));
    // random_tb random_tb(.itf(mem_itf)); // For randomized testing
    
    mon_itf #(.CHANNELS(8)) mon_itf(.*);
    monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));

    cpu dut(
        .clk            (clk),
        .rst            (rst),

        .bmem_addr  (mem_itf.addr  ),
        .bmem_read  (mem_itf.read  ),
        .bmem_write (mem_itf.write ),
        .bmem_wdata (mem_itf.wdata ),
        .bmem_ready (mem_itf.ready ),
        .bmem_raddr (mem_itf.raddr ),
        .bmem_rdata (mem_itf.rdata ),
        .bmem_rvalid(mem_itf.rvalid)
    );

    `include "rvfi_reference.svh"

    // BR PREDICTIONS
    real correct_predictions;
    real incorrect_predictions;
    real total_predictions;

    integer n_taken;
    integer n_not_taken;
    integer n_br_predictions;

    integer n_jal_instructions;

    always @(posedge clk) begin
        if (mon_itf.halt) begin
            n_jal_instructions      = integer'(dut.n_jal_instructions);
            n_br_predictions        = integer'(dut.br_predictor.n_br_predictions);
            n_taken                 = integer'(dut.br_predictor.n_taken);
            n_not_taken             = integer'(dut.br_predictor.n_not_taken);
            incorrect_predictions   = dut.br_predictor.n_incorrect_pred;
            correct_predictions     = dut.br_predictor.n_correct_pred;
            total_predictions       = correct_predictions + incorrect_predictions;
            if (total_predictions != '0) begin
                $display("BRANCH PREDICT ACCURACY:   %f%%", (correct_predictions/total_predictions)*100);
                $display("BRANCHES TAKEN #:          %0d", n_taken);
                $display("BRANCHES NOT TAKEN #:      %0d", n_not_taken);
                $display("BRANCHES TOTAL #:          %0d", total_predictions);
                $display("BR PREDICTIONS FLUSHED:    %0d", n_br_predictions - total_predictions);
            end
            $display("JAL INSTRUCTIONS #:        %0d", n_jal_instructions);
            $display();
            $finish;
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        if (mem_itf.error != 0 || mon_itf.error != 0) begin
            $fatal;
        end

        timeout <= timeout - 1;
    end
    