```
 ____ ___ ____    _    _     ____     ________   ___  
|  _ \_ _/ ___|  / \  | |   / ___|   |__  ( _ ) / _ \ 
| |_) | | |     / _ \ | |  | |   _____ / // _ \| | | |
|  __/| | |___ / ___ \| |__| |__|_____/ /| (_) | |_| |
|_|  |___\____/_/   \_\_____\____|   /____\___/ \___/ 
```                                                       

![Banner](https://repository-images.githubusercontent.com/806794224/33ef9e2e-9f8a-400b-9a47-7b4fd8e0ea4f)

## Project

PICALC-Z80

## Description

A calculator that yields an arbitrary number of digits of the number PI.

## Target

Any Z80-based computer/emulator. Details of memory allocation and stack
positioning must be adjusted for the specifics of the target. In addition,
INT 08h is used as a function call to print character over TTY (Reg A = 
character), which implementation has to be adjusted to the target.

## Compiler to build this project

[Bas Wijnen \<wijnen@debian.org\>'s z80asm](https://manpages.ubuntu.com/manpages/trusty/man1/z80asm.1.html)

Other compilers/assemblers may require minor changes in the source code.

## Usage

The desired amount of PI digits is defined in the macro **NUM_DECS**. Default
value is 100. Note that incrementing this value will increase RAM usage
proportionally, and the needed CPU cycles quadratically. Don't change the
other algorithm constants unless you really know what you are doing.

The algorithm was validated for 1,000 digits of PI, all of them checked
against the generally known published digits. For an actual Z80, yielding
this number of digits may prove to be a daunting task, especially because
of the gigantic number of CPU cycles needed (RAM is a lesser problem in
this regard). 100 digits is way more practical amount, unless you have A
LOT of time to spare.

The main loop iteracts as many times as needed to calculate all the
decimal places requested (the number of iterations / number of digits have
a ratio close to 0.9). With each iteration the message 'TOTAL:' is printed
along the PI approximation calculated so far.

## Version & Date
1.0 - 2024-MAY-27

## Author
Milton Maldonado Jr (ARM_Coder)

## License
GPL V2

## Disclaimer
This code is supplied 'as is' with no warranty against bugs. It was tested
on a Z80 simulator that **I** wrote (haha), so it was not tested against any
actual, validated target.

## Note
Along the ASM source, you will see some commented 'C' statemens. The
project was initially built and tested in C, and then hand-translated
to Z80 ASM.

## Note 2
I hope this is my **last** ASM project ever. Writing code in ASM is a real
PITA, but this project was a challenge I've set for me.

## Funny note
This project implements the *Bailey-Borwein-Plouffe* method of calculating
PI. This method is much, much faster that the classic Euler series.
The funny thing is that the method was discovered (invented?) in 1995,
when the Z80 had already passed its heyday and was fading into a niche,
retro platform.

