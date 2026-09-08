.section .text
.globl _start

_start:
    addi x1, x0, 0        # x1 = fib(0) = 0
    addi x2, x0, 1          # x2 = fib(1) = 1
    addi x3, x0, 10           # x3 = loop counter (compute 10 more terms)

fib_loop:
    add  x4, x1, x2       # x4 = next fib value
    addi x1, x2, 0          # x1 = x2 (shift)
    addi x2, x4, 0            # x2 = x4 (shift)
    addi x3, x3, -1              # counter--
    bne  x3, x0, fib_loop           # loop while counter != 0

done:
    jal x0, done              # explicit DONE marker -- deterministic completion point