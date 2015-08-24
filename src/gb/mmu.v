`default_nettype none
`timescale 1ns / 1ps

module mmu(
  input  wire        clock,
  input  wire        reset,
  
  // CPU
  input  wire [15:0] A_cpu,
  input  wire  [7:0] Di_cpu, // should be Do from cpu
  output wire  [7:0] Do_cpu, // should be mux'd to cpu's Di
  input  wire        rd_cpu_n,
  input  wire        wr_cpu_n,
  
  // Main RAM (Cartridge + WRAM)
  output wire [15:0] A,
  output wire  [7:0] Do,
  input  wire  [7:0] Di,
  output wire        wr_n,
  output wire        rd_n,
  output wire        cs_n,
  
  // PPU (VRAM + OAM + Registers)
  output wire [15:0] A_ppu,
  output wire  [7:0] Do_ppu,
  input  wire  [7:0] Di_ppu,
  output wire        rd_ppu_n,
  output wire        wr_ppu_n,
  output wire        cs_ppu,
  
  // I/O Registers (except for PPU)
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
  wire [7:0] Do_high_ram;

  // internal r/w enables
  wire cs_boot_rom;
  wire cs_jump_rom;
  wire cs_high_ram;
  
  // remapped addresses
  wire [6:0] A_jump_rom;
  wire [6:0] A_high_ram;
  
  // when 8'h01 gets written into FF50h the ROM is disabled
  reg boot_rom_enable;

  // dma stuff
  reg cs_dma;
  reg dma_rd_n_video;
  reg dma_wr_n_video;
  reg[7:0] A_dma_high;
  reg[7:0] dma_counter;
  wire[7:0] Do_dma;

  parameter DMA_WR_ENABLE = 0;
  parameter DMA_WAIT = 1;
  parameter DMA_WR_DISABLE = 2;
  parameter DMA_COUNT = 3;
  reg[1:0] dma_state;

  // if dma is enabled, make address source as the dma address
  assign A_dma = { A_dma_high, 8'b0 } + dma_counter;
  wire[15:0] A_temp = cs_dma ? { A_dma_high, 8'b0 } + dma_counter : A;
  
  // Internal ROMs
  reg [7:0] boot_rom [0:255];
  reg [7:0] jump_rom [0:9];
  
  initial begin
    $readmemb("data/boot.bin", boot_rom, 0, 255);
    $readmemh("data/jump.hex", jump_rom, 0, 9);
  end
  
  // High RAM
  async_mem #(.asz(8), .depth(127)) high_ram (
    .rd_data(Do_high_ram),
    .wr_clk(clock),
    .wr_data(Di_cpu),
    .wr_cs(cs_high_ram && !wr_n),
    .addr(A_high_ram),
    .rd_cs(cs_high_ram)
  );
  
  always @ (posedge clock)
  begin
    if (reset)
    begin
      boot_rom_enable <= 1;
    end
    else
    begin    
      if (cs_dma) begin
        case (dma_state)
          DMA_WR_ENABLE:
          begin
            dma_rd_n_video <= 1;
            dma_wr_n_video <= 0;
            dma_state <= DMA_WAIT;
          end
          DMA_WAIT: dma_state <= DMA_WR_DISABLE;
          DMA_WR_DISABLE:
          begin
            dma_rd_n_video <= 1;
            dma_wr_n_video <= 1;
            dma_state <= DMA_COUNT;
          end
          DMA_COUNT:
          begin
            dma_rd_n_video <= 1;
            dma_wr_n_video <= 1;
            dma_state <= DMA_COUNT;
            dma_counter <= dma_counter + 1;
            if (dma_counter >= 159) begin
              cs_dma <= 0;
            end
            else begin
              dma_state <= DMA_WR_ENABLE;
            end
          end
        endcase
      end

      if (!wr_n)
      begin
        case (A)
          16'hFF46:
          begin
            if (!cs_dma)
            begin
              cs_dma <= 1;
              dma_counter <= 0;
              dma_addr <= Di;
              dma_state <= DMA_WR_ENABLE;
            end
          end
          16'hFF50: if (Di == 8'h01) boot_rom_enable <= 1'b0;
        endcase
      end
    end
  end
  
  // selector flags
  assign cs_n = (A < 16'hFE00) ? 1'b0 : 1'b1; // echo of internal ram
    
  assign cs_ppu = 
    (A >= 16'h8000 && A < 16'hA000) || // VRAM
    (A >= 16'hFE00 && A < 16'hFEA0) || // OAM
    (A >= 16'hFF40 && A <= 16'hFF4B && A != 16'hFF46); // registers (except for DMA)
    
  assign cs_boot_rom = boot_rom_enable && A < 16'h0100;
  assign cs_jump_rom = A >= 16'hFEA0 && A < 16'hFF00;
  assign cs_high_ram = A >= 16'hFF80 && A < 16'hFFFF;
  
  assign cs_interrupt = A == 16'hFF0F || A == 16'hFFFF;
  assign cs_sound = A >= 16'hFF10 && A <= 16'hFF3F; // there are some gaps here
  assign cs_timer = A >= 16'hFF04 && A <= 16'hFF07;
  assign cs_joypad = A == 16'hFF00;
  
  // remap internal addresses
  assign A_jump_rom = A - 16'hFEA0;
  assign A_high_ram = A - 16'hFF80;
  
  // Main RAM + Cartridge
  assign A = A_cpu;
  assign Do = Di_cpu;
  assign wr_n = wr_cpu_n;
  assign rd_n = rd_cpu_n;
  
  // PPU
  assign A_ppu =  (cs_dma) ? 16'hFE00 + dma_counter : A_cpu;
  assign Do_ppu = Di_cpu; // TODO DMA
  assign wr_ppu_n = wr_cpu_n;
  assign rd_ppu_n = rd_cpu_n;

  assign Do_ppu = 
    (cs_dma) ? (
      (cs_boot_rom) ? boot_rom[A_cpu] :
      (cs_cartridge) ? Di :
      (cs_internal_ram) ? Do : 8'hFF) : 8'hFF; 

  assign Do_cpu =
    (cs_boot_rom) ? boot_rom[A_cpu] :
    (cs_high_ram) ? Do_high_ram :
    (cs_jump_rom) ? jump_rom[A_jump_rom] :
    (cs_interrupt) ? Do_interrupt :
    (cs_timer) ? Do_timer :
    (cs_sound) ? Do_sound :
    (cs_joypad) ? Do_joypad :
    (cs_ppu) ? Do_ppu :
    (!cs_n) ? Di : 8'hFF;
  
endmodule
