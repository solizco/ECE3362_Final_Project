# ECE3362_Final_Project
MSP430 assembly Breakout game for the MSP430FR6989 and Educational BoosterPack MKII. Features joystick paddle control, SPI-driven TFT graphics, ADC input, timer-based updates, ball physics, randomized brick layouts, a 3-life system, and start/reset button controls.


# Breakout Game on MSP430FR6989

A single-player Breakout game written entirely in MSP430 assembly for the MSP430FR6989 using the Educational BoosterPack MKII TFT display. The project uses low-level hardware control for graphics, joystick input, timing, and button handling. 

## Overview

The player controls a horizontal paddle near the bottom of the screen with the joystick. A ball bounces around the display, reflects off the walls and paddle, and destroys bricks placed near the top of the screen. The game includes randomized level layouts, a 3-life system, a start screen, and dedicated start/reset controls. 

## Features

- MSP430 assembly implementation
- SPI-driven TFT graphics
- ADC-based joystick paddle control
- Timer-based game updates
- Ball and paddle collision physics
- Randomized brick layouts that increase in difficulty
- 3-life system with on-screen life display
- Start screen with pause-style symbol
- Dedicated start and reset buttons 

## Hardware

- MSP430FR6989 LaunchPad
- Educational BoosterPack MKII TFT display
- Onboard joystick
- Two BoosterPack buttons for start and reset 

## Hardware Connections

- LCD RST -> P9.4
- LCD CLK -> P1.4 (`UCB0CLK`)
- LCD MOSI -> P1.6 (`UCB0SIMO`)
- LCD CS -> P2.5
- LCD DC -> P2.3
- LCD BL -> P2.6
- Joy H -> P9.2 (`A10`)
- Joy V -> P8.7 (`A4`)
- Start Button -> P3.0
- Reset Button -> P3.1 

## Controls

- **Joystick**: move paddle left and right
- **B1 / Start button**: start the game from the start screen
- **B2 / Reset button**: return to the start screen

## Game Logic

- The game starts on a waiting screen.
- Pressing the start button begins gameplay.
- The player starts with 3 lives.
- If the ball falls past the paddle, one life is lost.
- When all lives are lost, the game returns to the start screen.
- Clearing all current bricks advances to the next level.
- Brick placement is randomized using an LFSR-based routine.

## Peripherals Used

### SPI
The TFT display is controlled through `UCB0` using SPI helper routines for commands and data transfers. 

### ADC
The joystick horizontal and vertical values are read from the ADC using repeated sequence mode. 

### Timer
Timer A0 generates the periodic frame tick used for game updates. 

## Project Goals

This project demonstrates:

- embedded game design in assembly
- direct register-level hardware control
- graphics rendering on a TFT display
- timer-driven game loops
- ADC joystick interfacing
- basic pseudo-random level generation
- collision detection and state management on a microcontroller 

## Authors

- Nicholas Soliz


## Course

ECE 3362 
