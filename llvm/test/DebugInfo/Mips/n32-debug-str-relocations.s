# RUN: llvm-mc -triple=mips64-linux-gnuabin32 -target-abi=n32 -filetype=obj %s -o %t.o
# RUN: llvm-dwarfdump --debug-info %t.o | FileCheck %s
# RUN: llvm-mc -triple=mips64el-linux-gnuabin32 -target-abi=n32 -filetype=obj %s -o %t.o
# RUN: llvm-dwarfdump --debug-info %t.o | FileCheck %s
# RUN: llvm-mc -triple=mips-linux-gnu -target-abi=o32 -filetype=obj %s -o %t.o
# RUN: llvm-dwarfdump --debug-info %t.o | FileCheck %s
# RUN: llvm-mc -triple=mipsel-linux-gnu -target-abi=o32 -filetype=obj %s -o %t.o
# RUN: llvm-dwarfdump --debug-info %t.o | FileCheck %s

# N32 stores the string offset in the RELA addend. O32 stores it at the
# relocation site. Discarding either contribution selects the first string.
# CHECK: DW_TAG_compile_unit
# CHECK: DW_AT_name ("Packet.c")

.section .debug_abbrev,"",@progbits
.Labbrev:
.byte 1, 0x11, 0 # DW_TAG_compile_unit, no children
.byte 3, 0x0e    # DW_AT_name, DW_FORM_strp
.byte 0, 0, 0

.section .debug_str,"MS",@progbits,1
.asciz "producer"
.Lname:
.asciz "Packet.c"

.section .debug_info,"",@progbits
.4byte .Lend-.Lstart
.Lstart:
.2byte 4
.4byte .Labbrev
.byte 4
.byte 1
.4byte .Lname
.Lend:
