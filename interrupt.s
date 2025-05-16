.global main
.global IRQ_ISR
.equ TIMERBase, 0xFE003000
.equ GICD_CTLR, 0xFF841000
.equ GICC_CTLR, 0xFF842000
.equ GICD_ISENABLER3, 0xFF84110C
.equ GICD_ITARGETSR24, 0xFF841860
.equ GICD_IPRIORITYR24, 0xFF841460
.equ INTERRUPT_SET_ENABLE_REG, 0xFE00B210
.section .text

/* *** WE WANT VC IRQ3 -- TRANSLATES TO SPI ID 99 ON THE GIC-400 *** 
    GICD_ICENABLERn and GICD_ISENABLERn reads present the same information -- write GICD_ISENABLERn bit(s) with 1 to enable corresponding interrupt forwarding. */

main:
	bl		uartInit		@ Initialize the UART
    bl      outputIJTandVectors
    
/* Clear the I-bit (bit 7) in order to enable interrupts globally. */
    mrs r0, CPSR
    bic r0, r0, #0x80
    msr cpsr_c, r0
    
/* Ensure interrupts actually globally enabled. */
    ldr r0, =CPSRAfter
    bl outputString
    mrs r0, CPSR
    bl outputR0
    bl crlf
    
/* Read what is in GICD_CTLR to see if GIC will forward interrupts to processor -- 1 in LSB means enabled. */
    ldr r0, =GICDControl
    bl outputString
    ldr r1, =GICD_CTLR
    ldr r0, [r1]
    bl outputR0
    bl crlf
 
/* Enable GICD_ISENABLER3, bit 3, to enable IRQ3 (SPI 99) forwarding from distributor. */
    mov r0, #0x08
    ldr r1, =GICD_ISENABLER3
    str r0, [r1]
    
/* Read what is in the GICD_ISENABLER3 to see if IRQ3 (SPI 99) being forwarded from distributor. -- 1 in bit three means enabled IRQ3 forwarding. */
    ldr r0, =GICDEnableR3
    bl outputString
    ldr r1, =GICD_ISENABLER3
    ldr r0, [r1]
    bl outputR0
    bl crlf

/* Enable GICD_ITARGETSR24, bit 24, to enable IRQ3 (SPI 99) targetting to processor core 0. */
    mov r0, #0x01000000
    ldr r1, =GICD_ITARGETSR24
    str r0, [r1]

/* Read what is in the GICD_ITARGETSR24 to see if IRQ3 (SPI 99) targetted to correct core (core 0) -- 1 in bit twenty-four means correct targetting. */
    ldr r0, =GICDITargetsR24
    bl outputString
    ldr r1, =GICD_ITARGETSR24
    ldr r0, [r1]
    bl outputR0
    bl crlf

/* Read what is in the GICC_CTLR register to see if processor core will handle interrupts - odd and <= 7 means IRQ mode and enabled interrupt processing. */
    ldr r0, = GICCControl
    bl outputString
    ldr r1, =GICC_CTLR
    ldr r0, [r1]
    bl outputR0
    bl crlf
    
/* Read what is in ARMC IRQ0_SET_EN_0 register to see what is enabled. */
    ldr r0, =IRQ0SETEN0
    bl outputString
    ldr r1, =INTERRUPT_SET_ENABLE_REG
    ldr r0, [r1]
    bl outputR0
    bl crlf

/* Enable the C3 timer interrupt (corresponding to the IRQ3 interrupt). */
    mov r0, #0x08
    ldr r1, =INTERRUPT_SET_ENABLE_REG
    str r0, [r1]
    
/* Read what is in ARMC IRQ0_SET_EN_0 register to see what is enabled. */
    ldr r0, =IRQ0SETEN0
    bl outputString
    ldr r1, =INTERRUPT_SET_ENABLE_REG
    ldr r0, [r1]
    bl outputR0
    bl crlf
    
/* Ensure interrupts actually globally enabled. */
    ldr r0, =CPSRAfter
    bl outputString
    mrs r0, CPSR
    bl outputR0
    bl crlf

/* The next 7 lines are used to set up compare register and clear compare flag	*/
	ldr		r3,=TIMERBase	/* Load r3 with base address of system timer regs	*/
	ldr		r2,[r3,#4]		/* Read low half of free-running timer (offset 0x4)	*/
	add		r2,r2,#0xF4000	/* Add number of ticks equivalent to about 1 second */
	str		r2,[r3,#0x18]	/* Store new value in compare reg. 3 at offset 0x18	*/
	mov		r2,#(1 << 3)	/* Load r2 with mask that will clear M3 at bit 3	*/
	str		r2,[r3]			/* Store r2 to CS to force clear of bit M3			*/

loop:
	b		loop			/* Go output the next character						*/

/******* We are going to insert our IRQ interrupt service routine here. *******/
IRQ_ISR:
/* Save all working registers and link register w/single block store. */
    push {r0-r12,lr}

/* Just send a "bang" to indicate that an interrupt occurred. */
    mov r0, #'!'
    bl uartSend
    
/* Clear/acknowledge interrupt to prepare code for next C3 match. */
    ldr r3,=TIMERBase /* Load r3 with base address of system timer regs */
    ldr r2, [r3] /* Grab a copy of the contents of CS */
    tst r2, #(1 << 3) /* If M3 is set, compare reg. C3 matched counter */
    beq exitISR /* If M3 is not set, exit without outputting bang */    
    mov r2,#(1 << 3) /* Load r2 with mask that will clear M3 at bit 3 */
    str r2,[r3] /* Store r2 to CS to force clear of bit M3 */
    
/* Add another 0x100000 to the C3 compare register. */
    ldr r2, [r3,#4]
    add r2, r2, #0x100000
    str r2, [r3,#0x18]

/* Restore working registers and link register w/single block load */
exitISR:
    pop {r0-r12,lr}
    
/* Adjust link register and store result in program counter to go back to */
/* halted code. Note that this command is special in that it also restores */
/* the mode by replacing CPSR with its pre-interrupt condition. */
    subs pc, lr, #4

/************************* outputIJTandVectors Function *************************/
/* outputIJTandVectors is a convenience function allowing us to output to the */
/* serial port a formatted version of what is contained in the interrupt jump */
/* table. Since the Raspberry Pi model is to create a vector table after the */
/* jump table, this function also outputs the 8 32-bit vectors that are stored */
/* after the jump table. */
/********************************************************************************/
outputIJTandVectors:
    push {r0, r4, lr}
/* We should be professional and output a header for our table. */
    ldr r0, =IJTHeader
    bl outputString
/* Load the starting address for the interrupt jump table, i.e., 0. */
    ldr r4, =0x0000
/* One location at a time, output the address, a colon, a space, then the */
/* contents of that memory address. We also output a carriage return and line */
/* feed before going to the next address. */
outputNextLocation:
    mov r0, r4
    bl outputR0
    mov r0, #':'
    bl uartSend
    mov r0, #' '
    bl uartSend
    ldr r0, [r4]
    bl outputR0
    bl crlf
/* Move pointer so that it is pointing to the next memory location, then check */
/* to see if we have gone past the end of the vectors. If we have not, then loop*/
/* back up to output the next row. */
    add r4, r4, #4
    cmp r4, #0x40
    blt outputNextLocation
/* Restore everything and get out of here. */
    pop {r0, r4, lr}
    mov pc, lr
/********************* End of outputIJTandVectors Function **********************/
.section .rodata
/*** Zero-terminated string acting as header for Interrupt Jump Table output. ***/
IJTHeader:
    .string " Address Contents\n\r"
    .long 0
CPSRAfter:
    .string " What CPSR contains after global interrupt enable: \x00\x00\x00\x00"
GICDControl:
    .string " What GICD_CTLR currently holds: \x00\x00"
GICCControl:
    .string " What GICC_CTLR currently holds: \x00\x00"
GICDEnableR3:
    .string " What GICD_ISENABLER3 is showing currently: \x00\x00\x00"
GICDITargetsR24:
    .string " What GICD_ITARGETSR24 is showing currently: \x00\x00"
IRQ0SETEN0:
    .string " What ARMC IRQ0_SET_EN_0 currently contains: \x00"
