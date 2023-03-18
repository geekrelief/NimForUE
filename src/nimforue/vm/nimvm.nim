include ../unreal/prelude
import ../unreal/editor/editor

import ../../buildscripts/[nimforueconfig]
import ../unreal/core/containers/containers

import std/[os, times, asyncdispatch, json, jsonutils, tables]
import std/[strutils, options, tables, sequtils, strformat, strutils, sugar]

import compiler / [ast, nimeval, vmdef, vm, llstream, types, lineinfos]
import compiler/options as copt
import ../vm/[uecall]



type   
  VMQuit* = object of CatchableError
    info*: TLineInfo



proc onInterpreterError(config: ConfigRef, info: TLineInfo, msg: string, severity : Severity)  {.gcsafe.}  = 
  if severity == Severity.Error and config.error_counter >= config.error_max:
    var fileName: string
    for k, v in config.m.filenameToIndexTbl.pairs:
      if v == info.fileIndex:
        fileName = k
    UE_Error "Script Error: $1:$2:$3 $4." % [fileName, $info.line, $(info.col + 1), msg]
    raise (ref VMQuit)(info: info, msg: msg)



proc implementBaseFunctions(interpreter:Interpreter) = 
  #TODO review this. Maybe even something like nimscripter can help
   #This function can be implemented with uebind directly 
  interpreter.implementRoutine("*", "exposed", "log", proc (a: VmArgs) =
      let msg = a.getString(0)
      UE_Log msg
      discard
    )


  interpreter.implementRoutine("*", "exposed", "uCallInterop", proc (a: VmArgs) =
      let msg = a.getString(0)
      let ueCall = msg.parseJson().to(UECall)
      let result = ueCall.uCall()
      let json = $result.toJson()
      setResult(a, json)
      discard
    )

  #This function can be implemented with uebind directly 
  interpreter.implementRoutine("*", "exposed", "getClassByNameInterop", proc (a: VmArgs) =
      let className = a.getString(0)
      let cls = getClassByName(className)
      let classAddr = cast[int](cls)
      setResult(a, classAddr)
      discard
    )

  interpreter.implementRoutine("*", "exposed", "newUObjectInterop", proc (a: VmArgs) =
      #It needs cls and owner which can be nil
      let owner = cast[UObjectPtr](getInt(a, 0))
      let cls = cast[UClassPtr](getInt(a, 1))

      let obj = newObjectFromClass(owner, cls, ENone)
      obj.setFlags(RF_MarkAsRootSet)
      let objAddr = cast[int](obj)
      setResult(a, objAddr)
      discard
    )

  #This function can be implemented with uebind directly 
  interpreter.implementRoutine("*", "exposed", "getName", proc(a: VmArgs) =
      let actor = cast[UObjectPtr](getInt(a, 0))
      if actor.isNil():
        setResult(a, "nil")
      else:
        setResult(a, actor.getName())
      # setResult(a, $actor.getName())
    )




#should args be here too?
type UEBorrowInfo = object
  vmFnName: string #ufuncVmImpl name where in ue would be UFunc so for Salute (ue) it will be saluteVmImpl 
  className : string


func getUFuncName*(info: UEBorrowInfo): string =
  info.vmFnName.capitalizeASCII().replace("VmImpl", "")


func getBorrowKey*(info: UEBorrowInfo): string = info.className & info.getUFuncName()
func getBorrowKey*(fn: UFunctionPtr) : string = fn.getOuter().getName() & fn.getName()

# var borrowedFns = newSeq[UFunctionNativeSignature]()
var borrowTable = newTable[string, UEBorrowInfo]() 
var lastBorrow : UEBorrowInfo #last/current borrow info asked to be implemented
#[
  [] Functions are being replaced, we need to store them with a table. 
]#


var interpreter : Interpreter #needs to be global so it can be accesed from cdecl

proc implementBorrow() = 
  proc borrowImpl(context: UObjectPtr; stack: var FFrame; returnResult: pointer) : void {.cdecl.} =
      stack.increaseStack()
      let fn = stack.node
      let borrowKey = fn.getBorrowKey()
      let borrowInfo = borrowTable[borrowKey]
      let vmFn = interpreter.selectRoutine(borrowInfo.vmFnName)
      if vmFn.isNil():
        UE_Error &"script does not export a proc of the name: {borrowInfo.vmFnName}"
        return
      #TODO pass params as json to vm call (from stack but review how it's done in uebind)
      let ueCall = $makeUECall(makeUEFunc("TODO", "TODO"), context, newJNull()).toJson()
      let res = interpreter.callRoutine(vmFn, [newStrNode(nkStrLit, ueCall)])
      #TODO return value
  
  #At this point it will be the last added or not because it can be updated
  #But let's assume it's the case (we could use a stack or just store the last one separatedly)
  let cls = getClassByName(lastBorrow.className)
  if cls.isNil():
    UE_Error &"could not find class {lastBorrow.className}"
    return

  let ueBorrowUFunc = cls.findFunctionByName(n lastBorrow.getUFuncName())
  if ueBorrowUFunc.isNil(): 
      UE_Error &"could not find function { lastBorrow.getUFuncName()} in class {lastBorrow.className}"
      return

  #notice we could store the prev version to restore it later on 
  ueBorrowUFunc.setNativeFunc((cast[FNativeFuncPtr](borrowImpl)))


proc setupBorrow(interpreter:Interpreter) = 
  interpreter.implementRoutine("*", "exposed", "setupBorrowInterop", proc(a: VmArgs) =
          {.cast(noSideEffect).}:
            let borrowInfo = a.getString(0).parseJson().jsonTo(UEBorrowInfo)
            let borrowKey = borrowInfo.getBorrowKey()
            borrowTable.addOrUpdate(borrowKey, borrowInfo)
            lastBorrow = borrowInfo
            implementBorrow()
        )



proc initInterpreter*(searchPaths:seq[string], script: string = "script.nims") : Interpreter = 
  let std = findNimStdLibCompileTime()
  interpreter = createInterpreter(script, @[
    std,
    std / "pure",
    std / "pure" / "collections",
    std / "core", 
    PluginDir/"src"/"nimforue"/"utils",
   
    ] & searchPaths)
  interpreter.registerErrorHook(onInterpreterError)
  interpreter.implementBaseFunctions()
  interpreter.setupBorrow()
  interpreter



