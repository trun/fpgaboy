`default_nettype none
`timescale 1ns / 1ps

module sprite (
  input  wire        clock,
  input  wire        reset,

  input  wire        sprite_latch,
  input  wire  [7:0] sprite_i_x,
  input  wire        sprite_i_priority,
  input  wire  [7:0] sprite_i_data_h,
  input  wire  [7:0] sprite_i_data_l,
  output reg   [7:0] sprite_o_x,
  output reg         sprite_o_priority,
  output reg   [7:0] sprite_o_data_h,
  output reg   [7:0] sprite_o_data_l,

  input  wire  [3:0] background_col,
  input  wire  [7:0] background_i_h,
  input  wire  [7:0] background_i_l,
  output wire  [7:0] background_o_h,
  output wire  [7:0] background_o_l
);

  reg[7:0] sprite_x;
  reg sprite_priority;
  reg[7:0] sprite_data_h;
  reg[7:0] sprite_data_l;

  wire [2:0] sprite_shift;
  wire [7:0] sprite_mask;
  wire [7:0] background_mask;
  wire [7:0] background_x;
  wire sprite_overlap;

  wire [7:0] sprite_shifted_data_h;
  wire [7:0] sprite_shifted_data_l;
  wire [7:0] sprite_shifted_mask;

  always @(posedge clock)
  begin
    if (reset)
    begin
      sprite_x <= 8'hFF;
      sprite_y <= 8'hFF;
      sprite_priority <= 1'b0;
      sprite_data_h <= 8'hFF;
      sprite_data_l <= 8'hFF;
    end
    else
    begin
      if (sprite_latch && sprite_i_x < sprite_x)
      begin
        sprite_x <= sprite_i_x;
        sprite_priority <= sprite_i_priority;
        sprite_data_h <= sprite_i_data_h;
        sprite_data_l <= sprite_i_data_l;
      end
    end
  end

  assign sprite_o_x = sprite_i_x < sprite_x ? sprite_x : sprite_i_x;
  assign sprite_o_priority = sprite_i_x < sprite_x ? sprite_priority : sprite_i_priority;
  assign sprite_o_data_h = sprite_i_x < sprite_x ? sprite_data_h : sprite_i_data_h;
  assign sprite_o_data_l = sprite_i_x < sprite_x ? sprite_data_l : sprite_i_data_l;

  assign sprite_mask = sprite_data_h | sprite_data_l;
  assign background_mask = background_i_h | background_i_l;
  assign background_x = background_col << 3;
  assign sprite_shift = sprite_x < background_x ? background_x - sprite_x : sprite_x - background_x;
  assign sprite_overlap = sprite_shift < 8;

  assign sprite_shifted_data_h = sprite_x < background_x ? sprite_data_h << sprite_shift : sprite_data_h >> sprite_shift;
  assign sprite_shifted_data_l = sprite_x < background_x ? sprite_data_l << sprite_shift : sprite_data_l >> sprite_shift;
  assign sprite_shift_mask = sprite_x < background_x ? sprite_mask << sprite_shift : sprite_mask >> sprite_shift;

  assign background_o_h = 
    sprite_overlap ?
      (sprite_attr[7] ?
       (~background_mask & sprite_shifted_data_h) | background_i_h :
       (~sprite_shifted_mask & background_i_h) | sprite_shifted_data_h) :
      background_i_h;
  assign background_o_l = 
    sprite_overlap ?
      (sprite_attr[7] ?
       (~background_mask & sprite_shifted_data_l) | background_i_l :
       (~sprite_shifted_mask & background_i_l) | sprite_shifted_data_l) :
      background_i_h;

endmodule