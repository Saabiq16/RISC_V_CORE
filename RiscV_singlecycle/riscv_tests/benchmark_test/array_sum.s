.section .text
.globl _start

_start:
    # Initialize array of 5 values at addresses 0, 4, 8, 12, 16
    addi x1, x0, 10          # value 1
    addi x2, x0, 20            # value 2
    addi x3, x0, 30              # value 3
    addi x4, x0, 40                # value 4
    addi x5, x0, 50                  # value 5

    sw x1, 0(x0)
    sw x2, 4(x0)
    sw x3, 8(x0)
    sw x4, 12(x0)
    sw x5, 16(x0)

    # Sum loop: 5 elements, base address 0, stride 4
    addi x6, x0, 0            # x6 = accumulator (sum)
    addi x7, x0, 0              # x7 = array index / byte offset
    addi x8, x0, 5                 # x8 = remaining count

sum_loop:
    lw   x9, 0(x7)             # load array[i]  <- LOAD-USE dependency starts here
    add  x6, x6, x9               # sum += array[i]   <- uses x9 IMMEDIATELY next instruction
    addi x7, x7, 4                  # advance byte offset by 4 (word stride)
    addi x8, x8, -1                    # count--
    bne  x8, x0, sum_loop                 # loop while count != 0

done:
    jal x0, done