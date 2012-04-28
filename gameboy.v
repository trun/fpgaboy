`default_nettype none
`timescale 1ns / 1ps

module gameboy (
  input  wire        clock,
  input  wire        reset,
  input  wire        reset_init,
  
  // Main RAM + Cartridge
  output wire [15:0] A,
  input  wire  [7:0] Di,
  output wire  [7:0] Do,
  output wire        wr_n,
  output wire        rd_n,
  output wire        cs_n,
  
  // Video RAM
  output wire [15:0] A_video,
  input  wire  [7:0] Di_video,
  output wire  [7:0] Do_video,
  output wire        wr_video_n,
  output wire        rd_video_n,
  output wire        cs_video_n,
  
  // Video Display
  output wire  [1:0] pixel_data,
  output wire        pixel_clock,
  output wire        pixel_latch,
  output wire        hsync,
  output wire        vsync,
  
  // Controller
  input  wire  [3:0] joypad_data,
  output wire  [1:0] joypad_sel,
  
  // Audio
  output wire        audio_left,
  output wire        audio_right,
  
  // Debug - CPU Pins
  output wire  [7:0] dbg_led
);

  //assign A = 16'b0;
  //assign Do = 16'b0;
  //assign wr_n = 1'b1;
  //assign rd_n = 1'b1;
  //assign cs_n = 1'b1;
  
  assign A_video = 16'b0;
  assign Do_video = 16'b0;
  assign wr_video_n = 1'b1;
  assign rd_video_n = 1'b1;
  assign cs_video_n = 1'b1;
  
  assign pixel_data = 2'b0;
  assign pixel_clock = 1'b0;
  assign pixel_latch = 1'b0;
  assign hsync = 1'b0;
  assign vsync = 1'b0;
  
  assign joypad_sel = 2'b0;

  assign audio_left = 1'b0;
  assign audio_right = 1'b0;
  
  //
  // CPU I/O Pins
  //
  
  wire reset_n, wait_n, int_n, nmi_n, busrq_n; // cpu inputs
  wire m1_n, mreq_n, iorq_n, rd_cpu_n, wr_cpu_n, rfsh_n, halt_n, busak_n; // cpu outputs
  wire [15:0] A_cpu;
  wire [7:0] Di_cpu;
  wire [7:0] Do_cpu;
  
  //
  // Debug - CPU I/O Pins
  //
  
  assign dbg_led = {
    m1_n,
    mreq_n,
    iorq_n,
    int_n,
    halt_n,
    reset_n,
    rd_n,
    wr_n
  };
  
  //
  // CPU clock
  //
  
  reg [2:0] clock_divider; // overflows every 8 cycles
  
  wire cpu_clock; 
  BUFG cpu_clock_buf(.I(clock_divider[2]), .O(cpu_clock));
  
  //
  // CPU internal registers
  //
  
  wire [15:0] AF;
  wire [15:0] BC;
  wire [15:0] DE;
  wire [15:0] HL;
  wire [15:0] PC;
  wire [15:0] SP;
  wire IntE_FF1;
  wire IntE_FF2;
  wire INT_s;
  
  //
  // TV80 CPU
  //
      
  tv80s tv80_core(
    .reset_n(reset_n),
    .clk(cpu_clock),
    .wait_n(wait_n),
    .int_n(int_n),
    .nmi_n(nmi_n),
    .busrq_n(busrq_n),
    .m1_n(m1_n),
    .mreq_n(mreq_n),
    .iorq_n(iorq_n),
    .rd_n(rd_cpu_n),
    .wr_n(wr_cpu_n),
    .rfsh_n(rfsh_n),
    .halt_n(halt_n),
    .busak_n(busak_n),
    .A(A_cpu),
    .di(Di_cpu),
    .do(Do_cpu),
    .ACC(AF[15:8]),
    .F(AF[7:0]),
    .BC(BC),
    .DE(DE),
    .HL(HL),
    .PC(PC),
    .SP(SP),
    .IntE_FF1(IntE_FF1),
    .IntE_FF2(IntE_FF2),
    .INT_s(INT_s)
  );
  
  assign reset_n = !reset;
  assign wait_n = 1'b1;
  assign nmi_n = 1'b1;
  assign busrq_n = 1'b1;
  
  //
  // MMU
  //
  
  wire cs_main;
  wire cs_interrupt;
  wire cs_timer;
  wire cs_video;
  wire cs_sound;
  wire cs_joypad;
  
  wire[7:0] Do_mmu;
  wire[7:0] Do_interrupt;
  wire[7:0] Do_timer;
  wire[7:0] Do_sound;
  wire[7:0] Do_joypad;
  
  memory_controller memory (
    .clock(clock),
    .reset(reset),
    .A_cpu(A_cpu),
    .Di_cpu(Do_cpu),
    .Do_cpu(Do_mmu),
    .rd_cpu_n(rd_cpu_n),
    .wr_cpu_n(wr_cpu_n),
    .A(A),
    .Do(Do),
    .Di(Di),
    .wr_n(wr_n),
    .rd_n(rd_n),
    .cs(cs_main),
    .A_video(A_video),
    .Do_video(Do_video),
    .Di_video(Di_video),
    .rd_video_n(rd_video_n),
    .wr_video_n(wr_video_n),
    .cs_video(cs_video),
    .Do_interrupt(Do_interrupt),
    .Do_timer(Do_timer),
    .Do_sound(Do_sound),
    .Do_joypad(Do_joypad),
    .cs_interrupt(cs_interrupt),
    .cs_timer(cs_timer),
    .cs_sound(cs_sound),
    .cs_joypad(cs_joypad)
  );
  
  assign cs_n = !cs_main;
  assign cs_video_n = !cs_video;
  
  //
  // Interrupt Controller
  //
  
  wire[4:0] int_req;
  wire[4:0] int_ack;
  wire[7:0] jump_addr;
  
  interrupt_controller interrupt(
    .reset(reset),
    .clock(clock),
    .cs(cs_interrupt),
    .rd_n(rd_n),
    .wr_n(wr_n),
    .m1_n(m1_n),
    .int_n(int_n),
    .iorq_n(iorq_n),
    .int_ack(int_ack),
    .int_req(int_req),
    .jump_addr(jump_addr),
    .A(A),
    .Di(Do_cpu),
    .Do(Do_interrupt)
  );
  
  assign Di_cpu = (!iorq_n && !m1_n) ? jump_addr : Do_mmu;
  
  //
  // Timer Controller
  //
  
  timer_controller timer (
    .reset(reset),
    .clock(cpu_clock),
    .cs(cs_timer),
    .rd_n(rd_n),
    .wr_n(wr_n),
    .int_ack(int_ack[2]),
    .int_req(int_req[2]),
    .A(A),
    .Di(Do_cpu),
    .Do(Do_timer)
  );
  
  //
  // Video Controller
  //
  
  video_controller video (
    .reset(reset),
    .clock(clock),
    .int_vblank_ack(int_ack[0]),
    .int_vblank_req(int_req[0]),
    .int_lcdc_ack(int_ack[1]),
    .int_lcdc_req(int_req[1]),
    .A(A_video),
    .Di(Do_video),
    .Do(Di_video),
    .rd_n(rd_video_n),
    .wr_n(wr_video_n),
    .cs(cs_video),
    .hsync(hsync),
    .vsync(vsync),
    .pixel_data(pixel_data),
    .pixel_latch(pixel_latch),
    .pixel_clock(clock) // TODO ??
  );
  
  //
  // Advance CPU Clock
  //
  
  always @(posedge clock)
  begin
    if (reset_init)
    begin
      clock_divider <= 0;
    end
    else
    begin
      clock_divider <= clock_divider + 1;
    end
  end

endmodule
