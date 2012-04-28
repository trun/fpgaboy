`default_nettype none
`timescale 1ns / 1ps

module memory_controller(
  input  wire        clock,
  input  wire        reset,
  
  // CPU
  input  wire [15:0] A_cpu,
  input  wire  [7:0] Di_cpu, // should be Do from cpu
  output wire  [7:0] Do_cpu, // should be mux'd to cpu's Di
  input  wire        rd_cpu_n,
  input  wire        wr_cpu_n,
  
  // Main RAM
  output wire [15:0] A,
  output wire  [7:0] Do,
  input  wire  [7:0] Di,
  output wire        wr_n,
  output wire        rd_n,
  output wire        cs,
  
  // Video RAM
  output wire [15:0] A_video,
  output wire  [7:0] Do_video,
  input  wire  [7:0] Di_video,
  output wire        rd_video_n,
  output wire        wr_video_n,
  output wire        cs_video,
  
  // Registers
  input  wire  [7:0] Do_interrupt,
  input  wire  [7:0] Do_timer,
  input  wire  [7:0] Do_sound,
  input  wire  [7:0] Do_joypad,
  output wire        cs_interrupt,
  output wire        cs_timer,
  output wire        cs_sound,
  output wire        cs_joypad
);

  // internal data out pins
  wire [7:0] Do_boot_rom;
  wire [7:0] Do_high_ram;
  wire [7:0] Do_int_table;

  // internal r/w enables
  wire cs_boot_rom;
  wire cs_high_ram;
  wire cs_int_table;
  
  // remapped addresses
  wire [6:0] A_high_ram;
  wire [6:0] A_int_table;
  
  // when 8'h01 gets written into $FF50 the ROM is disabled
  reg rom_enable;
  
  boot_rom br(A, Do_boot_rom);
  interrupt_table it(A_int_table, Do_int_table);
  high_ram hr(A_high_ram, Di_cpu, clock, cs_high_ram && !wr_n, Do_high_ram);
  
  always @ (posedge clock)
  begin
    if (reset)
    begin
      rom_enable <= 1;
    end
    else
    begin
      if (!wr_n)
      begin
        case(A)
          16'hFF46:
          begin
            // DMA
          end
          16'hFF50: if (Di == 8'h01) rom_enable <= 1'b0;
        endcase
      end
    end
  end
  
  // selector flags
  assign cs = A < 16'hFE00; // echo of internal ram
    
  assign cs_video = 
    (A >= 16'h8000 && A < 16'hA000) || // vram
    (A >= 16'hFE00 && A < 16'hFEA0) || // oam
    (A >= 16'hFF40 && A <= 16'hFF4B && A != 16'hFF46); // registers (except for DMA)
    
  assign cs_boot_rom = rom_enable && A < 16'h0100;
  assign cs_high_ram = A >= 16'hFF80 && A < 16'hFFFF;
  assign cs_int_table = A >= 16'hFEA0 && A < 16'hFF00;
  
  assign cs_interrupt = A == 16'hFF0F || A == 16'hFFFF;
  assign cs_sound = A >= 16'hFF10 && A <= 16'hFF3F; // there are some gaps here
  assign cs_timer = A >= 16'hFF04 && A <= 16'hFF07;
  assign cs_joypad = A == 16'hFF00;
  
  // remap addresses
  assign A_high_ram = A - 16'hFF80;
  assign A_int_table = A - 16'hFEA0;
  
  // Main RAM + Cartridge
  assign A = A_cpu;
  assign Do = Di_cpu;
  assign wr_n = wr_cpu_n;
  assign rd_n = rd_cpu_n;
  
  // video memory address
  assign A_video = A_cpu;
  assign Do_video = Di_cpu;
  assign wr_video_n = wr_cpu_n;
  assign rd_video_n = rd_cpu_n;
  
  assign Do_cpu =
    (cs_boot_rom) ? Do_boot_rom :
    (cs_high_ram) ? Do_high_ram :
    (cs_int_table) ? Do_int_table :
    (cs_interrupt) ? Do_interrupt :
    (cs_timer) ? Do_timer :
    (cs_sound) ? Do_sound :
    (cs_joypad) ? Do_joypad :
    (cs_video) ? Do_video :
    (cs) ? Di : 8'hFF;
  
endmodule
