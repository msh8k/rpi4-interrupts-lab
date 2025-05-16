/***************************************************************/
/* Filename: uart.s                                            */
/* Version/Date: 1.4/4 June 2020	                           */
/* Written by: David L. Tarnoff                                */
/* Modified by: Matthew S. Harrison							   */
/* Description:                                                */
/* This file contains basic string output operations for the   */
/* Raspberry Pi 4 ARM/Broadcom uart.  These functions include: */
/* C Prototypes:                                               */
/*   extern void uartInit(void);                               */
/*   extern void uartSend(char);                               */
/*   extern void hexCharOut(unsigned int);                     */
/*   extern void outputR0(unsigned int);                       */
/*   extern void outputString(char *);                         */
/*   extern void crlf(void);                                   */
/*   extern void debugDisplay(char, char);                     */
/*                                                             */
/* uartInit:     initializes the built-in serial port to the   */
/*               following settings:                           */
/*               -Baud rate: 115200                            */
/*               -Data: 8 bit                                  */
/*               -Parity: none                                 */
/*               -Stop: 1 bit                                  */
/*               -Flow control: none                           */
/* uartSend:     receives in r0 an ASCII character to send out */
/*               the serial port.                              */
/* hexCharOut:   outputs a single hexadecimal digit located in */
/*               the least significant nibble of r0.  It does  */
/*               this by                                       */
/*               1.) stripping away any bits other than the    */
/*                   least sig nibble                          */
/*               2.) adding/or-ing 0x30 to turn 0 through 9    */
/*                   into ASCII                                */
/*               3.) adding an additional 7 to A through F     */
/*                   so they're in ASCII                       */
/*               4.) calling uartSend to output the character  */
/* outputR0:     sends the contents of the register r0 in      */
/*               hexadecimal to the serial port.               */
/* outputString: outputs a zero terminated string starting     */
/*               at the address contained in r0.               */
/* crlf:         simply outputs a carriage return and line feed*/
/* debugDisplay: Outputs the character contained in r0 followed*/
/*               by the character followed in r1, then followed*/
/*               by a ": " to mark a place in the output.      */
/*                                                             */
/* Revision History                                            */
/* 1.1 - Updated memory mapped addresses to reflect change in  */
/*       Broadcom addressing when going to quad-core chip in   */
/*       Raspberry Pi 2 Model B.                               */
/* 1.2 - Moved uartInit to uart.s source code.                 */
/* 1.3 - Added debugDisplay.                                   */
/* 1.4 - Adapted to BCM2711's PL011 (UART0)                    */
/***************************************************************/

/* Base and offset declarations for the general purpose I/O    */
/* configuration registers.                                    */
.equ GPIOBase,         0xFE200000
.equ GPFSEL0_OFFSET,         0x00
.equ GPFSEL1_OFFSET,         0x04
.equ GPFSEL2_OFFSET,         0x08
.equ GPFSEL3_OFFSET,         0x0c
.equ GPFSEL4_OFFSET,         0x10
.equ GPFSEL5_OFFSET,         0x14
.equ GPSET0_OFFSET,          0x1c
.equ GPSET1_OFFSET,          0x20
.equ GPCLR0_OFFSET,          0x28
.equ GPCLR1_OFFSET,          0x2c
.equ GPLEV0_OFFSET,          0x34
.equ GPLEV1_OFFSET,          0x38

/* Base and offset declarations for the auxiliary peripherals  */
/* (including the mini UART) configuration registers.          */
.equ AUX_Base,         0xFE215000
.equ AUX_ENABLES_OFFSET,      0x4
.equ AUX_MU_IO_REG_OFFSET,   0x40
.equ AUX_MU_IER_REG_OFFSET,  0x44
.equ AUX_MU_IIR_REG_OFFSET,  0x48
.equ AUX_MU_LCR_REG_OFFSET,  0x4C
.equ AUX_MU_MCR_REG_OFFSET,  0x50
.equ AUX_MU_LSR_REG_OFFSET,  0x54
.equ AUX_MU_MSR_REG_OFFSET,  0x58
.equ AUX_MU_SCRATCH_OFFSET,  0x5C
.equ AUX_MU_CNTL_REG_OFFSET, 0x60
.equ AUX_MU_STAT_REG_OFFSET, 0x64
.equ AUX_MU_BAUD_REG_OFFSET, 0x68

.globl uartInit
.globl uartSend
.globl hexCharOut
.globl outputR0
.globl outputString
.globl crlf
.globl debugDisplay
.section .text

/* uartInit sets up the Tx and Rx GPIO pins for use with this */
/* code. It requires no parameters and returns no values.     */
uartInit:

/* Write 1 to bit 0 of AUX_ENABLES turns on the UART.         */
    ldr     r0, =AUX_Base
    ldr     r1, =1
    str     r1, [r0, #AUX_ENABLES_OFFSET]

/* Write 0 to AUX_MU_IER_REG. Since interrupts are not used   */
/* for this lab, we will need to write a 0 to this register   */
/* to make sure they are disabled.                            */
    ldr     r1, =0
    str     r1, [r0, #AUX_MU_IER_REG_OFFSET]

/* Write 0 to AUX_MU_CNTL_REG. This will disable both the     */
/* receiver and transmitter so that we can configure them.    */
    ldr     r1, =0
    str     r1, [r0, #AUX_MU_CNTL_REG_OFFSET]

/* Write 3 to AUX_MU_LCR_REG. A 1 in bit position 0 sets our  */
/* data length to 8 bits.                   
    ldr     r1, =3
    str     r1, [r0, #AUX_MU_LCR_REG_OFFSET]

/* Write 0 to AUX_MU_MCR_REG. The only thing we will use this */
/* register for is to clear one of the serial port control    */
/* lines (bit 1 controls RTS).  Therefore, we write a zero to */
/* this register.                                             */
    ldr     r1, =0
    str     r1, [r0, #AUX_MU_MCR_REG_OFFSET]

/* Write 0xC6 to lower 8 bits of AUX_MU_IIR_REG. This sets    */
/* the most significant 8 bits of the baudrate register when  */
/* DLAB = 1.                                                  */
    ldr     r1, =0xC6
    str     r1, [r0, #AUX_MU_IIR_REG_OFFSET]

/* Write 207 to AUX_MU_BAUD_REG. FOR RPI4 ONLY! */
    ldr     r1, =207
    str     r1, [r0, #AUX_MU_BAUD_REG_OFFSET]

/* Now, let's configure GPIO pin 14 as TX (function 010) and  */
/* pin 15 as RX (also function 010). From the "figure" below, */
/* we see that GPIO pin 14 is configured using GPFSEL1 bits   */
/* 12, 13, and 14, and GPIO pin 15 is configured using GPFSEL1*/
/* bits 15, 16, and 17.  For both pins, we need to write 010  */
/* to their configuration bits.  By the way, GPFSEL1 is at    */
/* offset 0x4 from GPIOBASE.                                  */
/*                                                            */
/*               GPFSEL1 Configuration Bits                   */
/*            33222222222211111111110000000000                */
/*            10987654321098765432109876543210                */
/*              \_/\_/\_/\_/\_/\_/\_/\_/\_/\_/                */
/*               1  1  1  1  1  1  1  1  1  1                 */
/*               9  8  7  6  5  4  3  2  1  0                 */
/*                                                            */
/* Bit mask for bits 12, 13, and 14 is                        */
/* 00000000000000000111000000000000 = 0x00007000              */
/* Bit mask for bits 15, 16, and 17 is                        */
/* 00000000000000111000000000000000 = 0x00038000              */
/* Start by loading the value of GPFSEL1 into r2, clear the   */
/* necessary bits using the bic, bit clear, instruction, set  */
/* the necessary bits using a bitwise OR, and then store back */
/* in GPFSEL.                                                 */
    ldr     r0,=GPIOBase
    ldr     r1, [r0, #GPFSEL1_OFFSET]
    bic     r1, r1, #0x2D000
    orr     r1, r1, #0x12000
    str     r1, [r0, #GPFSEL1_OFFSET] 

/* Write 3 to AUX_MU_CNTL_REG. This will ENABLE both the      */
/* receiver and transmitter so that we can use them.          */
    ldr     r0, =AUX_Base
    ldr     r1, =3
    str     r1, [r0, #AUX_MU_CNTL_REG_OFFSET]

/* Now that initialization is complete, return to the calling */
/* function.                                                  */
    bx      lr


/* uartSend receives in r0 an ASCII character to send out the 
serial port.*/
uartSend:
    push    {r4, lr}
    mov     r4, r0

/* First, load the Mini Uart Line Status Register.  If 1 in the bit 5
position of this register (Mask 0x20) tells us if the transmit FIFO 
can accept at least one byte.  We're going to wait here until there
is space in the transmit FIFO.  */
    ldr     r0,=AUX_Base
wait4txempty:
    ldr     r1,[r0, #AUX_MU_LSR_REG_OFFSET]
    tst     r1, #0x20
    beq     wait4txempty

/* Now that we know we have space in the transmit buffer, let's put
a character there to be sent out.  When written to, the least 
significant 8 bits of AUX_MU_IO_REG (when DLAB = 0) are transmit 
data when written to.  Any value written to these bits when DLAB
equals zero is put in the transmit FIFO if it isn't full. */
    mov     r1, r4
    str     r1,[r0, #AUX_MU_IO_REG_OFFSET]

/* That should do it.  Let's restore the registers and get out of
here.*/
    pop     {r4, lr}
    bx      lr

/* hexCharOut outputs a single hexadecimal digit located in the 
least significant nibble of r0.  It does this by
  1.) stripping away any bits other than the least sig nibble
  2.) adding/or-ing 0x30 to turn 0 through 9 into ASCII
  3.) adding an additional 7 to A through F so they're in ASCII
  4.) calling uartSend to output the character
*/
hexCharOut:
    push    {r0, lr}
    and     r0, r0, #0xf;
    orr     r0, r0, #0x30;
    cmp     r0, #0x39
    addgt   r0, r0, #7
    bl      uartSend
    pop     {r0, lr}
    bx      lr

/* outputR0 sends the contents of the register r0 in hexadecimal
to the serial port. */
outputR0:
    push    {r0, r2, r4, lr}

/* Start by making a back up copy of r0 in r1 */
    mov     r4, r0

/* Load r2 with the number of bits in r0.  Each time through, 
this value will be decremented by 4 until there's no more
to shift by. */
    mov     r2, #32

outputNibbleLoop:
/* Decrement shift value by 4 so we output the next nibble */
    sub     r2, r2, #4
/* Restore r0, then shift to the next nibble to output */
    mov     r0, r4
    mov     r0, r0, lsr r2

/* Output next nibble */
    bl      hexCharOut

/* Check to see if this was the last character to output.
This is done by seeing if the last shift was by 0 bits. */
    cmp     r2, #0
    bgt     outputNibbleLoop

/* Restore and get out of here. */
    pop     {r0, r2, r4, lr}
    bx      lr

/* outputString outputs a zero terminated string starting
at the address contained in r0. */
outputString:
    push    {r0, r4, r5, lr}
    mov     r4, r0

/* Get the next character to send to the serial output */
outputNextChar:
    ands    r0, r4, #0x3
    ldreq   r5, [r4]
    mov     r0, r5
    lsr     r5, r5, #8 
    and     r0, r0, #0xff
    
/* If the next character equals zero, we need to leave */
    cmp     r0, #0
    beq     outputStringExit

/* Otherwise, send the character to the output and
incremente out pointer */
    bl      uartSend
    add     r4, r4, #1
    b       outputNextChar

outputStringExit:
    pop     {r0, r4, r5, lr}
    bx      lr
    

/* crlf simply outputs a carriage return and line feed. */
crlf:
    push    {r0, lr}
    mov     r0, #'\n'
    bl      uartSend
    mov     r0, #'\r'
    bl      uartSend
    pop     {r0, lr}
    bx      lr

/* Poor man's debug support.  Send characters in r0 and */
/* r1 and they are outputted preceeding a colon and a   */
/* space.  For example if you intend to output the value*/
/* of the program counter, you might want to run code   */
/* like:                                                */
/*        mov     r0, #'p'                              */
/*        mov     r1, #'c'                              */
/*        bl      debugDisplay                          */
/*        mov     r0, pc                                */
/*        bl      outputR0                              */
/*        bl      crlf                                  */
/* This would output something like this;               */
/* pc: 00080000                                         */
debugDisplay:
    push    {lr}
    push    {r1}
    bl      uartSend
    pop     {r0}
    bl      uartSend
    mov     r0, #':'
    bl      uartSend
    mov     r0, #' '
    bl      uartSend
    pop     {lr}
    bx      lr
