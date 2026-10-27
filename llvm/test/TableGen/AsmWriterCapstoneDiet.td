// RUN: llvm-tblgen -gen-asm-writer --printerLang=CCS -I %p/../../include %s | FileCheck %s --check-prefixes=CHECK,DEFAULT
// RUN: llvm-tblgen -gen-asm-writer --printerLang=CCS -D CUSTOM_PRINT -I %p/../../include %s | FileCheck %s --check-prefixes=CHECK,CUSTOM
// RUN: llvm-tblgen -gen-asm-writer --printerLang=CCS -D NO_ALIAS -I %p/../../include %s | FileCheck %s --check-prefix=NOALIAS
// RUN: llvm-tblgen -gen-asm-writer --printerLang=CCS -D PREDICATE -I %p/../../include %s | FileCheck %s --check-prefix=PRED

include "llvm/Target/Target.td"

def ArchInstrInfo : InstrInfo;
def Arch : Target {
  let InstructionSet = ArchInstrInfo;
}

def Reg : Register<"reg">;
def RegClass : RegisterClass<"Arch", [i32], 0, (add Reg)>;
def IntOperand : Operand<i32>, ImmLeaf<i32, "return true;"> {
#ifdef CUSTOM_PRINT
  let PrintMethod = "printCustomImm";
#endif
#ifdef PREDICATE
  let MCOperandPredicate = [{ return true; }];
#endif
}

def foo : Instruction {
  let Size = 2;
  let Namespace = "Arch";
  let OutOperandList = (outs);
  let InOperandList = (ins IntOperand:$imm);
  let AsmString = "foo $imm";
}
#ifndef NO_ALIAS
def FooAlias : InstAlias<"alias $imm", (foo IntOperand:$imm)>;
#endif

// NOALIAS-LABEL: static bool printAliasInstr(
// NOALIAS-NEXT: #ifndef CAPSTONE_DIET
// NOALIAS-NEXT: #endif // CAPSTONE_DIET
// NOALIAS-NEXT: return false;
// NOALIAS-NEXT: }
// NOALIAS-NOT: printCustomAliasOperand

// PRED-LABEL: #undef PRINT_ALIAS_INSTR
// PRED:      #ifndef CAPSTONE_DIET
// PRED-NEXT: static bool ArchInstPrinterValidateMCOperand(const MCOperand *MCOp,
// PRED-NEXT: unsigned PredicateIndex);
// PRED-NEXT: #endif // CAPSTONE_DIET
// PRED-LABEL: static void printCustomAliasOperand(
// PRED:      #endif // CAPSTONE_DIET
// PRED-EMPTY:
// PRED-NEXT: #ifndef CAPSTONE_DIET
// PRED-NEXT: static bool ArchInstPrinterValidateMCOperand(const MCOperand *MCOp,
// PRED-NEXT: unsigned PredicateIndex) {
// PRED:      return true;
// PRED-NEXT: }
// PRED-NEXT: }
// PRED-NEXT: }
// PRED-NEXT: #endif // CAPSTONE_DIET

// The whole static helper must disappear in DIET, including its declaration.
// An empty, unused definition still fails Capstone's warning-as-error build.
// CHECK-LABEL: static bool printAliasInstr(
// CHECK:      #else
// CHECK-NEXT: return false;
// CHECK-NEXT: #endif // CAPSTONE_DIET
// CHECK-NEXT: }
// CHECK-EMPTY:
// CHECK-NEXT: #ifndef CAPSTONE_DIET
// CHECK-NEXT: static void printCustomAliasOperand(
// CHECK-NEXT: MCInst *MI, uint64_t Address, unsigned OpIdx,
// CHECK-NEXT: unsigned PrintMethodIdx,
// CHECK-NEXT: SStream *OS) {
// DEFAULT-NEXT: CS_ASSERT_RET(0 && "Unknown PrintMethod kind");
// CUSTOM-NEXT: switch (PrintMethodIdx) {
// CUSTOM:     printCustomImm(MI, OpIdx, OS);
// CUSTOM-NEXT: break;
// CUSTOM-NEXT: }
// CHECK-NEXT: }
// CHECK-NEXT: #endif // CAPSTONE_DIET
