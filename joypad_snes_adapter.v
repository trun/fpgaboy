`default_nettype none
`timescale 1ns / 1ps

module joypad_snes_adapter(
  input  wire        clock,
  input  wire        reset,
  input  wire        reset_init,
  // to gameboy
  input  wire  [1:0] button_sel,
  output wire  [3:0] button_data,
  // to controller
  input  wire        controller_data,
  output wire        controller_latch,
  output wire        controller_clock,
  // debug
  output reg [15:0] button_state
);

  ////////////////////////////////////////////////////////
  // http://www.gamefaqs.com/snes/916396-snes/faqs/5395
  //
  // NOTE: Color of wires on my controller ext. cable
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
  //reg  [15:0] button_state;
  
  wire pulse_166khz;
  reg  clock_166khz;
  divider#(.DELAY(300)) div_6us (
    .reset(reset_init),
    .clock(clock),
    .enable(pulse_166khz)
  );
  
  wire pulse_60hz;
  divider#(.DELAY(2778)) div_16ms (
    .reset(reset),
    .clock(clock_166khz),
    .enable(pulse_60hz)
  );
  
  always @(posedge clock)
  begin
    if (reset_init)
    begin
      clock_166khz <= 0;
    end
    else
    begin
      if (pulse_166khz || reset)
        clock_166khz <= !clock_166khz;
    end
  end
  
  always @(clock_166khz)
  begin
    if (reset)
    begin
      state <= WAIT_STATE;
      button_index <= 4'b0;
      button_state <= 16'b1;
    end
    else
    begin
      if (state == WAIT_STATE && pulse_60hz)
      begin
        state <= LATCH_STATE;
      end
      else if (state == LATCH_STATE && clock_166khz)
      begin
        state <= READ_STATE;
      end
      else if (state == READ_STATE && !clock_166khz)
      begin
        // button order is
        // B Y SELECT START UP DOWN LEFT RIGHT A X L R - - - -
        button_state[button_index] <= controller_data;
        
        // increment read counter
        if (button_index == 15)
        begin
          button_index <= 4'b0;
          state <= WAIT_STATE;
        end
        else
        begin
          button_index <= button_index + 1;
        end
      end
    end
  end
  
  assign controller_latch = pulse_60hz;
  assign controller_clock = (state == READ_STATE) ? clock_166khz : 1'b1;

  assign button_data =
    button_sel[0] == 1'b0 ? { button_state[7], button_state[6], button_state[4], button_state[5] } :
    button_sel[1] == 1'b0 ? { button_state[8], button_state[0], button_state[2], button_state[3] } : 4'b1111;

endmodule
