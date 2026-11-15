`timescale 1ns/1ps
// uart_rx testbench: hattı BİZ süreriz (TX modülünden bağımsız), sonucu gereksinimlerle karşılaştırırız
module uart_rx_tb;
  localparam CPB = 16;

  reg        clk = 0, rst = 1, rx = 1;
  wire [7:0] data;
  wire       valid, frame_err;

  integer    errors = 0, valid_cnt = 0, ferr_cnt = 0, v0, f0;
  reg  [7:0] last_data = 8'h00;

  uart_rx #(.CLKS_PER_BIT(CPB)) dut (
    .clk(clk), .rst(rst), .rx(rx), .data(data), .valid(valid), .frame_err(frame_err));

  always #5 clk = ~clk;

  // İzleyici: her valid / frame_err darbesini sayar
  always @(posedge clk) begin
    if (valid)     begin valid_cnt <= valid_cnt + 1; last_data <= data; end
    if (frame_err) ferr_cnt <= ferr_cnt + 1;
  end

  task check(input ok, input [511:0] msg);
    begin
      if (!ok) begin errors = errors + 1; $display("FAIL: %0s", msg); end
    end
  endtask

  task send_bit(input b);
    begin rx = b; repeat (CPB) @(negedge clk); end
  endtask

  task send_frame(input [7:0] b, input stop);
    integer k;
    begin
      send_bit(1'b0);                                   // start
      for (k = 0; k < 8; k = k + 1) send_bit(b[k]);     // veri, LSB önce
      send_bit(stop);                                   // stop
    end
  endtask

  task idle(input [15:0] n);                            // n bit süresi boşta
    begin rx = 1'b1; repeat (n * CPB) @(negedge clk); end
  endtask

  task send_and_check(input [7:0] b);
    begin
      v0 = valid_cnt; f0 = ferr_cnt;
      send_frame(b, 1'b1);
      check(valid_cnt === v0 + 1, "RX-2/RX-3 tam olarak 1 valid darbesi bekleniyordu");
      check(last_data === b,      "RX-2 alinan byte yanlis");
      check(ferr_cnt  === f0,     "RX-2 saglam cerceve frame_err uretmemeli");
      if (valid_cnt === v0 + 1 && last_data === b && ferr_cnt === f0)
        $display("PASS: 0x%h alindi", b);
    end
  endtask

  initial begin
    $dumpfile("uart_rx.vcd");
    $dumpvars(0, uart_rx_tb);

    repeat (3) @(negedge clk);
    rst = 0;

    // RX-1: boştayken hiçbir şey olmamalı
    idle(5);
    check(valid_cnt === 0 && ferr_cnt === 0, "RX-1 bostayken valid/frame_err 0 olmali");

    // RX-2, RX-3: normal baytlar
    send_and_check(8'h55);
    send_and_check(8'h00);
    send_and_check(8'hFF);
    send_and_check(8'h01);
    send_and_check(8'h80);
    send_and_check(8'h96);
    send_and_check(8'h1B);

    // RX-4: stop biti 0 -> frame_err, valid yok
    v0 = valid_cnt; f0 = ferr_cnt;
    send_frame(8'h42, 1'b0);
    idle(3);
    check(ferr_cnt === f0 + 1, "RX-4 frame_err bekleniyordu");
    check(valid_cnt === v0,    "RX-4 hatali cerceve valid uretmemeli");
    $display("RX-4 tamamlandi");

    // RX-5: start ortasında biten kısa parazit çerçeve sayılmaz
    v0 = valid_cnt; f0 = ferr_cnt;
    rx = 1'b0; repeat (CPB/4) @(negedge clk);
    idle(3);
    check(valid_cnt === v0 && ferr_cnt === f0, "RX-5 parazit cerceve sayilmamali");
    send_and_check(8'hA7);                              // parazitten sonra toparlanma

    // RX-6: boşluksuz arka arkaya çerçeveler
    send_and_check(8'h3C);
    send_and_check(8'hC3);
    send_and_check(8'h0F);

    // RX-7: çerçeve ortasında reset
    v0 = valid_cnt; f0 = ferr_cnt;
    send_bit(1'b0); send_bit(1'b1); send_bit(1'b0);     // start + ilk iki bit
    rst = 1; rx = 1'b1;
    repeat (3) @(negedge clk);
    rst = 0;
    idle(3);
    check(valid_cnt === v0 && ferr_cnt === f0, "RX-7 reset sonrasi sahte cerceve olmamali");
    send_and_check(8'h2D);

    if (errors == 0) $display("uart_rx: TUM TESTLER GECTI");
    else             $display("uart_rx: %0d HATA", errors);
    $finish;
  end
endmodule
