`timescale 1ns/1ps
module uart_tx_tb;
  localparam CPB = 8;
  reg clk = 0, rst = 1, start = 0;
  reg [7:0] data = 0;
  wire tx, busy;
  integer errors = 0, busy_clks = 0, i, e0;
  reg [7:0] got;

  uart_tx #(.CLKS_PER_BIT(CPB)) dut (
    .clk(clk), .rst(rst), .data(data), .start(start), .tx(tx), .busy(busy));

  always #5 clk = ~clk;
  always @(posedge clk) if (busy) busy_clks <= busy_clks + 1;

  task check(input ok, input [511:0] msg);
    begin
      if (!ok) begin errors = errors + 1; $display("FAIL: %0s", msg); end
    end
  endtask

  task send_and_check(input [7:0] b);
    begin
      e0 = errors;
      busy_clks = 0;
      @(negedge clk); data = b; start = 1;
      @(negedge clk); start = 0;
      repeat (CPB/2) @(negedge clk);
      check(tx === 1'b0, "REQ-2 start biti 0 degil");
      check(busy === 1'b1, "REQ-6 gonderirken busy 1 olmali");
      for (i = 0; i < 8; i = i + 1) begin
        repeat (CPB) @(negedge clk);
        got[i] = tx;
      end
      check(got === b, "REQ-3 veri bitleri yanlis (once LSB)");
      repeat (CPB) @(negedge clk);
      check(tx === 1'b1, "REQ-4 stop biti 1 degil");
      wait (!busy);
      @(negedge clk);
      check(busy_clks === 10*CPB, "REQ-5 cerceve suresi yanlis");
      check(tx === 1'b1, "REQ-1 bostayken tx 1 olmali");
      if (errors == e0) $display("PASS: 0x%h gonderildi", b);
    end
  endtask

  initial begin
    $dumpfile("uart_tx.vcd");
    $dumpvars(0, uart_tx_tb);
    repeat (3) @(negedge clk);
    check(tx === 1'b1, "REQ-7 reset sirasinda tx 1 olmali");
    rst = 0;
    repeat (3) @(negedge clk);
    check(tx === 1'b1, "REQ-1 bostayken tx 1 olmali");

    send_and_check(8'h55);
    send_and_check(8'h00);
    send_and_check(8'hFF);
    send_and_check(8'hA5);
    send_and_check(8'h01);
    send_and_check(8'h80);

    // REQ-7: gonderim ortasinda reset
    @(negedge clk); data = 8'h00; start = 1;
    @(negedge clk); start = 0;
    repeat (CPB*3) @(negedge clk);
    rst = 1;
    repeat (2) @(negedge clk);
    check(tx === 1'b1, "REQ-7 reset tx yi 1 yapmali");
    check(busy === 1'b0, "REQ-7 reset sonrasi busy 0 olmali");
    rst = 0;
    repeat (3) @(negedge clk);

    if (errors == 0) $display("TUM TESTLER GECTI");
    else $display("%0d HATA VAR", errors);
    $finish;
  end
endmodule