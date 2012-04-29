`default_nettype none
`timescale 1ns / 1ps

// Main board module.
module s6atlys(
  // Global clock
  input  wire        CLK_100M,
  
  // onboard HDMI OUT
  //output wire        HDMIOUTCLKP,
  //output wire        HDMIOUTCLKN,
  //output wire        HDMIOUTD0P,
  //output wire        HDMIOUTD0N,
  //output wire        HDMIOUTD1P,
  //output wire        HDMIOUTD1N,
  //output wire        HDMIOUTD2P,
  //output wire        HDMIOUTD2N,
  //output wire        HDMIOUTSCL,
  //output wire        HDMIOUTSDA,
  
  // LEDs
  output wire  [7:0] LED,
  
  // Switches
  input  wire  [7:0] SW,
  
  // Buttons
  input  wire  [5:0] BTN
);

  //
  // Initialize outputs -- remove these when they're actually used
  //
  
  // Audio output
  //assign AUD_L = 0;
  //assign AUD_R = 0;
  
  // VGA output
  //assign VGA_R = 0;
  //assign VGA_G = 0;
  //assign VGA_B = 0;
  //assign VGA_HSYNC = 0;
  //assign VGA_VSYNC = 0;
  
  //
  // Clocks (GameBoy clock runs at ~4.194304 MHz)
  // 
  // FPGABoy runs at 33.5 MHz, mostly to simplify the video controller.
  //  Certain cycle sensitive modules, such as the CPU and Timer are
  //  internally clocked down to the GameBoy's normal speed.
  //
  
  // Core Clock: 33.5 MHz (33.3333 MHz)
  wire coreclk, core_clock;
  DCM_SP core_clock_dcm (.CLKIN(CLK_100M), .CLKFX(coreclk), .RST(1'b0));
  defparam core_clock_dcm.CLKFX_DIVIDE = 6;
  defparam core_clock_dcm.CLKFX_MULTIPLY = 2;
  defparam core_clock_dcm.CLK_FEEDBACK = "NONE";
  BUFG core_clock_buf (.I(coreclk), .O(core_clock));
  
  // TODO: HDMI Clocks
  //  No idea what these look like yet.
  
  // TODO: Debug Clock 
  //  The clock should mux between the core clock and a switch based 
  //  debug clock to allow a simple method of stepping through instructions.
  
  // Game Clock
  wire clock;
  assign clock = core_clock;
  
  // Initial Reset
  wire reset_init, reset;
  SRL16 reset_sr(.D(1'b0), .CLK(CLK_100M), .Q(reset_init),
                 .A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1));
  defparam reset_sr.INIT = 16'hFFFF;
  
  // Power Button
  wire reset_sync;
  debounce debounce_reset_sync(reset_init, core_clock, !SW[7], reset_sync);
  assign reset = (reset_init || reset_sync);
  
  //
  // GameBoy
  //
  
  wire [15:0] A;
  wire [7:0] Di;
  wire [7:0] Do;
  wire wr_n, rd_n, cs_n;
  
  wire [15:0] A_video;
  wire [7:0] Di_video;
  wire [7:0] Do_video;
  wire wr_video_n, rd_video_n, cs_video_n;
  
  wire [1:0] pixel_data;
  wire pixel_clock;
  wire pixel_latch;
  wire hsync, vsync;
  
  wire [3:0] joypad_data;
  wire [1:0] joypad_sel;
  
  wire audio_left, audio_right;
  
  gameboy gameboy (
    .clock(clock),
    .reset(reset),
    .reset_init(reset_init),
    .A(A),
    .Di(Di),
    .Do(Do),
    .wr_n(wr_n),
    .rd_n(rd_n),
    .cs_n(cs_n),
    .A_video(A_video),
    .Di_video(Di_video),
    .Do_video(Do_video),
    .wr_video_n(wr_video_n),
    .rd_video_n(rd_video_n),
    .cs_video_n(cs_video_n),
    .pixel_data(pixel_data),
    .pixel_clock(pixel_clock),
    .pixel_latch(pixel_latch),
    .hsync(hsync),
    .vsync(vsync),
    .joypad_data(joypad_data),
    .joypad_sel(joypad_sel),
    .audio_left(audio_left),
    .audio_right(audio_right),
    // debug output
    .dbg_led(LED)
  );
  
  assign Di = 8'b0;
  assign Di_video = 8'b0;
  assign joypad_data = 4'b0;
  
endmodule
  
////////////////////////////////////////////////////////////////////////////////
//
// 6.111 FPGA Labkit -- Debounce/Synchronize module
//
//
// Use your system clock for the clock input to produce a synchronous,
// debounced output
//
////////////////////////////////////////////////////////////////////////////////

module debounce (reset, clock, noisy, clean);
  parameter DELAY = 1000000;   // .01 sec with a 100Mhz clock
  input reset, clock, noisy;
  output clean;
  
  reg [18:0] count;
  reg new, clean;
  
  always @(posedge clock)
    if (reset)
    begin
      count <= 0;
      new <= noisy;
      clean <= noisy;
    end
    else if (noisy != new)
    begin
      new <= noisy;
      count <= 0;
    end
    else if (count == DELAY)
      clean <= new;
    else
      count <= count+1;

endmodule
