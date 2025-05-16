.globl _start
.section .init

_start:
    ldr pc,reset_handler
    ldr pc,undefined_handler
    ldr pc,swi_handler
    ldr pc,prefetch_handler
    ldr pc,data_handler
    ldr pc,hyp_handler
    ldr pc,irq_handler
    ldr pc,fiq_handler
reset_handler:      .word reset
undefined_handler:  .word hang
swi_handler:        .word smc
prefetch_handler:   .word hang
data_handler:       .word hang
hyp_handler:        .word hang
irq_handler:        .word IRQ_ISR
fiq_handler:        .word hang

reset:
    mrs r0,cpsr
    bic r0,r0,#0x1F
    orr r0,r0,#0x13
    msr spsr_cxsf,r0
    add r0,pc,#4
    msr ELR_hyp,r0
    eret

skip:

    mrc p15, 0, r1, c12, c0, 0 ;@ get vbar
    mov r0,#0x8000
    ldmia r0!,{r2,r3,r4,r5,r6,r7,r8,r9}
    stmia r1!,{r2,r3,r4,r5,r6,r7,r8,r9}
    ldmia r0!,{r2,r3,r4,r5,r6,r7,r8,r9}
    stmia r1!,{r2,r3,r4,r5,r6,r7,r8,r9}

    mov r12,#0
    mcr p15, 0, r12, c7, c10, 1
    dsb
    mov r12, #0
    mcr p15, 0, r12, c7, c5, 0
    mov r12, #0
    mcr p15, 0, r12, c7, c5, 6
    dsb
    isb
    smc #0

    mrc p15,0,r2,c1,c0,0
    bic r2,#0x1000
    bic r2,#0x0004
    mcr p15,0,r2,c1,c0,0

/* Place ARM in IRQ mode, then put the stack pointer at 0x8000.*/
    mov r0,#0xd2
    msr cpsr_c,r0
    mov sp,#0x8000

/* Place ARM in supervisor mode, then load sp with 0x8000000. */
    mov r0,#0xd3
    msr cpsr_c,r0
    mov sp,#0x8000000

    mov r0,pc
    bl main
hang: b hang

smc:
    mrc p15, 0, r1, c1, c1, 0
    bic r1, r1, #1
    mcr p15, 0, r1, c1, c1, 0
    movs    pc, lr
