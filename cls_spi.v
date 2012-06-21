`default_nettype none
`timescale 1ns / 1ps

module cls_spi(
  input wire        clock,
  input wire        reset,
  
  input wire [15:0] A,
  input wire  [7:0] Di,
  input wire  [7:0] Do,
  input wire [15:0] PC,
  input wire [15:0] SP,
  input wire [15:0] AF,
  input wire [15:0] BC,
  input wire [15:0] DE,
  input wire [15:0] HL,
  
  output wire       ss,
  output reg        mosi,
  input  wire       miso,
  output wire       sclk
);

  parameter WAIT = 1;
  parameter SEND = 2;
  parameter SEND_2 = 3;
  parameter SEND_3 = 4;
  parameter SEND_4 = 5;
  parameter SEND_5 = 6;
  parameter SENDHEX = 7;
  
  parameter STARTUP_1  = 10;
  parameter STARTUP_2  = 11;
  parameter STARTUP_3  = 12;
  parameter STARTUP_4  = 13;
  
  parameter LOOP_1  = 20;
  parameter LOOP_2  = 21;
  parameter LOOP_3  = 22;
  
  reg [63:0] send_buf; // send buffer (8 bytes)
  reg  [2:0] send_idx; // current bit   (0h-7h)
  reg  [2:0] send_ctr; // current byte  (0h-7h)
  reg  [2:0] send_max; // total bytes   (0h-7h)
  
  reg [31:0] wait_ctr; // current cycle
  reg [31:0] wait_max; // total cycles
  
  reg  [2:0] hex_idx;  // current word
  
  // TODO probably don't need 7 bits for state
  reg [7:0] state;
  reg [7:0] next_state;
  reg [7:0] next_state_hex;
  
  reg ss_enable;
  reg sclk_enable;
  
  reg [7:0] glyph_rom [15:0];
  reg [31:0] data;
  reg [1:0] data_idx;
  
  initial begin
    $readmemh("data/hexascii.rom", glyph_rom, 0, 15);
  end
  
  always @(posedge clock) begin
    // RESET
    if (reset) begin
      send_buf <= 64'b0;
      send_idx <= 3'b0;
      send_ctr <= 3'b0;
      send_max <= 3'b0;
      wait_ctr <= 32'b0;
      wait_max <= 32'b0;
      state <= STARTUP_1;
      next_state <= 8'b0;
      next_state_hex <= 8'b0;
      
      hex_idx <= 3'b0;
      data <= 32'b0;
      data_idx <= 2'b0;
      
      ss_enable <= 0;
      sclk_enable <= 0;
      
      mosi <= 1'b0;
    end
    
    // STATES
    else begin
      // SEND - send up to eight serial bytes
      if (state == SEND) begin
        ss_enable <= 1;
        state <= SEND_2;
      end
      
      else if (state == SEND_2) begin
        state <= SEND_3;
      end
      
      else if (state == SEND_3) begin
        mosi <= send_buf[(7 - send_idx) + (8 * send_ctr)];
        if (send_idx == 7) begin
          send_idx <= 0;
          state <= SEND_4;
        end else begin
          sclk_enable <= 1;
          send_idx <= send_idx + 1;
        end
      end
      
      else if (state == SEND_4) begin
        mosi <= 0;
        state <= SEND_5;
      end
      
      else if (state == SEND_5) begin
        sclk_enable <= 0;
        ss_enable <= 0;
        if (send_ctr == send_max) begin
          send_ctr <= 0;
          send_max <= 0;
          state <= next_state;
        end else begin
          send_ctr <= send_ctr + 1;
          state <= SEND;
        end
      end
      
      // SENDHEX - send a glyph corresponding to a hex value
      else if (state == SENDHEX) begin
        send_buf <= glyph_rom[(data >> ({hex_idx, 2'b00})) & 4'hF];
        send_max <= 0;
        if (hex_idx == 0) begin
          next_state <= next_state_hex;
        end else begin
          next_state <= SENDHEX;
          hex_idx <= hex_idx - 1;
        end
        state <= SEND;
      end
      
      // WAIT - wait for # of cycles
      else if (state == WAIT) begin
        if (wait_ctr == wait_max) begin
          wait_ctr <= 0;
          state <= next_state;
        end else begin
          wait_ctr <= wait_ctr + 1;
        end
      end
      
      // STARTUP_1 -- send display on, backlight on cmd
      else if (state == STARTUP_1) begin
        send_buf <= 32'h65335B1B; // ESC  BRACKET '3' 'e'
        send_max <= 3;
        state <= SEND;
        next_state <= STARTUP_2;
      end
      
      // STARTUP_2 -- clear the display
      else if (state == STARTUP_2) begin
        send_buf <= 32'h6A305B1B; // ESC  BRACKET '0' 'j'
        send_max <= 3;
        state <= SEND;
        next_state <= STARTUP_3;
      end
      
      // STARTUP_3 -- set the cursor mode
      else if (state == STARTUP_3) begin
        send_buf <= 32'h63305B1B; // ESC  BRACKET '0' 'c'
        send_max <= 3;
        state <= SEND;
        next_state <= STARTUP_4;
      end
      
      // STARTUP_4 -- set the display mode
      else if (state == STARTUP_4) begin
        send_buf <= 32'h68305B1B; // ESC  BRACKET '0' 'h'
        send_max <= 3;
        state <= SEND;
        next_state <= LOOP_1;
      end
      
      // LOOP_1 -- set cursor to 0,0
      else if (state == LOOP_1) begin
        send_buf <= 48'h48303B305B1B; // ESC  BRACKET '0' ';' '0' 'H'
        send_max <= 5;
        state <= SEND;
        next_state <= LOOP_2;
      end
      
      else if (state == LOOP_2) begin
        case (data_idx)
          2'b00: data <= { A, Di, Do };
          2'b01: data <= { PC, SP };
          2'b10: data <= { AF, BC };
          2'b11: data <= { DE, HL };
        endcase
        hex_idx <= 7;
        state <= SENDHEX;
        next_state_hex <= LOOP_3;
      end
      
      else if (state == LOOP_3) begin
        data_idx <= data_idx + 1;
        wait_max <= 10;
        state <= WAIT;
        next_state <= LOOP_2;
      end
    end
  end
  
  assign ss = (ss_enable) ? 1'b0 : 1'b1;
  assign sclk = (sclk_enable) ? !clock : 1'b1;

endmodule
