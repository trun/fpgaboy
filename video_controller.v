`default_nettype none
`timescale 1ns / 1ps

module video_controller (
  input  wire        reset,
  input  wire        clock,
  
  // Interrupts
  input  wire        int_vblank_ack,
  output reg         int_vblank_req,
  input  wire        int_lcdc_ack,
  output reg         int_lcdc_req,
  
  // VRAM + OAM + Registers (PPU <-> MMU)
  input  wire [15:0] A,
  input  wire  [7:0] Di, // in from MMU
  output wire  [7:0] Do, // out to MMU
  input  wire        rd_n,
  input  wire        wr_n,
  input  wire        cs,
  
  // VRAM (PPU <-> VRAM)
  output wire [15:0] A_vram,
  output wire  [7:0] Do_vram, // out to VRAM
  input  wire  [7:0] Di_vram, // in from VRAM
  output wire        rd_vram_n,
  output wire        wr_vram_n,
  output wire        cs_vram_n,
  
  // LCD Output -- TODO pixel clock?
  output wire        hsync,
  output wire        vsync,
  output reg   [7:0] line_count,
  output reg   [8:0] pixel_count,
  output reg   [7:0] pixel_data_count,
  output reg   [1:0] pixel_data,
  output reg         pixel_latch
);
  
  ///////////////////////////////////
  //
  // Video Registers
  //
  // LCDC - LCD Control (FF40) R/W
  //   
  //   Bit 7 - LCD Control Operation
  //     0: Stop completeLY (no picture on screen)
  //     1: operation
  //   Bit 6 - Window Screen Display Data Select
  //     0: $9800-$9BFF
  //     1: $9C00-$9FFF
  //   Bit 5 - Window Display
  //     0: off
  //     1: on
  //   Bit 4 - BG Character Data Select
  //     0: $8800-$97FF
  //     1: $8000-$8FFF <- Same area as OBJ
  //   Bit 3 - BG Screen Display Data Select
  //     0: $9800-$9BFF
  //     1: $9C00-$9FFF
  //   Bit 2 - OBJ Construction
  //     0: 8*8
  //     1: 8*16
  //   Bit 1 - Window priority bit
  //     0: window overlaps all sprites
  //     1: window onLY overlaps sprites whose
  //        priority bit is set to 1
  //   Bit 0 - BG Display
  //     0: off
  //     1: on
  //
  // STAT - LCDC Status (FF41) R/W
  // 
  //    Bits 6-3 - Interrupt Selection By LCDC Status
  //    Bit 6 - LYC=LY Coincidence          (1=Select)
  //    Bit 5 - Mode 2: OAM-Search          (1=Enabled)
  //    Bit 4 - Mode 1: V-Blank             (1=Enabled)
  //    Bit 3 - Mode 0: H-Blank             (1=Enabled)
  //    Bit 2 - Coincidence Flag
  //      0: LYC not equal to LCDC LY
  //      1: LYC = LCDC LY
  //    Bit 1-0 - Mode Flag (Current STATus of the LCD controller)
  //      0: During H-Blank. Entire Display Ram can be accessed.
  //      1: During V-Blank. Entire Display Ram can be accessed.
  //      2: During Searching OAM-RAM. OAM cannot be accessed.
  //      3: During Transfering Data to LCD Driver. CPU cannot
  //         access OAM and display RAM during this period.
  //
  //    The following are typical when the display is enabled:
  //
  //     Mode 0  000___000___000___000___000___000___000________________  H-Blank
  //     Mode 1  _______________________________________11111111111111__  V-Blank
  //     Mode 2  ___2_____2_____2_____2_____2_____2___________________2_  OAM
  //     Mode 3  ____33____33____33____33____33____33__________________3  Transfer
  //
  //
  //    The Mode Flag goes through the values 00, 02,
  //    and 03 at a cycle of about 109uS. 00 is present
  //    about 49uS, 02 about 20uS, and 03 about 40uS. This
  //    is interrupted every 16.6ms by the VBlank (01).
  //    The mode flag stays set at 01 for 1.1 ms.
  //
  //    Mode 0 is present between 201-207 clks, 2 about 77-83 clks,
  //    and 3 about 169-175 clks. A complete cycle through these
  //    states takes 456 clks. VBlank lasts 4560 clks. A complete
  //    screen refresh occurs every 70224 clks.)
  //
  // SCY - Scroll Y (FF42) R/W
  //    Vertical scroll of background
  //
  // SCX - Scroll X (FF43) R/W
  //    Horizontal scroll of background
  //
  // LY - LCDC Y-Coordinate (FF44) R
  //    The LY indicates the vertical line to which
  //    the present data is transferred to the LCD
  //    Driver. The LY can take on any value between
  //    0 through 153. The values between 144 and 153
  //    indicate the V-Blank period. Writing will
  //    reset the counter.
  //
  //    This is just a RASTER register. The current
  //    line is thrown into here. But since there are
  //    no RASTERS on an LCD display it's called the
  //    LCDC Y-Coordinate.
  //
  // LYC - LY Compare (FF45) R/W
  //    The LYC compares itself with the LY. If the
  //    values are the same it causes the STAT to set
  //    the coincident flag.
  //
  // DMA (FF46)
  //    Implemented in the MMU
  //
  // BGP - BG Palette Data (FF47) W
  //    
  //    Bit 7-6 - Data for Dot Data 11
  //    Bit 5-4 - Data for Dot Data 10
  //    Bit 3-2 - Data for Dot Data 01
  //    Bit 1-0 - Data for Dot Data 00
  //
  //    This selects the shade of gray you what for
  //    your BG pixel. Since each pixel uses 2 bits,
  //    the corresponding shade will be selected
  //    from here. The Background Color (00) lies at
  //    Bits 1-0, just put a value from 0-$3 to
  //    change the color.
  //
  // OBP0 - Object Palette 0 Data (FF48) W
  //    This selects the colors for sprite palette 0.
  //    It works exactLY as BGP ($FF47).
  //    See BGP for details.
  //
  // OBP1 - Object Palette 1 Data (FF49) W
  //    This selects the colors for sprite palette 1.
  //    It works exactLY as BGP ($FF47).
  //    See BGP for details.
  //
  // WY - Window Y Position (FF4A) R/W
  //    0 <= WY <= 143
  //
  // WX - Window X Position + 7 (FF4B) R/W
  //    7 <= WX <= 166
  //
  ///////////////////////////////////
  
  reg[7:0] LCDC;
  wire[7:0] STAT;
  reg[7:0] SCY;
  reg[7:0] SCX;
  reg[7:0] LYC;
  reg[7:0] BGP;
  reg[7:0] OBP0;
  reg[7:0] OBP1;
  reg[7:0] WY;
  reg[7:0] WX;
  
  // temp registers for r/rw mixtures
  reg[4:0] STAT_w;
  
  // timing params -- see STAT register
  parameter PIXELS = 456;
  parameter LINES = 154;
  parameter HACTIVE_VIDEO = 160;
  parameter HBLANK_PERIOD = 41;
  parameter OAM_ACTIVE = 80;
  parameter RAM_ACTIVE = 172;
  parameter VACTIVE_VIDEO = 144;
  parameter VBLANK_PERIOD = 10;
  
  reg[1:0] mode;
  parameter HBLANK_MODE = 0;
  parameter VBLANK_MODE = 1;
  parameter OAM_LOCK_MODE = 2;
  parameter RAM_LOCK_MODE = 3;
  
  reg[3:0] state;
  parameter IDLE_STATE = 0;

  reg   [7:0] Do_reg;
  
  wire  [7:0] next_line_count;
  wire  [8:0] next_pixel_count;
  
  wire  [7:0] A_oam;
  wire  [7:0] Do_oam;
  wire        wr_oam_n;
  wire        cs_oam;
  
  wire        cs_reg;
  
  wire clock_enable;
  divider #(8) clock_divider(reset, clock, clock_enable);
  
  always @(posedge clock)
  begin
    if (reset)
    begin
      // initialize registers
      LCDC <= 8'h00;  //91 
      SCY  <= 8'h00;  //4f
      SCX  <= 8'h00;
      LYC  <= 8'h00;
      BGP  <= 8'hFC;  //fc
      OBP0 <= 8'h00;
      OBP1 <= 8'h00;
      WY   <= 8'h00;
      WX   <= 8'h00;
      
      // reset internal registers
      int_vblank_req <= 0;
      int_lcdc_req <= 0;
      mode <= 0;
      state <= 0;
      STAT_w <= 0;
      
      pixel_count <= 0;
      line_count <= 0;
    end
    else
    begin
    
      // memory r/w
      if (cs)
      begin
        if (!rd_n)
        begin
          case (A)
            16'hFF40: Do_reg <= LCDC;
            16'hFF41: Do_reg <= STAT;
            16'hFF42: Do_reg <= SCY;
            16'hFF43: Do_reg <= SCX;
            16'hFF44: Do_reg <= line_count;
            16'hFF45: Do_reg <= LYC;
            16'hFF47: Do_reg <= BGP;
            16'hFF48: Do_reg <= OBP0;
            16'hFF49: Do_reg <= OBP1;
            16'hFF4A: Do_reg <= WX;
            16'hFF4B: Do_reg <= WY;
          endcase
        end
        else if (!wr_n)
        begin
          case (A)
            16'hFF40: LCDC <= Di;
            16'hFF41: STAT_w[4:0] <= Di[7:3];
            16'hFF42: SCY <= Di;
            16'hFF43: SCX <= Di;
            //16'hFF44: line_count <= 0; // TODO: reset counter
            16'hFF45: LYC <= Di;
            16'hFF47: BGP <= Di;
            16'hFF48: OBP0 <= Di;
            16'hFF49: OBP1 <= Di;
            16'hFF4A: WX <= Di;
            16'hFF4B: WY <= Di;
          endcase
        end
      end
      
      // clear interrupts
      if (int_vblank_ack)
        int_vblank_req <= 0;
      if (int_lcdc_ack)
        int_lcdc_req <= 0;
      
      if (LCDC[7]) // grapics enabled
      begin
      
        //////////////////////////////
        // STAT INTERRUPTS AND MODE //
        //////////////////////////////
        
        // vblank -- mode 1
        if (line_count >= VACTIVE_VIDEO)
        begin
          if (mode != VBLANK_MODE)
          begin
            int_vblank_req <= 1;
            if (STAT[4])
              int_lcdc_req <= 1;
          end
          mode <= VBLANK_MODE;
        end
        // oam lock -- mode 2
        else if (pixel_count < OAM_ACTIVE)
        begin  
          if (STAT[5] && mode != OAM_LOCK_MODE)
            int_lcdc_req <= 1;
          mode <= OAM_LOCK_MODE;
        end
        // ram + oam lock -- mode 3
        else if (pixel_count < OAM_ACTIVE + RAM_ACTIVE)
        begin
          mode <= RAM_LOCK_MODE;
          // does not generate an interrupt
        end
        // hblank -- mode 0
        else
        begin
          if (STAT[3] && mode != HBLANK_MODE)
            int_lcdc_req <= 1;
          mode <= HBLANK_MODE;
        end
        
        // lyc interrupt
        if (pixel_count == 0 && line_count == LYC)
        begin
          // stat bit set automatically
          if (STAT[6])
            int_lcdc_req <= 1;
        end
        
        /////////////////////
        // RENDER GRAPHICS //
        /////////////////////
        
        case (state)
          IDLE_STATE:
          begin
            if (mode == RAM_LOCK_MODE)
            begin
              // do nothing
            end
          end
        endcase
        
      end
      else
      begin
        mode <= HBLANK_MODE;
      end
      
      // failsafe -- if we somehow exceed the allotted cycles for rendering
      //if (mode != RAM_LOCK_MODE && state < PIXEL_WAIT_STATE && state > IDLE_STATE)
      //  state <= PIXEL_WAIT_STATE;
      
      //if (mode < RAM_LOCK_MODE)
      //  vram_addrA <= A - 16'h8000;
      //if (mode < OAM_LOCK_MODE)
      //  oam_addrA <= A - 16'hFE00;
      
      if (clock_enable)
      begin
        pixel_count <= next_pixel_count;
        line_count <= next_line_count;
      end
    end
  end

  assign next_pixel_count = (LCDC[7]) ?
    ((pixel_count == PIXELS - 1) ? 0 : pixel_count + 1) : 0;
    
  assign next_line_count = (LCDC[7]) ?
    ((pixel_count == PIXELS - 1) ?
      ((line_count == LINES - 1) ? 0 : line_count + 1) : line_count) : 0;
  
  assign hsync = (pixel_count > OAM_ACTIVE + RAM_ACTIVE + HACTIVE_VIDEO) ? 1'b1 : 1'b0;
  assign vsync = (line_count > VACTIVE_VIDEO) ? 1'b1 : 1'b0;
  
  assign cs_vram_n = !(cs && A >= 16'h8000 && A < 16'hA000);
  assign cs_oam = cs && A >= 16'hFE00 && A < 16'hFEA0;
  assign cs_reg = cs && cs_vram_n && !cs_oam;
  
  assign wr_vram_n = !(cs_oam && !wr_n && mode != RAM_LOCK_MODE);
  assign wr_oam_n = !(cs_oam && !wr_n && mode != RAM_LOCK_MODE && mode != OAM_LOCK_MODE);
  
  assign STAT[7:3] = STAT_w[4:0]; // r/w
  assign STAT[2] = (line_count == LYC) ? 1 : 0; // LYC Coincidence flag
  assign STAT[1:0] = mode; // read only -- set internally
  
  assign A_vram = A; // TODO: mux
  assign Do_vram = Di; // TODO: mux
  
  assign A_oam = A; // TODO: offset and mux
  assign Do_oam = 8'b0; // TODO: Di and mux
  
  assign Do =
    (!cs_vram_n) ? Do_vram :
    (cs_oam) ? Do_oam :
    (cs_reg) ? Do_reg : 8'hFF;

endmodule
