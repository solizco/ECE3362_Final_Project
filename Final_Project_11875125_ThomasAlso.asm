;===============================================================================
; Breakout - MSP430FR6989 + Educational BoosterPack MKII
;
; Single-player Breakout game written in MSP430 assembly.
;
; The joystick controls a horizontal paddle near the bottom of the screen.
; A ball bounces around the screen, reflects off the walls and paddle, and
; breaks bricks at the top of the display. The brick field has 32 total bricks
; arranged in 8 columns and 4 rows, with each row drawn in a different color. 
; However you start at one brick, and can reach the max of 32 over the course of 3 lives
;
; The player starts with 3 lives. If the ball falls below the paddle, one life
; is lost and the ball is served again. If all lives are lost, the game returns to level 1
; Pressing S1 starts the game at any time from the paused state, and s2 restarts to paused state
;
; Hardware connections:
;   LCD RST  -> P9.4
;   LCD CLK  -> P1.4   (UCB0CLK)
;   LCD MOSI -> P1.6   (UCB0SIMO)
;   LCD CS   -> P2.5
;   LCD DC   -> P2.3
;   LCD BL   -> P2.6
;   Joy H    -> P9.2   (A10)
;   Joy V    -> P8.7   (A4)
;   BUTTON1  -> PJ.3   (active-low restart button)
;
; The TFT LCD is driven over SPI using UCB0. The joystick is read through the
; ADC, and Timer A0 provides a frame tick of about 60 Hz for game updates.
;
;       Nicholas Soliz - R11875125
;       Thomas Lawrence
;
;       ECE 3362
;===============================================================================

                 .cdecls C, LIST, "msp430.h"                               ; Include device header
                .def    RESET                                             ; Export reset label

;-------------------------------------------------------------------------------
; Macros
;-------------------------------------------------------------------------------
delay       .macro  count                                         ; Simple delay macro
            mov     #count, R15
            dec     R15
            jnz     $-2
            .endm

RST_HIGH    .macro                                                ; Set LCD reset high
            bis.b   #BIT4, &P9OUT
            .endm

RST_LOW     .macro                                                ; Set LCD reset low
            bic.b   #BIT4, &P9OUT
            .endm

CS_HIGH     .macro                                                ; Set chip select high
            bis.b   #BIT5, &P2OUT
            .endm

CS_LOW      .macro                                                ; Set chip select low
            bic.b   #BIT5, &P2OUT
            .endm

tft_config  .macro  address, d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15
            mov.b   #address, R15                                 ; Load LCD command byte
            call    #tft_cmd_sr                                   ; Send command
            .if $symlen(":d0:") > 0
                    mov.b   d0, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d1:") > 0
                    mov.b   d1, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d2:") > 0
                    mov.b   d2, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d3:") > 0
                    mov.b   d3, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d4:") > 0
                    mov.b   d4, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d5:") > 0
                    mov.b   d5, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d6:") > 0
                    mov.b   d6, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d7:") > 0
                    mov.b   d7, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d8:") > 0
                    mov.b   d8, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d9:") > 0
                    mov.b   d9, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d10:") > 0
                    mov.b   d10, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d11:") > 0
                    mov.b   d11, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d12:") > 0
                    mov.b   d12, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d13:") > 0
                    mov.b   d13, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d14:") > 0
                    mov.b   d14, R15
                    call    #tft_data_sr
            .endif
            .if $symlen(":d15:") > 0
                    mov.b   d15, R15
                    call    #tft_data_sr
            .endif
            .endm

;===============================================================================
; CONSTANTS
;===============================================================================
LCD_X_OFF   .equ    2                                       ; LCD X offset
LCD_Y_OFF   .equ    1                                       ; LCD Y offset

PADDLE_W    .equ    28                                      ; Paddle width
PADDLE_H    .equ    4                                       ; Paddle height
PADDLE_Y    .equ    120                                     ; Paddle Y position
PADDLE_XMAX .equ    128-PADDLE_W                            ; Max paddle X

BALL_SZ     .equ    4                                       ; Ball size

BRICK_W     .equ    16                                      ; Brick width
BRICK_H     .equ    8                                       ; Brick height
BRICK_COLS  .equ    8                                       ; Number of brick columns
BRICK_ROWS  .equ    4                                       ; Number of brick rows
BRICK_Y0    .equ    16                                      ; First brick row Y
BRICK_TOTAL .equ    BRICK_COLS*BRICK_ROWS                   ; Total bricks
BRICK_YEND  .equ    BRICK_Y0+BRICK_ROWS*BRICK_H             ; End of brick area

V_FAST      .equ    2                                       ; Fast velocity
V_SLOW      .equ    1                                       ; Slow velocity

LIVES_INIT  .equ    3                                       ; Starting lives

TA0_PERIOD  .equ    125000/60                               ; Timer period for ~60 Hz

HUD_H       .equ     8

;===============================================================================
; RAM (.bss)
;===============================================================================
        .bss    BallX,          2                           ; Ball X position
        .bss    BallY,          2                           ; Ball Y position
        .bss    BallVX,         2                           ; Ball X velocity
        .bss    BallVY,         2                           ; Ball Y velocity
        .bss    PaddlePX,       2                           ; Paddle X position
        .bss    PrevBX,         2                           ; Previous ball X
        .bss    PrevBY,         2                           ; Previous ball Y
        .bss    PrevPPX,        2                           ; Previous paddle X
        .bss    NeedFullRedraw, 1                           ; Full redraw flag
        .bss    PhysTick,       1                           ; Physics tick flag
        .bss    JoyH,           2                           ; Horizontal joystick ADC
        .bss    JoyV,           2                           ; Vertical joystick ADC
        .bss    BtnPrev,        1                           ; Previous button state
        .bss    LFSR,           2                           ; Random seed
        .bss    FR_X,           2                           ; FillRect X
        .bss    FR_Y,           2                           ; FillRect Y
        .bss    FR_W,           2                           ; FillRect width
        .bss    FR_H,           2                           ; FillRect height
        .bss    FR_B,           1                           ; FillRect blue
        .bss    FR_G,           1                           ; FillRect green
        .bss    FR_R,           1                           ; FillRect red
        .bss    Bricks,         BRICK_TOTAL                 ; Brick alive/dead table
        .bss    BrickCount,     2                           ; Number of bricks left
        .bss    Lives,          1                           ; Remaining lives
        .bss    GameOver,       1                           ; Game over flag
        .bss    Level,          1                           ; Current Level
        .bss    BrickTarget,    2                           ; Number of bricks to spawn this round
        .bss    Started,        1                           ; 0 = waiting to start, 1 = game running
        .bss    BtnStartPrev,   1                           ; Previous B1 State
        .bss    BtnResetPrev,   1                           ; Previous B2 State
;===============================================================================
; Linker / startup
;===============================================================================
        .global __STACK_END
        .sect   ".stack"
        .text
        .retain
        .retainrefs

;-------------------------------------------------------------------------------
; RESET
;-------------------------------------------------------------------------------
RESET:
        mov.w   #(WDTPW+WDTHOLD), &WDTCTL                  ; Stop watchdog timer
        mov.w   #__STACK_END, SP                           ; Initialize stack pointer

        call    #Init_Clock                                ; Initialize clock
        call    #Init_GPIO                                 ; Initialize GPIO
        call    #Init_SPI                                  ; Initialize SPI

        RST_LOW                                            ; Hold LCD in reset
        delay   1000
        RST_HIGH                                           ; Release LCD reset
        delay   65000
        delay   65000
        delay   65000
        delay   65000
        delay   65000
        delay   65000

        tft_config  0x11                                   ; Exit LCD sleep mode
        delay   65000
        delay   65000
        delay   65000
        delay   65000
        delay   65000

        tft_config  0xB1,#0x02,#0x35,#0x36                ; LCD config
        tft_config  0xB2,#0x02,#0x35,#0x36
        tft_config  0xB3,#0x02,#0x35,#0x36,#0x02,#0x35,#0x36
        tft_config  0xB4,#0x07
        tft_config  0xC0,#0x02,#0x02
        tft_config  0xC1,#0xC5
        tft_config  0xC2,#0x0D,#0x00
        tft_config  0xC3,#0x8D,#0x1A
        tft_config  0xC4,#0x8D,#0xEE
        tft_config  0xC5,#0x51,#0x4D
        tft_config  0xE0,#0x0A,#0x1C,#0x0C,#0x14,#0x33,#0x2B,#0x24,#0x28,#0x27,#0x25,#0x2C,#0x39,#0x00,#0x05,#0x03,#0x0D
        tft_config  0xE1,#0x0A,#0x1C,#0x0C,#0x14,#0x33,#0x2B,#0x24,#0x28,#0x27,#0x25,#0x2D,#0x3A,#0x00,#0x05,#0x03,#0x0D
        tft_config  0x3A,#0x06                             ; 18-bit color mode
        tft_config  0x29                                   ; Display ON
        delay   1000
        tft_config  0x36,#0xC0                             ; Memory access control

        mov.w   #0,   &FR_X                                ; Full screen clear
        mov.w   #0,   &FR_Y
        mov.w   #128, &FR_W
        mov.w   #128, &FR_H
        call    #Clr_FG_B
        call    #LCD_FillRect

        call    #Init_ADC                                  ; Initialize ADC
        call    #Init_Timer                                ; Initialize timer
        mov.w   #0xC0DE, &LFSR                             ; Initial seed
        call    #Show_StartScreen                          ; Wait for S1 to start

;-------------------------------------------------------------------------------
; GameLoop
;-------------------------------------------------------------------------------
GameLoop:
        tst.b   &PhysTick                                  ; Wait for physics tick
        jz      GameLoop
        clr.b   &PhysTick

        call    #PollJoy_ADC                               ; Read joystick
        call    #Poll_Buttons                       ; Check restart button

        tst.b   &Started                                   ; Game started yet?
        jz      GameLoop
        
        tst.b   &GameOver                                  ; Game over?
        jnz     GameLoop

        call    #Update_Player_Paddle                      ; Move paddle

        tst.b   &NeedFullRedraw                            ; Check full redraw flag
        jnz     GF_FullDraw

        mov.w   &PrevBX, &FR_X                             ; Erase old ball
        mov.w   &PrevBY, &FR_Y
        mov.w   #BALL_SZ, &FR_W
        mov.w   #BALL_SZ, &FR_H
        call    #Clr_FG_B
        call    #LCD_FillRect

        mov.w   &PaddlePX, R12                             ; Check if paddle moved
        cmp.w   &PrevPPX, R12
        jeq     GF_AfterErase
        mov.w   &PrevPPX, &FR_X                            ; Erase old paddle
        mov.w   #PADDLE_Y, &FR_Y
        mov.w   #PADDLE_W, &FR_W
        mov.w   #PADDLE_H, &FR_H
        call    #Clr_FG_B
        call    #LCD_FillRect
        jmp     GF_AfterErase

GF_FullDraw:
        clr.b   &NeedFullRedraw                            ; Clear redraw flag

GF_AfterErase:
        call    #Physics_Ball                              ; Update ball physics
        
        tst.b   &Started
        jz      GameLoop

        tst.b   &GameOver                                  ; Stop if game over
        jnz     GameLoop

        mov.w   &BallX, &FR_X                              ; Draw ball
        mov.w   &BallY, &FR_Y
        mov.w   #BALL_SZ, &FR_W
        mov.w   #BALL_SZ, &FR_H
        mov.b   #0xFF, &FR_B
        mov.b   #0xFF, &FR_G
        mov.b   #0xFF, &FR_R
        call    #LCD_FillRect

        mov.w   &PaddlePX, &FR_X                           ; Draw paddle
        mov.w   #PADDLE_Y, &FR_Y
        mov.w   #PADDLE_W, &FR_W
        mov.w   #PADDLE_H, &FR_H
        mov.b   #0xFF, &FR_B
        mov.b   #0xFF, &FR_G
        mov.b   #0x20, &FR_R
        call    #LCD_FillRect

        call    #Draw_Lives                                ; Restore HUD every frame


        mov.w   &BallX,    &PrevBX                         ; Save current positions
        mov.w   &BallY,    &PrevBY
        mov.w   &PaddlePX, &PrevPPX
        jmp     GameLoop

;===============================================================================
; Init_Clock
;===============================================================================
Init_Clock:
        mov.b   #CSKEY_H, &CSCTL0_H                        ; Unlock clock system
        mov.w   #DCOFSEL_6, &CSCTL1                        ; Set DCO
        mov.w   #SELA__VLOCLK+SELS__DCOCLK+SELM__DCOCLK, &CSCTL2 ; Clock sources
        mov.w   #DIVA__1+DIVS__1+DIVM__1, &CSCTL3          ; No dividers
        clr.b   &CSCTL0_H                                  ; Lock clock system
        ret

;===============================================================================
; Init_GPIO
;===============================================================================
Init_GPIO:
        bic.w   #LCDON+LCDSON, &LCDCCTL0                   ; Disable on-chip LCD
        clr.w   &LCDCPCTL0                                 ; Clear LCD control regs
        clr.w   &LCDCPCTL1
        clr.w   &LCDCPCTL2

        bic.b   #BIT4, &P9SEL0                             ; P9.4 as GPIO
        bic.b   #BIT4, &P9SEL1
        bis.b   #BIT4, &P9DIR                              ; P9.4 output
        bis.b   #BIT4, &P9OUT                              ; P9.4 high

        bic.b   #BIT3+BIT5+BIT6, &P2SEL0                   ; P2.3, P2.5, P2.6 as GPIO
        bic.b   #BIT3+BIT5+BIT6, &P2SEL1
        bis.b   #BIT3+BIT5+BIT6, &P2DIR                    ; Outputs
        bis.b   #BIT5+BIT6, &P2OUT                         ; CS high, backlight on
        bic.b   #BIT3, &P2OUT                              ; DC low

        bis.b   #BIT4+BIT6+BIT7, &P1SEL0                   ; SPI pins
        bic.b   #BIT4+BIT6+BIT7, &P1SEL1

        bic.b   #BIT3, &PJSEL0_L                           ; Button as GPIO
        bic.b   #BIT3, &PJSEL1_L
        bic.b   #BIT3, &PJDIR_L                            ; Input
        bis.b   #BIT3, &PJREN_L                            ; Enable resistor
        bis.b   #BIT3, &PJOUT_L                            ; Pull-up

        bic.b   #BIT0+BIT1, &P3SEL0                        ; P3.0 / P3.1 as GPIO
        bic.b   #BIT0+BIT1, &P3SEL1
        bic.b   #BIT0+BIT1, &P3DIR                         ; Inputs
        bis.b   #BIT0+BIT1, &P3REN                         ; Enable pull resistors
        bis.b   #BIT0+BIT1, &P3OUT                         ; Pull-ups

        bic.w   #LOCKLPM5, &PM5CTL0                        ; Unlock GPIO
        ret

;===============================================================================
; Init_SPI
;===============================================================================
Init_SPI:
        mov.w   #UCSWRST, &UCB0CTLW0                       ; Hold SPI in reset
        bis.w   #UCSSEL__SMCLK+UCSYNC+UCMODE_0+UCMST+UCMSB, &UCB0CTLW0 ; SPI master
        mov.w   #2, &UCB0BRW                               ; Divider /2
        bic.w   #UCSWRST, &UCB0CTLW0                       ; Release reset
        ret

;===============================================================================
; Init_ADC
;===============================================================================
Init_ADC:
        mov.w   #ADC12SHT0_2+ADC12ON+ADC12MSC, &ADC12CTL0 ; ADC on
        bis.w   #ADC12SHP+ADC12CONSEQ_3, &ADC12CTL1       ; Repeated sequence
        bis.w   #ADC12RES_2, &ADC12CTL2                   ; 12-bit resolution
        bis.w   #ADC12INCH_10, &ADC12MCTL0                ; A10 first
        bis.w   #ADC12INCH_4+ADC12EOS, &ADC12MCTL1        ; A4 second, end sequence
        bis.w   #ADC12ENC+ADC12SC, &ADC12CTL0             ; Start ADC
        ret

;===============================================================================
; Init_Timer
;===============================================================================
Init_Timer:
        mov.w   #TASSEL__SMCLK+ID__8+MC__UP+TACLR, &TA0CTL ; Timer A setup
        mov.w   #TAIDEX_7, &TA0EX0                         ; Extra divider
        mov.w   #TA0_PERIOD, &TA0CCR0                      ; Period value
        bis.w   #CCIE, &TA0CCTL0                           ; Enable interrupt
        nop                                                ; Needed before GIE
        eint                                               ; Enable interrupts
        nop                                                ; Needed after GIE
        ret
;===============================================================================
; TFT helpers
;===============================================================================
tft_cmd_sr:
        CS_LOW                                             ; Select LCD
        bic.b   #BIT3, &P2OUT                              ; Command mode
        call    #spi_byte
        CS_HIGH                                            ; Deselect LCD
        ret

tft_data_sr:
        CS_LOW                                             ; Select LCD
        bis.b   #BIT3, &P2OUT                              ; Data mode
        call    #spi_byte
        CS_HIGH                                            ; Deselect LCD
        ret

spi_byte:
spiT1   bit.w   #UCTXIFG, &UCB0IFG                         ; Wait TX ready
        jz      spiT1
        mov.b   R15, &UCB0TXBUF                            ; Send byte
spiT2   bit.w   #UCBUSY, &UCB0STATW                        ; Wait until finished
        jnz     spiT2
        ret

;===============================================================================
; Misc helpers
;===============================================================================
Clr_FG_B:
        clr.b   &FR_B                                      ; Blue = 0
        clr.b   &FR_G                                      ; Green = 0
        clr.b   &FR_R                                      ; Red = 0
        ret

PollJoy_ADC:
        mov.w   &ADC12MEM0, &JoyH                          ; Read horizontal ADC
        mov.w   &ADC12MEM1, &JoyV                          ; Read vertical ADC
        ret

Neg_BallVy:
        mov.w   &BallVY, R12                               ; Negate BallVY
        inv.w   R12
        inc.w   R12
        mov.w   R12, &BallVY
        ret

Neg_BallVx:
        mov.w   &BallVX, R12                               ; Negate BallVX
        inv.w   R12
        inc.w   R12
        mov.w   R12, &BallVX
        ret

;===============================================================================
; LCD_SetWindow
;===============================================================================
LCD_SetWindow:
        push    R4                                         ; Save registers
        push    R5
        push    R6
        push    R7
        mov.w   R12, R4                                    ; x0
        mov.w   R13, R5                                    ; y0
        mov.w   R14, R6                                    ; x1
        mov.w   R15, R7                                    ; y1

        mov.b   #0x2A, R15                                 ; CASET command
        call    #tft_cmd_sr
        CS_LOW
        bis.b   #BIT3, &P2OUT
        clr.b   R15
        call    #spi_byte
        mov.w   R4, R15
        add.w   #LCD_X_OFF, R15
        call    #spi_byte
        clr.b   R15
        call    #spi_byte
        mov.w   R6, R15
        add.w   #LCD_X_OFF, R15
        call    #spi_byte
        CS_HIGH

        mov.b   #0x2B, R15                                 ; RASET command
        call    #tft_cmd_sr
        CS_LOW
        bis.b   #BIT3, &P2OUT
        clr.b   R15
        call    #spi_byte
        mov.w   R5, R15
        add.w   #LCD_Y_OFF, R15
        call    #spi_byte
        clr.b   R15
        call    #spi_byte
        mov.w   R7, R15
        add.w   #LCD_Y_OFF, R15
        call    #spi_byte
        CS_HIGH

        mov.b   #0x2C, R15                                 ; RAMWR command
        call    #tft_cmd_sr

        pop     R7
        pop     R6
        pop     R5
        pop     R4
        ret

;===============================================================================
; LCD_FillRect
;===============================================================================
LCD_FillRect:
        push    R4                                         ; Save registers
        push    R5
        push    R6
        push    R7
        push    R8
        push    R9

        mov.w   &FR_X, R4                                  ; Load rectangle X
        mov.w   &FR_Y, R5                                  ; Load rectangle Y
        mov.w   &FR_W, R6                                  ; Load rectangle width
        mov.w   &FR_H, R7                                  ; Load rectangle height

        mov.w   R4, R12                                    ; x0
        mov.w   R5, R13                                    ; y0
        mov.w   R4, R14
        add.w   R6, R14
        dec.w   R14                                        ; x1
        mov.w   R5, R15
        add.w   R7, R15
        dec.w   R15                                        ; y1
        call    #LCD_SetWindow

        mov.w   R6, &MPY                                   ; Multiply width
        mov.w   R7, &OP2                                   ; by height
        mov.w   &RESLO, R9                                 ; Pixel count

        mov.b   &FR_B, R6                                  ; Load blue
        mov.b   &FR_G, R7                                  ; Load green
        mov.b   &FR_R, R8                                  ; Load red

        CS_LOW                                             ; Start data transfer
        bis.b   #BIT3, &P2OUT

FR_Loop:
FR_WB   bit.w   #UCTXIFG, &UCB0IFG                         ; Wait TX ready
        jz      FR_WB
        mov.b   R6, &UCB0TXBUF                             ; Send blue
FR_WBx  bit.w   #UCBUSY, &UCB0STATW
        jnz     FR_WBx
FR_WG   bit.w   #UCTXIFG, &UCB0IFG
        jz      FR_WG
        mov.b   R7, &UCB0TXBUF                             ; Send green
FR_WGx  bit.w   #UCBUSY, &UCB0STATW
        jnz     FR_WGx
FR_WR   bit.w   #UCTXIFG, &UCB0IFG
        jz      FR_WR
        mov.b   R8, &UCB0TXBUF                             ; Send red
FR_WRx  bit.w   #UCBUSY, &UCB0STATW
        jnz     FR_WRx
        dec.w   R9                                         ; Count one pixel
        jnz     FR_Loop

        CS_HIGH                                            ; End transfer
        pop     R9
        pop     R8
        pop     R7
        pop     R6
        pop     R5
        pop     R4
        ret

;===============================================================================
; Update_Player_Paddle
;===============================================================================
Update_Player_Paddle:
        mov.w   &JoyH, R12                                 ; Get joystick reading
        clr.w   R13                                        ; Clear paddle X
UP_Loop:
        cmp.w   #41, R12                                   ; Compare to step
        jl      UP_Clamp
        sub.w   #41, R12                                   ; Subtract step
        inc.w   R13                                        ; Increment paddle X
        jmp     UP_Loop
UP_Clamp:
        cmp.w   #PADDLE_XMAX+1, R13                        ; Clamp if too large
        jl      UP_Done
        mov.w   #PADDLE_XMAX, R13
UP_Done:
        mov.w   R13, &PaddlePX                             ; Save paddle X
        ret

;===============================================================================
; Poll_Buttons
;   B1 (P3.0 / J4.33) starts the game.
;   B2 (P3.1 / J4.32) resets back to level 1.
;   Both buttons are active-low.
;===============================================================================
Poll_Buttons:
        ; ---- B1 START BUTTON ----
        clr.b   R4                                         ; Assume not pressed
        bit.b   #BIT0, &P3IN                               ; Check B1
        jnz     PB_StoreStart
        mov.b   #1, R4                                     ; Pressed
        cmp.b   #1, &BtnStartPrev                          ; Already held?
        jeq     PB_StoreStart
        tst.b   &Started                                   ; Start only if waiting
        jnz     PB_StoreStart
        mov.b   #1, &Started
        call    #Restart_Game

PB_StoreStart:
        mov.b   R4, &BtnStartPrev                          ; Save B1 state

        ; ---- B2 RESET BUTTON ----
        clr.b   R4                                         ; Assume not pressed
        bit.b   #BIT1, &P3IN                               ; Check B2
        jnz     PB_StoreReset
        mov.b   #1, R4                                     ; Pressed
        cmp.b   #1, &BtnResetPrev                          ; Already held?
        jeq     PB_StoreReset
        call    #Return_To_StartScreen                     ; Return to start screen


PB_StoreReset:
        mov.b   R4, &BtnResetPrev                          ; Save B2 state
        ret


;===============================================================================
; LFSR_Tick
;===============================================================================
LFSR_Tick:
        mov.w   &LFSR, R12                                 ; Get LFSR value
        tst.w   R12                                        ; Zero is invalid for LFSR
        jnz     LF_Run
        mov.w   #0xC0DE, R12                               ; Reload seed if zero

LF_Run:
        clrc                                               ; Clear carry
        rrc.w   R12                                        ; Shift right through carry
        jnc     LF_NoXor                                   ; If carry = 0, skip XOR
        xor.w   #0xB400, R12                               ; Apply polynomial

LF_NoXor:
        mov.w   R12, &LFSR                                 ; Save new value
        ret
        
;===============================================================================
; Serve_To
;===============================================================================
Serve_To:
        mov.w   &PaddlePX, R12                             ; Start at paddle X
        add.w   #PADDLE_W/2-BALL_SZ/2, R12                 ; Center ball
        mov.w   R12, &BallX
        mov.w   #PADDLE_Y-BALL_SZ-1, &BallY                ; Ball above paddle
        mov.w   #-V_FAST, &BallVY                          ; Upward velocity
        call    #LFSR_Tick                                 ; Randomize direction
        mov.w   &LFSR, R12
        and.w   #1, R12
        jz      ST_Right
        mov.w   #-V_SLOW, &BallVX                          ; Go left
        jmp     ST_Done
ST_Right:
        mov.w   #V_SLOW, &BallVX                           ; Go right
ST_Done:
        mov.b   #1, &NeedFullRedraw                        ; Force redraw
        ret

;===============================================================================
; Return_To_StartScreen
;   Fully stop gameplay and return to the waiting/start screen.
;===============================================================================
Return_To_StartScreen:
        clr.w   &BallVX                                    ; Stop ball motion
        clr.w   &BallVY
        clr.w   &BallX                                     ; Clear ball position
        clr.w   &BallY
        clr.w   &PrevBX                                    ; Clear previous positions
        clr.w   &PrevBY
        clr.w   &PrevPPX
        clr.b   &NeedFullRedraw                            ; Clear redraw request
        clr.b   &PhysTick                                  ; Clear pending tick
        clr.b   &Started                                   ; Waiting state
        clr.b   &GameOver                                  ; Not in game-over loop
        mov.b   #LIVES_INIT, &Lives                        ; Reset lives
        mov.b   #1, &Level                                 ; Reset level
        call    #Show_StartScreen                          ; Draw pause/start screen
        ret

;===============================================================================
; Lose_Life
;===============================================================================
Lose_Life:
        dec.b   &Lives                                     ; Decrement lives
        call    #Draw_Lives                                ; Update Life display
        tst.b   &Lives                                     ; Check remaining lives
        jz      LL_GameOver
        mov.w   #1, R12
        call    #Serve_To                                  ; Re-serve ball
        ret
LL_GameOver:
        call    #Return_To_StartScreen                     ; Go back to start screen
        ret

;===============================================================================
; Draw_Lives
;   Draw 1 to 3 red boxes at the top right of the screen.
;===============================================================================
Draw_Lives:
                                                         ; Clear life area first
        mov.w   #104, &FR_X
        mov.w   #2,   &FR_Y
        mov.w   #22,  &FR_W
        mov.w   #6,   &FR_H
        call    #Clr_FG_B
        call    #LCD_FillRect

        cmp.b   #1, &Lives                                 ; Draw first life?
        jl      DL_Done
        mov.w   #104, &FR_X
        mov.w   #2,   &FR_Y
        mov.w   #6,   &FR_W
        mov.w   #4,   &FR_H
        mov.b   #0x20, &FR_B
        mov.b   #0x20, &FR_G
        mov.b   #0xFF, &FR_R
        call    #LCD_FillRect

        cmp.b   #2, &Lives                                 ; Draw second life?
        jl      DL_Done
        mov.w   #112, &FR_X
        mov.w   #2,   &FR_Y
        mov.w   #6,   &FR_W
        mov.w   #4,   &FR_H
        mov.b   #0x20, &FR_B
        mov.b   #0x20, &FR_G
        mov.b   #0xFF, &FR_R
        call    #LCD_FillRect

        cmp.b   #3, &Lives                                 ; Draw third life?
        jl      DL_Done
        mov.w   #120, &FR_X
        mov.w   #2,   &FR_Y
        mov.w   #6,   &FR_W
        mov.w   #4,   &FR_H
        mov.b   #0x20, &FR_B
        mov.b   #0x20, &FR_G
        mov.b   #0xFF, &FR_R
        call    #LCD_FillRect

DL_Done:
        ret



;===============================================================================
; Show_StartScreen
;   Clear screen, center paddle, show lives, wait for S1 to begin.
;===============================================================================
Show_StartScreen:
        mov.w   #0, &FR_X                                  ; Clear screen
        mov.w   #0, &FR_Y
        mov.w   #128, &FR_W
        mov.w   #128, &FR_H
        call    #Clr_FG_B
        call    #LCD_FillRect

        mov.b   #0, &Started                               ; Not started yet
        mov.b   #LIVES_INIT, &Lives                        ; 3 lives
        mov.b   #1, &Level                                 ; Start at level 1
        clr.b   &GameOver
        clr.b   &BtnPrev
        clr.b   &BtnStartPrev
        clr.b   &BtnResetPrev
        clr.b   &PhysTick
        mov.w   #(128-PADDLE_W)/2, &PaddlePX               ; Center paddle

        call    #Draw_Lives                                ; Draw life boxes

        mov.b   #0xFF, &FR_B                               ; Pause symbol color
        mov.b   #0xFF, &FR_G
        mov.b   #0xFF, &FR_R

        mov.w   #54, &FR_X                                 ; Left pause bar
        mov.w   #50, &FR_Y
        mov.w   #6,  &FR_W
        mov.w   #20, &FR_H
        call    #LCD_FillRect

        mov.w   #68, &FR_X                                 ; Right pause bar
        mov.w   #50, &FR_Y
        mov.w   #6,  &FR_W
        mov.w   #20, &FR_H
        call    #LCD_FillRect

        mov.w   &PaddlePX, &FR_X                           ; Draw paddle
        mov.w   #PADDLE_Y, &FR_Y
        mov.w   #PADDLE_W, &FR_W
        mov.w   #PADDLE_H, &FR_H
        mov.b   #0xFF, &FR_B
        mov.b   #0xFF, &FR_G
        mov.b   #0x20, &FR_R
        call    #LCD_FillRect
        ret


;===============================================================================
; Show_GameOver
;===============================================================================
Show_GameOver:
        mov.w   #0, &FR_X                                  ; Full screen black
        mov.w   #0, &FR_Y
        mov.w   #128, &FR_W
        mov.w   #128, &FR_H
        call    #Clr_FG_B
        call    #LCD_FillRect
        ret

;===============================================================================
; Restart_Game
;===============================================================================
Restart_Game:
        mov.w   #0, &FR_X                                  ; Clear screen
        mov.w   #0, &FR_Y
        mov.w   #128, &FR_W
        mov.w   #128, &FR_H
        call    #Clr_FG_B
        call    #LCD_FillRect

        mov.w   #0xC0DE, &LFSR                             ; Seed random
        mov.b   #1, &Started                               ;Game is running
        clr.b   &GameOver                                  ; Reset game state
        mov.b   #LIVES_INIT, &Lives
        mov.b   #1, &Level                                 ; restart from level 1
        mov.w   #(128-PADDLE_W)/2, &PaddlePX               ; Center paddle
        clr.b   &PhysTick

        call    #Init_Bricks                               ; Reset bricks
        call    #Draw_All_Bricks
        call    #Draw_Lives

        mov.w   #1, R12
        call    #Serve_To                                  ; Serve ball

        mov.w   &BallX,    &PrevBX                         ; Save current positions
        mov.w   &BallY,    &PrevBY
        mov.w   &PaddlePX, &PrevPPX
        ret

;===============================================================================
; Game_Init
;===============================================================================
Game_Init:
        mov.w   #0xC0DE, &LFSR                             ; Seed random
        mov.w   #(128-PADDLE_W)/2, &PaddlePX               ; Center paddle
        mov.b   #LIVES_INIT, &Lives                        ; Set lives
        mov.b   #1, &Level                                 ; Start at level 1
        mov.b   #1, &Started                               ; Game running
        clr.b   &GameOver
        clr.b   &BtnPrev
        clr.b   &PhysTick

        call    #Init_Bricks                               ; Create bricks
        call    #Draw_All_Bricks
        call    #Draw_Lives

        mov.w   #1, R12
        call    #Serve_To                                  ; Serve ball

        mov.w   &BallX,    &PrevBX                         ; Save positions
        mov.w   &BallY,    &PrevBY
        mov.w   &PaddlePX, &PrevPPX
        ret

;===============================================================================
; Init_Bricks
;===============================================================================
Init_Bricks:
        push    R4                                         ; Save registers
        push    R5
        push    R6
        push    R7
        mov.w   #BRICK_TOTAL, R4                           ; Brick count
        mov.w   #Bricks, R5                                ; Brick pointer

IB_Clear:
        clr.b   0(R5)
        inc.w   R5
        dec.w   R4
        jnz     IB_Clear

        mov.b   &Level, R6                                 ; R6 = number of bricks to enable
        cmp.w   #BRICK_TOTAL, R6
        jl      IB_CountOK
        mov.w   #BRICK_TOTAL, R6
        
IB_CountOK:
        mov.w   R6, &BrickTarget                           ; Save target brick count
        mov.w   R6, &BrickCount                            ; Save active brick count


IB_Pick:
        cmp.w   #0, R6                                     ; Done placing bricks?
        jeq     IB_Done

        call    #LFSR_Tick                                 ; Advance random generator
        mov.w   &LFSR, R7
        and.w   #31, R7                                    ; Random index 0..31

        mov.w   #Bricks, R5
        add.w   R7, R5                                     ; Point to random brick
        tst.b   0(R5)                                      ; Already alive?
        jnz     IB_Pick                                    ; If so, try again

        mov.b   #1, 0(R5)                                  ; Turn this brick on
        dec.w   R6
        jmp     IB_Pick

IB_Done:
        pop     R7
        pop     R6
        pop     R5
        pop     R4
        ret
;===============================================================================
; Set_Brick_Color
;===============================================================================
Set_Brick_Color:
        cmp.w   #0, R4                                     ; Row 0?
        jne     SBC_R1
        mov.b   #0x20, &FR_B                               ; Red brick
        mov.b   #0x20, &FR_G
        mov.b   #0xFF, &FR_R
        ret
SBC_R1:
        cmp.w   #1, R4                                     ; Row 1?
        jne     SBC_R2
        mov.b   #0x20, &FR_B                               ; Yellow brick
        mov.b   #0xFF, &FR_G
        mov.b   #0xFF, &FR_R
        ret
SBC_R2:
        cmp.w   #2, R4                                     ; Row 2?
        jne     SBC_R3
        mov.b   #0x20, &FR_B                               ; Green brick
        mov.b   #0xFF, &FR_G
        mov.b   #0x20, &FR_R
        ret
SBC_R3:
        mov.b   #0xFF, &FR_B                               ; Blue brick
        mov.b   #0x20, &FR_G
        mov.b   #0x20, &FR_R
        ret

;===============================================================================
; Draw_All_Bricks
;===============================================================================
Draw_All_Bricks:
        push    R4                                         ; Save registers
        push    R5
        push    R6
        mov.w   #Bricks, R6                                ; Brick pointer
        clr.w   R4                                         ; Row = 0
DAB_RowLoop:
        clr.w   R5                                         ; Col = 0
DAB_ColLoop:
        tst.b   0(R6)                                      ; Brick alive?
        jz      DAB_NextCol
        mov.w   R5, R12                                    ; X = col * 16
        rla.w   R12
        rla.w   R12
        rla.w   R12
        rla.w   R12
        mov.w   R12, &FR_X

        mov.w   R4, R12                                    ; Y = BRICK_Y0 + row * 8
        rla.w   R12
        rla.w   R12
        rla.w   R12
        add.w   #BRICK_Y0, R12
        mov.w   R12, &FR_Y

        mov.w   #BRICK_W, &FR_W                            ; Brick width
        mov.w   #BRICK_H, &FR_H                            ; Brick height
        call    #Set_Brick_Color                           ; Set brick color
        call    #LCD_FillRect                              ; Draw brick
DAB_NextCol:
        inc.w   R6                                         ; Next brick
        inc.w   R5                                         ; Next column
        cmp.w   #BRICK_COLS, R5
        jl      DAB_ColLoop
        inc.w   R4                                         ; Next row
        cmp.w   #BRICK_ROWS, R4
        jl      DAB_RowLoop
        pop     R6
        pop     R5
        pop     R4
        ret

;===============================================================================
; Check_Brick_Collision
;===============================================================================
Check_Brick_Collision:
        push    R4                                         ; Save registers
        push    R5
        push    R6
        push    R7

        mov.w   &BallX, R4                                 ; Ball center X
        add.w   #BALL_SZ/2, R4
        mov.w   &BallY, R5                                 ; Ball center Y
        add.w   #BALL_SZ/2, R5

        cmp.w   #BRICK_Y0, R5                              ; Above brick area?
        jl      CBC_Miss
        cmp.w   #BRICK_YEND, R5                            ; Below brick area?
        jge     CBC_Miss

        rra.w   R4                                         ; col = cx / 16
        rra.w   R4
        rra.w   R4
        rra.w   R4
        cmp.w   #BRICK_COLS, R4
        jge     CBC_Miss

        sub.w   #BRICK_Y0, R5                              ; row = (cy - BRICK_Y0)/8
        rra.w   R5
        rra.w   R5
        rra.w   R5

        mov.w   R5, R6                                     ; index = row*8 + col
        rla.w   R6
        rla.w   R6
        rla.w   R6
        add.w   R4, R6

        mov.w   #Bricks, R7                                ; Brick pointer
        add.w   R6, R7
        tst.b   0(R7)                                      ; Brick alive?
        jz      CBC_Miss

        clr.b   0(R7)                                      ; Kill brick
        dec.w   &BrickCount

        mov.w   R4, R12                                    ; Erase brick X
        rla.w   R12
        rla.w   R12
        rla.w   R12
        rla.w   R12
        mov.w   R12, &FR_X

        mov.w   R5, R12                                    ; Erase brick Y
        rla.w   R12
        rla.w   R12
        rla.w   R12
        add.w   #BRICK_Y0, R12
        mov.w   R12, &FR_Y

        mov.w   #BRICK_W, &FR_W
        mov.w   #BRICK_H, &FR_H
        call    #Clr_FG_B                                  ; Black
        call    #LCD_FillRect

        mov.w   #1, R12                                    ; Collision happened
        jmp     CBC_Done
CBC_Miss:
        clr.w   R12                                        ; No collision
CBC_Done:
        pop     R7
        pop     R6
        pop     R5
        pop     R4
        ret

;===============================================================================
; Physics_Ball
;===============================================================================
Physics_Ball:
        push    R4                                         ; Save registers
        push    R6
        push    R7

        mov.w   &BallVX, R12                               ; BallX += BallVX
        add.w   &BallX, R12
        mov.w   R12, &BallX
        mov.w   &BallVY, R12                               ; BallY += BallVY
        add.w   &BallY, R12
        mov.w   R12, &BallY

        cmp.w   #HUD_H, &BallY                                 ; Top wall below HUD
        jge     PB_NotTop               
        mov.w   #HUD_H, &BallY                                  ;Keep ball out of HUD
        call    #Neg_BallVy
PB_NotTop:

        cmp.w   #0, &BallX                                 ; Left wall
        jge     PB_NotLeft
        clr.w   &BallX
        call    #Neg_BallVx
PB_NotLeft:

        mov.w   #128-BALL_SZ, R12                          ; Right wall
        cmp.w   &BallX, R12
        jge     PB_NotRight
        mov.w   R12, &BallX
        call    #Neg_BallVx
PB_NotRight:

        tst.w   &BallVY                                    ; Only check paddle if moving down
        jn      PB_AfterPaddle
        jz      PB_AfterPaddle
        mov.w   &BallY, R4
        add.w   #BALL_SZ, R4                               ; Ball bottom Y
        cmp.w   #PADDLE_Y, R4
        jl      PB_AfterPaddle
        cmp.w   #PADDLE_Y+PADDLE_H, R4
        jge     PB_AfterPaddle
        mov.w   &BallX, R6
        add.w   #BALL_SZ, R6                               ; Ball right X
        cmp.w   &PaddlePX, R6
        jl      PB_AfterPaddle
        jeq     PB_AfterPaddle
        mov.w   &PaddlePX, R7
        add.w   #PADDLE_W, R7                              ; Paddle right X
        cmp.w   R7, &BallX
        jge     PB_AfterPaddle

        mov.w   #PADDLE_Y-BALL_SZ, &BallY                  ; Bounce on paddle
        mov.w   #-V_FAST, &BallVY

        mov.w   &BallX, R12                                ; Spin calculation
        add.w   #BALL_SZ/2, R12
        mov.w   &PaddlePX, R13
        add.w   #PADDLE_W/2, R13
        sub.w   R13, R12
        rra.w   R12
        rra.w   R12
        cmp.w   #4, R12
        jl      PB_SpinLo
        mov.w   #3, R12
PB_SpinLo:
        cmp.w   #-3, R12
        jge     PB_SpinDone
        mov.w   #-3, R12
PB_SpinDone:
        mov.w   R12, &BallVX
PB_AfterPaddle:

        cmp.w   #PADDLE_Y+PADDLE_H, &BallY                 ; Ball missed paddle?
        jl      PB_BrickCheck
        call    #Lose_Life
        jmp     PB_Done

PB_BrickCheck:
        call    #Check_Brick_Collision                     ; Check bricks
        tst.w   R12
        jz      PB_NoBrick
        call    #Neg_BallVy
        tst.w   &BrickCount                    ;any bricks left?
        jnz     PB_NoBrick
        inc.b   &Level                      ; next level
        cmp.b   #33, &Level                 ; stop increasing after 32
        jl      PB_NewLevel
        mov.b   #32, &Level


PB_NewLevel:
        call    #Init_Bricks                               ; Build next level
        call    #Draw_All_Bricks
        call    #Draw_Lives
        mov.w   #1, R12
        call    #Serve_To                                  ; Re-serve ball
     
PB_NoBrick:

PB_Done:
        pop     R7
        pop     R6
        pop     R4
        ret

;===============================================================================
; IRQ stubs
;===============================================================================
ADC12_ISR:
        reti                                               ; Unused ADC ISR

Timer_A0_ISR:
        mov.b   #1, &PhysTick                              ; Set physics tick
        reti

;===============================================================================
; Interrupt vectors
;===============================================================================
        .sect   ".reset"
        .short  RESET

        .sect   ADC12_VECTOR
        .short  ADC12_ISR

        .sect   TIMER0_A0_VECTOR
        .short  Timer_A0_ISR

        .end