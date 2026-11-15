# UART 8N1 transmitter and receiver (Verilog)

A small, parameterised UART (8 data bits, no parity, 1 stop bit) written in Verilog,
with requirement-tagged, self-checking testbenches for Icarus Verilog.

**Status:** simulation only. Not synthesised, not tested on hardware.


## Files

```
rtl/uart_tx.v     transmitter
rtl/uart_rx.v     receiver
tb/uart_tx_tb.v   transmitter testbench
tb/uart_rx_tb.v   receiver testbench
```

## Interface

Both modules take `CLKS_PER_BIT` = clock frequency / baud rate
(e.g. 27 MHz / 115200 ≈ 234 for a 27 MHz oscillator). Reset is synchronous, active-high.

| Module | Port | Dir | Description |
|---|---|---|---|
| `uart_tx` | `data[7:0]` | in | byte to send |
| | `start` | in | one-clock pulse: begin sending (only accepted while idle) |
| | `tx` | out | serial line, idles high |
| | `busy` | out | high while a frame is being sent |
| `uart_rx` | `rx` | in | serial line (asynchronous to `clk`) |
| | `data[7:0]` | out | last received byte |
| | `valid` | out | one-clock pulse: a good byte is in `data` |
| | `frame_err` | out | one-clock pulse: stop bit was 0, byte discarded |

## Design notes

- **Transmitter:** four-state FSM (IDLE, START, DATA, STOP) with a bit-period counter; LSB first.
- **Receiver:** the `rx` input passes through a two-flip-flop synchroniser before use.
  On a falling edge it waits half a bit and re-checks the line (a short glitch is rejected),
  then samples each bit in the middle of its period and shifts it into a register
  (`{rx_s, shreg[7:1]}`, so the first bit received ends up in bit 0).
  The stop bit is checked in the middle of its period.

## Requirements and verification

Each testbench check prints the requirement ID when it fails.

**Transmitter** (`tb/uart_tx_tb.v`, `CLKS_PER_BIT = 8`)

| ID | Requirement | Checked by |
|---|---|---|
| REQ-1 | `tx` is 1 when idle | before and after every frame |
| REQ-2 | after `start`, `tx` is 0 for one bit period (start bit) | sampled mid start bit |
| REQ-3 | 8 data bits follow, LSB first | bits sampled mid-bit and compared to the sent byte |
| REQ-4 | one bit period of `tx` = 1 (stop bit) | sampled mid stop bit |
| REQ-5 | frame length is exactly 10 x `CLKS_PER_BIT` clocks | cycles counted while `busy` |
| REQ-6 | `busy` is 1 during the frame, 0 afterwards | sampled mid start bit and after the frame |
| REQ-7 | reset forces `tx` = 1 and `busy` = 0, also mid-frame | reset applied mid-frame |

**Receiver** (`tb/uart_rx_tb.v`, `CLKS_PER_BIT = 16`; the line is driven by the testbench, not by `uart_tx`)

| ID | Requirement | Checked by |
|---|---|---|
| RX-1 | idle line: `valid` = 0, `frame_err` = 0 | 5 idle bit periods |
| RX-2 | a valid frame gives `data` = sent byte and `valid` = 1 | 7 byte values (00, 01, 1B, 55, 80, 96, FF) |
| RX-3 | `valid` lasts exactly one clock | exactly one pulse counted per frame |
| RX-4 | stop bit 0 gives `frame_err` = 1 and no `valid` | frame with stop bit 0 |
| RX-5 | a glitch shorter than half a start bit is not a frame; receiver recovers | short low pulse, then a good frame |
| RX-6 | back-to-back frames with no idle gap are all received | 3C, C3, 0F in a row |
| RX-7 | reset mid-frame does not produce a false frame | reset after 3 bits, then a good frame |

## Run

Requires [Icarus Verilog](https://steveicarus.github.io/iverilog/) (and optionally GTKWave).

```
iverilog -o tx_sim rtl/uart_tx.v tb/uart_tx_tb.v && vvp tx_sim
iverilog -o rx_sim rtl/uart_rx.v tb/uart_rx_tb.v && vvp rx_sim
```


## Known limitations

- Baud-rate tolerance (transmitter and receiver clocks differing) is **not tested**.
- No code or functional coverage is measured; the test cases are hand-picked scenarios.
- The testbench changes `rx` only on the falling clock edge, so it cannot exercise
  metastability; the synchroniser is a design measure that simulation cannot verify.
- `start` while `busy` is ignored by the design, but this behaviour is not tested.
- Not run on an FPGA.

## How this was made

I used Claude to learn the design and the testbenches while I was learning
RTL and verification. I used it for write some parts of the code and learn
about RTL and verification.

## License

MIT (see `LICENSE`).
