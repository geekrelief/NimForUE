include ../unreal/prelude

import ../codegen/[modelconstructor, ueemit, uebind, models, uemeta]
import std/[json, strformat, jsonutils, sequtils, options, sugar, enumerate, strutils, tables]

import ../vm/[runtimefield, uecall]

import ../test/testutils

#Primero coger el parametro.
#Luego devolverlo en el out
#luego uecall


uStruct FStructVMTest:
  (BlueprintType)
  uprops(EditAnywhere):
    x: float32
    y: float32
    z: float32

uEnum EEnumVMTest:
  (BlueprintType)  
  (ValueA, ValueB, ValueC)

uClass UObjectPOC of UObject:
  (BlueprintType, Reinstance)
  ufunc: 
    proc instanceFunc() = 
      UE_Log "Hola from UObjectPOC instanceFunc"
    proc instanceFuncWithOneArgAndReturnTest(arg : int) : FVector = FVector(x:arg.float32, y:arg.float32, z:arg.float32)

  ufuncs(Static):   
    proc callWithOutArg(res: var int) : int = 
      res = res + 20
      UE_Log &"Inside callWithOutArg {res}"
      10
    proc callFuncWithNoArg() = 
      UE_Log "Hola from UObjectPOC"
    proc callFuncWithOneIntArg(arg : int) = 
      UE_Log "Hola from UObjectPOC with arg: " & $arg
    proc callFuncWithOneStrArg(arg : FString) = 
      UE_Log "Hola from UObjectPOC with arg: " & $arg
    proc callFuncWithTwoIntArg(arg1 : int, arg2 : int) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc callFuncWithTwoStrArg(arg1 : FString, arg2 : FString) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc callFuncWithInt32Int64Arg(arg1 : int32, arg2 : int64) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc saluteWitthTwoDifferentIntSizes2(arg1 : int64, arg2 : int32) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc callFuncWithOneObjPtrArg(obj:UObjectPtr) = 
      UE_Log "Object name: " & $obj.getName()
    proc callFuncWithObjPtrStrArg(obj:UObjectPtr, salute : FString) = 
      UE_Log "Object name: " & $obj.getName() & " Salute: " & $salute
    proc callFuncWithObjPtrArgReturnInt(obj:UObjectPtr) : int = 
      UE_Log "Object name: " & $obj.getName() 
      UE_Log "Object addr: " & $cast[int](obj)
      10
    proc callFuncWithObjPtrArgReturnObjPtr(obj:UObjectPtr) : UObjectPtr = 
      if obj.isNil():
        UE_Error "Object is nil"
        return nil
      UE_Log "Object name: " & $obj.getName() 
      obj
    proc callFuncWithObjPtrArgReturnStr(obj:UObjectPtr) : FString = 
      let str = "Object name: " & $obj.getName() 
      UE_Log str
      str
    
    proc callFuncWithOneFVectorArg(vec : FVector) = 
      UE_Log "Vector: " & $vec


    proc callFuncWithOneArrayIntArg(ints : TArray[int]) = 
      UE_Log "Int array length: " & $ints.len
      for vec in ints:
        UE_Log "int: " & $vec

    proc callFuncWithOneArrayVectorArg(vecs : TArray[FVector]) = 
      UE_Log "Vector array length: " & $vecs.len
      for vec in vecs:
        UE_Log "Vector: " & $vec


    proc callThatReturnsArrayInt() : TArray[int] = makeTArray(1, 2, 3, 4, 5)

    proc receiveFloat32(arg : float32) = #: float32 = 
      UE_Log "Float32: " & $arg
      # return arg

    
    proc receiveFloat64(arg : float) = 
      UE_Log "Float64: " & $arg

    proc receiveVectorAndFloat32(dir:FVector, scale:float32) = 
      UE_Error "receiveVectorAndFloat32 " & $dir & " scale:" & $scale

    proc callFuncWithOneFVectorArgReturnFVector(vec : FVector) : FVector = 
      var vec = vec
      vec.x = 10 * vec.x
      vec.y = 10 * vec.y
      vec.z = 10 * vec.z
      vec
    
    proc callFuncWithOneFVectorArgReturnFRotator(vec : FVector) : FRotator = 
      FRotator(pitch:vec.x, yaw:vec.y, roll:vec.z)
    
#[
1. [x] Create a function that makes a call by fn name
2. [x] Create a function that makes a call by fn name and pass a value argument
  2.1 [x] Create a function that makes a call by fn name and pass a two values of the same types as argument
  2.2 [x] Create a function that makes a call by fn name and pass a two values of different types as argument
  2.3 [x] Pass a int32 and a int64
3. [x] Create a function that makes a call by fn name and pass a pointer argument
4. [x] Create a function that makes a call by fn name and pass a value and pointer argument
5. [x] Create a function that makes a call by fn name and pass a value and pointer argument and return a value
6. [x] Create a function that makes a call by fn name and pass a value and pointer argument and return a pointer
  6.1 [x] Create a function that makes a call by fn name and pass a value and pointer argument and returns a string
7. [ ] Repeat 1-6 where value arguments are complex types
8. [ ] Add support for missing basic types
8. Arrays
9. TMaps

]#

# proc registerVmTests*() = 
#   unregisterAllNimTests()
#   suite "Hello":
#     ueTest "should create a ":
#       assert true == false
#     ueTest "another create a test2":
#       assert true == true

#maybe the way to go is by raising. Let's do a test to see if we can catch the errors in the actual actor




#Later on this can be an uobject that pulls and the actor will just run them. But this is fine as started point
uClass ANimTestBase of AActor: 
  uprops(EditAnywhere):
    printSucceed: bool
  ufunc(CallInEditor):
    proc runTests() = 
      self.printSucceed = false
     #Traverse all the tests and run them. A test is a function that starts with "test" or "should
      let testFns = self
        .getClass()
        .getFuncsFromClass()
        .filterIt(
          it.getName().tolower.startsWith("test") or 
          it.getName().tolower.startsWith("should"))
      for fn in testFns:
        try:
          UE_Log "Running test: " & $fn.getName()
          self.processEvent(fn, nil)
          self.printSucceed = false

        except CatchableError as e:
          UE_Error "Error in test: " & $fn.getName() & " " & $e.msg
      self.printSucceed = false
         

uClass AActorPOCVMTest of ANimTestBase:
  (BlueprintType)
 
  ufuncs(CallInEditor):
    proc testCallFuncWithNoArg() = 
      let callData = UECall(kind: uecFunc, fn: makeUEFunc("callFuncWithNoArg", "UObjectPOC"))
      discard uCall(callData)
    proc testCallWithOutArg() = 
        let callData = UECall(
            kind: uecFunc,
            fn: makeUEFunc("callWithOutArg", "UObjectPOC"),
            value: (res: 1).toRuntimeField()
          )        
        let res =  uCall(callData)
        UE_Log $res
    # var test = 2
    # discard callWithOutArg(1, test, 2)
    # UE_Log "the value afterwards is " & $test

    proc testCallFuncWithOneIntArg() =
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithOneIntArg", "UObjectPOC"),
          value: (arg: 10).toRuntimeField()
        )
      discard uCall(callData)
    proc testCallFuncWithOneStrArg() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithOneStrArg", "UObjectPOC"),
          value: (arg: "10 cadena").toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithTwoStrArg() =
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithTwoStrArg", "UObjectPOC"),
          value: (arg1: "10 cadena", arg2: "Hola").toRuntimeField()
        )
      discard uCall(callData)
    proc testCallFuncWithTwoIntArg() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithTwoIntArg", "UObjectPOC"),
          value: (arg1: 10, arg2: 10).toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithInt32Int64Arg() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithInt32Int64Arg", "UObjectPOC"),
          value: (arg1: 15, arg2: 10).toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithOneObjPtrArg() =
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithOneObjPtrArg", "UObjectPOC"),
          value: (obj: cast[int](self)).toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithObjPtrStrArg() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithObjPtrStrArg", "UObjectPOC"),
          value: (obj: cast[int](self), salute: "Hola").toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithObjPtrArgReturnInt() =
      let expected = 10
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithObjPtrArgReturnInt", "UObjectPOC"),
          value: (obj: cast[int](self)).toRuntimeField()
        )
      UE_Log $uCall(callData)

    proc testCallFuncWithObjPtrArgReturnObjPtr() =
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithObjPtrArgReturnObjPtr", "UObjectPOC"),
          value: (obj: cast[int](self)).toRuntimeField()
        )
      let objAddr = uCall(callData).get(RuntimeField(kind:Int)).getInt()
      UE_Log &"Returned object addr is {objAddr}"
      let obj = cast[UObjectPtr](objAddr)
      # if obj.isNotNil:
      #   UE_Log $obj

    proc testCallFuncWithObjPtrArgReturnStr() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithObjPtrArgReturnStr", "UObjectPOC"),
          value: (obj: cast[int](self)).toRuntimeField()
        )
      let str = uCall(callData).get(RuntimeField(kind:String)).getStr()
      UE_Log "Returned string is " & str
      

    proc testCallFuncWithOneFVectorArg() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithOneFVectorArg", "UObjectPOC"),
          value: (vec:FVector(x:12, y:10)).toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithOneArrayIntArg() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithOneArrayIntArg", "UObjectPOC"),
          value: (ints:[2, 10]).toRuntimeField()
        )
      UE_Log  $uCall(callData)

    proc testCallFuncWithOneArrayVectorArg() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithOneArrayVectorArg", "UObjectPOC"),
          value: (vecs:[FVector(x:12, y:10), FVector(x:12, z:1)]).toRuntimeField()
        )
      UE_Log  $uCall(callData)

    proc testCallFuncWithOneFVectorArgReturnFVector() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithOneFVectorArgReturnFVector", "UObjectPOC"),
          value: (vec:FVector(x:12, y:10)).toRuntimeField()
        )
      UE_Log  $uCall(callData).get.runtimeFieldTo(FVector)

    proc testCallFuncWithOneFVectorArgReturnFRotator() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callFuncWithOneFVectorArgReturnFRotator", "UObjectPOC"),
          value: (vec:FVector(x:12, y:10)).toRuntimeField()
        )
      UE_Log  $uCall(callData)
    
    proc testGetRightVector() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("GetRightVector", "UKismetMathLibrary"),
          value: (vec:FVector(x:12, y:10)).toRuntimeField()
        )
      UE_Log  $uCall(callData)

    proc testCallThatReturnsArrayInt() = 
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("callThatReturnsArrayInt", "UObjectPOC"),
          # value: ().toRuntimeField()
        )
      UE_Log  $uCall(callData)

   


    proc testRuntimeFieldCanRetrieveAStructMemberByName() = 
      let vector = FVector(x:10, y:10)
      let rtStruct = vector.toRuntimeField()
      let rtField = rtStruct["x"]
      let x = rtField.getFloat()
      # check x == 10.0
      UE_Log $x

    proc shouldReceiveFloat32() =
      let expected = 10.0
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("receiveFloat32", "UObjectPOC"),
          value: (arg: 10.0).toRuntimeField()
        )
      let val =  uCall(callData)#.jsonTo(float)
      # check val == expected

    proc shouldReceiveFloat64() =
      let callData = UECall(
           kind: uecFunc,
          fn: makeUEFunc("receiveFloat64", "UObjectPOC"),
          value: (arg: 10.0).toRuntimeField()
        )
      discard uCall(callData)
    

import std/[macros]
macro ownerName(someSym: typed): string = newLit someSym.owner.strVal()
macro astRepr(exp: typed): string = newLit repr exp
# macro deconstructExp(exp: typed): string = 
#   echo treeRepr exp
#   newEmptyNode()

#TODO do a nice macro that splits the call and tells you what part is wrong
template check(exp: typed) =
  var a = exp
  let astRepr {.inject.} = astRepr(exp)
  let res {.inject.} = $exp
  let fnName {.inject.} = ownerName(a)
  if not exp:
    let msg = &"{[fnName]}Check failed {astRepr} is  {res}" 
    UE_Error msg 
  else:
    when compiles(self.printSucceed):
      if self.printSucceed:
        UE_Log &"{[fnName]} Check passed"
    else:
      UE_Log &"{[fnName]} Check passed"

uClass AUECallPropReadTest of ANimTestBase:
  
  uprops(EditAnywhere):    
    intProp: int32 
    stringProp: FString
    boolProp: bool
    arrayProp: TArray[int]
    structProp: FVector
    enumProp: EEnumVMTest
    mapProp: TMap[int, FString]
    mapProp2: TMap[int, int]

  ufuncs(CallInEditor):
    proc shouldBeAbleToReadAnInt32Prop() =
      self.intProp = 10
      let callData = UECall(
          kind: uecGetProp,
          self: cast[int](self),
          clsName: self.getClass.getCppName(),
          value: (intProp: default(int32)).toRuntimeField()                       
        )
      let reply = uCall(callData)    
      let val = reply.get(RuntimeField(kind:Int)).getInt()
      check(val == self.intProp)                   
    
    proc shouldBeAbleToReadAFStringProp() =
      self.stringProp = "Hola"
      let callData = UECall(
          kind: uecGetProp,
          self: cast[int](self),
          clsName: self.getClass.getCppName(),
          value: (stringProp: default(FString)).toRuntimeField()                        
        )
      let reply = uCall(callData)      
      let val = reply.get(RuntimeField(kind:String)).getStr()
      check val == self.stringProp

    proc shouldBeAbleToReadABoolProp() =
      self.boolProp = true
      let callData = UECall(
          kind: uecGetProp,
          self: cast[int](self),
          clsName: self.getClass.getCppName(),
          value: (boolProp: default(bool)).toRuntimeField()                        
        )
      let reply = uCall(callData)      
      let val = reply.get(RuntimeField(kind:Bool)).getBool()
      check val == self.boolProp

    proc shouldBeAbleToReadAnArrayProp() = 
      self.arrayProp = @[1, 2, 3, 4, 5].toTArray()
      let callData = UECall(
          kind: uecGetProp,
          self: cast[int](self),
          clsName: self.getClass.getCppName(),
          value: (arrayProp: default(TArray[int])).toRuntimeField()                           
        )
      let reply = uCall(callData)
      let val = reply.get(RuntimeField(kind:Array)).runtimeFieldTo(seq[int]).toTArray()
      check val == self.arrayProp               
      
    proc shouldBeAbleToReadAStructProp() = 
      self.structProp = FVector(x:10, y:10, z:10)
      let callData = UECall(
          kind: uecGetProp,
          self: cast[int](self),
          clsName: self.getClass.getCppName(),
          value: (structProp: default(FVector)).toRuntimeField()                     
        )
      let reply = uCall(callData)      
      let val = reply.get(RuntimeField(kind:Struct)).runtimeFieldTo(FVector)
      check val.x == self.structProp.x           
         
    proc shouldBeAbleToReadAnEnumProp() =
      self.enumProp = EEnumVMTest.ValueC
      let callData = UECall(
          kind: uecGetProp,
          self: cast[int](self),
          clsName: self.getClass.getCppName(),
          value: (enumProp: default(EEnumVMTest)).toRuntimeField()                        
        )
      let reply = uCall(callData)           
      let val = reply.get(RuntimeField(kind:Int)).runtimeFieldTo(EEnumVMTest)
      check val == self.enumProp
              


uClass AUECallPropWriteTest of ANimTestBase:
  
  uprops(EditAnywhere):    
    intProp: int32 
    stringProp: FString
    boolProp: bool
    arrayProp: TArray[int]
    structProp: FVector
    enumProp: EEnumVMTest
    mapProp: TMap[int, FString]
    mapProp2: TMap[int, int]

  ufuncs(CallInEditor):
    proc shouldBeAbleToWritteAnInt32Prop() =
      let expectedValue = 1
      let callData = UECall(
          kind: uecSetProp,
          self: cast[int](self),
          clsName: self.getClass.getCppName(),
          value: (intProp: expectedValue).toRuntimeField()                        
        )
      discard uCall(callData)      
      check expectedValue == self.intProp

    proc shouldBeAbleToWriteAnArrayProp() = 
      let expected = @[1, 2, 4].toTArray()
      self.arrayProp = @[0].toTArray()
      let callData = UECall(
          kind: uecSetProp,
          self: cast[int](self),
          clsName: self.getClass.getCppName(),
          value: (arrayProp: expected).toRuntimeField()                          
        )
      discard uCall(callData)
      check expected == self.arrayProp

    proc shouldBeAbleToWriteAnEnumProp() =
      let expected = EEnumVMTest.ValueC
      self.enumProp = EEnumVMTest.ValueA
      let callData = UECall(
          kind: uecSetProp,
          self: cast[int](self),
          clsName: self.getClass.getCppName(),
          value: (enumProp: expected).toRuntimeField()                        
        )
      discard uCall(callData)
      check expected == self.enumProp

    proc shoulsBeAbleToWriteAStructProp() = 
        let expected = FVector(x:10, y:10, z:10)
        self.structProp = FVector(x:0, y:0, z:0)
        let callData = UECall(
            kind: uecSetProp,
            self: cast[int](self),
            clsName: self.getClass.getCppName(),
            value: (structProp: expected).toRuntimeField()                        
          )
        discard uCall(callData)
        check expected.x == self.structProp.x

uClass AUECallMapTest of ANimTestBase:
  (BlueprintType)
  uprops(EditAnywhere):
    mapIntIntProp: TMap[int, int]
    mapIntFStringProp: TMap[int, FString]
    mapIntBoolProp: TMap[int, bool]
    mapIntStructProp: TMap[int, FStructVMTest]

    mapStringIntProp: TMap[FString, int]

  ufuncs(CallInEditor):
    proc shouldBeAbleToWriteAMapIntIntProp() = 
      let expected = { 1: 10, 2: 20}.toTable().toTMap()
      self.mapIntIntProp = makeTMap[int, int]()
      let callData = UECall(
          kind: uecSetProp,
          self: cast[int](self),
          clsName: "A" & self.getClass.getName(),
          value: (mapIntIntProp: expected.toTable()).toRuntimeField()                        
        )
      discard uCall(callData)      
      check expected == self.mapIntIntProp
    
    proc shouldBeAbleToWriteAMapIntFringProp() = 
      let expected = { 1: f"Hola", 2: f"Mundo"}.toTable().toTMap()
      self.mapIntFStringProp = makeTMap[int, FString]()
      let callData = UECall(
          kind: uecSetProp,
          self: cast[int](self),
          clsName: "A" & self.getClass.getName(),
          value: (mapIntFStringProp: expected.toTable()).toRuntimeField()                        
        )
      discard uCall(callData)      
      check expected == self.mapIntFStringProp

    proc shouldBeAbleToWriteAMapIntBoolProp() =
      let expected = { 1: true, 2: false}.toTable()
      self.mapIntBoolProp = makeTMap[int, bool]()
      let callData = UECall(
          kind: uecSetProp,
          self: cast[int](self),
          clsName: "A" & self.getClass.getName(),
          value: (mapIntBoolProp: expected).toRuntimeField()                        
        )
      discard uCall(callData)      
      check expected.toTMap() == self.mapIntBoolProp    
    
    proc shouldBeAbleToWriteAMapStructProp() =
      let expected = { 1: FStructVMTest(x:10, y:10, z:10), 2: FStructVMTest(x:20, y:20, z:20)}.toTable()
      self.mapIntStructProp = makeTMap[int, FStructVMTest]()
      let callData = UECall(
          kind: uecSetProp,
          self: cast[int](self),
          clsName: "A" & self.getClass.getName(),
          value: (mapIntStructProp: expected).toRuntimeField()                        
        )
      discard uCall(callData)      
      check expected.toTMap() == self.mapIntStructProp
    
    proc shouldBeAbleToWriteAMapStringIntProp() = 
      let expected = { f"Hola": 10, f"Mundo": 20}.toTable().toTMap()
      self.mapStringIntProp = makeTMap[FString, int]()
      let callData = UECall(
          kind: uecSetProp,
          self: cast[int](self),
          clsName: "A" & self.getClass.getName(),
          value: (mapStringIntProp: expected.toTable()).toRuntimeField()                        
        )
      discard uCall(callData)      
      check expected == self.mapStringIntProp