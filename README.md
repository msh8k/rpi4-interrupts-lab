# Raspberry Pi 4 Interrupt Service Routines Lab
This was a lab offered in a computer architecture course at ETSU to teach students how to program an interrupt service routine (ISR) in a baremetal context--in this case, against a Raspberry Pi 4.

My major contribution was programming the (new to the RPI4 / BCM2711) GIC400 to properly route timer interrupts to the ARM core the baremetal application was executing against. If I recall correctly, prior RPI platforms (e.g., BCM2835 and BCM2836) handled interrupt routing on the Broadcom side (maybe in the VideoCore? A status register was populated on each core to signal an interrupt went off).

(Major) hat tips to David Welch for his Raspberry Pi bootloader and David Tarnoff for designing and implementing the BCM2835/2836 versions of this lab.
