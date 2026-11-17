//===---- Mips16HardFloatInfo.cpp for Mips16 Hard Float              -----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the Mips16 implementation of Mips16HardFloatInfo
// namespace.
//
//===----------------------------------------------------------------------===//

#include "Mips16HardFloatInfo.h"
#include <string.h>

namespace llvm {

namespace Mips16HardFloatInfo {

static void addDoubleMoves(FPIntRegMoves &Moves, unsigned GPR, unsigned FPR,
                           bool LE, bool FP64) {
  Moves.push_back({GPR + !LE, FPR, false});
  Moves.push_back({GPR + LE, FPR + !FP64, FP64});
}

FPIntRegMoves getFPParamMoves(FPParamVariant PV, bool LE, bool FP64) {
  FPIntRegMoves Moves;
  switch (PV) {
  case FSig:
    Moves.push_back({4, 12, false});
    break;
  case FFSig:
    Moves.push_back({4, 12, false});
    Moves.push_back({5, 14, false});
    break;
  case FDSig:
    Moves.push_back({4, 12, false});
    addDoubleMoves(Moves, 6, 14, LE, FP64);
    break;
  case DSig:
    addDoubleMoves(Moves, 4, 12, LE, FP64);
    break;
  case DDSig:
    addDoubleMoves(Moves, 4, 12, LE, FP64);
    addDoubleMoves(Moves, 6, 14, LE, FP64);
    break;
  case DFSig:
    addDoubleMoves(Moves, 4, 12, LE, FP64);
    Moves.push_back({6, 14, false});
    break;
  case NoSig:
    break;
  }
  return Moves;
}

FPIntRegMoves getFPReturnMoves(FPReturnVariant RV, bool LE, bool FP64) {
  FPIntRegMoves Moves;
  switch (RV) {
  case FRet:
    Moves.push_back({2, 0, false});
    break;
  case DRet:
    addDoubleMoves(Moves, 2, 0, LE, FP64);
    break;
  case CFRet:
    Moves.push_back({2, 0, false});
    Moves.push_back({3, 2, false});
    break;
  case CDRet:
    addDoubleMoves(Moves, 2, 0, LE, FP64);
    addDoubleMoves(Moves, 4, 2, LE, FP64);
    break;
  case NoFPRet:
    break;
  }
  return Moves;
}

const FuncNameSignature PredefinedFuncs[] = {
  { "__floatdidf", { NoSig, DRet } },
  { "__floatdisf", { NoSig, FRet } },
  { "__floatundidf", { NoSig, DRet } },
  { "__fixsfdi", { FSig, NoFPRet } },
  { "__fixunsdfsi", { DSig, NoFPRet } },
  { "__fixunsdfdi", { DSig, NoFPRet } },
  { "__fixdfdi", { DSig, NoFPRet } },
  { "__fixunssfsi", { FSig, NoFPRet } },
  { "__fixunssfdi", { FSig, NoFPRet } },
  { "__floatundisf", { NoSig, FRet } },
  { nullptr, { NoSig, NoFPRet } }
};

// just do a search for now. there are very few of these special cases.
//
extern FuncSignature const *findFuncSignature(const char *name) {
  const char *name_;
  int i = 0;
  while (PredefinedFuncs[i].Name) {
    name_ = PredefinedFuncs[i].Name;
    if (strcmp(name, name_) == 0)
      return &PredefinedFuncs[i].Signature;
    i++;
  }
  return nullptr;
}
}
}
