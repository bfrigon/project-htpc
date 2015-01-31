;******************************************************************************
;*   Project:      PBX Front panel lcd                                        *
;*   Version:      0.1                                                        *
;*                                                                            *
;*   Filename:     lcd.asm                                                    *
;*   Description:  LCD comm                                                   *
;*   Last mod:     28 July 2012                                               *
;*                                                                            *
;*   Author:       Benoit Frigon                                              *
;*   Email:        <bfrigon@gmail.com>                                        *
;*                                                                            *
;******************************************************************************

include <p18f2520.inc>
include "i2c.inc"
include "delay.inc"
include "macro.inc"


I2CADDR_LCD             equ     0x78        ;

MODE_INSTR              equ     0x00
MODE_DATA               equ     0x40

; *** Op codes ***
CMD_CLEAR               equ     0x01
CMD_RTNHOME             equ     0x02
CMD_ENTRYMODE           equ     0x04
CMD_DISPLAY             equ     0x08
CMD_FUNCTION            equ     0x20
CMD_DDRAM               equ     0x80
; --- when IS = 00 -----------------
CMD_SHIFT               equ     0x10
CMD_CGRAM               equ     0x40
; --- when IS = 01 -----------------
CMD_BIAS                equ     0x14
CMD_ICON                equ     0x40
CMD_CONTRAST_UPPER      equ     0x50
CMD_FOLLOWER            equ     0x60
CMD_CONTRAST_LOWER      equ     0x70
; --- when IS = 10 ------------------
CMD_DBLHEIGHT           equ     0x10

DEF_CONTRAST            equ     d'32'
DEF_FUNCTION            equ     0x18        ; DL=8bit, N=2line, DH=off, IS=0
DEF_DISPLAY             equ     0x04

; *** Transition types ***
#define TRANS_CUR           0x00
#define TRANS_SLIDE_RIGHT   0x01
#define TRANS_SLIDE_LEFT    0x02



;==============================================================================
;==============================================================================
;
;                                 Symbols 
;------------------------------------------------------------------------------
; *** subroutines ***
GLOBAL          lcd_init                    ; Initialize LCD
GLOBAL          lcd_write
GLOBAL          lcd_setcontrast
GLOBAL          lcd_setdisplay
GLOBAL          lcd_goto                    ; Move cursor to position x
GLOBAL          lcd_show_page               ; Set visible page
GLOBAL          lcd_clear                   ; Clear LCD
GLOBAL          lcd_clear_to                ; Clear LCD from cursor to pos x
GLOBAL          lcd_pos_calc
GLOBAL          lcd_pos_update
GLOBAL          lcd_set_page
GLOBAL          lcd_save_pos                ; Save current cursor position
GLOBAL          lcd_restore_pos             ; Restore previous cursor position
GLOBAL          lcd_write_cgram             ; Write custom characters data

; *** Variables ***
GLOBAL          lcd_trans_type              ; Transition type
GLOBAL          lcd_trans_speed             ; Transition speed
GLOBAL          cur_display
GLOBAL          prev_display
GLOBAL          cur_contrast
GLOBAL          lcd_cur_bptr

; *** External symbols import ***        
EXTERN          delay100tcy
EXTERN          delay10tcy
EXTERN          delay1ktcy
EXTERN          delay10ktcy

EXTERN          i2c_write
EXTERN          i2c_read


;==============================================================================
;==============================================================================
;
;                                  Data
;------------------------------------------------------------------------------
; *** Access bank ***
.a_lcd          UDATA_ACS
char            RES     0x01                ; char buffer
cur_contrast    RES     0x01                ; Current contrast value
cur_display     RES     0x01                ; Current display mode
prev_display    RES     0x01                ; Previous display mode
cur_function    RES     0x01
lcd_vis_page    RES     0x01                ; Current visible page
lcd_cur_bptr    RES     0x01                ; Current buffer ptr
temp            RES     0x01                ; Temporary data
i               RES     0x01                ; Iteration counter
lcd_prev_bptr   RES     0x01                ; Previous buffer ptr
lcd_saved_pos   RES     0x01                ; Saved cursor position
lcd_trans_type  RES     0x01                ; Transiton type
lcd_trans_speed RES     0x01                ; Transition speed


; Bank
.b_lcd          UDATA
lcd_buffer      RES     0x100               ; LCD buffer


;==============================================================================
;==============================================================================
;
;                                Subroutines 
;------------------------------------------------------------------------------
.c_lcd          CODE




;******************************************************************************
; lcd_init
;
; Arguments : None
; Return    : None
;******************************************************************************
lcd_init:

        clrf    cur_function
        clrf    cur_display
        clrf    prev_display
        clrf    cur_contrast
        clrf    lcd_cur_bptr
        clrf    temp
        clrf    lcd_vis_page


        ;-----------------------------------------
        ; Clear lcd buffer (all pages)
        ;-----------------------------------------
        lfsr    FSR1, lcd_buffer+0          ; Set FSR1 ptr to buffer

        clrf    i                           ; 256 characters to clear
                
loop_clear_buffer:
        movlw   0x20                        ; Fill buffer with spaces (0x20)
        movwf   POSTINC1
        
        decfsz  i
        bra     loop_clear_buffer           ; loop until buffer is cleared
        

        ;-----------------------------------------
        ; LCD Init sequence
        ;-----------------------------------------
        mdelay  d'40'                       ; 40ms delay
        
        i2sb    SEN                         ; Start condition
        i2wr    I2CADDR_LCD                 ; Send slave address
        i2wr    MODE_INSTR                  ; Set instruction mode
        
        i2wr    CMD_FUNCTION + b'11000'     ; DL=8bit, N=2 lines, DH=0, IS=00
        udelay  d'30'                       ; 30us delay

        i2wr    CMD_FUNCTION + b'11001'     ; DL=8bit, N=2 lines, DH=0, IS=01
        udelay  d'30'                       ; 30us delay
        
        i2wr    CMD_BIAS + b'0001'          ; Set bias, BS=0 (1/5), FX=1
        udelay  d'30'                       ; 30us delay

        i2wr    CMD_FOLLOWER + b'1101'      ; Fon=1, Rab=101
        mdelay  d'125'                      ; 30us delay

        i2wr    CMD_CLEAR
        mdelay  d'2'                        ; 2ms delay

        i2wr    CMD_ENTRYMODE + b'10'       ; I/D=1 (Left to right), shift=0
        udelay  d'30'

        i2sb    PEN                         ; Stop condition    


        movlw   DEF_CONTRAST
        call    lcd_setcontrast             ; Set Contrast

        movlw   DEF_DISPLAY
        call    lcd_setdisplay              ; Turn on display
        
        
        

        return



;******************************************************************************
; lcd_set_page : Set buffer page.
;
; Arguments : W= Page ID
; Return    : None
;******************************************************************************
lcd_set_page:
        mullw   D'64'                       ; Set buffer ptr to page X
        movff   PRODL, lcd_cur_bptr         ; boundary
        
        movlw   D'0'                        ; Set position to 0,0
        rcall   lcd_goto
        return



;******************************************************************************
; lcd_set_page : Set visible page.
;
; Arguments : W= Page ID
;             lcd_trans_type= Type of transition to use
;             lcd_trans_speed= Delay between transition step
;
; Return    : None
;******************************************************************************
lcd_show_page:
        mullw   0x40                        ; Set current page
        movff   PRODL, lcd_vis_page
        movff   PRODL, lcd_cur_bptr
        
        ;movlw  OP_DISPLAY + 0x04           ; Hide cursor during the
        ;rcall  lcd_send_cmd                ; transition
        
        brfeq   lcd_trans_type, TRANS_SLIDE_RIGHT, trans_slide
        brfeq   lcd_trans_type, TRANS_SLIDE_LEFT, trans_slide
        bra     trans_cut


trans_done:
        movlw   d'0'
        rcall   lcd_goto
        
        ;movf   cur_mode, W                 ; Restore previous display mode
        ;addlw  OP_DISPLAY
        ;rcall  lcd_send_cmd
        
        return


;------------------------------------------------------------------------------
; Transition : Cut
;------------------------------------------------------------------------------
trans_cut:
        movlw   0x00                        ; Copy new buffer page in place
        rcall   lcd_dump_buffer 

        bra     trans_done


;------------------------------------------------------------------------------
; Transition : Slide
;------------------------------------------------------------------------------
trans_slide:
        ;--------------------------------
        ; Visible address range on LCD is 
        ; 00-0F (first row) and 40-4F 
        ; (second row). To acheive the 
        ; slide effect, we dump the new 
        ; page outside the visible range
        ; and then shift the display 16 
        ; times.
        ;--------------------------------       

        movlw   0x14                        ; Set DDRAM address at 0x14 (right
                                            ; of visible range)

        ;btfsc  lcd_trans_type, 0           ; if direction is right, set DDRAM 
        ;addlw  0x08                        ; at 0x18 (left of visible range)

        rcall   lcd_dump_buffer             ; Copy the new page to this address


        movlw   D'20'                       ; Shift the display 20 times
        movwf   i

loop_shift:


        ;--------------------------------
        ; Shift screen
        ;--------------------------------       
        i2sb    SEN                         ; Start condition on i2c bus
        
        i2wr    I2CADDR_LCD                 ; Send slave address
        i2wr    MODE_INSTR                  ; Set instruction mode      
        
        movlw   CMD_SHIFT                   ; Cursor opcode (0x10)
        bsf     WREG, 3                     ; Set display shift=on (bit 3)
                                            ; shift to left by default

        btfsc   lcd_trans_type, 0           ; if direction is right, set shift
        bsf     WREG, 2                     ; to right bit (2).
        
        call    i2c_write
        mdelay  d'2'                        ; 2ms delay 
        
        i2sb    PEN                         ; Stop condition on i2c bus     

        movf    lcd_trans_speed, W          ; if speed = 0, set speed to 5
        btfsc   STATUS, Z

        movlw   D'5'                        ; delay : speed x 5ms
        call    delay10ktcy
        
        decfsz  i
        bra     loop_shift
        
        ;--------------------------------       
        ; Once the transition is over, 
        ; the entire display has been 
        ; shifted and previous page is 
        ; now hidden. We then copy the 
        ; new page over the previous one 
        ; at the origin (0x00) and then 
        ; shift the display back to it's 
        ; original position.
        ;--------------------------------       
        
        movlw   0x00                        ; Copy new page to origin
        rcall   lcd_dump_buffer

        
        ;--------------------------------
        ; Return cursor home
        ;--------------------------------       
        i2sb    SEN                         ; Start condition on i2c bus
        
        i2wr    I2CADDR_LCD                 ; Send slave address
        i2wr    MODE_INSTR                  ; Set instruction mode      
        
        i2wr    CMD_RTNHOME
        mdelay  d'2'                        ; 2ms delay 
        
        i2sb    PEN                         ; Stop condition on i2c bus     

        bra     trans_done



;******************************************************************************
; lcd_dump_buffer : Transfert page from buffer to LCD.
;
; Arguments : W= Address of LCD DDRAM where to dump the buffer.
; Return    : None
;******************************************************************************
lcd_dump_buffer:
        
        rcall   lcd_set_ddram_ptr
        
        movf    lcd_cur_bptr, W
        andlw   0xC0
        
        movwf   FSR1L
        
        movlw   d'40'
        movwf   i
        
loop_dump_buffer:
        
        ;--------------------------------
        ; Write the character to lcd
        ;--------------------------------       
        i2sb    SEN                         ; Start condition on i2c bus
        
        i2wr    I2CADDR_LCD                 ; Send slave address
        i2wr    MODE_DATA                   ; Set instruction mode      
        
        movf    POSTINC1, W     
        call    i2c_write
        udelay  d'30'                       ; 30us delay
        
        i2sb    PEN                         ; Stop condition on i2c bus
        

        ;--------------------------------
        ; Check if still on the same line
        ;--------------------------------
        movlw   d'21'
        cpfseq  i
        bra     $+4
        bra     change_line

        decfsz  i
        bra     loop_dump_buffer

        movlw   0x00                        ; Set cursor home
        rcall   lcd_goto

        return

change_line:
        movlw   0xE0
        andwf   FSR1L
        btg     FSR1L, 5
        
        movf    temp, W
        andlw   0x7F

        addlw   0x40
        rcall   lcd_set_ddram_ptr
        
        decf    i
        bra     loop_dump_buffer



;******************************************************************************
; lcd_set_ddram_ptr : 
;
; Arguments : None
; Return    : None
;******************************************************************************
lcd_set_ddram_ptr:
        movwf   temp

        i2sb    SEN                         ; Start condition on i2c bus
        
        i2wr    I2CADDR_LCD                 ; Send slave address
        i2wr    MODE_INSTR                  ; Set instruction mode  

        movf    temp, W
        andlw   0x7F

        iorlw   CMD_DDRAM                   ; Insert Set DDRAM opcode

        call    i2c_write                   ; Send command to the LCD
        udelay  d'30'                       ; 30us delay

        i2sb    PEN                         ; Stop condition on i2c bus     

        return  

        

;******************************************************************************
; lcd_write
;
; Arguments : None
; Return    : None
;******************************************************************************
lcd_write:
        movwf   char

        brfeq   char, "\b", chr_backspace   
        brfeq   char, 0x7F, chr_backspace   
        brfeq   char, "\n", chr_newline     
        brfeq   char, "\r", chr_return
        brfeq   char, "\f", chr_formfeed


        ;--------------------------------
        ; Write the character to buffer
        ;--------------------------------       
        lfsr    FSR1, lcd_buffer+0          ; Set FSR1 ptr to buffer
        movff   lcd_cur_bptr, FSR1L             
        movff   char, INDF1                 ; Write character to the buffer

        movlw   d'1'                        ; Increment the buffer ptr
        rcall   lcd_pos_calc

        ;--------------------------------
        ; Check if the current page is 
        ; visible
        ;--------------------------------
        movlw   0xC0
        andwf   lcd_cur_bptr, W

        cpfseq  lcd_vis_page                ; if current page is not visible,
        return  

        ;--------------------------------
        ; Write the character to lcd
        ;--------------------------------       
        i2sb    SEN                         ; Start condition on i2c bus
        
        i2wr    I2CADDR_LCD                 ; Send slave address
        i2wr    MODE_DATA                   ; Set data mode     
        
        movf    char, W     
        call    i2c_write
        udelay  d'30'                       ; 30us delay
        
        i2sb    PEN                         ; Stop condition on i2c bus


        ;--------------------------------
        ; If the row has changed, update
        ; the lcd cursor as well
        ;--------------------------------       
        movf    lcd_cur_bptr, W             ; If the new buffer ptr is located
        andlw   0x1F                        ; on the same row, return
        btfss   STATUS, Z
        return                  
        
        rcall   lcd_pos_update              ; Update the cursor position on the 
        return                              ; lcd


        
;------------------------------------------------------------------------------
; Backspace character
;------------------------------------------------------------------------------
chr_backspace:
        movlw   d'-1'                       ; Move cursor to the left
        rcall   lcd_pos_calc
        rcall   lcd_pos_update
        
        movlw   0x20                        ; Clear the character at this
        rcall   lcd_write                   ; position

        movlw   d'-1'                       ; Move cursor to the left again
        rcall   lcd_pos_calc
        rcall   lcd_pos_update
                
        return      
        
        
;------------------------------------------------------------------------------
; New line (\n)
;------------------------------------------------------------------------------
chr_newline:
        movlw   d'20'                       ; Move buffer pointer down one row
        rcall   lcd_pos_calc
        rcall   lcd_pos_update
        return


;------------------------------------------------------------------------------
; Carriage return (\r)
;------------------------------------------------------------------------------
chr_return:
        movlw   0x00                        ; move buffer pointer to the
                                            ; start of the current row

        btfsc   lcd_cur_bptr, 5
        addlw   d'20'
        
        rcall   lcd_goto
        return
                

;------------------------------------------------------------------------------
; Form feed (\f)
;------------------------------------------------------------------------------
chr_formfeed:
        rcall   lcd_clear                   ; Clear the current buffer page
        return



;******************************************************************************
; lcd_goto : Move cursor to position X.
;
; Arguments : W= new pointer ; (Row1=0x00-0x13, Row2=0x14-0x27)
; Return    : None
;******************************************************************************
lcd_goto:

        movwf   temp
        
        movlw   0xC0
        andwf   lcd_cur_bptr
        
        movf    temp, W
        bcf     WREG, 7                     ; Allowed range : 0-127 
        
        rcall   lcd_pos_calc
        
        ;--------------------------------
        ; Set new cursor position on LCD        
        ;--------------------------------
        rcall   lcd_pos_update

        return



;******************************************************************************
; lcd_clear : Fill the current buffer page with spaces (0x20) and clear the lcd
;             if the page is visible.
;
; Arguments : None
; Return    : None
;******************************************************************************
lcd_clear:
        movlw   0xC0                        ; Set buffer pointer to the origin
        andwf   lcd_cur_bptr                ; of the current page
        
        lfsr    FSR1, lcd_buffer+0          ; Point FSR1 to buffer base
        movff   lcd_cur_bptr, FSR1L         ; Point FSR1 to current page

        movlw   D'64'                       ; Erase 64 characters (page size)
        movwf   i
        
loop_clear_char:
        movlw   0x20                        ; Write a space character (0x20)
        movwf   POSTINC1                    ; to the buffer

        decfsz  i
        bra     loop_clear_char             ; loop until all character are
                                            ; cleared
        movlw   0xC0
        andwf   lcd_cur_bptr
        movf    lcd_cur_bptr, W

        cpfseq  lcd_vis_page                ; if current page is not visible,
        return                              ; return


        i2sb    SEN                         ; Start condition on i2c bus
        i2wr    I2CADDR_LCD                 ; Send slave address
        i2wr    MODE_INSTR                  ; Set instruction mode

        i2wr    CMD_CLEAR
        mdelay  d'2'                        ; 2ms delay     

        i2sb    PEN                         ; Stop condition on i2c bus

        return
        


;******************************************************************************
; lcd_clear_to: Clear the lcd from cursor to specified position
;
; Arguments : W= Position
; Return    : None
;******************************************************************************
lcd_clear_to:

        movwf   temp
        
        movf    lcd_cur_bptr, W
        andlw   0x1F
        btfsc   lcd_cur_bptr, 5
        addlw   d'20'
        
        cpfsgt  temp
        bra     clear_to_left
        
clear_to_right:
        ; temp - current        

        subwf   temp
        movff   temp, i
        incf    i
        
        bra     loop_clear_to

clear_to_left:
        ; current - temp

        movwf   i
        movf    temp, W
        subwf   i
        incf    i

        movf    temp, W
        rcall   lcd_goto

loop_clear_to
        movlw   0x20
        rcall   lcd_write
        
        decfsz  i
        bra     loop_clear_to

        return



;******************************************************************************
; lcd_pos_calc : Calculate the new buffer position from an offset
;
; Arguments : W= Number of characters (> 0 : move right, < 0 : Left)
; Return    : None
;******************************************************************************
lcd_pos_calc:

        ;--------------------------------
        ; Buffer pointer bits :
        ; [pp][r][ccccc]
        ; p = page id (0-3)
        ; r = row number (0-1)
        ; c = column number (0-19)
        ;--------------------------------

        movff   lcd_cur_bptr, temp
        movwf   lcd_cur_bptr        
        
        btfsc   WREG, 7
        bra     offset_left

offset_right:
        movlw   0x1F
        andwf   temp, W
        addwf   lcd_cur_bptr
        

loop_findrow_right:
        movlw   d'19'
        cpfsgt  lcd_cur_bptr
        bra     offset_done
        
        btg     temp, 5
        movlw   d'20'
        subwf   lcd_cur_bptr
        
        bra     loop_findrow_right      


offset_left:        

        movlw   0x1F
        andwf   temp, W
        addwf   lcd_cur_bptr    
        
loop_findrow_left:
        btfss   lcd_cur_bptr, 7
        bra     offset_done
        
        btg     temp, 5
        movlw   d'20'
        addwf   lcd_cur_bptr
        
        bra     loop_findrow_left   


offset_done:

        movlw   0xC0
        andwf   temp, W
        iorwf   lcd_cur_bptr

        btfsc   temp, 5
        bsf     lcd_cur_bptr, 5
                
        return      



;******************************************************************************
; lcd_pos_update : Sync the LCD position with the buffer position 
;
; Arguments : None
; Return    : None
;******************************************************************************
lcd_pos_update:

        movlw   0xC0
        andwf   lcd_cur_bptr, W

        cpfseq  lcd_vis_page                ; if current page is not visible,
        return                              ; return

        movlw   0x1F
        andwf   lcd_cur_bptr, W

        btfsc   lcd_cur_bptr, 5             ; if row == 1,
        addlw   0x40                        ; set DDRAM on second row

        rcall   lcd_set_ddram_ptr       
        return



;******************************************************************************
; lcd_save_pos : Save current cursor position.
;
; Arguments : None
; Return    : None
;******************************************************************************
lcd_save_pos:
        movf    lcd_cur_bptr, W
        andlw   0x1F
        btfsc   lcd_cur_bptr, 5
        addlw   d'20'
        movwf   lcd_saved_pos
        
        return



;******************************************************************************
; lcd_restore_pos : Restore previously saved cursor position.
;
; Arguments : None
; Return    : None
;******************************************************************************
lcd_restore_pos:
        movf    lcd_saved_pos, W
        rcall   lcd_goto

        return



;******************************************************************************
; lcd_setcontrast
;
; Arguments : None
; Return    : None
;******************************************************************************
lcd_setcontrast:
        andlw   0x3F                        ; Mask the 2 upper bits
        movwf   cur_contrast                ; Store the new contrast value
        

        i2sb    SEN                         ; Start condition on i2c bus
        
        i2wr    I2CADDR_LCD                 ; Send slave address
        i2wr    MODE_INSTR                  ; Set instruction mode      

        ;--------------------------------
        ; Select instruction table 01
        ;--------------------------------       
        movf    cur_function, W
        iorlw   DEF_FUNCTION
        iorlw   0x01                        ; Set IS bits 01
        iorlw   CMD_FUNCTION                ; Insert FUNCTION opcode

        call    i2c_write                   ; Send command to LCD
        udelay  d'30'                       ; 30us delay

        ;--------------------------------
        ; Set lower 4 bits of the contrast
        ; value (C0-C3)
        ;--------------------------------       
        movf    cur_contrast, W
        andlw   0x0F                        ; Mask the 4 upper bits
        iorlw   CMD_CONTRAST_LOWER          ; Insert CONTRAST opcode

        call    i2c_write                   ; Send CONTRAST command to LCD
        udelay  d'30'                       ; 30us delay        

        ;--------------------------------
        ; Set upper 2 bits of the contrast
        ; value (C4-C5)
        ;--------------------------------       
        swapf   cur_contrast, W
        andlw   0x03                        ; Mask the 6 upper bits
        iorlw   0x0C                        ; Set Ion=1 (bit 2), Bon=1 (bit 3)
        iorlw   CMD_CONTRAST_UPPER          ; Insert PWR/ICON/CONTRAST opcode

        call    i2c_write                   ; Send command to LCD
        udelay  d'30'                       ; 30us delay


        ;--------------------------------
        ; Select instruction table 00
        ;--------------------------------       
        movf    cur_function, W
        iorlw   DEF_FUNCTION
        iorlw   CMD_FUNCTION                ; Insert FUNCTION opcode

        call    i2c_write                   ; Send FUNCTION command to LCD
        udelay  d'30'                       ; 30us delay

        
        i2sb    PEN                         ; Stop condition on i2c bus
        
        return



;******************************************************************************
; lcd_setdisplay
;
; Arguments : None
; Return    : None
;******************************************************************************
lcd_setdisplay:
        andlw   0x07                        ; Only keep the 3 lower bits
        movwf   cur_display                 ; Store the new display mode

        i2sb    SEN                         ; Start condition on i2c bus
        
        i2wr    I2CADDR_LCD                 ; Send slave address
        i2wr    MODE_INSTR                  ; Set instruction mode      
        
        movf    cur_display, W
        iorlw   CMD_DISPLAY                 ; Insert DISPLAY opcode
        
        call    i2c_write                   ; Send DISPLAY command to LCD
        udelay  d'30'                       ; 30us delay

        i2sb    PEN                         ; Stop condition on i2c bus

        return

;******************************************************************************
; lcd_write_cgram: Write custom characters on LCD
;
; Arguments : W= Character ID (0-7), FSR0 must point to an 8 byte buffer that
;             contains the custom character data
; Return    : None
;******************************************************************************
lcd_write_cgram:
        movwf   temp

        i2sb    SEN                         ; Start condition on i2c bus
        
        i2wr    I2CADDR_LCD                 ; Send slave address
        i2wr    MODE_INSTR                  ; Set instruction mode      

        ;--------------------------------
        ; Select instruction table 00
        ;--------------------------------       
        movf    cur_function, W
        iorlw   DEF_FUNCTION
        iorlw   CMD_FUNCTION                ; Insert FUNCTION opcode        
        
        ;--------------------------------
        ; Set CGRAM pointer
        ;--------------------------------       
        movf    temp, W                     ; Calculate CGRAM pointer
        andlw   0x07
        swapf   WREG
        bcf     STATUS, C
        rrcf    WREG
        
        addlw   CMD_CGRAM                   ; Insert CGRAM opcode
        
        call    i2c_write                   ; Send CGRAM command to the LCD
        udelay  d'30'                       ; 30us delay
        
        i2sb    PEN                         ; Stop condition on i2c bus
        
        
        ;--------------------------------
        ; Send custom char data
        ; (8 bytes pointed by FSR0)
        ;--------------------------------       
        i2sb    SEN                         ; Start condition on i2c bus
        
        i2wr    I2CADDR_LCD                 ; Send slave address
        i2wr    MODE_DATA                   ; Set data mode      
        
        movlw   D'8'
        movwf   i
        
loop_write_cgram:
        movf    POSTINC0, W
        
        call    i2c_write                   ; Send data to the LCD
        udelay  d'30'                       ; 30us delay
        
        decfsz  i
        bra     loop_write_cgram

        i2sb    PEN                         ; Stop condition on i2c bus        
        
        movf    lcd_cur_bptr, W             ; Set pointer back to DDRAM
        rcall   lcd_goto        
        
        return
        
;==============================================================================
;==============================================================================
        END     

