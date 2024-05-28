;//////////////////////////////////////////////////////////////////////////////;
; Project:                                                                     ;
;    PICALC-Z80                                                                ;
;                                                                              ;
; Description:                                                                 ;
;    A calculator that yields an arbitrary number of digits of the number PI.  ;
;                                                                              ;
; Target:                                                                      ;
;    Any Z80-based computer. Details of memory allocation and stack positioning;
;    must be adjusted for the specifics of the target. In addition, INT 08h    ;
;    is used as a function call to print character over TTY (A = character),   ;
;    which implementation has to be adjusted to the target.                    ;
;                                                                              ;
; Compiler:                                                                    ;
;    z80asm                                                                    ;
;    https://manpages.ubuntu.com/manpages/trusty/man1/z80asm.1.html            ;
;                                                                              ;
;    Other compilers/assemblers may require minor changes in the source code.  ;
;                                                                              ;
; Usage:                                                                       ;
;    The desired amount of PI digits is defined in the macro NUM_DECS. Default ;
;    value is 100. Note that incrementing this value will increase RAM usage   ;
;    proportionally, and the needed CPU cycles quadratically. Don't change the ;
;    other algorithm constants unless you really know what you are doing.      ;
;                                                                              ;
;    The algorithm was validated for 1,000 digits of PI, all of them checked   ;
;    against the generally known published digits. For an actual Z80, yielding ;
;    this number of digits may prove to be a daunting task, especially because ;
;    of the gigantic number of CPU cycles needed (RAM is a lesser problem in   ;
;    this regard). 100 digits is way more practical amount, unless you have A  ;
;    LOT of time to spare.                                                     ;
;                                                                              ;
;    The main loop iteracts as many times as needed to calculate all the       ;
;    decimal places requested (the number of iterations / number of digits have;
;    a ratio close to 0.9). With each iteration the message 'TOTAL:' is printed;
;    along the PI approximation calculated so far.                             ;
;                                                                              ;
; Version & Date:                                                              ;
;    1.0 - 2024-MAY-27                                                         ;
;                                                                              ;
; Author:                                                                      ;
;    Milton Maldonado Jr (ARM_Coder)                                           ;
;                                                                              ;
; License:                                                                     ;
;    GPL V2                                                                    ;
;                                                                              ;
; Disclaimer:                                                                  ;
;    This code is supplied 'as is' with no warranty against bugs. It was tested;
;    on a Z80 simulator that *I* wrote (haha), so it was not tested against any;
;    actual, validated target.                                                 ;
;                                                                              ;
; Note:                                                                        ;
;    Along the ASM source, you will see some commented 'C' statemens. The      ;
;    project was initially built and tested in C, and then hand-translated     ;
;    to Z80 ASM.                                                               ;
;                                                                              ;
; Note 2:                                                                      ;
;    I hope this is my last ASM project ever. Writing code in ASM is a real    ;
;    PITA, but this project was a challenge I've set for me.                   ;
;                                                                              ;
; Funny note:                                                                  ;
;    This project implements the Bailey-Borwein-Plouffe method of calculating  ;
;    PI. This method is much, much faster that the classic Euler series.       ;
;    The funny thing is that the method was discovered (invented?) in 1995,    ;
;    when the Z80 had already passed its heyday and was fading into a niche,   ;
;    retro platform.                                                           ;
;//////////////////////////////////////////////////////////////////////////////;

; Example: z80asm picalc.asm -o - | xxd -ps -c 16 > test.hex

; Hardware constants
ROMBASE:        equ 0
ROMSZ:          equ 8192
RAMBASE:        equ 8192
RAMSZ:          equ 8192

; Algorithm constants
NUM_DECS:       equ 100
NUM_IT:         equ ((NUM_DECS*9)/10)
NBITS_FR:       equ (3*NUM_DECS + (NUM_DECS >> 1))
NBITS_INT:      equ 16
NBITS_FRAC:     equ 8*(1 + (NBITS_FR >> 3)) ; The number of bits should be at least 3.33x (1 / log(2)) the number of decimal places, plus a small cushion.
NBYTES_INT:     equ NBITS_INT >> 3
NBITS:          equ NBITS_INT+NBITS_FRAC
NBYTES:         equ NBITS>>3
NBYTES1:        equ NBYTES-1

    org ROMBASE     ; Expected to be 0x00. Other values will clash with the
                    ; interrupt handlers below.

    ld sp,RAMBASE + RAMSZ
    call _main
    halt

    seek 0x0008     ; SW Interrupt. Used here to print characters.
    org 0x0008
    out (0),a       ; Change it for whatever your target needs.
    ret

    seek 0x0038     ; HW Interrupt IM 1.
    org 0x0038
    reti

    seek 0x0066     ; NMI.
    org 0x0066
    retn

;///////////////////////////////////////////////////////////////////////////////
;   prints
;   void prints(const char *string);
;   Parameters: HL: string
;   Returns: Nothing
;   Affects: HL
prints:

    pop hl
prints_1:
    ld a,(hl)
    or a
    jr z,prints_2
    rst 08h
    inc hl
    jr prints_1
prints_2:
    inc hl
    push hl
    ret

;///////////////////////////////////////////////////////////////////////////////
;   print_crlf
;   void print_crlf(void);
;   Parameters: Nothing
;   Returns: Nothing
;   Affects: HL
print_crlf:

    call prints
    db 13,10,0
    ret

;///////////////////////////////////////////////////////////////////////////////
;   zero_reg
;   void zero_reg(uint8_t *reg);
;   Parameters:
;     HL: reg
;   Returns: Nothing
;   Affects: BC DE HL AF
zero_reg:

    ;    memset(reg,0,NBYTES);
    ld bc,NBYTES-1
    xor a
    ld (hl),a
    ld d,h
    ld e,l
    inc de
    ldir
    ret

;///////////////////////////////////////////////////////////////////////////////
;   set_bit_reg
;   void set_bit_reg(uint8_t *reg, int place);
;   Parameters:
;     HL: reg
;     BC: place
;   Returns: Nothing
;   Affects: BC DE HL AF
set_bit_reg:

    ;   int byte = NBYTES1 - (place >> 3);
    push hl
    ld hl,NBYTES1

set_bit_reg0:

    ld d,b
    ld e,c
    srl d
    rr e
    srl d
    rr e
    srl d
    rr e
    scf
    ccf
    sbc hl,de
    ex de,hl    ;DE: byte
    pop hl

    ;   int bits = place & 0x07;
    ld a,c
    and 0x07    ;A: bits

    ;   reg[byte] |= 1<<bits;
    add hl,de

    ld b,1
    or a
    jr z,set_bit_reg2

set_bit_reg1:

    sla b
    dec a
    jr nz,set_bit_reg1

set_bit_reg2:

    ld a,(hl)
    or b
    ld (hl),a
    ret

;///////////////////////////////////////////////////////////////////////////////
;   set_bit_reg_int
;   void set_bit_reg_int(uint8_t *reg, int place);
;   Parameters:
;     HL: reg
;     BC: place
;   Returns: Nothing
;   Affects: BC DE HL AF
set_bit_reg_int:

    ;   int byte = NBYTES_INT - 1 - (place >> 3);
    push hl
    ld hl,NBYTES_INT-1
    jr set_bit_reg0

;///////////////////////////////////////////////////////////////////////////////
;   print_reg
;   void print_reg(uint8_t *reg);
;   Não portada

;///////////////////////////////////////////////////////////////////////////////
;   add_reg2_to_reg1
;   void add_reg2_to_reg1(uint8_t *reg1, const uint8_t *reg2);
;   Parameters:
;     HL: reg2
;     DE: reg1
;   Returns: Nothing
;   Affects: BC DE HL AF BC' DE' HL' AF'
add_reg2_to_reg1:

    ;   uint16_t cy = 0;
    ;   int i;
    ;   for (i = NBYTES1; i >= 0; i--){
    ;       uint16_t sum = (uint16_t)reg1[i] + (uint16_t)reg2[i] + cy;
    ;       if (sum & 0x100)
    ;           cy = 1;
    ;       else
    ;           cy = 0;
    ;       reg1[i] = sum & 0xff;
    ;   }

    ld bc,NBYTES1
    add hl,bc
    ex de,hl
    add hl,bc
    ex de,hl
    exx
    ld bc,NBYTES1
    inc bc
    exx
    sub a   ;zero Carry Flag

add_reg2_to_reg1_0:

    ld b,(hl)
    ld a,(de)
    adc a,b
    ld (de),a

    dec hl
    dec de

    exx                         ; Save HL & DE, restores counter in BC
    ex af,af'                   ; Save CY
    dec bc
    ld a,b
    or c
    ret z                       ; End loop, bye
    ex af,af'                   ; Restore CY
    exx                         ; Save counter in BC, restores HL & DE
    jr add_reg2_to_reg1_0

;///////////////////////////////////////////////////////////////////////////////
;   add_reg_to_acc
;   void add_reg_to_acc(const uint8_t *reg);
;   Parameters:
;     HL: reg
;   Returns: Nothing
;   Affects: BC DE HL AF BC' DE' HL' AF'
add_reg_to_acc:

    ld de,acc
    jr add_reg2_to_reg1

;///////////////////////////////////////////////////////////////////////////////
;   inc_reg_int8
;   void inc_reg_int8(uint8_t *reg, uint8_t byteval);
;   Parameters:
;     DE: reg
;     A:  byteval
;   Returns: Nothing
;   Affects: BC DE HL AF BC' DE' HL' AF'
inc_reg_int8:

    ;    uint16_t cy = byteval;
    ;    int i;
    ;    for (i = NBYTES_INT - 1; i >= 0; i--){
    ;        uint16_t sum =(uint16_t)reg[i] + cy;
    ;        reg[i] = sum & 0xff;
    ;        if (!(sum & 0x100))
    ;            return;
    ;        cy = 1;
    ;    }

    ld bc,NBYTES_INT
    ex de,hl
    add hl,bc
    dec hl
    ld e,a

inc_reg_int8_0:

    ld a,(hl)
    add a,e
    ld (hl),a

    ld e,0
    jr nc, inc_reg_int8_1
    inc e       ; Here E propagates the carry for the sums.

inc_reg_int8_1:

    dec bc
    ld a,b
    or c
    ret z                       ; End loop, bye

    dec hl
    jr inc_reg_int8_0

;///////////////////////////////////////////////////////////////////////////////
;   load_reg_int
;   void load_reg_int(uint8_t *reg, int val);
;   Parameters:
;     DE: reg
;     HL: val
;   Returns: Nothing
;   Affects: BC DE HL AF BC' DE' HL' AF'
load_reg_int:

;    for (int i = NBYTES_INT - 1; i >= 0; i--){
;        reg[i] = val & 0xff;
;        val >>= 8;
;    }
    ex de,hl
    ld bc,NBYTES_INT
    add hl,bc
    dec hl
    ld b,NBYTES_INT
    ld a,e
    ld (hl),a
    dec hl
    ld a,d
    ld (hl),a
    dec b
    dec b
    ld a,b
    or a
    ret z
    dec hl
    xor a
load_reg_int_0:
    ld (hl),a
    dec hl
    djnz load_reg_int_0
    ret

;///////////////////////////////////////////////////////////////////////////////
;   sub_reg2_from_reg1
;   void sub_reg2_from_reg1(uint8_t *reg1, const uint8_t *reg2);
;   Parameters:
;     DE: reg1
;     HL: reg2
;   Returns: Nothing
;   Affects: BC DE HL AF BC' DE' HL' AF'
sub_reg2_from_reg1:

;    uint16_t cy = 0;
;    int i;
;    for (i = NBYTES1; i >= 0; i--){
;        uint16_t diff = (uint16_t)reg1[i] - (uint16_t)reg2[i] - cy;
;        if (diff & 0x8000)
;            cy = 1;
;        else
;            cy = 0;
;        reg1[i] = diff & 0xff;
;    }

    ld bc,NBYTES1
    add hl,bc
    ex de,hl
    add hl,bc
    ex de,hl
    exx
    ld bc,NBYTES1
    inc bc
    exx
    sub a   ;zera CY

sub_reg2_to_reg1_0:

    ld b,(hl)
    ld a,(de)
    sbc a,b
    ld (de),a

    dec hl
    dec de

    exx                         ; Save HL & DE, restores counter in BC
    ex af,af'                   ; Save CY
    dec bc
    ld a,b
    or c
    ret z                       ; End loop, bye
    ex af,af'                   ; Restore CY
    exx                         ; Save counter in BC, restore HL & DE
    jr sub_reg2_to_reg1_0

;///////////////////////////////////////////////////////////////////////////////
;   sub_reg_from_acc
;   void sub_reg_from_acc(const uint8_t *reg);
;   Parameters:
;     HL: reg
;   Returns: Nothing
;   Affects: BC DE HL AF BC' DE' HL' AF'
sub_reg_from_acc:

    ld de,acc
    call sub_reg2_from_reg1
    ret

;///////////////////////////////////////////////////////////////////////////////
;   shl_reg
;   void shl_reg(uint8_t *reg, int places)
;   Parameters:
;     DE: reg
;     BC: places
;   Returns: Nothing
;   Affects: BC DE HL AF
shl_reg:

    push ix
    ld ix,0xFFF8    ; Allocates 8 bytes
    add ix,sp
    ld sp,ix

    ld (ix+0),e     ;IX+0, IX+1 = 'reg'
    ld (ix+1),d

;    if (places > NBITS)
;        places = NBITS;
    ld a,NBITS >> 8
    sub b
    jr c,shl_reg_0
    jr nz,shl_reg_1

    ld a,NBITS & 255
    sub c
    jr nc, shl_reg_1

shl_reg_0:

    ld bc,NBITS

shl_reg_1:

;    int bytes = places >> 3;
;    int bits = places & 0x07;
    ld a,c
    and 0x07
    ld (ix+2),a     ; IX+2 = 'bits'
    srl b
    rr c
    srl b
    rr c
    srl b
    rr c            ; BC = 'bytes'

;    int leftbytes = NBYTES - bytes;
    ld hl,NBYTES
    xor a
    sbc hl,bc       ; HL = 'leftbytes'
    ld (ix+4),l     ; IX+4, IX+5 = 'leftbytes'
    ld (ix+5),h

;    if (bytes){
    ld a,b
    or c
    jr z,shl_reg_2

;        if (leftbytes)
    ld a,h
    or l
    jr z,shl_reg_1a

    push bc         ; Save 'bytes'
    push hl         ; Save 'leftbytes'

;            memmove(&reg[0], &reg[bytes], leftbytes);
    ld h,d
    ld l,e
    add hl,bc       ; DE='reg' HL='reg[bytes]'
    pop bc          ; Restore 'leftbytes'
    ldir

    pop bc          ; Restore 'bytes'

shl_reg_1a:

;        memset(&reg[leftbytes],0,bytes);
;    }

    ld h,d  ; Here DE points to the 1st byte to fill w/ zero (obtained from the
    ld l,e  ; previous LDIR if it took place, or the previous value).

shl_reg_1b:

    xor a
    ld (hl),a
    inc hl
    dec bc
    ld a,b
    or c
    jr nz,shl_reg_1b

shl_reg_2:

;    if (bits){
    ld a,(ix+2)     ; 'bits'
    or a
    jr z,shl_reg_end

;        for (i = 0; i < (leftbytes-1); i++){
    ; Vai fazer o shift
    ld c,(ix+4)
    ld b,(ix+5)     ;'leftbytes'
    ld a,b
    or c
    jr z,shl_reg_3
    dec bc
    ld a,b
    or c
    jr z,shl_reg_3

    ld l,(ix+0)
    ld h,(ix+1)     ; HL = 'reg'

shl_reg_2a:

;            reg[i] <<= bits;
    ld a,(ix+2)     ; 'bits'
    ld e,a          ; 'bits'
    neg
    add a,8
    ld d,a
    ld a,(hl)

shl_reg_2b:

    sla a
    dec e
    jr nz,shl_reg_2b

;            uint8_t aux = reg[i+1] >> (8-bits);
    ld e,a

    inc hl
    ld a,(hl)
    dec hl

shl_reg_2c:

    srl a
    dec d
    jr nz,shl_reg_2c

;            reg[i] |= aux;
;        }
    or e
    ld (hl),a
    inc hl

    dec bc
    ld a,b
    or c
    jr nz,shl_reg_2a

shl_reg_3:
;        reg[leftbytes - 1] <<= bits;
    ld a,(hl)
    ld b,(IX+2)     ; 'bits'

shl_reg_2d:

    sla a
    djnz shl_reg_2d

    ld (hl),a

;    }

shl_reg_end:

    ld hl,0x0008    ; Frees 8 bytes
    add hl,sp
    ld sp,hl
    pop ix
    ret

;///////////////////////////////////////////////////////////////////////////////
stack_test:

    push ix
    ld ix,0xFFF8    ; Allocates 8 bytes
    add ix,sp
    ld sp,ix

    ld c,(ix+0)
    ld b,(ix+1)
    ;....
    ld hl,0x0008    ; Frees 8 bytes
    add hl,sp
    ld sp,hl
    pop ix
    ret

;///////////////////////////////////////////////////////////////////////////////
;   shr_reg
;   void shr_reg(uint8_t *reg, int places);
;   Parameters:
;     DE: reg
;     BC: places
;   Returns: Nothing
;   Affects: BC DE HL AF
shr_reg:

    push ix
    ld ix,0xFFF8    ; Allocates 8 bytes
    add ix,sp
    ld sp,ix

    ld (ix+0),e     ; IX+0, IX+1 = 'reg'
    ld (ix+1),d

;    if (places > NBITS)
;        places = NBITS;
    ld a,NBITS >> 8
    sub b
    jr c,shr_reg_0
    jr nz,shr_reg_1

    ld a,NBITS & 255
    sub c
    jr nc, shr_reg_1

shr_reg_0:

    ld bc,NBITS

shr_reg_1:

;    int bytes = places >> 3;
;    int bits = places & 0x07;
    ld a,c
    and 0x07
    ld (ix+2),a     ; IX+2 = 'bits'
    srl b
    rr c
    srl b
    rr c
    srl b
    rr c            ; BC = 'bytes'
    ld (ix+6),c
    ld (ix+7),b     ; IX+6, IX+7 = 'bytes'

;    int rightbytes = NBYTES - bytes;
    ld hl,NBYTES
    xor a
    sbc hl,bc       ; HL = 'rightbytes'
    ld (ix+4),l     ; IX+4, IX+5 = 'rightbytes'
    ld (ix+5),h

;    if (bytes){
    ld a,b
    or c
    jr z,shr_reg_2

;        if (rightbytes)
    ld a,h
    or l
    jr z,shr_reg_1a

;            memmove(&reg[bytes], &reg[0], rightbytes);
    ld hl,NBYTES1
    add hl,de
    ld d,h
    ld e,l          ; DE = last buffer's byte (destination)

    xor a           ; BC = 'bytes'
    sbc hl,bc       ; HL = origem
    ld c,(ix+4)     ; 'rightbytes'
    ld b,(ix+5)
    lddr

shr_reg_1a:

;        memset(&reg[0],0,bytes);
    ld c,(ix+6)
    ld b,(ix+7)     ; IX+6, IX+7 = 'bytes'
    ld l,(ix+0)
    ld h,(ix+1)     ; IX+0, IX+1 = 'reg'

shr_reg_1b:

    xor a
    ld (hl),a
    inc hl
    dec bc
    ld a,b
    or c
    jr nz,shr_reg_1b

;    }

shr_reg_2:

;    if (bits){
    ld a,(ix+2)     ; 'bits'
    or a
    jr z,shr_reg_end


;        for (i = NBYTES1; i > bytes; i--){
    ld hl,NBYTES1
    ld c,(ix+6)
    ld b,(ix+7)     ; IX+6, IX+7 = 'bytes'
    xor a
    sbc hl,bc

    ld a,h
    or l
    jr z,shr_reg_2e

    ld b,h
    ld c,l          ; BC = # of bytes to process

    ld l,(ix+0)
    ld h,(ix+1)     ; HL = 'reg'

    ld de,NBYTES1
    add hl,de

shr_reg_2a:

;            reg[i] >>= bits;
    ld a,(ix+2)     ; 'bits'
    ld e,a          ; E = 'bits'
    neg
    add a,8
    ld d,a          ; D = 8 - 'bits'
    ld a,(hl)

shr_reg_2b:

    srl a
    dec e
    jr nz,shr_reg_2b

    ld e,a

;            uint8_t aux = reg[i-1] << (8-bits);
    dec hl
    ld a,(hl)
    inc hl

shr_reg_2c:

    sla a
    dec d
    jr nz,shr_reg_2c

;            reg[i] |= aux;
    or e
    ld (hl),a

;        }
    dec hl
    dec bc
    ld a,b
    or c
    jr nz,shr_reg_2a

shr_reg_2e:

;        reg[bytes] >>= bits;
    ld a,(hl)
    ld b,(IX+2)     ; 'bits'

shr_reg_2d:
    srl a
    djnz shr_reg_2d
    ld (hl),a

;    }

shr_reg_end:

    ld hl,0x0008    ; Frees 8 bytes
    add hl,sp
    ld sp,hl
    pop ix
    ret

;///////////////////////////////////////////////////////////////////////////////
;   mul_reg2_by_reg1
;   void mul_reg2_by_reg1(const uint8_t *reg1, uint8_t *reg2);
;   Parameters:
;     HL: reg1
;     DE: reg2
;   Returns: Nothing
;   Affects: BC DE HL AF IY BC' DE' HL' AF'
mul_reg2_by_reg1:

    push ix
    ld ix,0xFFF8-2*NBYTES    ; Allocates 8 bytes + 2 buffers
    add ix,sp
    ld sp,ix

    ld (ix+0),l
    ld (ix+1),h         ; IX+0, IX+1: reg1
    ld (ix+2),e
    ld (ix+3),d         ; IX+2, IX+3: reg2

;    uint8_t regmdiv[NBYTES];
    ld c,ixl
    ld b,ixh            ; Copia IX em BC
    ld HL,8
    add hl,bc
    ld (ix+4),l
    ld (ix+5),h         ; IX+4, IX+5: regmdiv

;    uint8_t regmdiv2[NBYTES];
    ld bc,NBYTES
    add hl,bc
    ld (ix+6),l
    ld (ix+7),h         ; IX+6, IX+7: regmdiv2

;    memcpy(regmdiv, reg2, NBYTES);
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: reg2
    ld bc,NBYTES
    ldir

;    memcpy(regmdiv2, reg2, NBYTES);
    ld e,(ix+6)
    ld d,(ix+7)         ; IX+6, IX+7: regmdiv2
    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: reg2
    ld bc,NBYTES
    ldir

;    zero_reg(reg2);
    ld l,(ix+2)
    ld h,(ix+3)
    call zero_reg       ;Zera reg2

;    int places = 0;
    ld iy,0             ; IY = places

;    // Integer part
;    for (int i = NBYTES_INT-1; i>=0; i--){

    ld bc,NBYTES_INT
    ld l,(ix+0)
    ld h,(ix+1)       ; IX+0, IX+1: reg1
    add hl,bc
    dec hl            ; HL: buffer to process

mul_reg2_by_reg1_1:

;        int msk = 1;
    ld d,1

;        for (int j = 0; j < 8; j++){
    ld e,8

mul_reg2_by_reg1_2:

;            if (reg1[i] & msk){
    ld a,(hl)
    and d
    jr z, mul_reg2_by_reg1_3

;                shl_reg(regmdiv,places);
    push bc
    push de
    push hl

    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    ld b,iyh
    ld c,iyl            ; BC recebe IY = 'places'
    call shl_reg

;                add_reg2_to_reg1(reg2, regmdiv);
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: reg2
    ld l,(ix+4)
    ld h,(ix+5)         ; IX+4, IX+5: regmdiv
    call add_reg2_to_reg1

    pop hl
    pop de
    pop bc

;                places = 1;
    ld iy,1     ; IY = places
;            }
;            else
;                places++;
    jr mul_reg2_by_reg1_4

mul_reg2_by_reg1_3:

    inc iy

mul_reg2_by_reg1_4:

;            msk <<= 1;
    ld a,d
    sla a
    ld d,a

;        }
    dec e
    jr nz,mul_reg2_by_reg1_2

;    }
    dec hl
    dec bc
    ld a,b
    or c
    jr nz,mul_reg2_by_reg1_1

;    memcpy(regmdiv, regmdiv2, NBYTES);
    ld l,(ix+6)
    ld h,(ix+7)         ; IX+6, IX+7: regmdiv2
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    ld bc,NBYTES
    ldir

;    shr_reg(regmdiv,1);
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    ld bc,1
    call shr_reg

;    places = 0;
    ld iy,0

;    //Frac part
;    for (int i = NBYTES_INT; i < NBYTES; i++){
    ld l,(ix+0)
    ld h,(ix+1)         ; IX+0, IX+1: reg1
    ld bc,NBYTES_INT
    add hl,bc
    ld bc, NBYTES - NBYTES_INT

mul_reg2_by_reg1_5:

;        int msk = 128;
    ld d,128

;        for (int j = 0; j < 8; j++){
    ld e,8

mul_reg2_by_reg1_6:

;            if (reg1[i] & msk){
    ld a,(hl)
    and d
    jr z,mul_reg2_by_reg1_7

    push bc
    push de
    push hl

;                shr_reg(regmdiv,places);
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    ld b,iyh
    ld c,iyl            ; BC <- IY = 'places'
    call shr_reg

;                add_reg2_to_reg1(reg2, regmdiv);
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: reg2
    ld l,(ix+4)
    ld h,(ix+5)         ; IX+4, IX+5: regmdiv
    call add_reg2_to_reg1

    pop hl
    pop de
    pop bc

;                places = 1;
    ld iy,1
    jr mul_reg2_by_reg1_8
;            }
;            else
;                places++;
mul_reg2_by_reg1_7:

    inc iy

mul_reg2_by_reg1_8:

;            msk >>= 1;
    ld a,d
    srl a
    ld d,a

;        }
    dec e
    jr nz, mul_reg2_by_reg1_6

;    }
    inc hl
    dec bc
    ld a,b
    or c
    jr nz,mul_reg2_by_reg1_5

mul_reg2_by_reg1_end:

    ld hl,0x0008+2*NBYTES    ; Frees 8 bytes + 2 buffers
    add hl,sp
    ld sp,hl
    pop ix
    ret

;///////////////////////////////////////////////////////////////////////////////
;   mul_acc_by_reg
;   void mul_acc_by_reg(const uint8_t *reg);
;   Parameters:
;     HL: reg
;   Returns: Nothing
;   Affects: BC DE HL AF IY BC' DE' HL' AF'
mul_acc_by_reg:

;    mul_reg2_by_reg1(reg, acc);
    ld de,acc
    call mul_reg2_by_reg1
    ret

;///////////////////////////////////////////////////////////////////////////////
;   mul_reg_10
;   void mul_reg_10(uint8_t *reg);
;   Parameters:
;     DE: reg
;   Returns: Nothing
;   Affects: BC DE HL AF IY BC' DE' HL' AF'
mul_reg_10:

    push ix
    ld ix,0xFFF8-NBYTES    ; Allocates 8 bytes + buffer
    add ix,sp
    ld sp,ix

    ld (ix+0),e
    ld (ix+1),d         ; IX+0, IX+1: reg

;    uint8_t regmdiv[NBYTES];
    ld c,ixl
    ld b,ixh            ; Copia IX em BC
    ld HL,8
    add hl,bc
    ld (ix+4),l
    ld (ix+5),h         ; IX+4, IX+5: regmdiv

;    memcpy(regmdiv, reg, NBYTES);
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    ld l,(ix+0)
    ld h,(ix+1)         ; IX+0, IX+1: reg
    ld bc,NBYTES
    ldir

;    shl_reg(reg, 1);
    ld e,(ix+0)
    ld d,(ix+1)         ; IX+0, IX+1: reg
    ld bc,1
    call shl_reg

;    shl_reg(regmdiv, 3);
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    ld bc,3
    call shl_reg

;    add_reg2_to_reg1(reg,regmdiv);
    ld e,(ix+0)
    ld d,(ix+1)         ; IX+0, IX+1: reg
    ld l,(ix+4)
    ld h,(ix+5)         ; IX+4, IX+5: regmdiv
    call add_reg2_to_reg1

    ld hl,0x0008+NBYTES    ; Frees 8 bytes + buffer
    add hl,sp
    ld sp,hl
    pop ix
    ret

;///////////////////////////////////////////////////////////////////////////////
;   compare
;   int compare (const uint8_t *reg1, const uint8_t *reg2);
;   Parameters:
;     HL: reg1
;     DE: reg2
;   Returns: Flags: Z:        reg1 = reg2
;                   NZ e C:   reg1 < reg2
;                   NC e NC:  reg1 > reg2
;   Affects: BC DE HL AF
compare:

;    for (int i = 0; i < NBYTES; i++){
    ld bc,NBYTES

compare_1:

;        if (reg1[i] < reg2[i]) return -1;   // reg1 < reg2
;        if (reg1[i] > reg2[i]) return 1;    // reg1 > reg2
;    }

    ld a,(de)
    cpi
    jr nz,compare_2
    inc de
    jp pe,compare_1

;    return 0;   // Same value
    xor a
    ret

compare_2:
    dec hl
    cp (hl)
    ccf
    ret

;///////////////////////////////////////////////////////////////////////////////
;   iszero
;   int iszero (const uint8_t *reg);
;   Parameters:
;     HL: reg
;   Returns: Flags: Z:        reg = 0
;                   NZ:       reg1 != 0
;   Affects: BC DE HL AF
iszero:

;    for (int i = 0; i < NBYTES; i++){
    ld bc,NBYTES
    xor a

iszero_1:

;        if (reg[i]) return 0;   // nonzero
    cpi
    ret nz

;    }
    jp pe,iszero_1

;    return 1;   // Is zero
    xor a
    ret

;///////////////////////////////////////////////////////////////////////////////
;   div_reg2_by_reg1
;   int div_reg2_by_reg1(const uint8_t *reg1, uint8_t *reg2);
;   Parameters:
;     HL: reg1
;     DE: reg2
;   Returns: Flags: Z:        Div OK
;                   NZ:       Div Error
;   Affects: BC DE HL AF IY BC' DE' HL' AF'
div_reg2_by_reg1:

    push ix
    ld ix,0xFFF6-3*NBYTES    ; Allocates 10 bytes + 3 buffers
    add ix,sp
    ld sp,ix

    ld (ix+0),l
    ld (ix+1),h         ; IX+0, IX+1: reg1
    ld (ix+2),e
    ld (ix+3),d         ; IX+2, IX+3: reg2

;    uint8_t regmdiv[NBYTES];
    ld c,ixl
    ld b,ixh            ; Copia IX em BC
    ld HL,10
    add hl,bc
    ld (ix+4),l
    ld (ix+5),h         ; IX+4, IX+5: regmdiv

;    uint8_t regmdiv2[NBYTES];
    ld bc,NBYTES
    add hl,bc
    ld (ix+6),l
    ld (ix+7),h         ; IX+6, IX+7: regmdiv2

;    if (iszero(reg1)) return -1; // Divide by zero
    ld l,(ix+0)
    ld h,(ix+1)         ; IX+0, IX+1: reg
    call iszero
    jr nz, div_reg2_by_reg1_1
    ld a,0xff
    jp div_reg2_by_reg1_end

div_reg2_by_reg1_1:

;    int res = compare (reg2, reg1);
;    if (res == 0){   // iguais
;        zero_reg(reg2);
;        set_bit_reg_int(reg2, 0);    //1
;        return 0;   //ok
;    }
    ld l,(ix+0)
    ld h,(ix+1)         ; IX+0, IX+1: reg1
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: reg2
    call compare
    jr nz, div_reg2_by_reg1_2

    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: reg2
    call zero_reg
    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: reg2
    ld bc,0
    call set_bit_reg_int
    xor a
    jp div_reg2_by_reg1_end

div_reg2_by_reg1_2:

;    uint8_t regquot[NBYTES];
    ld bc,NBYTES
    ld l,(ix+6)
    ld h,(ix+7)         ; IX+6, IX+7: regmdiv2
    add hl,bc
    ld (ix+8),l
    ld (ix+9),h         ; IX+8, IX+9: regquot

;    zero_reg(regquot);
    ;ld l,(ix+8)
    ;ld h,(ix+9)         ; IX+8, IX+9: regquot
    call zero_reg

;    memcpy(regmdiv, reg1, NBYTES);
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    ld l,(ix+0)
    ld h,(ix+1)         ; IX+0, IX+1: reg1
    ld bc,NBYTES
    ldir

;    memcpy(regmdiv2, reg1, NBYTES);
    ld e,(ix+6)
    ld d,(ix+7)         ; IX+6, IX+7: regmdiv2
    ld l,(ix+0)
    ld h,(ix+1)         ; IX+0, IX+1: reg1
    ld bc,NBYTES
    ldir

;    for (;!iszero(reg2);){
div_reg2_by_reg1_3:

    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: reg2
    call iszero
    jp z, div_reg2_by_reg1_5

;        int res = compare (reg2, regmdiv);
    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: reg2
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    call compare

;        if (res == -1){ // reg2 < regmdiv
    jp nc, div_reg2_by_reg1_4
    jp z, div_reg2_by_reg1_4

;            int order = 0;
    ld iy,0

;            for (;!iszero(reg2);){
div_reg2_by_reg1_3a:

    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: reg2
    call iszero
    jr z, div_reg2_by_reg1_3b

;                if (compare(reg2, regmdiv) < 0){ //reg2 < regmdiv

    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: reg2
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    call compare
    jr nc, div_reg2_by_reg1_3c
    jr z, div_reg2_by_reg1_3c

;                    shr_reg(regmdiv, 1);
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    ld bc,1
    call shr_reg

;                    order++;
    inc iy
;                    if (order >= NBITS_FRAC){
;                        memcpy(reg2, regquot, NBYTES);
;                        return 0;
;                    }
    ld d,iyh
    ld e,iyl
    ex de,hl
    ld de,NBITS_FRAC
    xor a
    sbc hl,de
    jr nc, div_reg2_by_reg1_3b

;                   continue;
    jr div_reg2_by_reg1_3a
;                }

div_reg2_by_reg1_3c:

;                sub_reg2_from_reg1(reg2, regmdiv);
    ld l,(ix+4)
    ld h,(ix+5)         ; IX+0, IX+1: regmdiv
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: reg2
    call sub_reg2_from_reg1

;                set_bit_reg(regquot, NBITS_FRAC - order);
    ld hl,NBITS_FRAC
    ld c,iyl
    ld b,iyh
    xor a
    sbc hl,bc
    ld c,l
    ld b,h
    ld l,(ix+8)
    ld h,(ix+9)         ; IX+8, IX+9: regquot
    call set_bit_reg

;            }
    jp div_reg2_by_reg1_3a

div_reg2_by_reg1_3b:

;            memcpy(reg2, regquot, NBYTES);
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: reg2
    ld l,(ix+8)
    ld h,(ix+9)         ; IX+8, IX+9: regquot
    ld bc,NBYTES
    ldir

;            return 0;
    xor a
    jp div_reg2_by_reg1_end

;        }
;        else{   // reg2 >= regmdiv

div_reg2_by_reg1_4:

;            int order = 0;
    ld iy,0

;            for (;;){
div_reg2_by_reg1_4a:

;                if (compare(reg2, regmdiv) < 0){ //reg2 < regmdiv
;                    break;
;                }
    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: reg2
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    call compare
    jr c, div_reg2_by_reg1_4b

;                shl_reg(regmdiv, 1);
    ld bc,1
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    call shl_reg

;                if (compare(reg2, regmdiv) < 0){ //reg2 < regmdiv
;                    break;
;                }
    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: reg2
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    call compare
    jr c, div_reg2_by_reg1_4b

;                order++;
    inc iy

;            }
    jr div_reg2_by_reg1_4a

div_reg2_by_reg1_4b:

;            memcpy(regmdiv, regmdiv2, NBYTES);
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    ld l,(ix+6)
    ld h,(ix+7)         ; IX+6, IX+7: regmdiv2
    ld bc,NBYTES
    ldir

;            shl_reg(regmdiv, order);
    ld c,iyl
    ld b,iyh
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    call shl_reg

;            sub_reg2_from_reg1(reg2, regmdiv);
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: reg2
    ld l,(ix+4)
    ld h,(ix+5)         ; IX+4, IX+5: regmdiv
    call sub_reg2_from_reg1

;            set_bit_reg_int(regquot, order);
    ld l,(ix+8)
    ld h,(ix+9)         ; IX+8, IX+9: regquot
    ld c,iyl
    ld b,iyh
    call set_bit_reg_int

;            memcpy(regmdiv, regmdiv2, NBYTES);
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regmdiv
    ld l,(ix+6)
    ld h,(ix+7)         ; IX+6, IX+7: regmdiv2
    ld bc,NBYTES
    ldir

;        }
;    }
    jp div_reg2_by_reg1_3

div_reg2_by_reg1_5:

;    memcpy(reg2, regquot, NBYTES);
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: reg2
    ld l,(ix+8)
    ld h,(ix+9)         ; IX+8, IX+9: regquot
    ld bc,NBYTES
    ldir

;    return 0;
    xor a

div_reg2_by_reg1_end:

    ld hl,0x000A+3*NBYTES    ; Frees 10 bytes + 3 buffers
    add hl,sp
    ld sp,hl
    pop ix
    or a
    ret

;///////////////////////////////////////////////////////////////////////////////
;   div_acc_by_reg
;   int div_acc_by_reg(const uint8_t *reg)
;   Parameters:
;     HL: reg
;   Returns: Flags: Z:        Div OK
;                   NZ:       Div Error
;   Affects: BC DE HL AF IY BC' DE' HL' AF'
div_acc_by_reg:

    ;return div_reg2_by_reg1(reg, acc);
    ld de,acc
    jp div_reg2_by_reg1

;///////////////////////////////////////////////////////////////////////////////
;   print_int_part
;   void print_int_part(const uint8_t *reg);
;   Parameters:
;     HL: reg
;   Returns: Nothing
;   Affects: BC DE HL AF
print_int_part_digit:

    ld e,0
    xor a

print_int_part_digit_0:

    sbc hl,bc
    jr z,print_int_part_digit_2b
    jr c,print_int_part_digit_2a
    inc e
    jr print_int_part_digit_0

print_int_part_digit_2a:
    add hl,bc
    jr print_int_part_digit_2

print_int_part_digit_2b:
    inc e

print_int_part_digit_2:

    ld a,e
    or a
    jr nz,print_int_part_digit_3

    bit 0,d
    ret z

print_int_part_digit_3:

    ld d,1
    add a,'0'
    rst 08h
    ret

print_int_part:

    ld b,(hl)
    inc hl
    ld c,(hl)
    ld l,c
    ld h,b

    ld d,0
    ld bc,10000
    call print_int_part_digit
    ld bc,1000
    call print_int_part_digit
    ld bc,100
    call print_int_part_digit
    ld bc,10
    call print_int_part_digit
    ;ld bc,1
    ;call print_int_part_digit
    ld a,l
    add a,'0'
    rst 08h
    ret

;///////////////////////////////////////////////////////////////////////////////
;   print_bc
;   Internal function for debugging
;   Parameters:
;     BC: value to print
;   Returns: Nothing
;   Affects: BC DE HL AF
print_bc:

    ld l,c
    ld h,b

    ld d,0
    ld bc,10000
    call print_int_part_digit
    ld bc,1000
    call print_int_part_digit
    ld bc,100
    call print_int_part_digit
    ld bc,10
    call print_int_part_digit
    ld a,l
    add a,'0'
    rst 08h
    ret

;///////////////////////////////////////////////////////////////////////////////
;   print_reg_decimal
;   void print_reg_decimal(const uint8_t *reg, int nplaces);
;   Parameters:
;     HL: reg
;     BC: nplaces
;   Returns: Nothing
;   Affects: BC DE HL AF
print_reg_decimal:

    push ix
    ld ix,0xFFF8-NBYTES    ; Allocates 8 bytes + buffer
    add ix,sp
    ld sp,ix
    ld (ix+0),l
    ld (ix+1),h         ; IX+0, IX+1: reg

    ;uint8_t regtmp[NBYTES];
    ld e,ixl
    ld d,ixh            ; Copia IX em DE
    ld HL,8
    add hl,de
    ld (ix+2),l
    ld (ix+3),h         ; IX+2, IX+3: regtmp

;    print_int_part(reg);
;    printf(".");
    ld l,(ix+0)
    ld h,(ix+1)         ; IX+0, IX+1: reg
    push hl
    push bc
    call print_int_part
    pop bc
    ld a,'.'
    rst 08h
    pop hl

;    memcpy(regtmp, reg, NBYTES);
    push bc

    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: regtmp
    ld bc,NBYTES
    ldir

    pop bc

    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: regtmp

;    if (nplaces)
;        ++nplaces;
    ld a,b
    or c
    jr z, print_reg_decimal_1
    inc bc

print_reg_decimal_1:

;    for (;;){
;        if (nplaces){
    ld a,b
    or c
    jr z, print_reg_decimal_2

;            --nplaces;
    dec bc
;            if (!nplaces)
;                break;
    ld a,b
    or c
    jr z, print_reg_decimal_3
;        }

print_reg_decimal_2:

;        memset(regtmp,0,NBYTES_INT);
    xor a
    ld (hl),a
    inc hl
    ld (hl),a
    dec hl

;        if (iszero(regtmp)) break;
    push bc
    push hl
    call iszero
    pop hl
    pop bc
    jr z, print_reg_decimal_3

;        mul_reg_10(regtmp);
    push bc
    push hl
    ld e,l
    ld d,h
    call mul_reg_10
    pop hl
    pop bc

;        print_int_part(regtmp);
    inc hl
    ld a,(hl)
    dec hl
    add a,'0'
    rst 08h

;    }
    jr print_reg_decimal_1

print_reg_decimal_3:
print_reg_decimal_end:

    ld hl,0x0008+NBYTES    ; Frees 8 bytes + buffer
    add hl,sp
    ld sp,hl
    pop ix
    ret

;///////////////////////////////////////////////////////////////////////////////
;   println_reg_decimal
;   void println_reg_decimal(const uint8_t *reg, int nplaces);
;   Parameters:
;     HL: reg
;     BC: nplaces
;   Returns: Nothing
;   Affects: BC DE HL AF
println_reg_decimal:

    call print_reg_decimal
    call print_crlf
    ret

;///////////////////////////////////////////////////////////////////////////////
;   test_pi_bbp
;   void test_pi_bbp(void); // Bailey-Borwein-Plouffe
;   Parameters: Nothing
;   Returns: Nothing
;   Affects: BC DE HL AF
test_pi_bbp:

    push ix
    ld ix,0xFFF6-3*NBYTES    ; Allocates 10 bytes + 3 buffers
    add ix,sp
    ld sp,ix

;    uint8_t regtotal[NBYTES];
    ld c,ixl
    ld b,ixh            ; IX -> BC
    ld HL,10
    add hl,bc
    ld (ix+0),l
    ld (ix+1),h         ; IX+0, IX+1: regtotal

;    uint8_t regsubtotal[NBYTES];
    ld bc,NBYTES
    add hl,bc
    ld (ix+2),l
    ld (ix+3),h         ; IX+2, IX+3: regsubtotal

;    uint8_t regden[NBYTES];
    ;ld bc,NBYTES
    add hl,bc
    ld (ix+4),l
    ld (ix+5),h         ; IX+4, IX+5: regden

;    zero_reg(regtotal);
    ld l,(ix+0)
    ld h,(ix+1)         ; IX+0, IX+1: regtotal
    call zero_reg

;    for (int k = 0; k < 10000; k++){
    ld bc,0

test_pi_bbp_1:

    ld (ix+6),c
    ld (ix+7),b         ; IX+6, IX+7: k

    ld a,b
    cp NUM_IT >> 8
    jr c, test_pi_bbp_1a

    ld a,c
    cp NUM_IT & 0xFF
    jr c, test_pi_bbp_1a

    jp test_pi_bbp_2

test_pi_bbp_1a:

;        zero_reg(regsubtotal);
    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: regsubtotal
    call zero_reg

;        zero_reg(regden);
    ld l,(ix+4)
    ld h,(ix+5)         ; IX+4, IX+5: regden
    push hl
    call zero_reg
    pop de              ; DE contém regden

;        load_reg_int(regden,8*k+1);     // Sets 8k+1
    ld l,(ix+6)
    ld h,(ix+7)         ; IX+6, IX+7: k
    sla l
    rl h
    sla l
    rl h
    sla l
    rl h
    inc hl
    call load_reg_int   ; DE is correct here

;        zero_reg(acc);
    ld hl,acc
    call zero_reg

;        set_bit_reg_int(acc, 2);        // Sets with 4
    ld hl,acc
    ld bc,2
    call set_bit_reg_int

;        div_acc_by_reg(regden);
    ld l,(ix+4)
    ld h,(ix+5)         ; IX+4, IX+5: regden
    call div_acc_by_reg

;        add_reg2_to_reg1(regsubtotal,acc);
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: regsubtotal
    ld hl,acc
    call add_reg2_to_reg1

;        inc_reg_int8(regden, 3);        // 8k+4
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regden
    ld a,3
    call inc_reg_int8

;        zero_reg(acc);
    ld hl,acc
    call zero_reg

;        set_bit_reg_int(acc, 1);        // Sets with 2
    ld hl,acc
    ld bc,1
    call set_bit_reg_int

;        div_acc_by_reg(regden);
    ld l,(ix+4)
    ld h,(ix+5)         ; IX+4, IX+5: regden
    call div_acc_by_reg

;        sub_reg2_from_reg1(regsubtotal,acc);
    ld hl,acc
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: regsubtotal
    call sub_reg2_from_reg1

;        inc_reg_int8(regden, 1);        // 8k+5
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regden
    ld a,1
    call inc_reg_int8

;        zero_reg(acc);
    ld hl,acc
    call zero_reg

;        set_bit_reg_int(acc, 0);        // Sets with 1
    ld hl,acc
    ld bc,0
    call set_bit_reg_int

;        div_acc_by_reg(regden);
    ld l,(ix+4)
    ld h,(ix+5)         ; IX+4, IX+5: regden
    call div_acc_by_reg

;        sub_reg2_from_reg1(regsubtotal,acc);
    ld hl,acc
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: regsubtotal
    call sub_reg2_from_reg1

;        inc_reg_int8(regden, 1);        // 8k+6
    ld e,(ix+4)
    ld d,(ix+5)         ; IX+4, IX+5: regden
    ld a,1
    call inc_reg_int8

;        zero_reg(acc);
    ld hl,acc
    call zero_reg

;        set_bit_reg_int(acc, 0);        // Sets with 1
    ld hl,acc
    ld bc,0
    call set_bit_reg_int

;        div_acc_by_reg(regden);
    ld l,(ix+4)
    ld h,(ix+5)         ; IX+4, IX+5: regden
    call div_acc_by_reg

;        sub_reg2_from_reg1(regsubtotal,acc);
    ld hl,acc
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: regsubtotal
    call sub_reg2_from_reg1

;        shr_reg(regsubtotal, 4*k);
    ld e,(ix+2)
    ld d,(ix+3)         ; IX+2, IX+3: regsubtotal
    ld c,(ix+6)
    ld b,(ix+7)         ; IX+6, IX+7: k
    sla c
    rl b
    sla c
    rl b
    call shr_reg

;        add_reg2_to_reg1(regtotal, regsubtotal);
    ld e,(ix+0)
    ld d,(ix+1)         ; IX+0, IX+1: regtotal
    ld l,(ix+2)
    ld h,(ix+3)         ; IX+2, IX+3: regsubtotal
    call add_reg2_to_reg1

;;        if (!(k % 10)){
;;            printf("%5d: ",k);
;;            print_reg_decimal(regtotal, 120);
;;            int places_ok = compare_digits_to_pi(regtotal);
;;            printf(" (%d)\n",places_ok);
;;            if (places_ok >= 1000) return;
;;        }
;            print_reg_decimal(regtotal, 120);
    call prints
    db "TOTAL:",0
    ld l,(ix+0)
    ld h,(ix+1)         ; IX+0, IX+1: regtotal
    ld bc,NUM_DECS
    call println_reg_decimal

;    }
    ld c,(ix+6)
    ld b,(ix+7)         ; IX+6, IX+7: k
    inc bc
    ;ld (ix+6),c
    ;ld (ix+7),b         ; IX+6, IX+7: k

    jp test_pi_bbp_1

test_pi_bbp_2:
test_pi_bbp_end:

    ld hl,0x000A+3*NBYTES    ; Frees 10 bytes + 3 buffers
    add hl,sp
    ld sp,hl
    pop ix
    ret

;///////////////////////////////////////////////////////////////////////////////
;   _main
;   void _main(void);
;   Parameters: Nothing
;   Returns: Nothing
;   Affects: BC DE HL AF IY BC' DE' HL' AF'
_main:

    call test_pi_bbp
    ret

;///////////////////////////////////////////////////////////////////////////////
    seek RAMBASE
    org RAMBASE

acc:    ds NBYTES   ; The only global variable, to make things a bit easier.

    end
