;
; 6 5 0 2   F U N C T I O N A L   T E S T
;
; Copyright (C) 2012-2020  Klaus Dormann
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.


; This program is designed to test all opcodes of a 6502 emulator using all
; addressing modes with focus on propper setting of the processor status
; register bits.
; 
; version 05-jan-2020
; contact info at http://2m5.de or email K@2m5.de
;
; assembled with AS65 written by Frank A. Kingswood
; The assembler as65_142.zip can be obtained from my GitHub repository 
; command line switches: -l -m -s2 -w -h0
;                         |  |  |   |  no page headers in listing
;                         |  |  |   wide listing (133 char/col)
;                         |  |  write intel hex file instead of binary
;                         |  expand macros in listing
;                         generate pass2 listing
;
; No IO - should be run from a monitor with access to registers.
; To run load intel hex image with a load command, than alter PC to 400 hex
; (code_segment) and enter a go command.
; Loop on program counter determines error or successful completion of test.
; Check listing for relevant traps (jump/branch *).
; Please note that in early tests some instructions will have to be used before
; they are actually tested!
;
; RESET, NMI or IRQ should not occur and will be trapped if vectors are enabled.
; Tests documented behavior of the original NMOS 6502 only! No unofficial
; opcodes. Additional opcodes of newer versions of the CPU (65C02, 65816) will
; not be tested. Decimal ops will only be tested with valid BCD operands and
; N V Z flags will be ignored.
;
; Debugging hints:
;     Most of the code is written sequentially. if you hit a trap, check the
;   immediately preceeding code for the instruction to be tested. Results are
;   tested first, flags are checked second by pushing them onto the stack and
;   pulling them to the accumulator after the result was checked. The "real"
;   flags are no longer valid for the tested instruction at this time!
;     If the tested instruction was indexed, the relevant index (X or Y) must
;   also be checked. Opposed to the flags, X and Y registers are still valid.
;
; versions:
;   28-jul-2012  1st version distributed for testing
;   29-jul-2012  fixed references to location 0, now #0
;                added license - GPLv3
;   30-jul-2012  added configuration options
;   01-aug-2012  added trap macro to allow user to change error handling
;   01-dec-2012  fixed trap in branch field must be a branch
;   02-mar-2013  fixed PLA flags not tested
;   19-jul-2013  allowed ROM vectors to be loaded when load_data_direct = 0
;                added test sequence check to detect if tests jump their fence
;   23-jul-2013  added RAM integrity check option
;   16-aug-2013  added error report to standard output option
;   13-dec-2014  added binary/decimal opcode table switch test
;   14-dec-2014  improved relative address test
;   23-aug-2015  added option to disable self modifying tests
;   24-aug-2015  all self modifying immediate opcodes now execute in data RAM
;                added small branch offset pretest
;   21-oct-2015  added option to disable decimal mode ADC & SBC tests
;   04-dec-2017  fixed BRK only tested with interrupts enabled
;                added option to skip the remainder of a failing test
;                in report.i65
;   05-jan-2020  fixed shifts not testing zero result and flag when last 1-bit
;                is shifted out

; C O N F I G U R A T I O N

;ROM_vectors writable (0=no, 1=yes)
;if ROM vectors can not be used interrupts will not be trapped
;as a consequence BRK can not be tested but will be emulated to test RTI
ROM_vectors = 1

;load_data_direct (0=move from code segment, 1=load directly)
;loading directly is preferred but may not be supported by your platform
;0 produces only consecutive object code, 1 is not suitable for a binary image
load_data_direct = 0

;I_flag behavior (0=force enabled, 1=force disabled, 2=prohibit change, 3=allow
;change) 2 requires extra code and is not recommended. SEI & CLI can only be
;tested if you allow changing the interrupt status (I_flag = 3)
I_flag = 3

;configure memory - try to stay away from memory used by the system
;zero_page memory start address, $52 (82) consecutive Bytes required
;                                add 2 if I_flag = 2
zero_page = $a  

;data_segment memory start address, $7B (123) consecutive Bytes required
data_segment = $200  
    if (data_segment & $ff) != 0
        ERROR ERROR ERROR low byte of data_segment MUST be $00 !!
    endif  

;code_segment memory start address, 13.1kB of consecutive space required
;                                   add 2.5 kB if I_flag = 2
code_segment = $400  

;self modifying code may be disabled to allow running in ROM
;0=part of the code is self modifying and must reside in RAM
;1=tests disabled: branch range
disable_selfmod = 0

;report errors through I/O channel (0=use standard self trap loops, 1=include
;report.i65 as I/O channel, add 3.5 kB)
report = 0

;RAM integrity test option. Checks for undesired RAM writes.
;set lowest non RAM or RAM mirror address page (-1=disable, 0=64k, $40=16k)
;leave disabled if a monitor, OS or background interrupt is allowed to alter RAM
ram_top = -1

;disable test decimal mode ADC & SBC, 0=enable, 1=disable,
;2=disable including decimal flag in processor status
disable_decimal = 0

        noopt       ;do not take shortcuts

;macros for error & success traps to allow user modification
;example:
;trap    macro
;        jsr my_error_handler
;        endm
;trap_eq macro
;        bne skip\?
;        trap           ;failed equal (zero)
;skip\?
;        endm
;
; my_error_handler should pop the calling address from the stack and report it.
; putting larger portions of code (more than 3 bytes) inside the trap macro
; may lead to branch range problems for some tests.
    if report = 0
trap    macro
        jmp *           ;failed anyway
        endm
trap_eq macro
        beq *           ;failed equal (zero)
        endm
trap_ne macro
        bne *           ;failed not equal (non zero)
        endm
trap_cs macro
        bcs *           ;failed carry set
        endm
trap_cc macro
        bcc *           ;failed carry clear
        endm
trap_mi macro
        bmi *           ;failed minus (bit 7 set)
        endm
trap_pl macro
        bpl *           ;failed plus (bit 7 clear)
        endm
trap_vs macro
        bvs *           ;failed overflow set
        endm
trap_vc macro
        bvc *           ;failed overflow clear
        endm
; please observe that during the test the stack gets invalidated
; therefore a RTS inside the success macro is not possible
success macro
        jmp *           ;test passed, no errors
        endm
    endif
    if report = 1
trap    macro
        jsr report_error
        endm
trap_eq macro
        bne skip\?
        trap           ;failed equal (zero)
skip\?
        endm
trap_ne macro
        beq skip\?
        trap            ;failed not equal (non zero)
skip\?
        endm
trap_cs macro
        bcc skip\?
        trap            ;failed carry set
skip\?
        endm
trap_cc macro
        bcs skip\?
        trap            ;failed carry clear
skip\?
        endm
trap_mi macro
        bpl skip\?
        trap            ;failed minus (bit 7 set)
skip\?
        endm
trap_pl macro
        bmi skip\?
        trap            ;failed plus (bit 7 clear)
skip\?
        endm
trap_vs macro
        bvc skip\?
        trap            ;failed overflow set
skip\?
        endm
trap_vc macro
        bvs skip\?
        trap            ;failed overflow clear
skip\?
        endm
; please observe that during the test the stack gets invalidated
; therefore a RTS inside the success macro is not possible
success macro
        jsr report_success
        endm
    endif


carry   equ %00000001   ;flag bits in status
zero    equ %00000010
intdis  equ %00000100
decmode equ %00001000
break   equ %00010000
reserv  equ %00100000
overfl  equ %01000000
minus   equ %10000000

fc      equ carry
fz      equ zero
fzc     equ carry+zero
fv      equ overfl
fvz     equ overfl+zero
fn      equ minus
fnc     equ minus+carry
fnz     equ minus+zero
fnzc    equ minus+zero+carry
fnv     equ minus+overfl

fao     equ break+reserv    ;bits always on after PHP, BRK
fai     equ fao+intdis      ;+ forced interrupt disable
faod    equ fao+decmode     ;+ ignore decimal
faid    equ fai+decmode     ;+ ignore decimal
m8      equ $ff             ;8 bit mask
m8i     equ $ff&~intdis     ;8 bit mask - interrupt disable

;macros to allow masking of status bits.
;masking test of decimal bit
;masking of interrupt enable/disable on load and compare
;masking of always on bits after PHP or BRK (unused & break) on compare
    if disable_decimal < 2
        if I_flag = 0
load_flag   macro
            lda #\1&m8i         ;force enable interrupts (mask I)
            endm
cmp_flag    macro
            cmp #(\1|fao)&m8i   ;I_flag is always enabled + always on bits
            endm
eor_flag    macro
            eor #(\1&m8i|fao)   ;mask I, invert expected flags + always on bits
            endm
        endif
        if I_flag = 1
load_flag   macro
            lda #\1|intdis      ;force disable interrupts
            endm
cmp_flag    macro
            cmp #(\1|fai)&m8    ;I_flag is always disabled + always on bits
            endm
eor_flag    macro
            eor #(\1|fai)       ;invert expected flags + always on bits + I
            endm
        endif
        if I_flag = 2
load_flag   macro
            lda #\1
            ora flag_I_on       ;restore I-flag
            and flag_I_off
            endm
cmp_flag    macro
            eor flag_I_on       ;I_flag is never changed
            cmp #(\1|fao)&m8i   ;expected flags + always on bits, mask I
            endm
eor_flag    macro
            eor flag_I_on       ;I_flag is never changed
            eor #(\1&m8i|fao)   ;mask I, invert expected flags + always on bits
            endm
        endif
        if I_flag = 3
load_flag   macro
            lda #\1             ;allow test to change I-flag (no mask)
            endm
cmp_flag    macro
            cmp #(\1|fao)&m8    ;expected flags + always on bits
            endm
eor_flag    macro
            eor #\1|fao         ;invert expected flags + always on bits
            endm
        endif
    else
        if I_flag = 0
load_flag   macro
            lda #\1&m8i         ;force enable interrupts (mask I)
            endm
cmp_flag    macro
            ora #decmode        ;ignore decimal mode bit
            cmp #(\1|faod)&m8i  ;I_flag is always enabled + always on bits
            endm
eor_flag    macro
            ora #decmode        ;ignore decimal mode bit
            eor #(\1&m8i|faod)  ;mask I, invert expected flags + always on bits
            endm
        endif
        if I_flag = 1
load_flag   macro
            lda #\1|intdis      ;force disable interrupts
            endm
cmp_flag    macro
            ora #decmode        ;ignore decimal mode bit
            cmp #(\1|faid)&m8   ;I_flag is always disabled + always on bits
            endm
eor_flag    macro
            ora #decmode        ;ignore decimal mode bit
            eor #(\1|faid)      ;invert expected flags + always on bits + I
            endm
        endif
        if I_flag = 2
load_flag   macro
            lda #\1
            ora flag_I_on       ;restore I-flag
            and flag_I_off
            endm
cmp_flag    macro
            eor flag_I_on       ;I_flag is never changed
            ora #decmode        ;ignore decimal mode bit
            cmp #(\1|faod)&m8i  ;expected flags + always on bits, mask I
            endm
eor_flag    macro
            eor flag_I_on       ;I_flag is never changed
            ora #decmode        ;ignore decimal mode bit
            eor #(\1&m8i|faod)  ;mask I, invert expected flags + always on bits
            endm
        endif
        if I_flag = 3
load_flag   macro
            lda #\1             ;allow test to change I-flag (no mask)
            endm
cmp_flag    macro
            ora #decmode        ;ignore decimal mode bit
            cmp #(\1|faod)&m8   ;expected flags + always on bits
            endm
eor_flag    macro
            ora #decmode        ;ignore decimal mode bit
            eor #\1|faod        ;invert expected flags + always on bits
            endm
        endif
    endif

;macros to set (register|memory|zeropage) & status
set_stat    macro       ;setting flags in the processor status register
            load_flag \1
            pha         ;use stack to load status
            plp
            endm

set_a       macro       ;precharging accu & status
            load_flag \2
            pha         ;use stack to load status
            lda #\1     ;precharge accu
            plp
            endm

set_x       macro       ;precharging index & status
            load_flag \2
            pha         ;use stack to load status
            ldx #\1     ;precharge index x
            plp
            endm

set_y       macro       ;precharging index & status
            load_flag \2
            pha         ;use stack to load status
            ldy #\1     ;precharge index y
            plp
            endm

set_ax      macro       ;precharging indexed accu & immediate status
            load_flag \2
            pha         ;use stack to load status
            lda \1,x    ;precharge accu
            plp
            endm

set_ay      macro       ;precharging indexed accu & immediate status
            load_flag \2
            pha         ;use stack to load status
            lda \1,y    ;precharge accu
            plp
            endm

set_z       macro       ;precharging indexed zp & immediate status
            load_flag \2
            pha         ;use stack to load status
            lda \1,x    ;load to zeropage
            sta zpt
            plp
            endm

set_zx      macro       ;precharging zp,x & immediate status
            load_flag \2
            pha         ;use stack to load status
            lda \1,x    ;load to indexed zeropage
            sta zpt,x
            plp
            endm

set_abs     macro       ;precharging indexed memory & immediate status
            load_flag \2
            pha         ;use stack to load status
            lda \1,x    ;load to memory
            sta abst
            plp
            endm

set_absx    macro       ;precharging abs,x & immediate status
            load_flag \2
            pha         ;use stack to load status
            lda \1,x    ;load to indexed memory
            sta abst,x
            plp
            endm

;macros to test (register|memory|zeropage) & status & (mask)
tst_stat    macro       ;testing flags in the processor status register
            php         ;save status
            pla         ;use stack to retrieve status
            pha
            cmp_flag \1
            trap_ne
            plp         ;restore status
            endm
            
tst_a       macro       ;testing result in accu & flags
            php         ;save flags
            cmp #\1     ;test result
            trap_ne
            pla         ;load status
            pha
            cmp_flag \2
            trap_ne
            plp         ;restore status
            endm

tst_x       macro       ;testing result in x index & flags
            php         ;save flags
            cpx #\1     ;test result
            trap_ne
            pla         ;load status
            pha
            cmp_flag \2
            trap_ne
            plp         ;restore status
            endm

tst_y       macro       ;testing result in y index & flags
            php         ;save flags
            cpy #\1     ;test result
            trap_ne
            pla         ;load status
            pha
            cmp_flag \2
            trap_ne
            plp         ;restore status
            endm

tst_ax      macro       ;indexed testing result in accu & flags
            php         ;save flags
            cmp \1,x    ;test result
            trap_ne
            pla         ;load status
            eor_flag \3
            cmp \2,x    ;test flags
            trap_ne     ;
            endm

tst_ay      macro       ;indexed testing result in accu & flags
            php         ;save flags
            cmp \1,y    ;test result
            trap_ne     ;
            pla         ;load status
            eor_flag \3
            cmp \2,y    ;test flags
            trap_ne
            endm
        
tst_z       macro       ;indexed testing result in zp & flags
            php         ;save flags
            lda zpt
            cmp \1,x    ;test result
            trap_ne
            pla         ;load status
            eor_flag \3
            cmp \2,x    ;test flags
            trap_ne
            endm

tst_zx      macro       ;testing result in zp,x & flags
            php         ;save flags
            lda zpt,x
            cmp \1,x    ;test result
            trap_ne
            pla         ;load status
            eor_flag \3
            cmp \2,x    ;test flags
            trap_ne
            endm

tst_abs     macro       ;indexed testing result in memory & flags
            php         ;save flags
            lda abst
            cmp \1,x    ;test result
            trap_ne
            pla         ;load status
            eor_flag \3
            cmp \2,x    ;test flags
            trap_ne
            endm

tst_absx    macro       ;testing result in abs,x & flags
            php         ;save flags
            lda abst,x
            cmp \1,x    ;test result
            trap_ne
            pla         ;load status
            eor_flag \3
            cmp \2,x    ;test flags
            trap_ne
            endm
            
; RAM integrity test
;   verifies that none of the previous tests has altered RAM outside of the
;   designated write areas.
;   uses zpt word as indirect pointer, zpt+2 word as checksum
        if ram_top > -1
check_ram   macro 
            cld
            lda #0
            sta zpt         ;set low byte of indirect pointer
            sta zpt+3       ;checksum high byte
          if disable_selfmod = 0
            sta range_adr   ;reset self modifying code
          endif
            clc
            ldx #zp_bss-zero_page ;zeropage - write test area
ccs3\?      adc zero_page,x
            bcc ccs2\?
            inc zpt+3       ;carry to high byte
            clc
ccs2\?      inx
            bne ccs3\?
            ldx #hi(abs1)   ;set high byte of indirect pointer
            stx zpt+1
            ldy #lo(abs1)   ;data after write & execute test area
ccs5\?      adc (zpt),y
            bcc ccs4\?
            inc zpt+3       ;carry to high byte
            clc
ccs4\?      iny
            bne ccs5\?
            inx             ;advance RAM high address
            stx zpt+1
            cpx #ram_top
            bne ccs5\?
            sta zpt+2       ;checksum low is
            cmp ram_chksm   ;checksum low expected
            trap_ne         ;checksum mismatch
            lda zpt+3       ;checksum high is
            cmp ram_chksm+1 ;checksum high expected
            trap_ne         ;checksum mismatch
            endm            
        else
check_ram   macro
            ;RAM check disabled - RAM size not set
            endm
        endif

next_test   macro           ;make sure, tests don't jump the fence
            lda test_case   ;previous test
            cmp #test_num
            trap_ne         ;test is out of sequence
test_num = test_num + 1
            lda #test_num   ;*** next tests' number
            sta test_case
            ;check_ram       ;uncomment to find altered RAM after each test
            endm

    if load_data_direct = 1
        data
    else
        bss                 ;uninitialized segment, copy of data at end of code!
    endif
        org zero_page
;break test interrupt save
irq_a   ds  1               ;a register
irq_x   ds  1               ;x register
    if I_flag = 2
;masking for I bit in status
flag_I_on   ds  1           ;or mask to load flags   
flag_I_off  ds  1           ;and mask to load flags
    endif
zpt                         ;6 bytes store/modify test area
;add/subtract operand generation and result/flag prediction
adfc    ds  1               ;carry flag before op
ad1     ds  1               ;operand 1 - accumulator
ad2     ds  1               ;operand 2 - memory / immediate
adrl    ds  1               ;expected result bits 0-7
adrh    ds  1               ;expected result bit 8 (carry)
adrf    ds  1               ;expected flags NV0000ZC (only binary mode)
sb2     ds  1               ;operand 2 complemented for subtract
zp_bss
zps     db  $80,1           ;additional shift pattern to test zero result & flag
zp1     db  $c3,$82,$41,0   ;test patterns for LDx BIT ROL ROR ASL LSR
zp7f    db  $7f             ;test pattern for compare  
;logical zeropage operands
zpOR    db  0,$1f,$71,$80   ;test pattern for OR
zpAN    db  $0f,$ff,$7f,$80 ;test pattern for AND
zpEO    db  $ff,$0f,$8f,$8f ;test pattern for EOR
;indirect addressing pointers
ind1    dw  abs1            ;indirect pointer to pattern in absolute memory
        dw  abs1+1
        dw  abs1+2
        dw  abs1+3
        dw  abs7f
inw1    dw  abs1-$f8        ;indirect pointer for wrap-test pattern
indt    dw  abst            ;indirect pointer to store area in absolute memory
        dw  abst+1
        dw  abst+2
        dw  abst+3
inwt    dw  abst-$f8        ;indirect pointer for wrap-test store
indAN   dw  absAN           ;indirect pointer to AND pattern in absolute memory
        dw  absAN+1
        dw  absAN+2
        dw  absAN+3
indEO   dw  absEO           ;indirect pointer to EOR pattern in absolute memory
        dw  absEO+1
        dw  absEO+2
        dw  absEO+3
indOR   dw  absOR           ;indirect pointer to OR pattern in absolute memory
        dw  absOR+1
        dw  absOR+2
        dw  absOR+3
;add/subtract indirect pointers
adi2    dw  ada2            ;indirect pointer to operand 2 in absolute memory
sbi2    dw  sba2            ;indirect pointer to complemented operand 2 (SBC)
adiy2   dw  ada2-$ff        ;with offset for indirect indexed
sbiy2   dw  sba2-$ff
zp_bss_end
   
        org data_segment
test_case   ds  1           ;current test number
ram_chksm   ds  2           ;checksum for RAM integrity test
;add/subtract operand copy - abs tests write area
abst                        ;6 bytes store/modify test area
ada2    ds  1               ;operand 2
sba2    ds  1               ;operand 2 complemented for subtract
        ds  4               ;fill remaining bytes
data_bss
    if load_data_direct = 1
ex_andi and #0              ;execute immediate opcodes
        rts
ex_eori eor #0              ;execute immediate opcodes
        rts
ex_orai ora #0              ;execute immediate opcodes
        rts
ex_adci adc #0              ;execute immediate opcodes
        rts
ex_sbci sbc #0              ;execute immediate opcodes
        rts
    else
ex_andi ds  3
ex_eori ds  3
ex_orai ds  3
ex_adci ds  3
ex_sbci ds  3
    endif
;zps    db  $80,1           ;additional shift patterns test zero result & flag
abs1    db  $c3,$82,$41,0   ;test patterns for LDx BIT ROL ROR ASL LSR
abs7f   db  $7f             ;test pattern for compare
;loads
fLDx    db  fn,fn,0,fz              ;expected flags for load
;shifts
rASL                                ;expected result ASL & ROL -carry
rROL    db  0,2,$86,$04,$82,0
rROLc   db  1,3,$87,$05,$83,1       ;expected result ROL +carry
rLSR                                ;expected result LSR & ROR -carry
rROR    db  $40,0,$61,$41,$20,0
rRORc   db  $c0,$80,$e1,$c1,$a0,$80 ;expected result ROR +carry
fASL                                ;expected flags for shifts
fROL    db  fzc,0,fnc,fc,fn,fz      ;no carry in
fROLc   db  fc,0,fnc,fc,fn,0        ;carry in 
fLSR 
fROR    db  0,fzc,fc,0,fc,fz        ;no carry in
fRORc   db  fn,fnc,fnc,fn,fnc,fn    ;carry in
;increments (decrements)
rINC    db  $7f,$80,$ff,0,1         ;expected result for INC/DEC
fINC    db  0,fn,fn,fz,0            ;expected flags for INC/DEC
;logical memory operand
absOR   db  0,$1f,$71,$80           ;test pattern for OR
absAN   db  $0f,$ff,$7f,$80         ;test pattern for AND
absEO   db  $ff,$0f,$8f,$8f         ;test pattern for EOR
;logical accu operand
absORa  db  0,$f1,$1f,0             ;test pattern for OR
absANa  db  $f0,$ff,$ff,$ff         ;test pattern for AND
absEOa  db  $ff,$f0,$f0,$0f         ;test pattern for EOR
;logical results
absrlo  db  0,$ff,$7f,$80
absflo  db  fz,fn,0,fn
data_bss_end


        code
        org code_segment
start   cld
        ldx #$ff
        txs
        lda #0          ;*** test 0 = initialize
        sta test_case
test_num = 0

;stop interrupts before initializing BSS
    if I_flag = 1
        sei
    endif
    
;initialize I/O for report channel
    if report = 1
        jsr report_init
    endif
    
;pretest small branch offset
        ldx #5
        jmp psb_test
psb_bwok
        ldy #5
        bne psb_forw
        trap        ;branch should be taken
        dey         ;forward landing zone
        dey
        dey
        dey
        dey
psb_forw
        dey
        dey
        dey
        dey
        dey
        beq psb_fwok
        trap        ;forward offset

        dex         ;backward landing zone
        dex
        dex
        dex
        dex
psb_back
        dex
        dex
        dex
        dex
        dex
        beq psb_bwok
        trap        ;backward offset
psb_test
        bne psb_back
        trap        ;branch should be taken
psb_fwok
        
;initialize BSS segment
    if load_data_direct != 1
        ldx #zp_end-zp_init-1
ld_zp   lda zp_init,x
        sta zp_bss,x
        dex
        bpl ld_zp
        ldx #data_end-data_init-1
ld_data lda data_init,x
        sta data_bss,x
        dex
        bpl ld_data
      if ROM_vectors = 1
        ldx #5
ld_vect lda vec_init,x
        sta vec_bss,x
        dex
        bpl ld_vect
      endif
    endif

;retain status of interrupt flag
    if I_flag = 2
        php
        pla
        and #4          ;isolate flag
        sta flag_I_on   ;or mask
        eor #lo(~4)     ;reverse
        sta flag_I_off  ;and mask
    endif
        
;generate checksum for RAM integrity test
    if ram_top > -1
        lda #0 
        sta zpt         ;set low byte of indirect pointer
        sta ram_chksm+1 ;checksum high byte
      if disable_selfmod = 0
        sta range_adr   ;reset self modifying code
      endif
        clc
        ldx #zp_bss-zero_page ;zeropage - write test area
gcs3    adc zero_page,x
        bcc gcs2
        inc ram_chksm+1 ;carry to high byte
        clc
gcs2    inx
        bne gcs3
        ldx #hi(abs1)   ;set high byte of indirect pointer
        stx zpt+1
        ldy #lo(abs1)   ;data after write & execute test area
gcs5    adc (zpt),y
        bcc gcs4
        inc ram_chksm+1 ;carry to high byte
        clc
gcs4    iny
        bne gcs5
        inx             ;advance RAM high address
        stx zpt+1
        cpx #ram_top
        bne gcs5
        sta ram_chksm   ;checksum complete
    endif
        next_test            

    if disable_selfmod = 0
;testing relative addressing with BEQ
        ldy #$fe        ;testing maximum range, not -1/-2 (invalid/self adr)
range_loop
        dey             ;next relative address
        tya
        tax             ;precharge count to end of loop
        bpl range_fw    ;calculate relative address
        clc             ;avoid branch self or to relative address of branch
        adc #2
        nop             ;offset landing zone - tolerate +/-5 offset to branch
        nop
        nop
        nop
        nop
range_fw
        nop
        nop
        nop
        nop
        nop
        eor #$7f        ;complement except sign
        sta range_adr   ;load into test target
        lda #0          ;should set zero flag in status register
        jmp range_op
        
        dex             ; offset landing zone - backward branch too far
        dex
        dex
        dex
        dex
        ;relative address target field with branch under test in the middle
        dex             ;-128 - max backward
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-120
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-110
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-100
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-90
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-80
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-70
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-60
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-50
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-40
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-30
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-20
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-10
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;-3
range_op                ;test target with zero flag=0, z=1 if previous dex
range_adr   = *+1       ;modifiable relative address
        beq *+64        ;+64 if called without modification
        dex             ;+0
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+10
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+20
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+30
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+40
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+50
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+60
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+70
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+80
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+90
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+100
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+110
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex
        dex             ;+120
        dex
        dex
        dex
        dex
        dex
        dex
        nop             ;offset landing zone - forward branch too far
        nop
        nop
        nop
        nop
        beq range_ok    ;+127 - max forward
        trap            ; bad range
        nop             ;offset landing zone - tolerate +/-5 offset to branch
        nop
        nop
        nop
        nop
range_ok
        nop
        nop
        nop
        nop
        nop
        cpy #0
        beq range_end   
        jmp range_loop
range_end               ;range test successful
    endif
        next_test

;partial test BNE & CMP, CPX, CPY immediate
        cpy #1          ;testing BNE true
        bne test_bne
        trap 
test_bne
        lda #0 
        cmp #0          ;test compare immediate 
        trap_ne
        trap_cc
        trap_mi
        cmp #1
        trap_eq 
        trap_cs
        trap_pl
        tax 
        cpx #0          ;test compare x immediate
        trap_ne
        trap_cc
        trap_mi
        cpx #1
        trap_eq 
        trap_cs
        trap_pl
        tay 
        cpy #0          ;test compare y immediate
        trap_ne
        trap_cc
        trap_mi
        cpy #1
        trap_eq 
        trap_cs
        trap_pl
        next_test
;testing stack operations PHA PHP PLA PLP
            
        ldx #$ff        ;initialize stack
        txs
        lda #$55
        pha
        lda #$aa
        pha
        cmp $1fe        ;on stack ?
        trap_ne
        tsx
        txa             ;overwrite accu
        cmp #$fd        ;sp decremented?
        trap_ne
        pla
        cmp #$aa        ;successful retreived from stack?
        trap_ne
        pla
        cmp #$55
        trap_ne
        cmp $1ff        ;remains on stack?
        trap_ne
        tsx
        cpx #$ff        ;sp incremented?
        trap_ne
        next_test

;testing branch decisions BPL BMI BVC BVS BCC BCS BNE BEQ
        set_stat $ff    ;all on
        bpl nbr1        ;branches should not be taken
        bvc nbr2
        bcc nbr3
        bne nbr4
        bmi br1         ;branches should be taken
        trap 
br1     bvs br2
        trap 
br2     bcs br3
        trap 
br3     beq br4
        trap 
nbr1
        trap            ;previous bpl taken 
nbr2
        trap            ;previous bvc taken
nbr3
        trap            ;previous bcc taken
nbr4
        trap            ;previous bne taken
br4     php
        tsx
        cpx #$fe        ;sp after php?
        trap_ne
        pla
        cmp_flag $ff    ;returned all flags on?
        trap_ne
        tsx
        cpx #$ff        ;sp after php?
        trap_ne
        set_stat 0      ;all off
        bmi nbr11       ;branches should not be taken
        bvs nbr12
        bcs nbr13
        beq nbr14
        bpl br11        ;branches should be taken
        trap 
br11    bvc br12
        trap 
br12    bcc br13
        trap 
br13    bne br14
        trap 
nbr11
        trap            ;previous bmi taken 
nbr12
        trap            ;previous bvs taken 
nbr13
        trap            ;previous bcs taken 
nbr14
        trap            ;previous beq taken 
br14    php
        pla
        cmp_flag 0      ;flags off except break (pushed by sw) + reserved?
        trap_ne
        ;crosscheck flags
        set_stat zero
        bne brzs1
        beq brzs2
brzs1
        trap            ;branch zero/non zero
brzs2   bcs brzs3
        bcc brzs4
brzs3
        trap            ;branch carry/no carry
brzs4   bmi brzs5
        bpl brzs6
brzs5
        trap            ;branch minus/plus
brzs6   bvs brzs7
        bvc brzs8
brzs7
        trap            ;branch overflow/no overflow
brzs8
        set_stat carry
        beq brcs1
        bne brcs2
brcs1
        trap            ;branch zero/non zero
brcs2   bcc brcs3
        bcs brcs4
brcs3
        trap            ;branch carry/no carry
brcs4   bmi brcs5
        bpl brcs6
brcs5
        trap            ;branch minus/plus
brcs6   bvs brcs7
        bvc brcs8
brcs7
        trap            ;branch overflow/no overflow

brcs8
        set_stat minus
        beq brmi1
        bne brmi2
brmi1
        trap            ;branch zero/non zero
brmi2   bcs brmi3
        bcc brmi4
brmi3
        trap            ;branch carry/no carry
brmi4   bpl brmi5
        bmi brmi6
brmi5
        trap            ;branch minus/plus
brmi6   bvs brmi7
        bvc brmi8
brmi7
        trap            ;branch overflow/no overflow
brmi8
        set_stat overfl
        beq brvs1
        bne brvs2
brvs1
        trap            ;branch zero/non zero
brvs2   bcs brvs3
        bcc brvs4
brvs3
        trap            ;branch carry/no carry
brvs4   bmi brvs5
        bpl brvs6
brvs5
        trap            ;branch minus/plus
brvs6   bvc brvs7
        bvs brvs8
brvs7
        trap            ;branch overflow/no overflow
brvs8
        set_stat $ff-zero
        beq brzc1
        bne brzc2
brzc1
        trap            ;branch zero/non zero
brzc2   bcc brzc3
        bcs brzc4
brzc3
        trap            ;branch carry/no carry
brzc4   bpl brzc5
        bmi brzc6
brzc5
        trap            ;branch minus/plus
brzc6   bvc brzc7
        bvs brzc8
brzc7
        trap            ;branch overflow/no overflow
brzc8
        set_stat $ff-carry
        bne brcc1
        beq brcc2
brcc1
        trap            ;branch zero/non zero
brcc2   bcs brcc3
        bcc brcc4
brcc3
        trap            ;branch carry/no carry
brcc4   bpl brcc5
        bmi brcc6
brcc5
        trap            ;branch minus/plus
brcc6   bvc brcc7
        bvs brcc8
brcc7
        trap            ;branch overflow/no overflow
brcc8
        set_stat $ff-minus
        bne brpl1
        beq brpl2
brpl1
        trap            ;branch zero/non zero
brpl2   bcc brpl3
        bcs brpl4
brpl3
        trap            ;branch carry/no carry
brpl4   bmi brpl5
        bpl brpl6
brpl5
        trap            ;branch minus/plus
brpl6   bvc brpl7
        bvs brpl8
brpl7
        trap            ;branch overflow/no overflow
brpl8
        set_stat $ff-overfl
        bne brvc1
        beq brvc2
brvc1
        trap            ;branch zero/non zero
brvc2   bcc brvc3
        bcs brvc4
brvc3
        trap            ;branch carry/no carry
brvc4   bpl brvc5
        bmi brvc6
brvc5
        trap            ;branch minus/plus
brvc6   bvs brvc7
        bvc brvc8
brvc7
        trap            ;branch overflow/no overflow
brvc8
        next_test

; test PHA does not alter flags or accumulator but PLA does
        ldx #$55        ;x & y protected
        ldy #$aa
        set_a 1,$ff     ;push
        pha
        tst_a 1,$ff
        set_a 0,0
        pha
        tst_a 0,0
        set_a $ff,$ff
        pha
        tst_a $ff,$ff
        set_a 1,0
        pha
        tst_a 1,0
        set_a 0,$ff
        pha
        tst_a 0,$ff
        set_a $ff,0
        pha
        tst_a $ff,0
        set_a 0,$ff     ;pull
        pla
        tst_a $ff,$ff-zero
        set_a $ff,0
        pla
        tst_a 0,zero
        set_a $fe,$ff
        pla
        tst_a 1,$ff-zero-minus
        set_a 0,0
        pla
        tst_a $ff,minus
        set_a $ff,$ff
        pla
        tst_a 0,$ff-minus
        set_a $fe,0
        pla
        tst_a 1,0
        cpx #$55        ;x & y unchanged?
        trap_ne
        cpy #$aa
        trap_ne
        next_test
 
; partial pretest EOR #
        set_a $3c,0
        eor #$c3
        tst_a $ff,fn
        set_a $c3,0
        eor #$c3
        tst_a 0,fz
        next_test

; PC modifying instructions except branches (NOP, JMP, JSR, RTS, BRK, RTI)
; testing NOP
        ldx #$24
        ldy #$42
        set_a $18,0
        nop
        tst_a $18,0
        cpx #$24
        trap_ne
        cpy #$42
        trap_ne
        ldx #$db
        ldy #$bd
        set_a $e7,$ff
        nop
        tst_a $e7,$ff
        cpx #$db
        trap_ne
        cpy #$bd
        trap_ne
        next_test
        
; jump absolute
        set_stat $0
        lda #'F'
        ldx #'A'
        ldy #'R'        ;N=0, V=0, Z=0, C=0
        jmp test_far
        nop
        nop
        trap_ne         ;runover protection
        inx
        inx
far_ret 
        trap_eq         ;returned flags OK?
        trap_pl
        trap_cc
        trap_vc
        cmp #('F'^$aa)  ;returned registers OK?
        trap_ne
        cpx #('A'+1)
        trap_ne
        cpy #('R'-3)
        trap_ne
        dex
        iny
        iny
        iny
        eor #$aa        ;N=0, V=1, Z=0, C=1
        jmp test_near
        nop
        nop
        trap_ne         ;runover protection
        inx
        inx
test_near
        trap_eq         ;passed flags OK?
        trap_mi
        trap_cc
        trap_vc
        cmp #'F'        ;passed registers OK?
        trap_ne
        cpx #'A'
        trap_ne
        cpy #'R'
        trap_ne
        next_test
        
; jump indirect
        set_stat 0
        lda #'I'
        ldx #'N'
        ldy #'D'        ;N=0, V=0, Z=0, C=0
        jmp (ptr_tst_ind)
        nop
        trap_ne         ;runover protection
        dey
        dey
ind_ret 
        php             ;either SP or Y count will fail, if we do not hit
        dey
        dey
        dey
        plp
        trap_eq         ;returned flags OK?
        trap_pl
        trap_cc
        trap_vc
        cmp #('I'^$aa)  ;returned registers OK?
        trap_ne
        cpx #('N'+1)
        trap_ne
        cpy #('D'-6)
        trap_ne
        tsx             ;SP check
        cpx #$ff
        trap_ne
        next_test

; jump subroutine & return from subroutine
        set_stat 0
        lda #'J'
        ldx #'S'
        ldy #'R'        ;N=0, V=0, Z=0, C=0
        jsr test_jsr
jsr_ret = *-1           ;last address of jsr = return address
        php             ;either SP or Y count will fail, if we do not hit
        dey
        dey
        dey
        plp
        trap_eq         ;returned flags OK?
        trap_pl
        trap_cc
        trap_vc
        cmp #('J'^$aa)  ;returned registers OK?
        trap_ne
        cpx #('S'+1)
        trap_ne
        cpy #('R'-6)
        trap_ne
        tsx             ;sp?
        cpx #$ff
        trap_ne
        next_test

; break & return from interrupt
    if ROM_vectors = 1
        load_flag 0     ;with interrupts enabled if allowed!
        pha
        lda #'B'
        ldx #'R'
        ldy #'K'
        plp             ;N=0, V=0, Z=0, C=0
        brk
    else
        lda #hi brk_ret0 ;emulated break
        pha
        lda #lo brk_ret0
        pha
        load_flag fao    ;set break & unused on stack
        pha
        load_flag intdis ;during interrupt
        pha
        lda #'B'
        ldx #'R'
        ldy #'K'
        plp             ;N=0, V=0, Z=0, C=0
        jmp irq_trap
    endif
        dey             ;should not be executed
brk_ret0                ;address of break return
        php             ;either SP or Y count will fail, if we do not hit
        dey
        dey
        dey
        cmp #'B'^$aa    ;returned registers OK?
        ;the IRQ vector was never executed if A & X stay unmodified
        trap_ne
        cpx #'R'+1
        trap_ne
        cpy #'K'-6
        trap_ne
        pla             ;returned flags OK (unchanged)?
        cmp_flag 0
        trap_ne
        tsx             ;sp?
        cpx #$ff
        trap_ne
    if ROM_vectors = 1
        load_flag $ff   ;with interrupts disabled if allowed!
        pha
        lda #$ff-'B'
        ldx #$ff-'R'
        ldy #$ff-'K'
        plp             ;N=1, V=1, Z=1, C=1
        brk
    else
        lda #hi brk_ret1 ;emulated break
        pha
        lda #lo brk_ret1
        pha
        load_flag $ff
        pha             ;set break & unused on stack
        pha             ;actual flags
        lda #$ff-'B'
        ldx #$ff-'R'
        ldy #$ff-'K'
        plp             ;N=1, V=1, Z=1, C=1
        jmp irq_trap
    endif
        dey             ;should not be executed
brk_ret1                ;address of break return
        php             ;either SP or Y count will fail, if we do not hit
        dey
        dey
        dey
        cmp #($ff-'B')^$aa  ;returned registers OK?
        ;the IRQ vector was never executed if A & X stay unmodified
        trap_ne
        cpx #$ff-'R'+1
        trap_ne
        cpy #$ff-'K'-6
        trap_ne
        pla             ;returned flags OK (unchanged)?
        cmp_flag $ff
        trap_ne
        tsx             ;sp?
        cpx #$ff
        trap_ne
        next_test
 
; test set and clear flags CLC CLI CLD CLV SEC SEI SED
        set_stat $ff
        clc
        tst_stat $ff-carry
        sec
        tst_stat $ff
    if I_flag = 3
        cli
        tst_stat $ff-intdis
        sei
        tst_stat $ff
    endif
        cld
        tst_stat $ff-decmode
        sed
        tst_stat $ff
        clv
        tst_stat $ff-overfl
        set_stat 0
        tst_stat 0
        sec
        tst_stat carry
        clc
        tst_stat 0  
    if I_flag = 3
        sei
        tst_stat intdis
        cli
        tst_stat 0
    endif  
        sed
        tst_stat decmode
        cld
        tst_stat 0  
        set_stat overfl
        tst_stat overfl
        clv
        tst_stat 0
        next_test
; testing index register increment/decrement and transfer
; INX INY DEX DEY TAX TXA TAY TYA 
        ldx #$fe
        set_stat $ff
        inx             ;ff
        tst_x $ff,$ff-zero
        inx             ;00
        tst_x 0,$ff-minus
        inx             ;01
        tst_x 1,$ff-minus-zero
        dex             ;00
        tst_x 0,$ff-minus
        dex             ;ff
        tst_x $ff,$ff-zero
        dex             ;fe
        set_stat 0
        inx             ;ff
        tst_x $ff,minus
        inx             ;00
        tst_x 0,zero
        inx             ;01
        tst_x 1,0
        dex             ;00
        tst_x 0,zero
        dex             ;ff
        tst_x $ff,minus

        ldy #$fe
        set_stat $ff
        iny             ;ff
        tst_y $ff,$ff-zero
        iny             ;00
        tst_y 0,$ff-minus
        iny             ;01
        tst_y 1,$ff-minus-zero
        dey             ;00
        tst_y 0,$ff-minus
        dey             ;ff
        tst_y $ff,$ff-zero
        dey             ;fe
        set_stat 0
        iny             ;ff
        tst_y $ff,0+minus
        iny             ;00
        tst_y 0,zero
        iny             ;01
        tst_y 1,0
        dey             ;00
        tst_y 0,zero
        dey             ;ff
        tst_y $ff,minus
                
        ldx #$ff
        set_stat $ff
        txa
        tst_a $ff,$ff-zero
        php
        inx             ;00
        plp
        txa
        tst_a 0,$ff-minus
        php
        inx             ;01
        plp
        txa
        tst_a 1,$ff-minus-zero
        set_stat 0
        txa
        tst_a 1,0
        php
        dex             ;00
        plp
        txa
        tst_a 0,zero
        php
        dex             ;ff
        plp
        txa
        tst_a $ff,minus
                        
        ldy #$ff
        set_stat $ff
        tya
        tst_a $ff,$ff-zero
        php
        iny             ;00
        plp
        tya
        tst_a 0,$ff-minus
        php
        iny             ;01
        plp
        tya
        tst_a 1,$ff-minus-zero
        set_stat 0
        tya
        tst_a 1,0
        php
        dey             ;00
        plp
        tya
        tst_a 0,zero
        php
        dey             ;ff
        plp
        tya
        tst_a $ff,minus

        load_flag $ff
        pha
        ldx #$ff        ;ff
        txa
        plp             
        tay
        tst_y $ff,$ff-zero
        php
        inx             ;00
        txa
        plp
        tay
        tst_y 0,$ff-minus
        php
        inx             ;01
        txa
        plp
        tay
        tst_y 1,$ff-minus-zero
        load_flag 0
        pha
        lda #0
        txa
        plp
        tay
        tst_y 1,0
        php
        dex             ;00
        txa
        plp
        tay
        tst_y 0,zero
        php
        dex             ;ff
        txa
        plp
        tay
        tst_y $ff,minus


        load_flag $ff
        pha
        ldy #$ff        ;ff
        tya
        plp
        tax
        tst_x $ff,$ff-zero
        php
        iny             ;00
        tya
        plp
        tax
        tst_x 0,$ff-minus
        php
        iny             ;01
        tya
        plp
        tax
        tst_x 1,$ff-minus-zero
        load_flag 0
        pha
        lda #0          ;preset status
        tya
        plp
        tax
        tst_x 1,0
        php
        dey             ;00
        tya
        plp
        tax
        tst_x 0,zero
        php
        dey             ;ff
        tya
        plp
        tax
        tst_x $ff,minus
        next_test
     
;TSX sets NZ - TXS does not
;  This section also tests for proper stack wrap around.
        ldx #1          ;01
        set_stat $ff
        txs
        php
        lda $101
        cmp_flag $ff
        trap_ne
        set_stat 0
        txs
        php
        lda $101
        cmp_flag 0
        trap_ne
        dex             ;00
        set_stat $ff
        txs
        php
        lda $100
        cmp_flag $ff
        trap_ne
        set_stat 0
        txs
        php
        lda $100
        cmp_flag 0
        trap_ne
        dex             ;ff
        set_stat $ff
        txs
        php
        lda $1ff
        cmp_flag $ff
        trap_ne
        set_stat 0
        txs
        php
        lda $1ff
        cmp_flag 0
        
        ldx #1
        txs             ;sp=01
        set_stat $ff
        tsx             ;clears Z, N
        php             ;sp=00
        cpx #1
        trap_ne
        lda $101
        cmp_flag $ff-minus-zero
        trap_ne
        set_stat $ff
        tsx             ;clears N, sets Z
        php             ;sp=ff
        cpx #0
        trap_ne
        lda $100
        cmp_flag $ff-minus
        trap_ne
        set_stat $ff
        tsx             ;clears N, sets Z
        php             ;sp=fe
        cpx #$ff
        trap_ne
        lda $1ff
        cmp_flag $ff-zero
        trap_ne
        
        ldx #1
        txs             ;sp=01
        set_stat 0
        tsx             ;clears Z, N
        php             ;sp=00
        cpx #1
        trap_ne
        lda $101
        cmp_flag 0
        trap_ne
        set_stat 0
        tsx             ;clears N, sets Z
        php             ;sp=ff
        cpx #0
        trap_ne
        lda $100
        cmp_flag zero
        trap_ne
        set_stat 0
        tsx             ;clears N, sets Z
        php             ;sp=fe
        cpx #$ff
        trap_ne
        lda $1ff
        cmp_flag minus
        trap_ne
        pla             ;sp=ff
        next_test
        
; testing index register load & store LDY LDX STY STX all addressing modes
; LDX / STX - zp,y / abs,y
        ldy #3
tldx    
        set_stat 0
        ldx zp1,y
        php         ;test stores do not alter flags
        txa
        eor #$c3
        plp
        sta abst,y
        php         ;flags after load/store sequence
        eor #$c3
        cmp abs1,y  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx,y  ;test flags
        trap_ne
        dey
        bpl tldx                  

        ldy #3
tldx1   
        set_stat $ff
        ldx zp1,y
        php         ;test stores do not alter flags
        txa
        eor #$c3
        plp
        sta abst,y
        php         ;flags after load/store sequence
        eor #$c3
        cmp abs1,y  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx,y  ;test flags
        trap_ne
        dey
        bpl tldx1                  

        ldy #3
tldx2   
        set_stat 0
        ldx abs1,y
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx zpt,y
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1,y   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx,y  ;test flags
        trap_ne
        dey
        bpl tldx2                  

        ldy #3
tldx3   
        set_stat $ff
        ldx abs1,y
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx zpt,y
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1,y   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx,y  ;test flags
        trap_ne
        dey
        bpl tldx3
        
        ldy #3      ;testing store result
        ldx #0
tstx    lda zpt,y
        eor #$c3
        cmp zp1,y
        trap_ne     ;store to zp data
        stx zpt,y   ;clear                
        lda abst,y
        eor #$c3
        cmp abs1,y
        trap_ne     ;store to abs data
        txa
        sta abst,y  ;clear                
        dey
        bpl tstx
        next_test
        
; indexed wraparound test (only zp should wrap)
        ldy #3+$fa
tldx4   ldx zp1-$fa&$ff,y   ;wrap on indexed zp
        txa
        sta abst-$fa,y      ;no STX abs,y!
        dey
        cpy #$fa
        bcs tldx4                  
        ldy #3+$fa
tldx5   ldx abs1-$fa,y      ;no wrap on indexed abs
        stx zpt-$fa&$ff,y
        dey
        cpy #$fa
        bcs tldx5                  
        ldy #3      ;testing wraparound result
        ldx #0
tstx1   lda zpt,y
        cmp zp1,y
        trap_ne     ;store to zp data
        stx zpt,y   ;clear                
        lda abst,y
        cmp abs1,y
        trap_ne     ;store to abs data
        txa
        sta abst,y  ;clear                
        dey
        bpl tstx1
        next_test
        
; LDY / STY - zp,x / abs,x
        ldx #3
tldy    
        set_stat 0
        ldy zp1,x
        php         ;test stores do not alter flags
        tya
        eor #$c3
        plp
        sta abst,x
        php         ;flags after load/store sequence
        eor #$c3
        cmp abs1,x  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx,x  ;test flags
        trap_ne
        dex
        bpl tldy                  

        ldx #3
tldy1   
        set_stat $ff
        ldy zp1,x
        php         ;test stores do not alter flags
        tya
        eor #$c3
        plp
        sta abst,x
        php         ;flags after load/store sequence
        eor #$c3
        cmp abs1,x  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx,x  ;test flags
        trap_ne
        dex
        bpl tldy1                  

        ldx #3
tldy2   
        set_stat 0
        ldy abs1,x
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty zpt,x
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1,x   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx,x  ;test flags
        trap_ne
        dex
        bpl tldy2                  

        ldx #3
tldy3
        set_stat $ff
        ldy abs1,x
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty zpt,x
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1,x   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx,x  ;test flags
        trap_ne
        dex
        bpl tldy3

        ldx #3      ;testing store result
        ldy #0
tsty    lda zpt,x
        eor #$c3
        cmp zp1,x
        trap_ne     ;store to zp,x data
        sty zpt,x   ;clear                
        lda abst,x
        eor #$c3
        cmp abs1,x
        trap_ne     ;store to abs,x data
        txa
        sta abst,x  ;clear                
        dex
        bpl tsty
        next_test

; indexed wraparound test (only zp should wrap)
        ldx #3+$fa
tldy4   ldy zp1-$fa&$ff,x   ;wrap on indexed zp
        tya
        sta abst-$fa,x      ;no STX abs,x!
        dex
        cpx #$fa
        bcs tldy4                  
        ldx #3+$fa
tldy5   ldy abs1-$fa,x      ;no wrap on indexed abs
        sty zpt-$fa&$ff,x
        dex
        cpx #$fa
        bcs tldy5                  
        ldx #3      ;testing wraparound result
        ldy #0
tsty1   lda zpt,x
        cmp zp1,x
        trap_ne     ;store to zp,x data
        sty zpt,x   ;clear                
        lda abst,x
        cmp abs1,x
        trap_ne     ;store to abs,x data
        txa
        sta abst,x  ;clear                
        dex
        bpl tsty1
        next_test

; LDX / STX - zp / abs / #
        set_stat 0  
        ldx zp1
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx abst
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx #$c3    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx    ;test flags
        trap_ne
        set_stat 0
        ldx zp1+1
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx abst+1
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx #$82    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat 0
        ldx zp1+2
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx abst+2
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx #$41    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat 0
        ldx zp1+3
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx abst+3
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx #0      ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+3  ;test flags
        trap_ne

        set_stat $ff
        ldx zp1  
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx abst  
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx #$c3    ;test result
        trap_ne     ;
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx    ;test flags
        trap_ne
        set_stat $ff
        ldx zp1+1
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx abst+1
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx #$82    ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat $ff
        ldx zp1+2
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx abst+2
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx #$41    ;test result
        trap_ne     ;
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat $ff
        ldx zp1+3
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx abst+3
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx #0      ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+3  ;test flags
        trap_ne

        set_stat 0
        ldx abs1  
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx zpt  
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1     ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx    ;test flags
        trap_ne
        set_stat 0
        ldx abs1+1
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx zpt+1
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1+1   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat 0
        ldx abs1+2
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx zpt+2
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1+2   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat 0
        ldx abs1+3
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx zpt+3
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1+3   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+3  ;test flags
        trap_ne

        set_stat $ff
        ldx abs1  
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx zpt  
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx zp1     ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx    ;test flags
        trap_ne
        set_stat $ff
        ldx abs1+1
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx zpt+1
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx zp1+1   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat $ff
        ldx abs1+2
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx zpt+2
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx zp1+2   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat $ff
        ldx abs1+3
        php         ;test stores do not alter flags
        txa
        eor #$c3
        tax
        plp
        stx zpt+3
        php         ;flags after load/store sequence
        eor #$c3
        tax
        cpx zp1+3   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+3  ;test flags
        trap_ne

        set_stat 0  
        ldx #$c3
        php
        cpx abs1    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx    ;test flags
        trap_ne
        set_stat 0
        ldx #$82
        php
        cpx abs1+1  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat 0
        ldx #$41
        php
        cpx abs1+2  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat 0
        ldx #0
        php
        cpx abs1+3  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+3  ;test flags
        trap_ne

        set_stat $ff
        ldx #$c3  
        php
        cpx abs1    ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx    ;test flags
        trap_ne
        set_stat $ff
        ldx #$82
        php
        cpx abs1+1  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat $ff
        ldx #$41
        php
        cpx abs1+2  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat $ff
        ldx #0
        php
        cpx abs1+3  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+3  ;test flags
        trap_ne

        ldx #0
        lda zpt  
        eor #$c3
        cmp zp1  
        trap_ne     ;store to zp data
        stx zpt     ;clear                
        lda abst  
        eor #$c3
        cmp abs1  
        trap_ne     ;store to abs data
        stx abst    ;clear                
        lda zpt+1
        eor #$c3
        cmp zp1+1
        trap_ne     ;store to zp data
        stx zpt+1   ;clear                
        lda abst+1
        eor #$c3
        cmp abs1+1
        trap_ne     ;store to abs data
        stx abst+1  ;clear                
        lda zpt+2
        eor #$c3
        cmp zp1+2
        trap_ne     ;store to zp data
        stx zpt+2   ;clear                
        lda abst+2
        eor #$c3
        cmp abs1+2
        trap_ne     ;store to abs data
        stx abst+2  ;clear                
        lda zpt+3
        eor #$c3
        cmp zp1+3
        trap_ne     ;store to zp data
        stx zpt+3   ;clear                
        lda abst+3
        eor #$c3
        cmp abs1+3
        trap_ne     ;store to abs data
        stx abst+3  ;clear                
        next_test

; LDY / STY - zp / abs / #
        set_stat 0
        ldy zp1  
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty abst  
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy #$c3    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx    ;test flags
        trap_ne
        set_stat 0
        ldy zp1+1
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty abst+1
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy #$82    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat 0
        ldy zp1+2
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty abst+2
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy #$41    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat 0
        ldy zp1+3
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty abst+3
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy #0      ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+3  ;test flags
        trap_ne

        set_stat $ff
        ldy zp1  
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty abst  
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy #$c3    ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx    ;test flags
        trap_ne
        set_stat $ff
        ldy zp1+1
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty abst+1
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy #$82   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat $ff
        ldy zp1+2
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty abst+2
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy #$41    ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat $ff
        ldy zp1+3
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty abst+3
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy #0      ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+3  ;test flags
        trap_ne
        
        set_stat 0
        ldy abs1  
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty zpt  
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy zp1     ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx    ;test flags
        trap_ne
        set_stat 0
        ldy abs1+1
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty zpt+1
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy zp1+1   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat 0
        ldy abs1+2
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty zpt+2
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy zp1+2   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat 0
        ldy abs1+3
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty zpt+3
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cpy zp1+3   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+3  ;test flags
        trap_ne

        set_stat $ff
        ldy abs1  
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty zpt  
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cmp zp1     ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx    ;test flags
        trap_ne
        set_stat $ff
        ldy abs1+1
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty zpt+1
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cmp zp1+1   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat $ff
        ldy abs1+2
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty zpt+2
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cmp zp1+2   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat $ff
        ldy abs1+3
        php         ;test stores do not alter flags
        tya
        eor #$c3
        tay
        plp
        sty zpt+3
        php         ;flags after load/store sequence
        eor #$c3
        tay
        cmp zp1+3   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+3  ;test flags
        trap_ne


        set_stat 0
        ldy #$c3  
        php
        cpy abs1    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx    ;test flags
        trap_ne
        set_stat 0
        ldy #$82
        php
        cpy abs1+1  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat 0
        ldy #$41
        php
        cpy abs1+2  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat 0
        ldy #0
        php
        cpy abs1+3  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+3  ;test flags
        trap_ne

        set_stat $ff
        ldy #$c3  
        php
        cpy abs1    ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx    ;test flags
        trap_ne
        set_stat $ff
        ldy #$82
        php
        cpy abs1+1  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat $ff
        ldy #$41
        php
        cpy abs1+2   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat $ff
        ldy #0
        php
        cpy abs1+3  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+3  ;test flags
        trap_ne
        
        ldy #0
        lda zpt  
        eor #$c3
        cmp zp1  
        trap_ne     ;store to zp   data
        sty zpt     ;clear                
        lda abst  
        eor #$c3
        cmp abs1  
        trap_ne     ;store to abs   data
        sty abst    ;clear                
        lda zpt+1
        eor #$c3
        cmp zp1+1
        trap_ne     ;store to zp+1 data
        sty zpt+1   ;clear                
        lda abst+1
        eor #$c3
        cmp abs1+1
        trap_ne     ;store to abs+1 data
        sty abst+1  ;clear                
        lda zpt+2
        eor #$c3
        cmp zp1+2
        trap_ne     ;store to zp+2 data
        sty zpt+2   ;clear                
        lda abst+2
        eor #$c3
        cmp abs1+2
        trap_ne     ;store to abs+2 data
        sty abst+2  ;clear                
        lda zpt+3
        eor #$c3
        cmp zp1+3
        trap_ne     ;store to zp+3 data
        sty zpt+3   ;clear                
        lda abst+3
        eor #$c3
        cmp abs1+3
        trap_ne     ;store to abs+3 data
        sty abst+3  ;clear                
        next_test

; testing load / store accumulator LDA / STA all addressing modes
; LDA / STA - zp,x / abs,x
        ldx #3
tldax    
        set_stat 0
        lda zp1,x
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst,x
        php         ;flags after load/store sequence
        eor #$c3
        cmp abs1,x  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx,x  ;test flags
        trap_ne
        dex
        bpl tldax                  

        ldx #3
tldax1   
        set_stat $ff
        lda zp1,x
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst,x
        php         ;flags after load/store sequence
        eor #$c3
        cmp abs1,x   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx,x  ;test flags
        trap_ne
        dex
        bpl tldax1                  

        ldx #3
tldax2   
        set_stat 0
        lda abs1,x
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta zpt,x
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1,x   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx,x  ;test flags
        trap_ne
        dex
        bpl tldax2                  

        ldx #3
tldax3
        set_stat $ff
        lda abs1,x
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta zpt,x
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1,x   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx,x  ;test flags
        trap_ne
        dex
        bpl tldax3

        ldx #3      ;testing store result
        ldy #0
tstax   lda zpt,x
        eor #$c3
        cmp zp1,x
        trap_ne     ;store to zp,x data
        sty zpt,x   ;clear                
        lda abst,x
        eor #$c3
        cmp abs1,x
        trap_ne     ;store to abs,x data
        txa
        sta abst,x  ;clear                
        dex
        bpl tstax
        next_test

; LDA / STA - (zp),y / abs,y / (zp,x)
        ldy #3
tlday    
        set_stat 0
        lda (ind1),y
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst,y
        php         ;flags after load/store sequence
        eor #$c3
        cmp abs1,y  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx,y  ;test flags
        trap_ne
        dey
        bpl tlday                  

        ldy #3
tlday1   
        set_stat $ff
        lda (ind1),y
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst,y
        php         ;flags after load/store sequence
        eor #$c3
        cmp abs1,y  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx,y  ;test flags
        trap_ne
        dey
        bpl tlday1                  

        ldy #3      ;testing store result
        ldx #0
tstay   lda abst,y
        eor #$c3
        cmp abs1,y
        trap_ne     ;store to abs data
        txa
        sta abst,y  ;clear                
        dey
        bpl tstay

        ldy #3
tlday2   
        set_stat 0
        lda abs1,y
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta (indt),y
        php         ;flags after load/store sequence
        eor #$c3
        cmp (ind1),y    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx,y  ;test flags
        trap_ne
        dey
        bpl tlday2                  

        ldy #3
tlday3   
        set_stat $ff
        lda abs1,y
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta (indt),y
        php         ;flags after load/store sequence
        eor #$c3
        cmp (ind1),y   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx,y  ;test flags
        trap_ne
        dey
        bpl tlday3
        
        ldy #3      ;testing store result
        ldx #0
tstay1  lda abst,y
        eor #$c3
        cmp abs1,y
        trap_ne     ;store to abs data
        txa
        sta abst,y  ;clear                
        dey
        bpl tstay1
        
        ldx #6
        ldy #3
tldax4   
        set_stat 0
        lda (ind1,x)
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta (indt,x)
        php         ;flags after load/store sequence
        eor #$c3
        cmp abs1,y  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx,y  ;test flags
        trap_ne
        dex
        dex
        dey
        bpl tldax4                  

        ldx #6
        ldy #3
tldax5
        set_stat $ff
        lda (ind1,x)
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta (indt,x)
        php         ;flags after load/store sequence
        eor #$c3
        cmp abs1,y  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx,y  ;test flags
        trap_ne
        dex
        dex
        dey
        bpl tldax5

        ldy #3      ;testing store result
        ldx #0
tstay2  lda abst,y
        eor #$c3
        cmp abs1,y
        trap_ne     ;store to abs data
        txa
        sta abst,y  ;clear                
        dey
        bpl tstay2
        next_test

; indexed wraparound test (only zp should wrap)
        ldx #3+$fa
tldax6  lda zp1-$fa&$ff,x   ;wrap on indexed zp
        sta abst-$fa,x      ;no STX abs,x!
        dex
        cpx #$fa
        bcs tldax6                  
        ldx #3+$fa
tldax7  lda abs1-$fa,x      ;no wrap on indexed abs
        sta zpt-$fa&$ff,x
        dex
        cpx #$fa
        bcs tldax7
                          
        ldx #3      ;testing wraparound result
        ldy #0
tstax1  lda zpt,x
        cmp zp1,x
        trap_ne     ;store to zp,x data
        sty zpt,x   ;clear                
        lda abst,x
        cmp abs1,x
        trap_ne     ;store to abs,x data
        txa
        sta abst,x  ;clear                
        dex
        bpl tstax1

        ldy #3+$f8
        ldx #6+$f8
tlday4  lda (ind1-$f8&$ff,x) ;wrap on indexed zp indirect
        sta abst-$f8,y
        dex
        dex
        dey
        cpy #$f8
        bcs tlday4
        ldy #3      ;testing wraparound result
        ldx #0
tstay4  lda abst,y
        cmp abs1,y
        trap_ne     ;store to abs data
        txa
        sta abst,y  ;clear                
        dey
        bpl tstay4
        
        ldy #3+$f8
tlday5  lda abs1-$f8,y  ;no wrap on indexed abs
        sta (inwt),y
        dey
        cpy #$f8
        bcs tlday5                  
        ldy #3      ;testing wraparound result
        ldx #0
tstay5  lda abst,y
        cmp abs1,y
        trap_ne     ;store to abs data
        txa
        sta abst,y  ;clear                
        dey
        bpl tstay5

        ldy #3+$f8
        ldx #6+$f8
tlday6  lda (inw1),y    ;no wrap on zp indirect indexed 
        sta (indt-$f8&$ff,x)
        dex
        dex
        dey
        cpy #$f8
        bcs tlday6
        ldy #3      ;testing wraparound result
        ldx #0
tstay6  lda abst,y
        cmp abs1,y
        trap_ne     ;store to abs data
        txa
        sta abst,y  ;clear                
        dey
        bpl tstay6
        next_test

; LDA / STA - zp / abs / #
        set_stat 0  
        lda zp1
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst
        php         ;flags after load/store sequence
        eor #$c3
        cmp #$c3    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx    ;test flags
        trap_ne
        set_stat 0
        lda zp1+1
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst+1
        php         ;flags after load/store sequence
        eor #$c3
        cmp #$82    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat 0
        lda zp1+2
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst+2
        php         ;flags after load/store sequence
        eor #$c3
        cmp #$41    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat 0
        lda zp1+3
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst+3
        php         ;flags after load/store sequence
        eor #$c3
        cmp #0      ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+3  ;test flags
        trap_ne
        set_stat $ff
        lda zp1  
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst  
        php         ;flags after load/store sequence
        eor #$c3
        cmp #$c3    ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx    ;test flags
        trap_ne
        set_stat $ff
        lda zp1+1
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst+1
        php         ;flags after load/store sequence
        eor #$c3
        cmp #$82    ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat $ff
        lda zp1+2
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst+2
        php         ;flags after load/store sequence
        eor #$c3
        cmp #$41    ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat $ff
        lda zp1+3
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta abst+3
        php         ;flags after load/store sequence
        eor #$c3
        cmp #0      ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+3  ;test flags
        trap_ne
        set_stat 0
        lda abs1  
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta zpt  
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1     ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx    ;test flags
        trap_ne
        set_stat 0
        lda abs1+1
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta zpt+1
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1+1   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat 0
        lda abs1+2
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta zpt+2
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1+2   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat 0
        lda abs1+3
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta zpt+3
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1+3   ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+3  ;test flags
        trap_ne
        set_stat $ff
        lda abs1  
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta zpt  
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1     ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx    ;test flags
        trap_ne
        set_stat $ff
        lda abs1+1
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta zpt+1
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1+1   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat $ff
        lda abs1+2
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta zpt+2
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1+2   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat $ff
        lda abs1+3
        php         ;test stores do not alter flags
        eor #$c3
        plp
        sta zpt+3
        php         ;flags after load/store sequence
        eor #$c3
        cmp zp1+3   ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+3  ;test flags
        trap_ne
        set_stat 0  
        lda #$c3
        php
        cmp abs1    ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx    ;test flags
        trap_ne
        set_stat 0
        lda #$82
        php
        cmp abs1+1  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat 0
        lda #$41
        php
        cmp abs1+2  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat 0
        lda #0
        php
        cmp abs1+3  ;test result
        trap_ne
        pla         ;load status
        eor_flag 0
        cmp fLDx+3  ;test flags
        trap_ne

        set_stat $ff
        lda #$c3  
        php
        cmp abs1    ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx    ;test flags
        trap_ne
        set_stat $ff
        lda #$82
        php
        cmp abs1+1  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+1  ;test flags
        trap_ne
        set_stat $ff
        lda #$41
        php
        cmp abs1+2  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+2  ;test flags
        trap_ne
        set_stat $ff
        lda #0
        php
        cmp abs1+3  ;test result
        trap_ne
        pla         ;load status
        eor_flag lo~fnz ;mask bits not altered
        cmp fLDx+3  ;test flags
        trap_ne

        ldx #0
        lda zpt  
        eor #$c3
        cmp zp1  
        trap_ne     ;store to zp data
        stx zpt     ;clear                
        lda abst  
        eor #$c3
        cmp abs1  
        trap_ne     ;store to abs data
        stx abst    ;clear                
        lda zpt+1
        eor #$c3
        cmp zp1+1
        trap_ne     ;store to zp data
        stx zpt+1   ;clear                
        lda abst+1
        eor #$c3
        cmp abs1+1
        trap_ne     ;store to abs data
        stx abst+1  ;clear                
        lda zpt+2
        eor #$c3
        cmp zp1+2
        trap_ne     ;store to zp data
        stx zpt+2   ;clear                
        lda abst+2
        eor #$c3
        cmp abs1+2
        trap_ne     ;store to abs data
        stx abst+2  ;clear                
        lda zpt+3
        eor #$c3
        cmp zp1+3
        trap_ne     ;store to zp data
        stx zpt+3   ;clear                
        lda abst+3
        eor #$c3
        cmp abs1+3
        trap_ne     ;store to abs data
        stx abst+3  ;clear                
        next_test

; testing bit test & compares BIT CPX CPY CMP all addressing modes
; BIT - zp / abs
        set_a $ff,0
        bit zp1+3   ;00 - should set Z / clear  NV
        tst_a $ff,fz 
        set_a 1,0
        bit zp1+2   ;41 - should set V (M6) / clear NZ
        tst_a 1,fv
        set_a 1,0
        bit zp1+1   ;82 - should set N (M7) & Z / clear V
        tst_a 1,fnz
        set_a 1,0
        bit zp1     ;c3 - should set N (M7) & V (M6) / clear Z
        tst_a 1,fnv
        
        set_a $ff,$ff
        bit zp1+3   ;00 - should set Z / clear  NV
        tst_a $ff,~fnv 
        set_a 1,$ff
        bit zp1+2   ;41 - should set V (M6) / clear NZ
        tst_a 1,~fnz
        set_a 1,$ff
        bit zp1+1   ;82 - should set N (M7) & Z / clear V
        tst_a 1,~fv
        set_a 1,$ff
        bit zp1     ;c3 - should set N (M7) & V (M6) / clear Z
        tst_a 1,~fz
        
        set_a $ff,0
        bit abs1+3  ;00 - should set Z / clear  NV
        tst_a $ff,fz 
        set_a 1,0
        bit abs1+2  ;41 - should set V (M6) / clear NZ
        tst_a 1,fv
        set_a 1,0
        bit abs1+1  ;82 - should set N (M7) & Z / clear V
        tst_a 1,fnz
        set_a 1,0
        bit abs1    ;c3 - should set N (M7) & V (M6) / clear Z
        tst_a 1,fnv
        
        set_a $ff,$ff
        bit abs1+3  ;00 - should set Z / clear  NV
        tst_a $ff,~fnv 
        set_a 1,$ff
        bit abs1+2  ;41 - should set V (M6) / clear NZ
        tst_a 1,~fnz
        set_a 1,$ff
        bit abs1+1  ;82 - should set N (M7) & Z / clear V
        tst_a 1,~fv
        set_a 1,$ff
        bit abs1    ;c3 - should set N (M7) & V (M6) / clear Z
        tst_a 1,~fz
        next_test
        
; CPX - zp / abs / #         
        set_x $80,0
        cpx zp7f
        tst_stat fc
        dex
        cpx zp7f
        tst_stat fzc
        dex
        cpx zp7f
        tst_x $7e,fn
        set_x $80,$ff
        cpx zp7f
        tst_stat ~fnz
        dex
        cpx zp7f
        tst_stat ~fn
        dex
        cpx zp7f
        tst_x $7e,~fzc

        set_x $80,0
        cpx abs7f
        tst_stat fc
        dex
        cpx abs7f
        tst_stat fzc
        dex
        cpx abs7f
        tst_x $7e,fn
        set_x $80,$ff
        cpx abs7f
        tst_stat ~fnz
        dex
        cpx abs7f
        tst_stat ~fn
        dex
        cpx abs7f
        tst_x $7e,~fzc

        set_x $80,0
        cpx #$7f
        tst_stat fc
        dex
        cpx #$7f
        tst_stat fzc
        dex
        cpx #$7f
        tst_x $7e,fn
        set_x $80,$ff
        cpx #$7f
        tst_stat ~fnz
        dex
        cpx #$7f
        tst_stat ~fn
        dex
        cpx #$7f
        tst_x $7e,~fzc
        next_test

; CPY - zp / abs / #         
        set_y $80,0
        cpy zp7f
        tst_stat fc
        dey
        cpy zp7f
        tst_stat fzc
        dey
        cpy zp7f
        tst_y $7e,fn
        set_y $80,$ff
        cpy zp7f
        tst_stat ~fnz
        dey
        cpy zp7f
        tst_stat ~fn
        dey
        cpy zp7f
        tst_y $7e,~fzc

        set_y $80,0
        cpy abs7f
        tst_stat fc
        dey
        cpy abs7f
        tst_stat fzc
        dey
        cpy abs7f
        tst_y $7e,fn
        set_y $80,$ff
        cpy abs7f
        tst_stat ~fnz
        dey
        cpy abs7f
        tst_stat ~fn
        dey
        cpy abs7f
        tst_y $7e,~fzc

        set_y $80,0
        cpy #$7f
        tst_stat fc
        dey
        cpy #$7f
        tst_stat fzc
        dey
        cpy #$7f
        tst_y $7e,fn
        set_y $80,$ff
        cpy #$7f
        tst_stat ~fnz
        dey
        cpy #$7f
        tst_stat ~fn
        dey
        cpy #$7f
        tst_y $7e,~fzc
        next_test

; CMP - zp / abs / #         
        set_a $80,0
        cmp zp7f
        tst_a $80,fc
        set_a $7f,0
        cmp zp7f
        tst_a $7f,fzc
        set_a $7e,0
        cmp zp7f
        tst_a $7e,fn
        set_a $80,$ff
        cmp zp7f
        tst_a $80,~fnz
        set_a $7f,$ff
        cmp zp7f
        tst_a $7f,~fn
        set_a $7e,$ff
        cmp zp7f
        tst_a $7e,~fzc

        set_a $80,0
        cmp abs7f
        tst_a $80,fc
        set_a $7f,0
        cmp abs7f
        tst_a $7f,fzc
        set_a $7e,0
        cmp abs7f
        tst_a $7e,fn
        set_a $80,$ff
        cmp abs7f
        tst_a $80,~fnz
        set_a $7f,$ff
        cmp abs7f
        tst_a $7f,~fn
        set_a $7e,$ff
        cmp abs7f
        tst_a $7e,~fzc

        set_a $80,0
        cmp #$7f
        tst_a $80,fc
        set_a $7f,0
        cmp #$7f
        tst_a $7f,fzc
        set_a $7e,0
        cmp #$7f
        tst_a $7e,fn
        set_a $80,$ff
        cmp #$7f
        tst_a $80,~fnz
        set_a $7f,$ff
        cmp #$7f
        tst_a $7f,~fn
        set_a $7e,$ff
        cmp #$7f
        tst_a $7e,~fzc

        ldx #4          ;with indexing by X
        set_a $80,0
        cmp zp1,x
        tst_a $80,fc
        set_a $7f,0
        cmp zp1,x
        tst_a $7f,fzc
        set_a $7e,0
        cmp zp1,x
        tst_a $7e,fn
        set_a $80,$ff
        cmp zp1,x
        tst_a $80,~fnz
        set_a $7f,$ff
        cmp zp1,x
        tst_a $7f,~fn
        set_a $7e,$ff
        cmp zp1,x
        tst_a $7e,~fzc

        set_a $80,0
        cmp abs1,x
        tst_a $80,fc
        set_a $7f,0
        cmp abs1,x
        tst_a $7f,fzc
        set_a $7e,0
        cmp abs1,x
        tst_a $7e,fn
        set_a $80,$ff
        cmp abs1,x
        tst_a $80,~fnz
        set_a $7f,$ff
        cmp abs1,x
        tst_a $7f,~fn
        set_a $7e,$ff
        cmp abs1,x
        tst_a $7e,~fzc

        ldy #4          ;with indexing by Y
        ldx #8          ;with indexed indirect
        set_a $80,0
        cmp abs1,y
        tst_a $80,fc
        set_a $7f,0
        cmp abs1,y
        tst_a $7f,fzc
        set_a $7e,0
        cmp abs1,y
        tst_a $7e,fn
        set_a $80,$ff
        cmp abs1,y
        tst_a $80,~fnz
        set_a $7f,$ff
        cmp abs1,y
        tst_a $7f,~fn
        set_a $7e,$ff
        cmp abs1,y
        tst_a $7e,~fzc

        set_a $80,0
        cmp (ind1,x)
        tst_a $80,fc
        set_a $7f,0
        cmp (ind1,x)
        tst_a $7f,fzc
        set_a $7e,0
        cmp (ind1,x)
        tst_a $7e,fn
        set_a $80,$ff
        cmp (ind1,x)
        tst_a $80,~fnz
        set_a $7f,$ff
        cmp (ind1,x)
        tst_a $7f,~fn
        set_a $7e,$ff
        cmp (ind1,x)
        tst_a $7e,~fzc

        set_a $80,0
        cmp (ind1),y
        tst_a $80,fc
        set_a $7f,0
        cmp (ind1),y
        tst_a $7f,fzc
        set_a $7e,0
        cmp (ind1),y
        tst_a $7e,fn
        set_a $80,$ff
        cmp (ind1),y
        tst_a $80,~fnz
        set_a $7f,$ff
        cmp (ind1),y
        tst_a $7f,~fn
        set_a $7e,$ff
        cmp (ind1),y
        tst_a $7e,~fzc
        next_test

; testing shifts - ASL LSR ROL ROR all addressing modes
; shifts - accumulator
        ldx #5
tasl
        set_ax zps,0
        asl a
        tst_ax rASL,fASL,0
        dex
        bpl tasl
        ldx #5
tasl1
        set_ax zps,$ff
        asl a
        tst_ax rASL,fASL,$ff-fnzc
        dex
        bpl tasl1

        ldx #5
tlsr
        set_ax zps,0
        lsr a
        tst_ax rLSR,fLSR,0
        dex
        bpl tlsr
        ldx #5
tlsr1
        set_ax zps,$ff
        lsr a
        tst_ax rLSR,fLSR,$ff-fnzc
        dex
        bpl tlsr1

        ldx #5
trol
        set_ax zps,0
        rol a
        tst_ax rROL,fROL,0
        dex
        bpl trol
        ldx #5
trol1
        set_ax zps,$ff-fc
        rol a
        tst_ax rROL,fROL,$ff-fnzc
        dex
        bpl trol1

        ldx #5
trolc
        set_ax zps,fc
        rol a
        tst_ax rROLc,fROLc,0
        dex
        bpl trolc
        ldx #5
trolc1
        set_ax zps,$ff
        rol a
        tst_ax rROLc,fROLc,$ff-fnzc
        dex
        bpl trolc1

        ldx #5
tror
        set_ax zps,0
        ror a
        tst_ax rROR,fROR,0
        dex
        bpl tror
        ldx #5
tror1
        set_ax zps,$ff-fc
        ror a
        tst_ax rROR,fROR,$ff-fnzc
        dex
        bpl tror1

        ldx #5
trorc
        set_ax zps,fc
        ror a
        tst_ax rRORc,fRORc,0
        dex
        bpl trorc
        ldx #5
trorc1
        set_ax zps,$ff
        ror a
        tst_ax rRORc,fRORc,$ff-fnzc
        dex
        bpl trorc1
        next_test

; shifts - zeropage
        ldx #5
tasl2
        set_z zps,0
        asl zpt
        tst_z rASL,fASL,0
        dex
        bpl tasl2
        ldx #5
tasl3
        set_z zps,$ff
        asl zpt
        tst_z rASL,fASL,$ff-fnzc
        dex
        bpl tasl3

        ldx #5
tlsr2
        set_z zps,0
        lsr zpt
        tst_z rLSR,fLSR,0
        dex
        bpl tlsr2
        ldx #5
tlsr3
        set_z zps,$ff
        lsr zpt
        tst_z rLSR,fLSR,$ff-fnzc
        dex
        bpl tlsr3

        ldx #5
trol2
        set_z zps,0
        rol zpt
        tst_z rROL,fROL,0
        dex
        bpl trol2
        ldx #5
trol3
        set_z zps,$ff-fc
        rol zpt
        tst_z rROL,fROL,$ff-fnzc
        dex
        bpl trol3

        ldx #5
trolc2
        set_z zps,fc
        rol zpt
        tst_z rROLc,fROLc,0
        dex
        bpl trolc2
        ldx #5
trolc3
        set_z zps,$ff
        rol zpt
        tst_z rROLc,fROLc,$ff-fnzc
        dex
        bpl trolc3

        ldx #5
tror2
        set_z zps,0
        ror zpt
        tst_z rROR,fROR,0
        dex
        bpl tror2
        ldx #5
tror3
        set_z zps,$ff-fc
        ror zpt
        tst_z rROR,fROR,$ff-fnzc
        dex
        bpl tror3

        ldx #5
trorc2
        set_z zps,fc
        ror zpt
        tst_z rRORc,fRORc,0
        dex
        bpl trorc2
        ldx #5
trorc3
        set_z zps,$ff
        ror zpt
        tst_z rRORc,fRORc,$ff-fnzc
        dex
        bpl trorc3
        next_test

; shifts - absolute
        ldx #5
tasl4
        set_abs zps,0
        asl abst
        tst_abs rASL,fASL,0
        dex
        bpl tasl4
        ldx #5
tasl5
        set_abs zps,$ff
        asl abst
        tst_abs rASL,fASL,$ff-fnzc
        dex
        bpl tasl5

        ldx #5
tlsr4
        set_abs zps,0
        lsr abst
        tst_abs rLSR,fLSR,0
        dex
        bpl tlsr4
        ldx #5
tlsr5
        set_abs zps,$ff
        lsr abst
        tst_abs rLSR,fLSR,$ff-fnzc
        dex
        bpl tlsr5

        ldx #5
trol4
        set_abs zps,0
        rol abst
        tst_abs rROL,fROL,0
        dex
        bpl trol4
        ldx #5
trol5
        set_abs zps,$ff-fc
        rol abst
        tst_abs rROL,fROL,$ff-fnzc
        dex
        bpl trol5

        ldx #5
trolc4
        set_abs zps,fc
        rol abst
        tst_abs rROLc,fROLc,0
        dex
        bpl trolc4
        ldx #5
trolc5
        set_abs zps,$ff
        rol abst
        tst_abs rROLc,fROLc,$ff-fnzc
        dex
        bpl trolc5

        ldx #5
tror4
        set_abs zps,0
        ror abst
        tst_abs rROR,fROR,0
        dex
        bpl tror4
        ldx #5
tror5
        set_abs zps,$ff-fc
        ror abst
        tst_abs rROR,fROR,$ff-fnzc
        dex
        bpl tror5

        ldx #5
trorc4
        set_abs zps,fc
        ror abst
        tst_abs rRORc,fRORc,0
        dex
        bpl trorc4
        ldx #5
trorc5
        set_abs zps,$ff
        ror abst
        tst_abs rRORc,fRORc,$ff-fnzc
        dex
        bpl trorc5
        next_test

; shifts - zp indexed
        ldx #5
tasl6
        set_zx zps,0
        asl zpt,x
        tst_zx rASL,fASL,0
        dex
        bpl tasl6
        ldx #5
tasl7
        set_zx zps,$ff
        asl zpt,x
        tst_zx rASL,fASL,$ff-fnzc
        dex
        bpl tasl7

        ldx #5
tlsr6
        set_zx zps,0
        lsr zpt,x
        tst_zx rLSR,fLSR,0
        dex
        bpl tlsr6
        ldx #5
tlsr7
        set_zx zps,$ff
        lsr zpt,x
        tst_zx rLSR,fLSR,$ff-fnzc
        dex
        bpl tlsr7

        ldx #5
trol6
        set_zx zps,0
        rol zpt,x
        tst_zx rROL,fROL,0
        dex
        bpl trol6
        ldx #5
trol7
        set_zx zps,$ff-fc
        rol zpt,x
        tst_zx rROL,fROL,$ff-fnzc
        dex
        bpl trol7

        ldx #5
trolc6
        set_zx zps,fc
        rol zpt,x
        tst_zx rROLc,fROLc,0
        dex
        bpl trolc6
        ldx #5
trolc7
        set_zx zps,$ff
        rol zpt,x
        tst_zx rROLc,fROLc,$ff-fnzc
        dex
        bpl trolc7

        ldx #5
tror6
        set_zx zps,0
        ror zpt,x
        tst_zx rROR,fROR,0
        dex
        bpl tror6
        ldx #5
tror7
        set_zx zps,$ff-fc
        ror zpt,x
        tst_zx rROR,fROR,$ff-fnzc
        dex
        bpl tror7

        ldx #5
trorc6
        set_zx zps,fc
        ror zpt,x
        tst_zx rRORc,fRORc,0
        dex
        bpl trorc6
        ldx #5
trorc7
        set_zx zps,$ff
        ror zpt,x
        tst_zx rRORc,fRORc,$ff-fnzc
        dex
        bpl trorc7
        next_test
        
; shifts - abs indexed
        ldx #5
tasl8
        set_absx zps,0
        asl abst,x
        tst_absx rASL,fASL,0
        dex
        bpl tasl8
        ldx #5
tasl9
        set_absx zps,$ff
        asl abst,x
        tst_absx rASL,fASL,$ff-fnzc
        dex
        bpl tasl9

        ldx #5
tlsr8
        set_absx zps,0
        lsr abst,x
        tst_absx rLSR,fLSR,0
        dex
        bpl tlsr8
        ldx #5
tlsr9
        set_absx zps,$ff
        lsr abst,x
        tst_absx rLSR,fLSR,$ff-fnzc
        dex
        bpl tlsr9

        ldx #5
trol8
        set_absx zps,0
        rol abst,x
        tst_absx rROL,fROL,0
        dex
        bpl trol8
        ldx #5
trol9
        set_absx zps,$ff-fc
        rol abst,x
        tst_absx rROL,fROL,$ff-fnzc
        dex
        bpl trol9

        ldx #5
trolc8
        set_absx zps,fc
        rol abst,x
        tst_absx rROLc,fROLc,0
        dex
        bpl trolc8
        ldx #5
trolc9
        set_absx zps,$ff
        rol abst,x
        tst_absx rROLc,fROLc,$ff-fnzc
        dex
        bpl trolc9

        ldx #5
tror8
        set_absx zps,0
        ror abst,x
        tst_absx rROR,fROR,0
        dex
        bpl tror8
        ldx #5
tror9
        set_absx zps,$ff-fc
        ror abst,x
        tst_absx rROR,fROR,$ff-fnzc
        dex
        bpl tror9

        ldx #5
trorc8
        set_absx zps,fc
        ror abst,x
        tst_absx rRORc,fRORc,0
        dex
        bpl trorc8
        ldx #5
trorc9
        set_absx zps,$ff
        ror abst,x
        tst_absx rRORc,fRORc,$ff-fnzc
        dex
        bpl trorc9
        next_test

; testing memory increment/decrement - INC DEC all addressing modes
; zeropage
        ldx #0
        lda #$7e
        sta zpt
tinc    
        set_stat 0
        inc zpt
        tst_z rINC,fINC,0
        inx
        cpx #2
        bne tinc1
        lda #$fe
        sta zpt
tinc1   cpx #5
        bne tinc
        dex
        inc zpt
tdec    
        set_stat 0
        dec zpt
        tst_z rINC,fINC,0
        dex
        bmi tdec1
        cpx #1
        bne tdec
        lda #$81
        sta zpt
        bne tdec
tdec1
        ldx #0
        lda #$7e
        sta zpt
tinc10    
        set_stat $ff
        inc zpt
        tst_z rINC,fINC,$ff-fnz
        inx
        cpx #2
        bne tinc11
        lda #$fe
        sta zpt
tinc11  cpx #5
        bne tinc10
        dex
        inc zpt
tdec10    
        set_stat $ff
        dec zpt
        tst_z rINC,fINC,$ff-fnz
        dex
        bmi tdec11
        cpx #1
        bne tdec10
        lda #$81
        sta zpt
        bne tdec10
tdec11
        next_test

; absolute memory
        ldx #0
        lda #$7e
        sta abst
tinc2    
        set_stat 0
        inc abst
        tst_abs rINC,fINC,0
        inx
        cpx #2
        bne tinc3
        lda #$fe
        sta abst
tinc3   cpx #5
        bne tinc2
        dex
        inc abst
tdec2    
        set_stat 0
        dec abst
        tst_abs rINC,fINC,0
        dex
        bmi tdec3
        cpx #1
        bne tdec2
        lda #$81
        sta abst
        bne tdec2
tdec3
        ldx #0
        lda #$7e
        sta abst
tinc12    
        set_stat $ff
        inc abst
        tst_abs rINC,fINC,$ff-fnz
        inx
        cpx #2
        bne tinc13
        lda #$fe
        sta abst
tinc13   cpx #5
        bne tinc12
        dex
        inc abst
tdec12    
        set_stat $ff
        dec abst
        tst_abs rINC,fINC,$ff-fnz
        dex
        bmi tdec13
        cpx #1
        bne tdec12
        lda #$81
        sta abst
        bne tdec12
tdec13
        next_test

; zeropage indexed
        ldx #0
        lda #$7e
tinc4   sta zpt,x
        set_stat 0
        inc zpt,x
        tst_zx rINC,fINC,0
        lda zpt,x
        inx
        cpx #2
        bne tinc5
        lda #$fe
tinc5   cpx #5
        bne tinc4
        dex
        lda #2
tdec4   sta zpt,x 
        set_stat 0
        dec zpt,x
        tst_zx rINC,fINC,0
        lda zpt,x
        dex
        bmi tdec5
        cpx #1
        bne tdec4
        lda #$81
        bne tdec4
tdec5
        ldx #0
        lda #$7e
tinc14  sta zpt,x
        set_stat $ff
        inc zpt,x
        tst_zx rINC,fINC,$ff-fnz
        lda zpt,x
        inx
        cpx #2
        bne tinc15
        lda #$fe
tinc15  cpx #5
        bne tinc14
        dex
        lda #2
tdec14  sta zpt,x 
        set_stat $ff
        dec zpt,x
        tst_zx rINC,fINC,$ff-fnz
        lda zpt,x
        dex
        bmi tdec15
        cpx #1
        bne tdec14
        lda #$81
        bne tdec14
tdec15
        next_test

; memory indexed
        ldx #0
        lda #$7e
tinc6   sta abst,x
        set_stat 0
        inc abst,x
        tst_absx rINC,fINC,0
        lda abst,x
        inx
        cpx #2
        bne tinc7
        lda #$fe
tinc7   cpx #5
        bne tinc6
        dex
        lda #2
tdec6   sta abst,x 
        set_stat 0
        dec abst,x
        tst_absx rINC,fINC,0
        lda abst,x
        dex
        bmi tdec7
        cpx #1
        bne tdec6
        lda #$81
        bne tdec6
tdec7
        ldx #0
        lda #$7e
tinc16  sta abst,x
        set_stat $ff
        inc abst,x
        tst_absx rINC,fINC,$ff-fnz
        lda abst,x
        inx
        cpx #2
        bne tinc17
        lda #$fe
tinc17  cpx #5
        bne tinc16
        dex
        lda #2
tdec16  sta abst,x 
        set_stat $ff
        dec abst,x
        tst_absx rINC,fINC,$ff-fnz
        lda abst,x
        dex
        bmi tdec17
        cpx #1
        bne tdec16
        lda #$81
        bne tdec16
tdec17
        next_test

; testing logical instructions - AND EOR ORA all addressing modes
; AND
        ldx #3          ;immediate
tand    lda zpAN,x
        sta ex_andi+1   ;set AND # operand
        set_ax  absANa,0
        jsr ex_andi     ;execute AND # in RAM
        tst_ax  absrlo,absflo,0
        dex
        bpl tand
        ldx #3
tand1   lda zpAN,x
        sta ex_andi+1   ;set AND # operand
        set_ax  absANa,$ff
        jsr ex_andi     ;execute AND # in RAM
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl tand1
    
        ldx #3      ;zp
tand2   lda zpAN,x
        sta zpt
        set_ax  absANa,0
        and zpt
        tst_ax  absrlo,absflo,0
        dex
        bpl tand2
        ldx #3
tand3   lda zpAN,x
        sta zpt
        set_ax  absANa,$ff
        and zpt
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl tand3

        ldx #3      ;abs
tand4   lda zpAN,x
        sta abst
        set_ax  absANa,0
        and abst
        tst_ax  absrlo,absflo,0
        dex
        bpl tand4
        ldx #3
tand5   lda zpAN,x
        sta abst
        set_ax  absANa,$ff
        and abst
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl tand6

        ldx #3      ;zp,x
tand6
        set_ax  absANa,0
        and zpAN,x
        tst_ax  absrlo,absflo,0
        dex
        bpl tand6
        ldx #3
tand7
        set_ax  absANa,$ff
        and zpAN,x
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl tand7

        ldx #3      ;abs,x
tand8
        set_ax  absANa,0
        and absAN,x
        tst_ax  absrlo,absflo,0
        dex
        bpl tand8
        ldx #3
tand9
        set_ax  absANa,$ff
        and absAN,x
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl tand9

        ldy #3      ;abs,y
tand10
        set_ay  absANa,0
        and absAN,y
        tst_ay  absrlo,absflo,0
        dey
        bpl tand10
        ldy #3
tand11
        set_ay  absANa,$ff
        and absAN,y
        tst_ay  absrlo,absflo,$ff-fnz
        dey
        bpl tand11

        ldx #6      ;(zp,x)
        ldy #3
tand12
        set_ay  absANa,0
        and (indAN,x)
        tst_ay  absrlo,absflo,0
        dex
        dex
        dey
        bpl tand12
        ldx #6
        ldy #3
tand13
        set_ay  absANa,$ff
        and (indAN,x)
        tst_ay  absrlo,absflo,$ff-fnz
        dex
        dex
        dey
        bpl tand13

        ldy #3      ;(zp),y
tand14
        set_ay  absANa,0
        and (indAN),y
        tst_ay  absrlo,absflo,0
        dey
        bpl tand14
        ldy #3
tand15
        set_ay  absANa,$ff
        and (indAN),y
        tst_ay  absrlo,absflo,$ff-fnz
        dey
        bpl tand15
        next_test

; EOR
        ldx #3          ;immediate - self modifying code
teor    lda zpEO,x
        sta ex_eori+1   ;set EOR # operand
        set_ax  absEOa,0
        jsr ex_eori     ;execute EOR # in RAM
        tst_ax  absrlo,absflo,0
        dex
        bpl teor
        ldx #3
teor1   lda zpEO,x
        sta ex_eori+1   ;set EOR # operand
        set_ax  absEOa,$ff
        jsr ex_eori     ;execute EOR # in RAM
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl teor1
    
        ldx #3      ;zp
teor2    lda zpEO,x
        sta zpt
        set_ax  absEOa,0
        eor zpt
        tst_ax  absrlo,absflo,0
        dex
        bpl teor2
        ldx #3
teor3   lda zpEO,x
        sta zpt
        set_ax  absEOa,$ff
        eor zpt
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl teor3

        ldx #3      ;abs
teor4   lda zpEO,x
        sta abst
        set_ax  absEOa,0
        eor abst
        tst_ax  absrlo,absflo,0
        dex
        bpl teor4
        ldx #3
teor5   lda zpEO,x
        sta abst
        set_ax  absEOa,$ff
        eor abst
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl teor6

        ldx #3      ;zp,x
teor6
        set_ax  absEOa,0
        eor zpEO,x
        tst_ax  absrlo,absflo,0
        dex
        bpl teor6
        ldx #3
teor7
        set_ax  absEOa,$ff
        eor zpEO,x
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl teor7

        ldx #3      ;abs,x
teor8
        set_ax  absEOa,0
        eor absEO,x
        tst_ax  absrlo,absflo,0
        dex
        bpl teor8
        ldx #3
teor9
        set_ax  absEOa,$ff
        eor absEO,x
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl teor9

        ldy #3      ;abs,y
teor10
        set_ay  absEOa,0
        eor absEO,y
        tst_ay  absrlo,absflo,0
        dey
        bpl teor10
        ldy #3
teor11
        set_ay  absEOa,$ff
        eor absEO,y
        tst_ay  absrlo,absflo,$ff-fnz
        dey
        bpl teor11

        ldx #6      ;(zp,x)
        ldy #3
teor12
        set_ay  absEOa,0
        eor (indEO,x)
        tst_ay  absrlo,absflo,0
        dex
        dex
        dey
        bpl teor12
        ldx #6
        ldy #3
teor13
        set_ay  absEOa,$ff
        eor (indEO,x)
        tst_ay  absrlo,absflo,$ff-fnz
        dex
        dex
        dey
        bpl teor13

        ldy #3      ;(zp),y
teor14
        set_ay  absEOa,0
        eor (indEO),y
        tst_ay  absrlo,absflo,0
        dey
        bpl teor14
        ldy #3
teor15
        set_ay  absEOa,$ff
        eor (indEO),y
        tst_ay  absrlo,absflo,$ff-fnz
        dey
        bpl teor15
        next_test

; OR
        ldx #3          ;immediate - self modifying code
tora    lda zpOR,x
        sta ex_orai+1   ;set ORA # operand
        set_ax  absORa,0
        jsr ex_orai     ;execute ORA # in RAM
        tst_ax  absrlo,absflo,0
        dex
        bpl tora
        ldx #3
tora1   lda zpOR,x
        sta ex_orai+1   ;set ORA # operand
        set_ax  absORa,$ff
        jsr ex_orai     ;execute ORA # in RAM
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl tora1
    
        ldx #3      ;zp
tora2   lda zpOR,x
        sta zpt
        set_ax  absORa,0
        ora zpt
        tst_ax  absrlo,absflo,0
        dex
        bpl tora2
        ldx #3
tora3   lda zpOR,x
        sta zpt
        set_ax  absORa,$ff
        ora zpt
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl tora3

        ldx #3      ;abs
tora4   lda zpOR,x
        sta abst
        set_ax  absORa,0
        ora abst
        tst_ax  absrlo,absflo,0
        dex
        bpl tora4
        ldx #3
tora5   lda zpOR,x
        sta abst
        set_ax  absORa,$ff
        ora abst
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl tora6

        ldx #3      ;zp,x
tora6
        set_ax  absORa,0
        ora zpOR,x
        tst_ax  absrlo,absflo,0
        dex
        bpl tora6
        ldx #3
tora7
        set_ax  absORa,$ff
        ora zpOR,x
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl tora7

        ldx #3      ;abs,x
tora8
        set_ax  absORa,0
        ora absOR,x
        tst_ax  absrlo,absflo,0
        dex
        bpl tora8
        ldx #3
tora9
        set_ax  absORa,$ff
        ora absOR,x
        tst_ax  absrlo,absflo,$ff-fnz
        dex
        bpl tora9

        ldy #3      ;abs,y
tora10
        set_ay  absORa,0
        ora absOR,y
        tst_ay  absrlo,absflo,0
        dey
        bpl tora10
        ldy #3
tora11
        set_ay  absORa,$ff
        ora absOR,y
        tst_ay  absrlo,absflo,$ff-fnz
        dey
        bpl tora11

        ldx #6      ;(zp,x)
        ldy #3
tora12
        set_ay  absORa,0
        ora (indOR,x)
        tst_ay  absrlo,absflo,0
        dex
        dex
        dey
        bpl tora12
        ldx #6
        ldy #3
tora13
        set_ay  absORa,$ff
        ora (indOR,x)
        tst_ay  absrlo,absflo,$ff-fnz
        dex
        dex
        dey
        bpl tora13

        ldy #3      ;(zp),y
tora14
        set_ay  absORa,0
        ora (indOR),y
        tst_ay  absrlo,absflo,0
        dey
        bpl tora14
        ldy #3
tora15
        set_ay  absORa,$ff
        ora (indOR),y
        tst_ay  absrlo,absflo,$ff-fnz
        dey
        bpl tora15
    if I_flag = 3
        cli
    endif                
        next_test

; full binary add/subtract test
; iterates through all combinations of operands and carry input
; uses increments/decrements to predict result & result flags
        cld
        ldx #ad2        ;for indexed test
        ldy #$ff        ;max range
        lda #0          ;start with adding zeroes & no carry
        sta adfc        ;carry in - for diag
        sta ad1         ;operand 1 - accumulator
        sta ad2         ;operand 2 - memory or immediate
        sta ada2        ;non zp
        sta adrl        ;expected result bits 0-7
        sta adrh        ;expected result bit 8 (carry out)
        lda #$ff        ;complemented operand 2 for subtract
        sta sb2
        sta sba2        ;non zp
        lda #2          ;expected Z-flag
        sta adrf
tadd    clc             ;test with carry clear
        jsr chkadd
        inc adfc        ;now with carry
        inc adrl        ;result +1
        php             ;save N & Z from low result
        php
        pla             ;accu holds expected flags
        and #$82        ;mask N & Z
        plp
        bne tadd1
        inc adrh        ;result bit 8 - carry
tadd1   ora adrh        ;merge C to expected flags
        sta adrf        ;save expected flags except overflow
        sec             ;test with carry set
        jsr chkadd
        dec adfc        ;same for operand +1 but no carry
        inc ad1
        bne tadd        ;iterate op1
        lda #0          ;preset result to op2 when op1 = 0
        sta adrh
        inc ada2
        inc ad2
        php             ;save NZ as operand 2 becomes the new result
        pla
        and #$82        ;mask N00000Z0
        sta adrf        ;no need to check carry as we are adding to 0
        dec sb2         ;complement subtract operand 2
        dec sba2
        lda ad2         
        sta adrl
        bne tadd        ;iterate op2
    if disable_decimal < 1
        next_test

; decimal add/subtract test
; *** WARNING - tests documented behavior only! ***
;   only valid BCD operands are tested, N V Z flags are ignored
; iterates through all valid combinations of operands and carry input
; uses increments/decrements to predict result & carry flag
        sed 
        ldx #ad2        ;for indexed test
        ldy #$ff        ;max range
        lda #$99        ;start with adding 99 to 99 with carry
        sta ad1         ;operand 1 - accumulator
        sta ad2         ;operand 2 - memory or immediate
        sta ada2        ;non zp
        sta adrl        ;expected result bits 0-7
        lda #1          ;set carry in & out
        sta adfc        ;carry in - for diag
        sta adrh        ;expected result bit 8 (carry out)
        lda #0          ;complemented operand 2 for subtract
        sta sb2
        sta sba2        ;non zp
tdad    sec             ;test with carry set
        jsr chkdad
        dec adfc        ;now with carry clear
        lda adrl        ;decimal adjust result
        bne tdad1       ;skip clear carry & preset result 99 (9A-1)
        dec adrh
        lda #$99
        sta adrl
        bne tdad3
tdad1   and #$f         ;lower nibble mask
        bne tdad2       ;no decimal adjust needed
        dec adrl        ;decimal adjust (?0-6)
        dec adrl
        dec adrl
        dec adrl
        dec adrl
        dec adrl
tdad2   dec adrl        ;result -1
tdad3   clc             ;test with carry clear
        jsr chkdad
        inc adfc        ;same for operand -1 but with carry
        lda ad1         ;decimal adjust operand 1
        beq tdad5       ;iterate operand 2
        and #$f         ;lower nibble mask
        bne tdad4       ;skip decimal adjust
        dec ad1         ;decimal adjust (?0-6)
        dec ad1
        dec ad1
        dec ad1
        dec ad1
        dec ad1
tdad4   dec ad1         ;operand 1 -1
        jmp tdad        ;iterate op1

tdad5   lda #$99        ;precharge op1 max
        sta ad1
        lda ad2         ;decimal adjust operand 2
        beq tdad7       ;end of iteration
        and #$f         ;lower nibble mask
        bne tdad6       ;skip decimal adjust
        dec ad2         ;decimal adjust (?0-6)
        dec ad2
        dec ad2
        dec ad2
        dec ad2
        dec ad2
        inc sb2         ;complemented decimal adjust for subtract (?9+6)
        inc sb2
        inc sb2
        inc sb2
        inc sb2
        inc sb2
tdad6   dec ad2         ;operand 2 -1
        inc sb2         ;complemented operand for subtract
        lda sb2
        sta sba2        ;copy as non zp operand
        lda ad2
        sta ada2        ;copy as non zp operand
        sta adrl        ;new result since op1+carry=00+carry +op2=op2
        inc adrh        ;result carry
        bne tdad        ;iterate op2
tdad7
        next_test

; decimal/binary switch test
; tests CLD, SED, PLP, RTI to properly switch between decimal & binary opcode
;   tables
        clc
        cld
        php
        lda #$55
        adc #$55
        cmp #$aa
        trap_ne         ;expected binary result after cld
        clc
        sed
        php
        lda #$55
        adc #$55
        cmp #$10
        trap_ne         ;expected decimal result after sed
        cld
        plp
        lda #$55
        adc #$55
        cmp #$10
        trap_ne         ;expected decimal result after plp D=1
        plp
        lda #$55
        adc #$55
        cmp #$aa
        trap_ne         ;expected binary result after plp D=0
        clc
        lda #hi bin_rti_ret ;emulated interrupt for rti
        pha
        lda #lo bin_rti_ret
        pha
        php
        sed
        lda #hi dec_rti_ret ;emulated interrupt for rti
        pha
        lda #lo dec_rti_ret
        pha
        php
        cld
        rti
dec_rti_ret
        lda #$55
        adc #$55
        cmp #$10
        trap_ne         ;expected decimal result after rti D=1
        rti
bin_rti_ret        
        lda #$55
        adc #$55
        cmp #$aa
        trap_ne         ;expected binary result after rti D=0
    endif
    
        lda test_case
        cmp #test_num
        trap_ne         ;previous test is out of sequence
        lda #$f0        ;mark opcode testing complete
        sta test_case
        
; final RAM integrity test
;   verifies that none of the previous tests has altered RAM outside of the
;   designated write areas.
        check_ram
; *** DEBUG INFO ***
; to debug checksum errors uncomment check_ram in the next_test macro to
; narrow down the responsible opcode.
; may give false errors when monitor, OS or other background activity is
; allowed during previous tests.


; S U C C E S S ************************************************
; -------------       
        success         ;if you get here everything went well
; -------------       
; S U C C E S S ************************************************
        jmp start       ;run again      

    if disable_decimal < 1
; core subroutine of the decimal add/subtract test
; *** WARNING - tests documented behavior only! ***
;   only valid BCD operands are tested, N V Z flags are ignored
; iterates through all valid combinations of operands and carry input
; uses increments/decrements to predict result & carry flag
chkdad
; decimal ADC / SBC zp
        php             ;save carry for subtract
        lda ad1
        adc ad2         ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
        php             ;save carry for next add
        lda ad1
        sbc sb2         ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad flags
        plp
; decimal ADC / SBC abs
        php             ;save carry for subtract
        lda ad1
        adc ada2        ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
        php             ;save carry for next add
        lda ad1
        sbc sba2        ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
; decimal ADC / SBC #
        php             ;save carry for subtract
        lda ad2
        sta ex_adci+1   ;set ADC # operand
        lda ad1
        jsr ex_adci     ;execute ADC # in RAM
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
        php             ;save carry for next add
        lda sb2
        sta ex_sbci+1   ;set SBC # operand
        lda ad1
        jsr ex_sbci     ;execute SBC # in RAM
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
; decimal ADC / SBC zp,x
        php             ;save carry for subtract
        lda ad1
        adc 0,x         ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
        php             ;save carry for next add
        lda ad1
        sbc sb2-ad2,x   ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
; decimal ADC / SBC abs,x
        php             ;save carry for subtract
        lda ad1
        adc ada2-ad2,x  ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
        php             ;save carry for next add
        lda ad1
        sbc sba2-ad2,x  ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
; decimal ADC / SBC abs,y
        php             ;save carry for subtract
        lda ad1
        adc ada2-$ff,y  ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
        php             ;save carry for next add
        lda ad1
        sbc sba2-$ff,y  ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
; decimal ADC / SBC (zp,x)
        php             ;save carry for subtract
        lda ad1
        adc (lo adi2-ad2,x) ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
        php             ;save carry for next add
        lda ad1
        sbc (lo sbi2-ad2,x) ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
; decimal ADC / SBC (abs),y
        php             ;save carry for subtract
        lda ad1
        adc (adiy2),y   ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
        php             ;save carry for next add
        lda ad1
        sbc (sbiy2),y   ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #1          ;mask carry
        cmp adrh
        trap_ne         ;bad carry
        plp
        rts
    endif

; core subroutine of the full binary add/subtract test
; iterates through all combinations of operands and carry input
; uses increments/decrements to predict result & result flags
chkadd  lda adrf        ;add V-flag if overflow
        and #$83        ;keep N-----ZC / clear V
        pha
        lda ad1         ;test sign unequal between operands
        eor ad2
        bmi ckad1       ;no overflow possible - operands have different sign
        lda ad1         ;test sign equal between operands and result
        eor adrl
        bpl ckad1       ;no overflow occured - operand and result have same sign
        pla
        ora #$40        ;set V
        pha
ckad1   pla
        sta adrf        ;save expected flags
; binary ADC / SBC zp
        php             ;save carry for subtract
        lda ad1
        adc ad2         ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
        php             ;save carry for next add
        lda ad1
        sbc sb2         ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
; binary ADC / SBC abs
        php             ;save carry for subtract
        lda ad1
        adc ada2        ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
        php             ;save carry for next add
        lda ad1
        sbc sba2        ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
; binary ADC / SBC #
        php             ;save carry for subtract
        lda ad2
        sta ex_adci+1   ;set ADC # operand
        lda ad1
        jsr ex_adci     ;execute ADC # in RAM
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
        php             ;save carry for next add
        lda sb2
        sta ex_sbci+1   ;set SBC # operand
        lda ad1
        jsr ex_sbci     ;execute SBC # in RAM
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
; binary ADC / SBC zp,x
        php             ;save carry for subtract
        lda ad1
        adc 0,x         ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
        php             ;save carry for next add
        lda ad1
        sbc sb2-ad2,x   ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
; binary ADC / SBC abs,x
        php             ;save carry for subtract
        lda ad1
        adc ada2-ad2,x  ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
        php             ;save carry for next add
        lda ad1
        sbc sba2-ad2,x  ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
; binary ADC / SBC abs,y
        php             ;save carry for subtract
        lda ad1
        adc ada2-$ff,y  ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
        php             ;save carry for next add
        lda ad1
        sbc sba2-$ff,y  ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
; binary ADC / SBC (zp,x)
        php             ;save carry for subtract
        lda ad1
        adc (lo adi2-ad2,x) ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
        php             ;save carry for next add
        lda ad1
        sbc (lo sbi2-ad2,x) ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
; binary ADC / SBC (abs),y
        php             ;save carry for subtract
        lda ad1
        adc (adiy2),y   ;perform add
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
        php             ;save carry for next add
        lda ad1
        sbc (sbiy2),y   ;perform subtract
        php          
        cmp adrl        ;check result
        trap_ne         ;bad result
        pla             ;check flags
        and #$c3        ;mask NV----ZC
        cmp adrf
        trap_ne         ;bad flags
        plp
        rts

; target for the jump absolute test
        dey
        dey
test_far
        php             ;either SP or Y count will fail, if we do not hit
        dey
        dey
        dey
        plp
        trap_cs         ;flags loaded?
        trap_vs
        trap_mi
        trap_eq 
        cmp #'F'        ;registers loaded?
        trap_ne
        cpx #'A'
        trap_ne        
        cpy #('R'-3)
        trap_ne
        pha             ;save a,x
        txa
        pha
        tsx
        cpx #$fd        ;check SP
        trap_ne
        pla             ;restore x
        tax
        set_stat $ff
        pla             ;restore a
        inx             ;return registers with modifications
        eor #$aa        ;N=1, V=1, Z=0, C=1
        jmp far_ret
        
; target for the jump indirect test
        align
ptr_tst_ind dw test_ind
ptr_ind_ret dw ind_ret
        trap            ;runover protection
        dey
        dey
test_ind
        php             ;either SP or Y count will fail, if we do not hit
        dey
        dey
        dey
        plp
        trap_cs         ;flags loaded?
        trap_vs
        trap_mi
        trap_eq 
        cmp #'I'        ;registers loaded?
        trap_ne
        cpx #'N'
        trap_ne        
        cpy #('D'-3)
        trap_ne
        pha             ;save a,x
        txa
        pha
        tsx
        cpx #$fd        ;check SP
        trap_ne
        pla             ;restore x
        tax
        set_stat $ff
        pla             ;restore a
        inx             ;return registers with modifications
        eor #$aa        ;N=1, V=1, Z=0, C=1
        jmp (ptr_ind_ret)
        trap            ;runover protection
        jmp start       ;catastrophic error - cannot continue

; target for the jump subroutine test
        dey
        dey
test_jsr
        php             ;either SP or Y count will fail, if we do not hit
        dey
        dey
        dey
        plp
        trap_cs         ;flags loaded?
        trap_vs
        trap_mi
        trap_eq 
        cmp #'J'        ;registers loaded?
        trap_ne
        cpx #'S'
        trap_ne        
        cpy #('R'-3)
        trap_ne
        pha             ;save a,x
        txa
        pha       
        tsx             ;sp -4? (return addr,a,x)
        cpx #$fb
        trap_ne
        lda $1ff        ;propper return on stack
        cmp #hi(jsr_ret)
        trap_ne
        lda $1fe
        cmp #lo(jsr_ret)
        trap_ne
        set_stat $ff
        pla             ;pull x,a
        tax
        pla
        inx             ;return registers with modifications
        eor #$aa        ;N=1, V=1, Z=0, C=1
        rts
        trap            ;runover protection
        jmp start       ;catastrophic error - cannot continue
        
;trap in case of unexpected IRQ, NMI, BRK, RESET - BRK test target
nmi_trap
        trap            ;check stack for conditions at NMI
        jmp start       ;catastrophic error - cannot continue
res_trap
        trap            ;unexpected RESET
        jmp start       ;catastrophic error - cannot continue
        
        dey
        dey
irq_trap                ;BRK test or unextpected BRK or IRQ
        php             ;either SP or Y count will fail, if we do not hit
        dey
        dey
        dey
        ;next traps could be caused by unexpected BRK or IRQ
        ;check stack for BREAK and originating location
        ;possible jump/branch into weeds (uninitialized space)
        cmp #$ff-'B'    ;BRK pass 2 registers loaded?
        beq break2
        cmp #'B'        ;BRK pass 1 registers loaded?
        trap_ne
        cpx #'R'
        trap_ne        
        cpy #'K'-3
        trap_ne
        sta irq_a       ;save registers during break test
        stx irq_x
        tsx             ;test break on stack
        lda $102,x
        cmp_flag 0      ;break test should have B=1 & unused=1 on stack
        trap_ne         ; - no break flag on stack
        pla
        cmp_flag intdis ;should have added interrupt disable
        trap_ne
        tsx
        cpx #$fc        ;sp -3? (return addr, flags)
        trap_ne
        lda $1ff        ;propper return on stack
        cmp #hi(brk_ret0)
        trap_ne
        lda $1fe
        cmp #lo(brk_ret0)
        trap_ne
        load_flag $ff
        pha
        ldx irq_x
        inx             ;return registers with modifications
        lda irq_a
        eor #$aa
        plp             ;N=1, V=1, Z=1, C=1 but original flags should be restored
        rti
        trap            ;runover protection
        jmp start       ;catastrophic error - cannot continue
        
break2                  ;BRK pass 2        
        cpx #$ff-'R'
        trap_ne        
        cpy #$ff-'K'-3
        trap_ne
        sta irq_a       ;save registers during break test
        stx irq_x
        tsx             ;test break on stack
        lda $102,x
        cmp_flag $ff    ;break test should have B=1
        trap_ne         ; - no break flag on stack
        pla
        ora #decmode    ;ignore decmode cleared if 65c02
        cmp_flag $ff    ;actual passed flags
        trap_ne
        tsx
        cpx #$fc        ;sp -3? (return addr, flags)
        trap_ne
        lda $1ff        ;propper return on stack
        cmp #hi(brk_ret1)
        trap_ne
        lda $1fe
        cmp #lo(brk_ret1)
        trap_ne
        load_flag intdis
        pha      
        ldx irq_x
        inx             ;return registers with modifications
        lda irq_a
        eor #$aa
        plp             ;N=0, V=0, Z=0, C=0 but original flags should be restored
        rti
        trap            ;runover protection
        jmp start       ;catastrophic error - cannot continue

    if report = 1
        include "report.i65"
    endif
        
;copy of data to initialize BSS segment
    if load_data_direct != 1
zp_init
zps_    db  $80,1           ;additional shift pattern to test zero result & flag
zp1_    db  $c3,$82,$41,0   ;test patterns for LDx BIT ROL ROR ASL LSR
zp7f_   db  $7f             ;test pattern for compare
;logical zeropage operands
zpOR_   db  0,$1f,$71,$80   ;test pattern for OR
zpAN_   db  $0f,$ff,$7f,$80 ;test pattern for AND
zpEO_   db  $ff,$0f,$8f,$8f ;test pattern for EOR
;indirect addressing pointers
ind1_   dw  abs1            ;indirect pointer to pattern in absolute memory
        dw  abs1+1
        dw  abs1+2
        dw  abs1+3
        dw  abs7f
inw1_   dw  abs1-$f8        ;indirect pointer for wrap-test pattern
indt_   dw  abst            ;indirect pointer to store area in absolute memory
        dw  abst+1
        dw  abst+2
        dw  abst+3
inwt_   dw  abst-$f8        ;indirect pointer for wrap-test store
indAN_  dw  absAN           ;indirect pointer to AND pattern in absolute memory
        dw  absAN+1
        dw  absAN+2
        dw  absAN+3
indEO_  dw  absEO           ;indirect pointer to EOR pattern in absolute memory
        dw  absEO+1
        dw  absEO+2
        dw  absEO+3
indOR_  dw  absOR           ;indirect pointer to OR pattern in absolute memory
        dw  absOR+1
        dw  absOR+2
        dw  absOR+3
;add/subtract indirect pointers
adi2_   dw  ada2            ;indirect pointer to operand 2 in absolute memory
sbi2_   dw  sba2            ;indirect pointer to complemented operand 2 (SBC)
adiy2_  dw  ada2-$ff        ;with offset for indirect indexed
sbiy2_  dw  sba2-$ff
zp_end
    if (zp_end - zp_init) != (zp_bss_end - zp_bss)   
        ;force assembler error if size is different   
        ERROR ERROR ERROR   ;mismatch between bss and zeropage data
    endif 
data_init
ex_and_ and #0              ;execute immediate opcodes
        rts
ex_eor_ eor #0              ;execute immediate opcodes
        rts
ex_ora_ ora #0              ;execute immediate opcodes
        rts
ex_adc_ adc #0              ;execute immediate opcodes
        rts
ex_sbc_ sbc #0              ;execute immediate opcodes
        rts
;zps    db  $80,1           ;additional shift patterns test zero result & flag
abs1_   db  $c3,$82,$41,0   ;test patterns for LDx BIT ROL ROR ASL LSR
abs7f_  db  $7f             ;test pattern for compare
;loads
fLDx_   db  fn,fn,0,fz              ;expected flags for load
;shifts
rASL_                               ;expected result ASL & ROL -carry
rROL_   db  0,2,$86,$04,$82,0
rROLc_  db  1,3,$87,$05,$83,1       ;expected result ROL +carry
rLSR_                               ;expected result LSR & ROR -carry
rROR_   db  $40,0,$61,$41,$20,0
rRORc_  db  $c0,$80,$e1,$c1,$a0,$80 ;expected result ROR +carry
fASL_                               ;expected flags for shifts
fROL_   db  fzc,0,fnc,fc,fn,fz      ;no carry in
fROLc_  db  fc,0,fnc,fc,fn,0        ;carry in 
fLSR_
fROR_   db  0,fzc,fc,0,fc,fz        ;no carry in
fRORc_  db  fn,fnc,fnc,fn,fnc,fn    ;carry in
;increments (decrements)
rINC_   db  $7f,$80,$ff,0,1         ;expected result for INC/DEC
fINC_   db  0,fn,fn,fz,0            ;expected flags for INC/DEC
;logical memory operand
absOR_  db  0,$1f,$71,$80           ;test pattern for OR
absAN_  db  $0f,$ff,$7f,$80         ;test pattern for AND
absEO_  db  $ff,$0f,$8f,$8f         ;test pattern for EOR
;logical accu operand
absORa_ db  0,$f1,$1f,0             ;test pattern for OR
absANa_ db  $f0,$ff,$ff,$ff         ;test pattern for AND
absEOa_ db  $ff,$f0,$f0,$0f         ;test pattern for EOR
;logical results
absrlo_ db  0,$ff,$7f,$80
absflo_ db  fz,fn,0,fn
data_end
    if (data_end - data_init) != (data_bss_end - data_bss)
        ;force assembler error if size is different   
        ERROR ERROR ERROR   ;mismatch between bss and data
    endif 

vec_init
        dw  nmi_trap
        dw  res_trap
        dw  irq_trap
vec_bss equ $fffa
    endif                   ;end of RAM init data
    
    if (load_data_direct = 1) & (ROM_vectors = 1)  
        org $fffa       ;vectors
        dw  nmi_trap
        dw  res_trap
        dw  irq_trap
    endif

        end start
            