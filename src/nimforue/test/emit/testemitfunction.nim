
include ../../unreal/prelude
import std/[strutils]
import ../testutils
import unittest
import ../testdata
import ../../codegen/[uemeta, ueemit]


#[
    #define P_GET_PROPERTY(PropertyType, ParamName)													\
	PropertyType::TCppType ParamName = PropertyType::GetDefaultPropertyValue();					\
	Stack.StepCompiledIn<PropertyType>(&ParamName);

#define P_GET_PROPERTY_REF(PropertyType, ParamName)												\
	PropertyType::TCppType ParamName##Temp = PropertyType::GetDefaultPropertyValue();			\
	PropertyType::TCppType& ParamName = Stack.StepCompiledInRef<PropertyType, PropertyType::TCppType>(&ParamName##Temp);

    DEFINE_FUNCTION(UFunctionTestObject::execTestReturnStringWithParamsOut)
	{
		P_GET_PROPERTY(FStrProperty,Z_Param_A);
		P_GET_PROPERTY(FIntProperty,Z_Param_B);
		P_GET_PROPERTY_REF(FStrProperty,Z_Param_Out_Out);
		P_FINISH;
		P_NATIVE_BEGIN;
		P_THIS->TestReturnStringWithParamsOut(Z_Param_A,Z_Param_B,Z_Param_Out_Out);
		P_NATIVE_END;
	}
	DEFINE_FUNCTION(UFunctionTestObject::execTestReturnStringWithParams)
	{
		P_GET_PROPERTY(FStrProperty,Z_Param_A);
		P_GET_PROPERTY(FIntProperty,Z_Param_B);
		P_FINISH; //increaseStack
		P_NATIVE_BEGIN;
		*(FString*)Z_Param__Result=P_THIS->TestReturnStringWithParams(Z_Param_A,Z_Param_B);
		P_NATIVE_END;
	}
]#
uClass UMyClassToTestNim of UObject: #TODO specify the package 
    uprop():
        bWasCalled:bool
        testProperty:FString



# genUFun("UMyClassToTestNim", fnField)
 
# proc newFunctionDsl(self:UMyClassToTestNimPtr, param:FString) {.ufunc.}=
#     self.bWasCalled = true
    # self.testProperty = param
    # UE_Warn "Got updated?" & "shit this is so crazy that I dont fully get what's going on!!!" & param
    
    
    

 

suite "NimForUE.FunctionEmit":
    uetest "Should be able to find a function to an existing object":
        let cls = getClassByName("EmitObjectTest")
        let fn = cls.findFunctionByName(n"ExistingFunction")

        assert not fn.isNil()


    uetest "Should be able to create a ufunction to an existing object":
        let cls = getClassByName("EmitObjectTest")
        let fnName = n"NewFunction"

        var fn = cls.findFunctionByName fnName
        assert fn.isNil()

        let newFn = newUObject[UFunction](cls, fnName)
        cls.addFunctionToFunctionMap(newFn, fnName)

        fn = cls.findFunctionByName fnName
        
        assert not fn.isNil()

        cls.removeFunctionFromClass fn
     

    ueTest "Should be able to invoke a function":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()

        #replace with addDynamic
        let fn = obj.getClass().findFunctionByName(n"DelegateFunc")
        type Params = object
            param0 : FString
        var param = Params(param0: "Hello!")
        
        obj.processEvent(fn, param.addr)

        assert obj.bWasCalled 


#This test doesnt add much value now and it sometimes fails
    # ueTest "Should be able to replace a function implementation to a new UFunction NoMacro":
    #     let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    #     var cls = obj.getClass()
    #     let fnName =n"FakeFunc"

    #     proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
    #         stack.increaseStack()
    #         let obj = cast[UMyClassToTestPtr](context) 
    #         obj.bWasCalled = true
            
            
    #     var fn = obj.getClass().findFunctionByName fnName
       
    #     let fnPtr : FNativeFuncPtr = makeFNativeFuncPtr(fnImpl)
        
    #     assert not fn.isNil() 
     
    #     fn.setNativeFunc(fnPtr)

    #     obj.processEvent(fn, nil)

    #     assert obj.bWasCalled

    #     cls.removeFunctionFromClass fn
        


    ueTest "Should be able to create a new function in nim and map it to a new UFunction NoMacro":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()

        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            stack.increaseStack()
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true

        let fnField = UEField(kind:uefFunction, name:"NewFuncNoParams", fnFlags: FUNC_Native, 
                            signature: @[
                               
                            ]
                    )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)

        obj.processEvent(fn, nil)

        assert obj.bWasCalled
        
        cls.removeFunctionFromClass fn 
        

    ueTest "Should be able to create a new function that accepts a parameter in nim NO_MACRO":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()
        let fnName =n"NewFunction"


        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            stack.increaseStack()
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            let fn = stack.node
            let paramProp = cast[FPropertyPtr](fn.childProperties)
            assert not paramProp.isnil()
            let paramVal : ptr FString = getPropertyValuePtr[FString](paramProp, stack.locals)
            assert not paramVal.isNil()
            #actual func
            obj.testProperty = paramVal[]
            #end actual func
            
       
        let fnField = UEField(kind:uefFunction, name:"NewFunction", fnFlags: FUNC_Native, 
                    signature: @[
                        UEField(kind:uefProp, name: "TestProperty", uePropType: "FString", propFlags:CPF_Parm)
                    ]
        )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)

        type Param = object
            param0 : FString
        
        var param = Param(param0: "FString Parameter")

        obj.processEvent(fn, param.addr)

        assert obj.bWasCalled
        assert fn.numParms == 1
        assert obj.testProperty.equals(param.param0)
        
        cls.removeFunctionFromClass fn 


    ueTest "Should be able to create a new function that accepts a parameter in nim":
        let obj = newUObject[UMyClassToTestNim]()
        var cls = obj.getClass()

        # #Params needs to be retrieved from the function so they have to be set
        # proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
        #     stack.increaseStack()
        #     let obj = cast[UMyClassToTestNimPtr](context) 
        #     type Param = object
        #         param0 : FString
        #     let params = cast[ptr Param](stack.locals)
        #     let testProperty = params.param0

        

        #     #actual func
        #     # RAW BODY HERE?
        #     obj.bWasCalled = true
        #     obj.testProperty = testProperty
        #     #end actual func
        #     #TODO return and stuff



        # genNativeFunction "UMyClassToTestNim", fnField:
        #     self.testProperty = testProperty
        #     self.bWasCalled = true 
            
        # let fnField = UEField(kind:uefFunction, name:"NewFunction", fnFlags: FUNC_Native, 
        #         signature: @[
        #             UEField(kind:uefProp, name: "TestProperty", uePropType: "FString", propFlags:CPF_Parm)
        #         ])
        
        # let fn = emitUFunction(fnField, cls, nil)
        let times = 10
        var i = 0
        while i<times:
            inc i
            let expectedStr = "ParameterValue" & $i
            # obj.newFunctionDsl(expectedStr)
        assert obj.bWasCalled
        # assert fn.numParms == 1
        # assert obj.testProperty.equals(expectedStr) 
        
        # cls.removeFunctionFromClass fn 



    
    ueTest "Should be able to create a new function that accepts two parameters in nim":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()
        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            stack.increaseStack()
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            type Param = object
                param0 : int32
                param1 : FString

            let params = cast[ptr Param](stack.locals)[]

            #actual func
            obj.intProperty = params.param0 
            obj.testProperty = params.param1
            #end actual func



        let fnField = UEField(kind:uefFunction, name:"NewFunction2Params", fnFlags: FUNC_Native, 
                            signature: @[
                                UEField(kind:uefProp, name: "IntProperty", uePropType: "int32", propFlags:CPF_Parm), 
                                UEField(kind:uefProp, name: "TestProperty", uePropType: "FString", propFlags:CPF_Parm)
                            ]
                    )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)


        proc newFunction2Params(obj:UMyClassToTestPtr, param:int32, param2:FString) {.uebind .} 

        let expectedInt : int32 = 3
        let expectedStr = "Whatever"
        obj.newFunction2Params(expectedInt, expectedStr)

        assert obj.bWasCalled
        assert fn.numParms == 2
        assert obj.intProperty == expectedInt
        assert obj.testProperty.equals(expectedStr)
        
        cls.removeFunctionFromClass fn 

    
        
    
    ueTest "Should be able to create a new function that accepts two parameters and returns":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()

        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            stack.increaseStack()
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            type Param = object
                param0 : int32
                param1 : FString

            var params = cast[ptr Param](stack.locals)[]
            let str = $ params.param0 & params.param1
            let cstr : cstring = str.cstring
            var toReturn : FString = makeFString(cstr) #Needs to call the constructor so it allocates

            cast[ptr FString](result)[] = toReturn

            # let returnProp = stack.node.getReturnProperty()
            # returnProp.initializeValueInContainer(result)
            # setPropertyValuePtr[FString](returnProp, result, toReturn.addr)         


            let val : FString = cast[ptr FString](result)[]
            UE_Log("The value of result is " & val)

        
        let fnField = UEField(kind:uefFunction, name:"NewFunction2ParamsAndReturns2", fnFlags: FUNC_Native, 
                            signature: @[
                                UEField(kind:uefProp, name: "ReturnProp", uePropType: "FString", propFlags:CPF_ReturnParm or CPF_Parm),
                                UEField(kind:uefProp, name: "IntProperty", uePropType: "int32", propFlags:CPF_Parm), 
                                UEField(kind:uefProp, name: "TestProperty", uePropType: "FString", propFlags:CPF_Parm)
                            ]
                )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)

        proc newFunction2ParamsAndReturns2(obj:UMyClassToTestPtr, param:int32, param2:FString) : FString {.uebind .} 
        let expectedResult = $ 10 & "Whatever"

        let result = obj.newFunction2ParamsAndReturns2(10, "Whatever")
       
        assert obj.bWasCalled
        assert fn.numParms == 3
        assert result.equals(expectedResult)
        
        cls.removeFunctionFromClass fn 
        
        
        
    ueTest "Should be able to create a new function that accepts two parameters and returns and int":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()

        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result:pointer):void {. cdecl .} =
            stack.increaseStack()
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            type Param = object
                param0 : int32
                param1 : FString

  

            var value : int32 = 4


            cast[ptr int32](result)[] = value
            # UE_Warn $(cast[ptr int32](result)[])
            # let returnProp = stack.node.getReturnProperty()
            # returnProp.initializeValueInContainer(result)
            # setPropertyValuePtr[int32](returnProp, result, value.addr)
            # UE_Warn $(cast[ptr int32](result)[])

 
        
        let fnField = UEField(kind:uefFunction, name:"NewFunction2ParamsAndReturns", fnFlags: FUNC_Native, 
                            signature: @[
                                UEField(kind:uefProp, name: "ReturnProp", uePropType: "int32", propFlags:CPF_ReturnParm or CPF_Parm),
                                UEField(kind:uefProp, name: "IntProperty", uePropType: "int32", propFlags:CPF_Parm), 
                                UEField(kind:uefProp, name: "TestProperty", uePropType: "FString", propFlags:CPF_Parm)
                            ]
                )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)

        proc newFunction2ParamsAndReturns(obj:UMyClassToTestPtr, param:int32, param2:FString) : int32 {.uebind .} 
        
        let result = obj.newFunction2ParamsAndReturns(10, "Whatever")
        # UE_Warn $result
        # assert obj.bWasCalled
        assert fn.numParms == 3
        assert result == 4
        
        cls.removeFunctionFromClass fn
        
    
    ueTest "Should be able to create a new function that accepts parameters as out":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()

        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
          
            # stack.increaseStack()
            

            var paramVal : int32 = 5



            cast[ptr int32](stack.outParms.propAddr)[] = 5
   


        let fnField = UEField(kind:uefFunction, name:"NewFuncOutParams", fnFlags: FUNC_Native or FUNC_HasOutParms, 
                            signature: @[
                                UEField(kind:uefProp, name: "Param1", uePropType: "int32", propFlags:CPF_Parm or CPF_OutParm), 
                                UEField(kind:uefProp, name: "Param2", uePropType: "int32", propFlags:CPF_Parm or CPF_OutParm)
                            ]
                    )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)


        proc newFuncOutParams(obj:UMyClassToTestPtr, param:var int32, param2: int32) {.uebind .} 
        type
            Params = object
                param: int32
                param2: int32

        var params = Params(param: 3, param2: 2)
        var fnName: FString = "NewFuncOutParams"
        callUFuncOn(obj, fnName, params.addr)
        
        # obj.newFuncOutParams(param0, param1)

        # assert fn.getPropsWithFlags(CPF_OutParm).num() == 1
        assert params.param == 5 #only this one is changed
        # assert params.param2 == 1
        
        cls.removeFunctionFromClass fn
 
        


        

    ueTest "Should be able to create a new function that accepts parameters as out [FString]":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()

        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
          
            var paramVal : FString = "whatever"

            cast[ptr FString](stack.outParms.propAddr)[] = paramVal
   
        let fnField = UEField(kind:uefFunction, name:"NewFuncOutParams", fnFlags: FUNC_Native or FUNC_HasOutParms, 
                            signature: @[
                                UEField(kind:uefProp, name: "Param1", uePropType: "FString", propFlags:CPF_Parm or CPF_OutParm), 
                                UEField(kind:uefProp, name: "Param2", uePropType: "FString", propFlags:CPF_Parm or CPF_OutParm)
                            ]
                    )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)


        proc newFuncOutParams(obj:UMyClassToTestPtr, param:var FString, param2: FString) {.uebind .} 
        type
            Params = object
                param: FString
                param2: FString

        var params = Params(param: "3", param2: "2")
        var fnName: FString = "NewFuncOutParams"
        callUFuncOn(obj, fnName, params.addr)
        
        # obj.newFuncOutParams(param0, param1)

        # assert fn.getPropsWithFlags(CPF_OutParm).num() == 1
        assert params.param.equals("whatever") #only this one is changed
        # assert params.param2 == 1

        cls.removeFunctionFromClass fn

    

    ueTest "Should be able to create a new function that accepts parameters as out [two params]":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()

        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
          
            stack.increaseStack() 
            type Param = object
                param0 : int32
                param1 : FString

        

            var paramVal : int32 = 5

            cast[ptr int32](stack.outParms.propAddr)[] = 5
            cast[ptr int32](stack.outParms.nextOutParm.propAddr)[] = 10
   


        let fnField = UEField(kind:uefFunction, name:"NewFuncOutParams", fnFlags: FUNC_Native or FUNC_HasOutParms, 
                            signature: @[
                                UEField(kind:uefProp, name: "Param1", uePropType: "int32", propFlags:CPF_Parm or CPF_OutParm), 
                                UEField(kind:uefProp, name: "Param2", uePropType: "int32", propFlags:CPF_Parm or CPF_OutParm)
                            ]
                    )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)


        proc newFuncOutParams(obj:UMyClassToTestPtr, param:var int32, param2: int32) {.uebind .} 
        type
            Params = object
                param: int32
                param2: int32

        var params = Params(param: 3, param2: 2)
        var fnName: FString = "NewFuncOutParams"
        callUFuncOn(obj, fnName, params.addr)
        
        # obj.newFuncOutParams(param0, param1)

        # assert fn.getPropsWithFlags(CPF_OutParm).num() == 1
        assert params.param == 5 #only this one is changed
        assert params.param2 == 10 #only this one is changed
        # assert params.param2 == 1
        
        cls.removeFunctionFromClass fn

         


