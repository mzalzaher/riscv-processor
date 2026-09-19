module queue_i 
import rv32i_types::*;
#(
    parameter WIDTH     = 32,   // define a parameter for the data width of the register
	parameter DEPTH     = 8,

    localparam IDX_WIDTH = log2(DEPTH)

) (
	input  	logic	    			clk, 
	input  	logic	    		  	rst, 

	input  	logic	    		  	enqueue,
    input  	logic	    		  	dequeue,
	input  	logic   [WIDTH-1:0]    	data_in, // set input/output size based on parameter
    output  logic   [IDX_WIDTH-1:0] din_idx,

    input   logic   [IDX_WIDTH-1:0] read_idx,
    output  logic   [WIDTH-1:0]     read_data,

    input   logic                   write_en,
    input   logic   [IDX_WIDTH-1:0] write_idx,
    input   logic   [WIDTH-1:0]     write_data,


	output 	logic					full,
    output  logic                   empty,

	output 	logic   [WIDTH-1:0] 	data_out,
    output  logic   [IDX_WIDTH-1:0] dout_idx
);

	logic [WIDTH-1:0]   queue_table[DEPTH];

    logic [IDX_WIDTH:0] tail;
    logic [IDX_WIDTH:0] head;

	always_comb begin
        full    = head[IDX_WIDTH] != tail[IDX_WIDTH] &&
                head[IDX_WIDTH-1:0] == tail[IDX_WIDTH-1:0]
                && !(dequeue && !enqueue);
        empty   = head == tail
                && !(enqueue && !dequeue);   // if just enqueueing, queue is not empty

        read_data = queue_table[read_idx];

        dout_idx = head[IDX_WIDTH-1:0];
        din_idx  = tail[IDX_WIDTH-1:0];
        if (enqueue && dequeue && empty)
            data_out = data_in;
        else
            data_out = queue_table[head[IDX_WIDTH-1:0]];
	end

	always_ff @(posedge clk) begin
        if(rst) begin
            // for (integer i = 0; i < DEPTH; i++) begin
            //     queue_table[i] <= '0;
            // end
            tail <= '0;
            head <= '0;
        end else begin
            if (write_en) begin
                queue_table[write_idx] <= write_data;
            end
            
            if (enqueue && dequeue) begin
                if (empty) begin
                    queue_table[tail[IDX_WIDTH-1:0]] <= data_in;
                end
                else begin
                    queue_table[tail[IDX_WIDTH-1:0]] <= data_in;
                    tail <= tail + 1'b1;
                    head <= head + 1'b1;
                end
            end else if (enqueue && !full) begin
                queue_table[tail[IDX_WIDTH-1:0]] <= data_in;
                tail <= tail + 1'b1;
            end
            else if (dequeue && !empty) begin
                head <= head + 1'b1;
            end
        end
	end
endmodule : queue_i
