X86 native descriptor-state addresses
====================================

The descriptor-state intrinsics are ordered, potentially trapping processor
effects. Memory operands remain in the native instruction, including implicit
descriptor-table reads and LTR's busy-bit update. A dead result does not remove
an access. These interfaces neither emulate descriptor state nor bypass UMIP,
privilege, feature, segment or page checks.

Explicit address signatures
---------------------------

Each interface takes an integer offset, followed by constant ``i32`` address
width and segment-prefix operands. Unsuffixed ``.address`` names require
64-bit code and an ``i64`` offset. ``.address32`` names require i386 code and
an ``i32`` offset; this suffix describes code mode, not address width.

* ``llvm.x86.{verr,verw}.mem.address[32]`` returns the actual ZF as ``i8``.
* ``llvm.x86.{sldt,str,smsw,lldt,ltr,lmsw}.mem.address[32]`` returns ``void``.
  These instructions access exactly m16, independently of code mode.
* ``llvm.x86.{sgdt,sidt,lgdt,lidt}.address[32]`` returns ``void`` and uses the
  code mode's native descriptor-table operand size: ten bytes in long mode
  and six in i386.
* ``llvm.x86.invlpg.address[32]`` returns ``void``. The operand identifies a
  virtual address; it is not an ordinary memory load.
* ``llvm.x86.{sgdt16,sidt16,lgdt16,lidt16}.address32`` additionally retains
  the i386 16-bit operand-size attribute. The six-byte memory image and the
  processor's actual base-width behavior stay native. These forms are
  distinct from both a 16-bit address and a 16-bit code mode.

Valid address widths are 32/64 in long mode and 16/32 in i386. The offset is
truncated to that width before segment-base addition. Valid prefix values are
zero (default DS), ``0x26`` (ES), ``0x2e`` (CS), ``0x36`` (SS), ``0x3e`` (DS),
``0x64`` (FS) and ``0x65`` (GS). These are encoding bytes, not LLVM pointer
address-space numbers. Invalid controls and mismatched code modes fail;
code16 is not supported by these APIs.

The native operation uses a BX-family base, preserving DS for the zero-prefix
form. Address-size pseudos keep the normal machine pointer-register class
until MC lowering selects BX/EBX/RBX and emits the native override. An eager
C/IR selector load, a widened memory store, or software segment-base addition
is not equivalent to these instruction-owned accesses.

Examples
--------

.. code-block:: llvm

   declare i8 @llvm.x86.verr.mem.address(i64, i32 immarg, i32 immarg)
   declare void @llvm.x86.lgdt16.address32(i32, i32 immarg, i32 immarg)

   ; Long-mode offset wraps to 32 bits before adding GS.base.
   %zf = call i8 @llvm.x86.verr.mem.address(i64 %offset, i32 32, i32 101)

   ; In an i386 module: 16-bit operand size, 32-bit address size, default DS.
   call void @llvm.x86.lgdt16.address32(i32 %table, i32 32, i32 0)

The existing AS0 pointer and register APIs remain available. Register
SLDT/STR/SMSW results preserve their declared operand width, including native
upper SMSW bits; they are not synthesized by extending a 16-bit read.

Qualification
-------------

``descriptor-state-address-intrinsics.ll`` covers both code modes, all three
object formats, O0/O2, dead reads, explicit segments, narrow addresses, legacy
table operands and rejected controls. The companion NeverC repository's
``verify-descriptor-state-address-completion.py`` independently checks full
instruction bytes, address transport, ZF, ordinary-memory ordering, retained
effects and ABI preservation. Controlled completions do not qualify actual
descriptor validation or exception delivery. Its separate CPL0 QEMU guest
checks real emulated descriptor state and table transfers; physical hardware
qualification remains separate.
