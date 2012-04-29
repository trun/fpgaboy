`default_nettype none
`timescale 1ns / 1ps

module joypad_snes_adapter(
  input  wire        clock,
  input  wire        reset,
  // to gameboy
  input  wire  [1:0] button_sel,
  output wire  [3:0] button_data,
  // to controller
  input  wire        controller_data,
  output wire        controller_latch,
  output wire        controller_clock
);

  ////////////////////////////////////////////////////////
  // http://www.gamefaqs.com/snes/916396-snes/faqs/5395
  //
  // Note: Clocking at about 1khz seems to work pretty well
  //
  // Note: Color of wires on my controller ext. cable
  //  +5V    - Green
  //  Clock  - Blue
  //  Latch  - Yellow
  //  Data   - Red
  //  Ground - Brown
  ////////////////////////////////////////////////////////

  parameter WAIT_STATE = 0;
  parameter LATCH_STATE = 1;
  parameter READ_STATE = 2;

  reg   [1:0] state;
  reg   [3:0] button_index;
  reg  [15:0] button_state;
  
  always @(posedge clock)
  begin
    if (reset)
    begin
      state <= WAIT_STATE;
    end
    else
    begin
      if (state == WAIT_STATE)
      begin
        state <= LATCH_STATE;
      end
      else if (state == LATCH_STATE)
      begin
        state <= READ_STATE;
      end
      else if (state == READ_STATE)
      begin
        if (button_index == 15)
        begin
          state <= WAIT_STATE;
        end
      end
    end
  end
  
  always @(negedge clock)
  begin
    if (reset)
    begin
      button_index <= 4'b0;
      button_state <= 16'hFFFF;
    end
    else
    begin
    if (state == WAIT_STATE)
    begin
      button_index <= 4'b0;
    end
    if (state == READ_STATE)
      begin
        button_state[button_index] <= controller_data;
        button_index <= button_index + 1;
      end
    end
  end
  
  assign controller_latch = (state == LATCH_STATE) ? 1'b1 : 1'b0;
  assign controller_clock = (state == READ_STATE) ? clock : 1'b1;

  // button order is
  // B Y SELECT START UP DOWN LEFT RIGHT A X L R - - - -
  assign button_data =
    button_sel[0] == 1'b0 ? { button_state[7], button_state[6], button_state[4], button_state[5] } :
    button_sel[1] == 1'b0 ? { button_state[8], button_state[0], button_state[2], button_state[3] } : 4'b1111;

endmodule
