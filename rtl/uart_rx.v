`default_nettype none
// 8N1 UART alıcı (RX)
// Ayar: CLKS_PER_BIT = saat frekansı / baud  (27 MHz / 115200 ≈ 234)
module uart_rx #(parameter CLKS_PER_BIT = 234) (
  input  wire       clk,
  input  wire       rst,        // senkron, aktif-yüksek
  input  wire       rx,         // dışarıdan gelen hat (saatle ilgisiz!)
  output reg  [7:0] data,       // son alınan byte
  output reg        valid,      // byte hazır: 1 saat darbesi
  output reg        frame_err   // stop biti 1 değildi: 1 saat darbesi
);
  localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
  localparam HALF = CLKS_PER_BIT / 2;

  reg [1:0]  state;
  reg [15:0] cnt;
  reg [2:0]  bit_idx;
  reg [7:0]  shreg;

  // 1) Giriş senkronizörü: rx dış dünyadan geliyor, saatimize göre rastgele
  //    zamanda değişebilir. İki flip-flop'tan geçirerek güvenli hale getiriyoruz.
  reg rx_m, rx_s;
  always @(posedge clk) begin
    if (rst) begin rx_m <= 1'b1; rx_s <= 1'b1; end
    else     begin rx_m <= rx;   rx_s <= rx_m;  end
  end

  // 2) Durum makinesi
  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE; cnt <= 0; bit_idx <= 0; shreg <= 8'h00;
      data <= 8'h00; valid <= 1'b0; frame_err <= 1'b0;
    end else begin
      valid     <= 1'b0;      // varsayılan: darbe yok (her tıkta sıfırlanır)
      frame_err <= 1'b0;
      case (state)
        IDLE: begin
          cnt <= 0; bit_idx <= 0;
          if (rx_s == 1'b0) state <= START;       // düşen kenar: start biti olabilir
        end
        START: begin                              // start bitinin ORTASINA kadar say
          if (cnt == HALF - 1) begin
            cnt <= 0;
            if (rx_s == 1'b0) state <= DATA;      // hâlâ 0: gerçek start biti
            else              state <= IDLE;      // 1'e dönmüş: parazit, vazgeç
          end else cnt <= cnt + 1;
        end
        DATA: begin                               // her bitin ortasında oku
          if (cnt == CLKS_PER_BIT - 1) begin
            cnt   <= 0;
            shreg <= {rx_s, shreg[7:1]};          // yeni bit soldan girer, LSB sağa kayar
            if (bit_idx == 3'd7) state <= STOP;
            else bit_idx <= bit_idx + 1;
          end else cnt <= cnt + 1;
        end
        STOP: begin
          if (cnt == CLKS_PER_BIT - 1) begin
            cnt   <= 0;
            state <= IDLE;
            if (rx_s == 1'b1) begin data <= shreg; valid <= 1'b1; end
            else frame_err <= 1'b1;
          end else cnt <= cnt + 1;
        end
      endcase
    end
  end
endmodule
`default_nettype wire
