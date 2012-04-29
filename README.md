# About

FPGABoy is an implementation of Nintendo's classic handheld Game Boy system. It was originally created in 2009 by Trevor Rundell and Oleg Kozhushnyan as our final project for MIT's 6.111 course (Introductory Digital Systems Laboratory). The project has been been modified substantially since then, mostly to work with the smaller FPGA's I have available to me now.

**FPGABoy IS CURRENTLY NON FUNCTIONAL!** I play around with it occasionally in my spare time, but I'm not actively doing development. I welcome contributions from anyone and everyone. This was a really fun project and I would love to see it working again on a wider range of hardware.

![Tetris running on FPGABoy](https://raw.github.com/trun/fpgaboy/master/doc/static/tetris.png)

# Development

## Hardware

FPGABoy was originally designed to run on a [6.111 Labkit](http://www-mtl.mit.edu/Courses/6.111/labkit/) which contains a fairly powerful Virtex-2 FPGA. I no longer have access to that hardware, so the project has been modified to run on a [Digilent Atlys](http://digilentinc.com/Products/Detail.cfm?NavPath=2,400,836&Prod=ATLYS) board which contains a smaller Spartan-6 FPGA.

## Software

Development is being done using [Xilinx ISE WebPACK 13.4](http://www.xilinx.com/products/design-tools/ise-design-suite/ise-webpack.htm).

## Peripherals

FPGABoy requires a number of external components for input and output. Support for the following exists, in various states of compatibility.

### Input (Joypad)

 - On board buttons (in development)
 - NES controller (supported in original, currently untested)
 - SNES controller (working!)

### Output (Video)

 - VGA (supported in original, currently untested)
 - HDMI (in development)

# Documentation

 - [fpgaboy.pdf](https://raw.github.com/trun/fpgaboy/master/doc/fpgaboy.pdf) - Our original paper on the design and implementation of FPGABoy.

## Additional Resources

 - [Pan Docs](http://nocash.emubase.de/pandocs.htm) - "Everything You Always Wanted To Know About Gameboy"

 - [GameBoy Dev'rs](http://www.devrs.com/gb/hardware.php#hardgb) - Schematics and specifications for various elements of the GameBoy hardware.
