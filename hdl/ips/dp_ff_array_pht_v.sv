module dp_ff_array_pht_v #(
            parameter               S_INDEX     = 4,
            parameter               WIDTH       = 1
)(
    input   logic                   clk0,
    input   logic                   rst0,
    input   logic                   csb0,
    input   logic                   web0,
    input   logic   [S_INDEX-1:0]   addr0,
    input   logic   [WIDTH-1:0]     din0,
    output  logic   [WIDTH-1:0]     dout0,
    input   logic                   csb1,
    input   logic                   web1,
    input   logic   [S_INDEX-1:0]   addr1,
    input   logic   [WIDTH-1:0]     din1,
    output  logic   [WIDTH-1:0]     dout1
);

            localparam              NUM_SETS    = 2**S_INDEX;

            logic   [WIDTH-1:0]     internal_array [NUM_SETS];

    always_ff @(posedge clk0) begin
        if (rst0) begin
            for (integer i = 0; i < NUM_SETS; i++) begin
                internal_array[i] <= '0;
            end
        end else begin
            if (!csb0) begin
                if (!web0)
                    internal_array[addr0] <= din0;
            end else if (!csb1) begin
                if (!web1)
                    internal_array[addr1] <= din1;
            end
        end
        dout0 <= internal_array[addr0];
        dout1 <= internal_array[addr1];
    end

    always_comb begin
        // dout0 = internal_array[addr0];
        // dout1 = internal_array[addr1];
    end

endmodule : dp_ff_array_pht_v
