// RUN: llvm-tblgen -gen-asm-matcher -I %p/../../include %s | FileCheck %s

include "llvm/Target/Target.td"

def TestParser : AsmParser { let IndexOperandMnemonics = true; }
def TestInstrInfo : InstrInfo;
def TestTarget : Target {
  let InstructionSet = TestInstrInfo;
  let AssemblyParsers = [TestParser];
}

def Reg : Register<"r">;
def Regs : RegisterClass<"test", [i32], 32, (add Reg)>;
def Parsed : AsmOperandClass {
  let Name = "Parsed";
  let ParserMethod = "parseValue";
}
def Value : Operand<i32> { let ParserMatchClass = Parsed; }

class TestInst<string name> : Instruction {
  let OutOperandList = (outs);
  let InOperandList = (ins Value:$value);
  let AsmString = name # " $value";
}
def A : TestInst<"Alpha">;
def B : TestInst<"amber">;
def Z : TestInst<"Zed">;

// The two lower-case 'a' entries occupy [0, 2) and 'z' occupies [2, 3).
// Empty buckets on either side retain the neighboring one-past-end offset.
// CHECK: OperandMatchTable[3]
// CHECK: OperandMnemonicStarts[] = {{\{(0, ){98}(2, ){25}(3, ){133}3\};}}
// CHECK: OperandMatchTable + OperandMnemonicStarts[First],
// CHECK-NEXT: OperandMatchTable + OperandMnemonicStarts[First + 1],
// CHECK: return {Mnemonic, unsigned(Range.first - OperandMatchTable),
// CHECK-NEXT: unsigned(Range.second - OperandMatchTable)};
// CHECK: OperandMatchTable + Range.Begin,
// CHECK-NEXT: OperandMatchTable + Range.End);
