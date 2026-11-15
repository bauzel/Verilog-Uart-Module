module uart_tx #(parameter CLKS_PER_BIT = 234) (
  input        clk,
  input        rst,
  input  [7:0] data,
  input        start,
  output reg   tx,
  output       busy
);
  localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
  reg [1:0]  state;
  reg [15:0] cnt;
  reg [2:0]  bit_idx;
  reg [7:0]  shreg;

  assign busy = (state != IDLE);

  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE; tx <= 1'b1; cnt <= 0; bit_idx <= 0;
    end else case (state)
      IDLE: begin
        tx <= 1'b1; cnt <= 0; bit_idx <= 0;
        if (start) begin shreg <= data; tx <= 1'b0; state <= START; end
      end
      START: begin
        if (cnt == CLKS_PER_BIT-1) begin cnt <= 0; tx <= shreg[0]; state <= DATA; end
        else cnt <= cnt + 1;
      end
      DATA: begin
        if (cnt == CLKS_PER_BIT-1) begin
          cnt <= 0;
          if (bit_idx == 7) begin tx <= 1'b1; state <= STOP; end
          else begin bit_idx <= bit_idx + 1; tx <= shreg[bit_idx + 1]; end
        end else cnt <= cnt + 1;
      end
      STOP: begin
        if (cnt == CLKS_PER_BIT-1) begin cnt <= 0; state <= IDLE; end
        else cnt <= cnt + 1;
      end
    endcase
  end
endmodule