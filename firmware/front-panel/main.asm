;******************************************************************************
;*   Project:      PVR Front panel lcd                                        *
;*   Version:      0.1                                                        *
;*                                                                            *
;*   Filename:     main.asm                                                   *
;*   Description:                                                             *
;*   Last mod:     30 dec. 2012                                               *
;*                                                                            *
;*   Author:       Benoit Frigon                                              *
;*   Email:        <bfrigon@gmail.com>                                        *
;*                                                                            *
;******************************************************************************
RADIX       DECIMAL

include <p18f2520.inc>
include "macro.inc"
include "delay.inc"
include "i2c.inc"


#define REC_LED_TRIS_A      TRISA, TRISA3
#define REC_LED_TRIS_K      TRISA, TRISA2
#define REC_LED_LAT_A       LATA, LATA3
#define REC_LED_LAT_K       LATA, LATA2
#define MSG_LED_TRIS_A      TRISA, TRISA1
#define MSG_LED_TRIS_K      TRISA, TRISA0
#define MSG_LED_LAT_A       LATA, LATA1
#define MSG_LED_LAT_K       LATA, LATA0
#define KEYPAD_LAT_R0       LATB, LATB3
#define KEYPAD_LAT_R1       LATB, LATB4
#define KEYPAD_LAT_R2       LATC, LATC2
#define KEYPAD_PIN_C0       PORTB, RB0
#define KEYPAD_PIN_C1       PORTB, RB1



;==============================================================================
;==============================================================================
;
;                                   Symbols 
;------------------------------------------------------------------------------
; *** Subroutines ***
EXTERN          delay10tcy
EXTERN          delay100tcy
EXTERN          delay1ktcy
EXTERN          delay10ktcy
EXTERN          delay200ktcy
EXTERN          usart_init
EXTERN          usart_isr
EXTERN          usart_read_buffer
EXTERN          usart_write_byte
EXTERN          usart_buffer_len
EXTERN          i2c_init
EXTERN          i2c_read
EXTERN          i2c_write
EXTERN          lcd_init
EXTERN          lcd_write
EXTERN          lcd_goto
EXTERN          lcd_clear
EXTERN          lcd_clear_to
EXTERN          lcd_pos_calc
EXTERN          lcd_pos_update
EXTERN          lcd_setcontrast
EXTERN          lcd_setdisplay
EXTERN          lcd_write_cgram
EXTERN          lcd_save_pos
EXTERN          lcd_restore_pos
EXTERN          lcd_set_page
EXTERN          lcd_show_page               ; Set visible page
EXTERN          backlight_init
EXTERN          backlight_set
EXTERN          backlight_get_clrtbl


; *** Variables ***
EXTERN          lcd_trans_type              ; Transition type
EXTERN          lcd_trans_speed             ; Transition speed
EXTERN          cur_display
EXTERN          lcd_cur_bptr
EXTERN          backlight_lvl               ; Current backlight color
EXTERN          colortbl


;==============================================================================
;==============================================================================
;
;                              Configuration bits
;------------------------------------------------------------------------------
CONFIG          OSC=INTIO67
CONFIG          PWRT=ON
CONFIG          WDT=OFF
CONFIG          PBADEN=OFF
CONFIG          LVP=OFF
CONFIG          MCLRE=ON
CONFIG          DEBUG=OFF



;==============================================================================
;==============================================================================
;
;                                    Data
;------------------------------------------------------------------------------
; Access bank
.a_main         UDATA_ACS
char            RES     0x01                ; RX character buffer
params          RES     0x04                ; Escape sequence parameters
buffer          RES     0x08                ; 8 char. buffer                
p_count         RES     0x01                ; Escape seq parameter count
i               RES     0x01                ; Iteration counter
i2              RES     0x01                ; Iteration counter 2
kpd_lastkey     RES     0x01

prev_WREG       RES     0x01                ; Context backup (low priority interrupts) 
prev_STATUS     RES     0x01
prev_BSR        RES     0x01

p_tblptrl       RES     0x01
p_tblptrh       RES     0x01
p_tblptru       RES     0x01



;==============================================================================
;==============================================================================
;
;                                       IVT
;------------------------------------------------------------------------------
.i_reset        CODE    0x0400
        goto    main

.i_hi_int       CODE    0x0408
        goto    interrupts_hi

.i_lo_int       CODE    0x0418
        goto    interrupts_lo


;==============================================================================
;==============================================================================
;
;                                      Main  
;------------------------------------------------------------------------------
.c_main         CODE

main:
        
        ;--------------------------------
        ; Configure oscillator
        ;--------------------------------       
        movlw   0x72                        ; Int. osc @ 8Mhz
        movwf   OSCCON
        clrf    OSCTUNE                     
     
        ;--------------------------------
        ; Configure ports
        ;--------------------------------       
        clrf    PORTA
        clrf    TRISA                       ; Set all PORTA pins as outputs
        
        movlw   0x07
        movwf   TRISB                       ; Set RB0-RB2 as inputs
        clrf    PORTB

        movlw   0x80                        ; Set RC7 as input
        clrf    TRISC
        
        bcf     ADCON0, ADON                ; Disable A/D
        movlw   0x0F
        movwf   ADCON1

        
        bsf     KEYPAD_LAT_R0
        bsf     KEYPAD_LAT_R1
        bsf     KEYPAD_LAT_R2       


        ;--------------------------------
        ; Configure interrupts
        ;--------------------------------       
        movlw   b'00100000'                 ; TMR0IE=1
        movwf   INTCON
        
        movlw   b'11110001'                 ; TMR0IP=0 (low)
        movwf   INTCON2
        
        movlw   b'00000000'
        movwf   INTCON3

        
        ;--------------------------------
        ; Setup Timer0
        ;--------------------------------       
        movlw   B'00011111'
        movwf   T0CON

        movlw   0x8A
        movwf   TMR0H
        
        movlw   0xD0
        movwf   TMR0L
        
        bsf     T0CON, TMR0ON               ; Enable timer0
        
        ;--------------------------------
        ; Initialize peripherals
        ;--------------------------------   
        call    i2c_init                    ; Initialize I2C
        call    lcd_init                    ; Initialize LCD
        call    backlight_init              ; Enable backlight
        call    usart_init                  ; Initialize USART        
        
        
        ;--------------------------------
        ; Display boot screen
        ;--------------------------------   
        movlw   D'8'                        ; Goto column 8, row 0
        call    lcd_goto
        
        movlw   'X'                         ; Display 'XBMC'               
        call    lcd_write
        movlw   'B'
        call    lcd_write
        movlw   'M'
        call    lcd_write
        movlw   'C'
        call    lcd_write

        
        ;--------------------------------
        ; Enable interrupts
        ;--------------------------------   
        bsf     RCON, IPEN                  ; Enable interrupt priority
        bsf     INTCON, GIEL                ; Enable low priority interrupts
        bsf     INTCON, GIEH                ; Enable high priority interrupts
        
        
;------------------------------------------------------------------------------
;
; Main loop
;
;------------------------------------------------------------------------------
loop_main:
        clrf    p_count                     ; Clear parameter count
        clrf    params+0                    ; Clear parameters
        clrf    params+1                    
        clrf    params+2
        clrf    params+3

        call    usart_read_buffer           ; Read next character
        movwf   char
        
        xorlw   D'27'                       ; Check if escape character
        bz      escape_char

        movf    char, W
        call    lcd_write

        bra     loop_main                   ; Loop
    

;------------------------------------------------------------------------------
;
; Process escape sequence
;
;------------------------------------------------------------------------------
escape_char:

        call    usart_read_buffer           ; Read next character
        movwf   char
        
        brfeq   char, "[", escape_seq
        brfeq   char, "O", control
        bra     loop_main


escape_seq:     
        lfsr    FSR0,   params+0            ; move FSR1 to first parameter
    
loop_read_args:

        call    usart_read_buffer           ; Read next character
        movwf   char

        xorlw   ";"                
        bnz     chkif_number

        movlw   D'4'                        ; Maximum 4 parameters
        cpfslt  p_count
        bra     chkif_cmd

        incf    FSR0L, F                    ; Move FSR1 to next parameter
        incf    p_count
        
        bra     loop_read_args
        
chkif_number:       
        movlw   D'47'                       ; Check if the character is a
        cpfsgt  char                        ; number (ascii > 47 and < 58)
        bra     chkif_cmd
        
        movlw   D'58'                       
        cpfslt  char                        ; If not, jump to chkif_cmd, 
        bra     chkif_cmd                   ; otherwhise, process the number
                                            ; and store it in the current
                                            ; parameter pointed by FSR1
        
        movlw   D'10'                       ; Multiply the current parameter by
        mulwf   INDF0                       ; 10
        movff   PRODL, INDF0
        
        movlw   D'48'                       ; Convert number ascii to base 10
        subwf   char, W                     ; value and add it to the current 
        addwf   INDF0, F                    ; parameter

        movlw   D'0'                        ; Increment parameter counter if
        cpfsgt  p_count                     ; this is the first argument
        incf    p_count

        bra     loop_read_args
        
chkif_cmd:

        ;*** ECMA-48 sequences ***
        brfeq   char, "@", cmd_blank
        brfeq   char, "A", cmd_move_up
        brfeq   char, "B", cmd_move_down
        brfeq   char, "C", cmd_move_right
        brfeq   char, "D", cmd_move_left
        brfeq   char, "E", cmd_rtn
        brfeq   char, "F", cmd_rtn
        brfeq   char, "G", cmd_goto_col
        brfeq   char, "H", cmd_goto
        brfeq   char, "J", cmd_clr_screen
        brfeq   char, "K", cmd_erase_line
        ;              L : not implemented
        ;              M : not implemented
        ;              P : not implemented
        ;              X : not implemented      
        brfeq   char, "a", cmd_move_right
        ;              c : not implemented      
        brfeq   char, "d", cmd_goto_row
        brfeq   char, "e", cmd_move_down
        brfeq   char, "f", cmd_goto
        ;              g : not implemented      
        brfeq   char, "h", cmd_set_mode
        brfeq   char, "l", cmd_reset_mode
        brfeq   char, "m", cmd_set_attrib
        brfeq   char, "n", cmd_status
        ;              p : not implemented
        brfeq   char, "q", cmd_set_leds
        ;              r : not implemented
        brfeq   char, "s", cmd_save_pos
        brfeq   char, "u", cmd_restore_pos
                
        
        ;*** Extended sequences ***
        brfeq   char, "v", cmd_set_buffer_page      
        brfeq   char, "t", cmd_goto_page
        brfeq   char, "Y", cmd_set_custom_char
        brfeq   char, "Z", cmd_special_char
        brfeq   char, "!", cmd_reset
        
        goto    loop_main

control:
        call   usart_read_buffer           ; Read next character
        movwf   char
        
        brfeq   char, "H", control_home
        brfeq   char, "F", control_end
        goto    loop_main   



;------------------------------------------------------------------------------
;
; Commands
;
;------------------------------------------------------------------------------     

;------------------------------------------------------------------------------
; ESC [ {num} @ : Insert the indicated # of blank characters
;------------------------------------------------------------------------------
cmd_blank:
        movf    params+0
        btfsc   STATUS, Z
        goto    loop_main
        
        movlw   0x20
        call    lcd_write

        decf    params+0
        bra     cmd_blank


;------------------------------------------------------------------------------
; ESC [ {num} A : Move cursor up
;------------------------------------------------------------------------------
cmd_move_up:
        movlw   D'0'
        cpfsgt  params+0
        incf    params+0        

        movlw   D'20'
        mulwf   params+0
        movf    PRODL, W

        bcf     WREG, 7                     ; Allowed range : 0-127 
        negf    WREG
        
        call    lcd_pos_calc
        call    lcd_pos_update

        goto    loop_main

;------------------------------------------------------------------------------
; ESC [ {num} B : Move cursor down
; ESC [ {num} e
;------------------------------------------------------------------------------
cmd_move_down:
        movlw   D'0'
        cpfsgt  params+0
        incf    params+0

        movlw   D'20'
        mulwf   params+0
        movf    PRODL, W

        bcf     WREG, 7                     ; Allowed range : 0-127 
        
        call    lcd_pos_calc
        call    lcd_pos_update

        goto    loop_main

;------------------------------------------------------------------------------
; ESC [ {num} C : Move cursor right
; ESC [ {num} a
;------------------------------------------------------------------------------
cmd_move_right:
        movlw   D'1'
        tstfsz  params+0
        movf    params+0, W

        bcf     WREG, 7                     ; Allowed range : 0-127 
        
        call    lcd_pos_calc
        call    lcd_pos_update

        goto    loop_main

;------------------------------------------------------------------------------
; ESC [ {num} D : Move cursor left
;------------------------------------------------------------------------------
cmd_move_left:
        movlw   D'1'
        tstfsz  params+0
        movf    params+0, W

        bcf     WREG, 7                     ; Allowed range : 0-127 
        negf    WREG
        
        call    lcd_pos_calc
        call    lcd_pos_update

        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ {num} E : Move cursor down x row to column 1
; ESC [ {num} F : Move cursor up x row to column 1
;------------------------------------------------------------------------------
cmd_rtn:
        tstfsz  params+0
        decf    params+0

        movlw   0x00
        
        btfsc   lcd_cur_bptr, 5
        addlw   d'20'

        btfss   params+0, 0
        addlw   d'20'
        
        call    lcd_goto
        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ {num} G : Goto column x
;------------------------------------------------------------------------------
cmd_goto_col:
        tstfsz  params+0
        decf    params+0, W
        
        btfsc   lcd_cur_bptr, 5
        addlw   d'20'
        
        call    lcd_goto
        goto    loop_main

;------------------------------------------------------------------------------
; ESC [ {row};{col} H : Set cursor position
; ESC [ {row};{col} f
;------------------------------------------------------------------------------
cmd_goto:
        tstfsz  params+0
        decf    params+0
        
        tstfsz  params+1
        decf    params+1
        
        movlw   D'20'
        mulwf   params+0
        movf    PRODL, W
        addwf   params+1, W
        
        call    lcd_goto

        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ {mode} J : Clear screen
; - (default) From cursor to end of display
; - 1J = from cursor to begin of display
; - 2J = entire display
;------------------------------------------------------------------------------
cmd_clr_screen:

        movf    lcd_cur_bptr, W
        andlw   0x1F
        btfsc   lcd_cur_bptr, 5
        addlw   d'20'
        movwf   params+2


        brfeq   params+0, 0x02, clr_scr

        movlw   0x01
        cpfseq  params+0
        movlw   0x28
        decf    WREG

        call    lcd_clear_to
        
        movf    params+2, W
        call    lcd_goto
        
        goto    loop_main

;*** Clear entire screen ****
clr_scr:        
        call    lcd_clear
        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ {mode} K : Clear line
; - (default) From cursor to end of line
; - 1J = from cursor to begin of line
; - 2J = entire line
;------------------------------------------------------------------------------
cmd_erase_line:
        movf    lcd_cur_bptr, W
        andlw   0x1F
        btfsc   lcd_cur_bptr, 5
        addlw   d'20'
        movwf   params+2

        brfeq   params+0, 0x02, clr_line
        
        movlw   d'0'
        btfsc   lcd_cur_bptr, 5
        addlw   d'20'
        movwf   params+1
        
        movlw   d'1'
        cpfseq  params+0
        movlw   d'20'
        decf    WREG
        
        addwf   params+1, W
        call    lcd_clear_to    
        
        movf    params+2, W
        call    lcd_goto
        
        goto    loop_main
        
;*** Clear the entire line ****     
clr_line:

        movlw   d'0'
        btfsc   lcd_cur_bptr, 5
        addlw   d'20'
        call    lcd_goto                    ; Goto the begining of the current
                                            ; line

        movlw   d'19'
        btfsc   lcd_cur_bptr, 5
        addlw   d'20'
        call    lcd_clear_to                ; Clear to the end of the current
                                            ; line

        movf    params+2, W
        call    lcd_goto

        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ {row} d : Move cursor to the indicated row, current column
;------------------------------------------------------------------------------
cmd_goto_row:
        tstfsz  params+0
        decf    params+0
        
        movf    lcd_cur_bptr, W
        andlw   0x1F

        btfsc   params+0, 0
        addlw   d'20'
        
        call    lcd_goto
        
        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ {mode} h : Set display mode
;------------------------------------------------------------------------------
cmd_set_mode:
        brfeq   params+0, D'25', mode_set_cursor
        brfeq   params+0, D'26', mode_set_block
        brfeq   params+0, D'50', mode_set_display
        goto    loop_main
        
mode_set_cursor:
        bsf     cur_display, 1
        bra     set_display_mode

mode_set_display:
        bsf     cur_display, 2
        bra     set_display_mode

mode_set_block:     
        bsf     cur_display, 0
        bra     set_display_mode
        
;------------------------------------------------------------------------------
; ESC [ {mode} l : Reset display mode (display=1, block=0, cursor=0)
;------------------------------------------------------------------------------
cmd_reset_mode:
        brfeq   params+0, D'25', mode_reset_cursor
        brfeq   params+0, D'26', mode_reset_block
        brfeq   params+0, D'50', mode_reset_display
        goto    loop_main
        
mode_reset_cursor:
        bcf     cur_display, 1
        bra     set_display_mode

mode_reset_display:
        bcf     cur_display, 2
        bra     set_display_mode

mode_reset_block:       
        bcf     cur_display, 0
        bra     set_display_mode

set_display_mode:
        movf    cur_display, W
        call    lcd_setdisplay
        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ {attrib};{value} m : Reset display mode (display=1, block=0, cursor=0)
;------------------------------------------------------------------------------
cmd_set_attrib:

        brfeq   params+0, 0, attrib_default 
        brfeq   params+0, 48, attrib_backlight_rgb
        brfeq   params+0, 49, attrib_backlight_default
        brfeq   params+0, 62, attrib_backlight_r
        brfeq   params+0, 63, attrib_backlight_g
        brfeq   params+0, 64, attrib_backlight_b
        brfeq   params+0, 70, attrib_contrast
        
        
        tstfsr  params+0, 40, 47
        bra     $+8

        movlw   d'40'
        subwf   params+0, f
        goto    attrib_backlight_color

        tstfsr  params+0, 100, 107
        bra     $+8

        movlw   d'92'
        subwf   params+0, f
        goto    attrib_backlight_color




        goto    loop_main       



;*** Reset all attributes ***
attrib_default:

        movlw   d'32'
        call    lcd_setcontrast             ; Set Contrast

        ;*** Fall through ***

;*** Reset backlight color ***
attrib_backlight_default:
        call    backlight_init
        
        goto    loop_main   
        
    
;*** Set backlight color (red only) ***     
attrib_backlight_r:
    
        movff   params+1, backlight_lvl+0
        
        call    backlight_set
        goto    loop_main

;*** Set backlight color (green only) ***       
attrib_backlight_g:
    
        movff   params+1, backlight_lvl+1
        
        call    backlight_set
        goto    loop_main

;*** Set backlight color (blue only) ***        
attrib_backlight_b:
    
        movff   params+1, backlight_lvl+2
        
        call    backlight_set
        goto    loop_main

;*** Set backlight color (rgb) ***      
attrib_backlight_rgb:
    
        movff   params+1, backlight_lvl+0
        movff   params+2, backlight_lvl+1
        movff   params+3, backlight_lvl+2
        
        call    backlight_set
        goto    loop_main

attrib_backlight_color:

        movf    params+0, W
        call    backlight_get_clrtbl
        
        goto    loop_main

attrib_contrast:
        movf    params+1, W
        call    lcd_setcontrast
        
        goto    loop_main



;------------------------------------------------------------------------------
; ESC [ n : Query status
;------------------------------------------------------------------------------
cmd_status:
        
        brfeq   params+0, 6, status_position
        
        goto    loop_main

status_position:
        
        movlw   d'27'
        call    usart_write_byte
        movlw   "["
        

        goto    loop_main



;------------------------------------------------------------------------------
; ESC [ q : Set leds
;------------------------------------------------------------------------------
cmd_set_leds:

        brfeq   params+0, 0, leds_off
        brfeq   params+0, 5, led_record
        brfeq   params+0, 6, led_msg
        
        goto    loop_main

leds_off:   

        bcf     MSG_LED_LAT_A               ; Turn off all leds
        bcf     MSG_LED_LAT_K
        bcf     REC_LED_LAT_A
        bcf     REC_LED_LAT_K       

        goto    loop_main

led_record:
        bcf     REC_LED_LAT_A
        bcf     REC_LED_LAT_K
        
        btfss   params+1, 0
        bsf     REC_LED_LAT_A

        btfsc   params+1, 0
        bsf     REC_LED_LAT_K

        btfsc   params+1, 1
        bcf     REC_LED_LAT_A

        goto    loop_main

led_msg:

        bcf     MSG_LED_LAT_A
        bcf     MSG_LED_LAT_K
        
        btfss   params+1, 0
        bsf     MSG_LED_LAT_A

        btfsc   params+1, 0
        bsf     MSG_LED_LAT_K

        btfsc   params+1, 1
        bcf     MSG_LED_LAT_A

        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ s : Save cursor location
;------------------------------------------------------------------------------
cmd_save_pos:
        call    lcd_save_pos
        goto    loop_main

;------------------------------------------------------------------------------
; ESC [ u : Restore cursor location
;------------------------------------------------------------------------------
cmd_restore_pos:
        call    lcd_restore_pos
        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ {id} v : Set buffer page
;------------------------------------------------------------------------------
cmd_set_buffer_page:
        movf    params+0, W
        call    lcd_set_page
        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ {id};{transition};{speed} t : Goto page
;------------------------------------------------------------------------------
cmd_goto_page:
        movff   params+1, lcd_trans_type
        movff   params+2, lcd_trans_speed

        movf    params+0, W
        call    lcd_show_page
        
        movlw   "o"
        call    usart_write_byte
        
        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ {id} Y : Set custom character
;------------------------------------------------------------------------------
cmd_set_custom_char:

        lfsr    FSR0, buffer+0
        
        movlw   D'8'
        movwf   i
        
loop_rx:
        call    usart_read_buffer
        movwf   POSTINC0
        
        decfsz  i
        bra     loop_rx
        
        lfsr    FSR0, buffer+0
        
        movf    params+0, W
        call    lcd_write_cgram
        
        goto    loop_main
        
        
;------------------------------------------------------------------------------
; ESC [ {char} Z : Send special character
;------------------------------------------------------------------------------
cmd_special_char:
        movf    params+0, W
        call    lcd_write
        
        goto    loop_main


;------------------------------------------------------------------------------
; ESC [ ! : Reset
;------------------------------------------------------------------------------
cmd_reset:
        movff   params+0,   0x00
        movff   params+1,   0x01
        movff   params+2,   0x02
        
        reset


;------------------------------------------------------------------------------
; ESC O H : 
;------------------------------------------------------------------------------
control_home:
        movlw   D'0'
        call    lcd_goto
        
        goto    loop_main
        
;------------------------------------------------------------------------------
; ESC O F : 
;------------------------------------------------------------------------------
control_end:
        movlw   D'39'
        call    lcd_goto
        
        goto    loop_main









;==============================================================================
;==============================================================================
;
;                                Interrupt handler
;------------------------------------------------------------------------------
interrupts_hi:
        btfsc   PIR1, RCIF
        goto    usart_isr

        reset                               ; Unexpected interrupt

        
interrupts_lo:  
        movff   STATUS, prev_STATUS
        movff   WREG, prev_WREG
        movff   BSR, prev_BSR

        btfsc   INTCON, TMR0IF
        goto    timer0_isr

        reset

interrupts_lo_exit:     
        movff   prev_STATUS, STATUS
        movff   prev_WREG, WREG
        movff   prev_BSR, BSR
        
        retfie


;------------------------------------------------------------------------------
; Timer0 ISR
;------------------------------------------------------------------------------
timer0_isr:
        bcf     INTCON, TMR0IE              ; Disable Timer0 interupt

        btfsc   KEYPAD_PIN_C0
        bra     keypad_scan
        
        btfsc   KEYPAD_PIN_C1
        bra     keypad_scan
        
        bra     keypad_done
        
keypad_scan:
        mdelay  d'20'                       ; 20ms debounce time

        ;--------------------------------
        ; Scan Row 0
        ;--------------------------------
        bsf     KEYPAD_LAT_R0               ; Enable Row 0
        bcf     KEYPAD_LAT_R1               ; Disable other rows
        bcf     KEYPAD_LAT_R2

        movlw   "C"
        btfsc   KEYPAD_PIN_C0               ; Check column 0
        bra     keypad_match                ; R0,C0 = Right

        movlw   "A"
        btfsc   KEYPAD_PIN_C1               ; Check column 1
        bra     keypad_match                ; R0,C1 = Up

        ;--------------------------------
        ; Scan Row 1
        ;--------------------------------
        bcf     KEYPAD_LAT_R0               ; Disable Row 0
        bsf     KEYPAD_LAT_R1               ; Enable Row 1

        movlw   "D"
        btfsc   KEYPAD_PIN_C0               ; Check column 0
        bra     keypad_match                ; R1,C0 = Left
        
        movlw   0xD
        btfsc   KEYPAD_PIN_C1               ; Check column 1
        bra     keypad_match                ; R1,C1 = Enter

        ;--------------------------------
        ; Scan Row 2
        ;--------------------------------
        bcf     KEYPAD_LAT_R1               ; Disable Row 1
        bsf     KEYPAD_LAT_R2               ; Enable Row 2

        movlw   0x08
        btfsc   KEYPAD_PIN_C0               ; Check column 0
        bra     keypad_match                ; R2,C0 = Menu
        
        movlw   "B"
        btfsc   KEYPAD_PIN_C1               ; Check column 1
        bra     keypad_match                ; R2,C1 = Down

        bra     keypad_done

keypad_match:

        movwf   kpd_lastkey
        
        movlw   0x1F
        cpfsgt  kpd_lastkey
        bra     keypad_char
        
        movlw   d'27'   
        call    usart_write_byte        

        movlw   "["
        call    usart_write_byte        

keypad_char:

        movf    kpd_lastkey, W
        call    usart_write_byte        


keypad_done:
keypad_wait_release:

        btfsc   KEYPAD_PIN_C0
        bra     keypad_wait_release
        
        btfsc   KEYPAD_PIN_C1
        bra     keypad_wait_release

        bsf     KEYPAD_LAT_R0               ; Enable all rows
        bsf     KEYPAD_LAT_R1
        bsf     KEYPAD_LAT_R2

        movlw   0x8A
        movwf   TMR0H
        
        movlw   0xD0
        movwf   TMR0L
        
        bcf     INTCON, TMR0IF              ; Clear Timer0 interrupt flag       
        bsf     INTCON, TMR0IE              ; RE-enable Timer0 interrupt
        
        goto    interrupts_lo_exit


;******************************************************************************
;******************************************************************************
;* 
;* For tests on emulator (no bootloader)
;* 
;******************************************************************************
;******************************************************************************
        ORG     0x000
        goto    0x400
        
        ORG     0x008
        goto    0x408

        ORG     0x018
        goto    0x418

        
;==============================================================================
;==============================================================================
        END
