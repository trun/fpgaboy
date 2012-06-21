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
  input  wire  [5:0] BTN,
  
  // PMOD Connector
  inout  wire  [7:0] JB,
  
  // PMOD VmodMIB Connectors
  inout  wire  [7:0] VHDCIJA
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
  
  // Initial Reset
  wire reset_init, reset;
  SRL16 reset_sr(.D(1'b0), .CLK(CLK_100M), .Q(reset_init),
                 .A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1));
  defparam reset_sr.INIT = 16'hFFFF;
  
  //
  // Clocks (GameBoy clock runs at ~4.194304 MHz)
  // 
  // FPGABoy runs at 33.33 MHz, mostly to simplify the video controller.
  //  Certain cycle sensitive modules, such as the CPU and Timer are
  //  internally clocked down to the GameBoy's normal speed.
  //
  
  // Core Clock: 33.33 MHz
  wire coreclk, core_clock;
  DCM_SP core_clock_dcm (.CLKIN(CLK_100M), .CLKFX(coreclk), .RST(1'b0));
  defparam core_clock_dcm.CLKFX_DIVIDE = 6;
  defparam core_clock_dcm.CLKFX_MULTIPLY = 2;
  defparam core_clock_dcm.CLKDV_DIVIDE = 3.0;
  defparam core_clock_dcm.CLKIN_PERIOD = 10.000;
  BUFG core_clock_buf (.I(coreclk), .O(core_clock));
  
  // HDMI Clocks
  //  TODO: No idea what these look like yet.
  
  /*
  // OLED Clock 5.0 MHz (for PmodOLED)
  wire oledclk, oledsclk, oled_clock;
  DCM_SP oled_clock_dcm (.CLKIN(CLK_100M), .CLKFX(oledclk), .CLKFX180(oledsclk), .RST(1'b0));
  defparam oled_clock_dcm.CLKFX_DIVIDE = 20;
  defparam oled_clock_dcm.CLKFX_MULTIPLY = 2;
  defparam oled_clock_dcm.CLKDV_DIVIDE = 10.0;
  defparam oled_clock_dcm.CLKIN_PERIOD = 10.000;
  defparam oled_clock_dcm.CLKIN_DIVIDE_BY_2 = "TRUE";
  BUFG oled_clock_buf (.I(oledclk), .O(oled_clock));
  
  ODDR2 oled_clock_oddr2(
    .Q(VHDCIJA[3]),
    .C0(oledsclk),
    .C1(oledclk),
    .D0(1'b1),
    .D1(1'b0),
    .CE(1'b1),
    .S(1'b0),
    .R(1'b0)
  );
  */
  
  // Joypad Clock: 1 KHz
  wire pulse_1khz;
  reg  clock_1khz;
  divider#(.DELAY(33333)) div_1ms (
    .reset(reset_init),
    .clock(core_clock),
    .enable(pulse_1khz)
  );
  
  // CLS Clock: 200 Khz
  wire pulse_200khz;
  reg  clock_200khz;
  divider#(.DELAY(166)) div_5us (
    .reset(reset_init),
    .clock(core_clock),
    .enable(pulse_200khz)
  );
  
  //
  // Switches
  //   
  //   SW0-SW4 - Breakpoints Switches (Not Implemented)
  //   SW5 - Step Clock
  //   SW6 - Step Enable
  //   SW7 - Power (Reset)
  //
  
  wire reset_sync, step_sync, step_enable;
  debounce debounce_step_sync(reset_init, core_clock, !SW[5], step_sync);
  debounce debounce_step_enable(reset_init, core_clock, !SW[6], step_enable);
  debounce debounce_reset_sync(reset_init, core_clock, !SW[7], reset_sync);
  
  assign reset = (reset_init || reset_sync);
  
  // Game Clock
  wire clock;
  BUFGMUX clock_mux(.S(step_enable), .O(clock),
                    .I0(core_clock), .I1(step_sync));
  
  //
  // Buttons
  //
  // BTN0 - OLED Display Shutdown
  // BTN1-BTN5 - Not Implemented
  //
  
  wire shutdown_sync;
  debounce debounce_shutdown_sync(reset_init, core_clock, !BTN[0], shutdown_sync);
           
  //
  // PmodOLED Adapter
  //
  
  /*
  wire [7:0] oled_state;
  oled_spi oled(
    .reset(reset),
    .clock(oled_clock),
    .shutdown(shutdown_sync),
    .cs(VHDCIJA[0]),
    .sdin(VHDCIJA[1]),
    .dc(VHDCIJA[4]),
    .res(VHDCIJA[5]),
    .vbatc(VHDCIJA[6]),
    .vddc(VHDCIJA[7]),
    .state(oled_state)
  );
  */
  
  //
  // GameBoy
  //
  
  // GB <-> Cartridge + WRAM
  wire [15:0] A;
  wire [7:0] Di;
  wire [7:0] Do;
  wire wr_n, rd_n, cs_n;
  
  // GB <-> VRAM
  wire [15:0] A_vram;
  wire [7:0] Di_vram;
  wire [7:0] Do_vram;
  wire wr_vram_n, rd_vram_n, cs_vram_n;
  
  // GB <-> Display Adapter
  wire [1:0] pixel_data;
  wire pixel_clock;
  wire pixel_latch;
  wire hsync, vsync;
  
  // GB <-> Joypad Adapter
  wire [3:0] joypad_data;
  wire [1:0] joypad_sel;
  
  // GB <-> Audio Adapter
  wire audio_left, audio_right;
  
  // GB <-> CLS SPI
  wire [15:0] PC;
  wire [15:0] SP;
  wire [15:0] AF;
  wire [15:0] BC;
  wire [15:0] DE;
  wire [15:0] HL;
  
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
    .A_vram(A_vram),
    .Di_vram(Di_vram),
    .Do_vram(Do_vram),
    .wr_vram_n(wr_vram_n),
    .rd_vram_n(rd_vram_n),
    .cs_vram_n(cs_vram_n),
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
    .dbg_led(LED),
    .PC(PC),
    .SP(SP),
    .AF(AF),
    .BC(BC),
    .DE(DE),
    .HL(HL)
  );
  
  // Joypad Adapter
  joypad_snes_adapter joypad_adapter(
    .clock(clock_1khz),
    .reset(reset),
    .button_sel(joypad_sel),
    .button_data(joypad_data),
    .controller_data(JB[4]),
    .controller_clock(JB[5]),
    .controller_latch(JB[6])
  );
  
  cls_spi cls_spi(
    .clock(clock_200khz),
    .reset(reset),
    .ss(JB[0]),
    .mosi(JB[1]),
    .miso(JB[2]),
    .sclk(JB[3]),
    .A(A),
    .Di(Di),
    .Do(Do),
    .PC(PC),
    .SP(SP),
    .AF(AF),
    .BC(BC),
    .DE(DE),
    .HL(HL)
  );
  
  // driver for divider clocks
  always @(posedge core_clock) begin
    if (reset_init) begin
      clock_1khz <= 1'b0;
      clock_200khz <= 1'b0;
    end else begin
      if (pulse_1khz)
        clock_1khz <= !clock_1khz;
      if (pulse_200khz)
        clock_200khz <= !clock_200khz;
    end
  end
  
  // TODO: tie these to 8kb RAMs
  assign Di = 8'b0;
  assign Di_vram = 8'b0;
  
  assign VHDCIJA = 8'b0;
  
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
