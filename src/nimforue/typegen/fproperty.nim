
include ../unreal/prelude
import std/[times,strformat, strutils, options, sugar, algorithm, sequtils]
import models

const propObjFlags = RF_Public | RF_Transient | RF_MarkAsNative

func newUStructBasedFProperty(outer : UStructPtr, propType:string, name:FName, propFlags=CPF_None) : Option[FPropertyPtr] = 
    const flags = propObjFlags
         #It holds a complex type, like a struct or a class
    type EObjectMetaProp = enum
        emObjPtr, emClass, emTSubclassOf, emTSoftObjectPtr, emTSoftClassPtr, emScriptStruct, emTObjectPtr#, TSoftClassPtr = "TSoftClassPtr"
    
    var eMeta = if propType.contains("TSubclassOf"): emTSubclassOf
                elif propType.contains("TSoftObjectPtr"): emTSoftObjectPtr
                elif propType.contains("TSoftClassPtr"): emTSoftClassPtr
                elif propType.contains("TObjectPtr"): emTObjectPtr
                elif propType == ("UClass"): emClass
                else: emObjPtr #defaults to emObjPtr but it can be scriptStruct since the name it's the same(will worth to do an or?)
                
    let className = case eMeta 
        of emTSubclassOf: propType.extractTypeFromGenericInNimFormat("TSubclassOf").removeFirstLetter() 
        of emTSoftObjectPtr: propType.extractTypeFromGenericInNimFormat("TSoftObjectPtr").removeFirstLetter() 
        of emTSoftClassPtr: propType.extractTypeFromGenericInNimFormat("TSoftClassPtr").removeFirstLetter() 
        of emTObjectPtr: propType.extractTypeFromGenericInNimFormat("TObjectPtr").removeFirstLetter() 
        of emObjPtr, emClass, emScriptStruct: propType.removeFirstLetter().removeLastLettersIfPtr()

    UE_Log "Looking for ustruct.." & className 
    let ustruct = getUStructByName className
    if ustruct.isnil(): return none[FPropertyPtr]()
    #we still dont know if it's a script struct
    let cls = ueCast[UClass](ustruct)
    let scriptStruct = ueCast[UScriptStruct](ustruct)
    if not scriptStruct.isNil():
        eMeta = emScriptStruct   
        UE_Log "Found ScriptStruct " & propType & " creating Prop"
    else:
        UE_Log "Found Class " & propType & " creating Prop"

    some case eMeta:
    of emClass, emTSubclassOf:
        #check if it's a component here
        let clsProp = newFClassProperty(makeFieldVariant(outer), name, flags)
        clsProp.setPropertyMetaClass(cls)
        clsProp
    of emTSoftClassPtr:
        let clsProp = newFSoftClassProperty(makeFieldVariant(outer), name, flags)
        clsProp.setPropertyMetaClass(cls)
        clsProp
    of emObjPtr, emTObjectPtr:
        let isComponent = isChildOf[UActorComponent](cls)
        let objProp = newFObjectProperty(makeFieldVariant(outer), name, flags)
        objProp.setPropertyClass(cls)
        if isComponent: 
            objProp.setPropertyFlags(CPF_InstancedReference or CPF_NativeAccessSpecifierPublic or CPF_ExportObject)


        objProp
    of emTSoftObjectPtr:
        let softObjProp = newFSoftObjectProperty(makeFieldVariant(outer), name, flags)
        softObjProp.setPropertyClass(cls)
        softObjProp
    of emScriptStruct:
        let structProp = newFStructProperty(makeFieldVariant(outer), name, flags)
        structProp.setScriptStruct(scriptStruct)
        structProp


func newDelegateBasedProperty(outer : UStructPtr, propType:string, name:FName) : Option[FPropertyPtr] = 
    #Try to find it as Delegate
    const flags = propObjFlags
    UE_Log "Not a struct based prorperty. Trying as delegate.." & propType
    let delegateName = propType.removeFirstLetter() & DelegateFuncSuffix
    
    someNil(getUTypeByName[UDelegateFunction] delegateName)
        .map(func (delegate:UDelegateFunctionPtr) : FPropertyPtr = 
                let isMulticast = FUNC_MulticastDelegate in delegate.functionFlags
                if isMulticast:
                    UE_Log fmt("Found {propType}  as  MulticastDelegate. Creating prop")
                    let delegateProp = newFMulticastInlineDelegateProperty(makeFieldVariant(outer), name, flags)
                    delegateProp.setSignatureFunction(delegate)
                    delegateProp
                else:
                    UE_Log fmt("Found {propType}  as  Delegate. Creating prop")
                    let delegateProp = newFDelegateProperty(makeFieldVariant(outer), name, flags)
                    delegateProp.setSignatureFunction(delegate)
                    delegateProp
            )
    
func newEnumBasedProperty(outer : UStructPtr, propType:string, name:FName) : Option[FPropertyPtr] = 
    #Try to find it as Enum
    const flags = propObjFlags
    UE_Log "Not a delegate based prorperty. Trying as enum.." & propType
    let enumProp = propType.extractTypeFromGenericInNimFormat("TEnumAsByte")
    someNil(getUTypeByName[UEnum](enumProp))
        .map(func (ueEnum:UEnumPtr) : FPropertyPtr = 
                UE_Log "Found " & enumProp & " as Enum. Creating prop"
                let enumProp = newFEnumProperty(makeFieldVariant(outer), name, flags)
                enumProp.setEnum(ueEnum)
                #Assuming that Enums are exposed via TEnumAsByte or they are uint8. Revisit in the future (only bp exposed enums meets that)
                let underlayingProp : FPropertyPtr = newFByteProperty(makeFieldVariant(enumProp), n"UnderlayingEnumProp", flags)
                enumProp.addCppProperty(underlayingProp)
                enumProp
            )

func isBasicProperty*(nimTypeName: string) : bool =      
    nimTypeName in [
        "FString", "bool", "int8", "int16", "int32", "int64", "int", 
        "byte", "uint16", "uint32", "uint64", "float32", "float", "float64", 
        "FName"
    ]


       

proc newFProperty*(outer : UStructPtr | FFieldPtr, propField:UEField, optPropType="", optName="",  propFlags=CPF_None) : FPropertyPtr = 
    let 
        propType = optPropType.nonEmptyOr(propField.uePropType)
        name = optName.nonEmptyOr(propField.name).makeFName()

    const flags = propObjFlags

    let prop : FPropertyPtr = 
        if propType == "FString": 
            newFStrProperty(makeFieldVariant(outer), name, flags)
        elif propType == "bool": 
            newFBoolProperty(makeFieldVariant(outer), name, flags)
        elif propType == "int8": 
            newFInt8Property(makeFieldVariant(outer), name, flags)
        elif propType == "int16": 
            newFInt16Property(makeFieldVariant(outer), name, flags)
        elif propType == "int32": 
            newFIntProperty(makeFieldVariant(outer), name, flags)
        elif propType in ["int64", "int"]: 
            newFInt64Property(makeFieldVariant(outer), name, flags)
        elif propType == "byte": 
            newFByteProperty(makeFieldVariant(outer), name, flags)
        elif propType == "uint16": 
            newFUInt16Property(makeFieldVariant(outer), name, flags)
        elif propType == "uint32": 
            newFUInt32Property(makeFieldVariant(outer), name, flags)
        elif propType == "uint64": 
            newFUint64Property(makeFieldVariant(outer), name, flags)
        elif propType == "float32": 
            newFFloatProperty(makeFieldVariant(outer), name, flags)
        elif propType in ["float", "float64"]: 
            newFDoubleProperty(makeFieldVariant(outer), name, flags)
        elif propType == "FName": 
            newFNameProperty(makeFieldVariant(outer), name, flags)
        elif propType.contains("TArray"):
            let arrayProp = newFArrayProperty(makeFieldVariant(outer), name, flags)
            arrayProp.setPropertyFlags(CPF_ZeroConstructor)


            let innerType = propType.extractTypeFromGenericInNimFormat("TArray")
            let inner = newFProperty(outer, propField, optPropType=innerType, optName= $name & "_Inner")
            #TODO extract this so it can be easily apply to all instanced
            let isObjProp = not castField[FObjectProperty](inner).isNil() 
            if isObjProp: 
                discard
                # arrayProp.setPropertyFlags(CPF_UObjectWrapper)
                # arrayProp.setPropertyFlags(CPF_ContainsInstancedReference)
                # inner.setPropertyFlags(CPF_InstancedReference or CPF_NativeAccessSpecifierPublic or CPF_ExportObject)

            arrayProp.addCppProperty(inner)
            #Pywrapperfixed array
            
            let arrayValue = malloc(arrayProp.getSize(), arrayProp.getMinAlignment().uint32)
            arrayProp.initializeValue(arrayValue)


            arrayProp
        elif propType.contains("TSet"):
            let setProp = newFSetProperty(makeFieldVariant(outer), name, flags)
            let elementPropType = propType.extractTypeFromGenericInNimFormat("TSet")
            let elementProp = newFProperty(outer, propField, optPropType=elementPropType, optName="ElementProp",  propFlags=CPF_HasGetValueTypeHash)
            setProp.addCppProperty(elementProp)
            setProp
            
        elif propType.contains("TMap"):
            let mapProp = newFMapProperty(makeFieldVariant(outer), name, flags)
            let innerTypes = propType.extractKeyValueFromMapProp()
            let key = newFProperty(outer, propField, optPropType=innerTypes[0], optName= $name&"_Key", propFlags=CPF_HasGetValueTypeHash) 
            let value = newFProperty(outer, propField, optPropType=innerTypes[1], optName= $name&"_Value")
            

            mapProp.addCppProperty(key)
            mapProp.addCppProperty(value)

            let mapValue = malloc(mapProp.getSize(), mapProp.getMinAlignment().uint32)
            mapProp.initializeValue(mapValue)
            mapProp
        else: #ustruct based?
            newUStructBasedFProperty(cast[UStructPtr](outer), propType, name, propFlags)
                .chainNone(()=>newDelegateBasedProperty(cast[UStructPtr](outer), propType, name))
                .chainNone(()=>newEnumBasedProperty(cast[UStructPtr](outer), propType, name))
                .getOrRaise("FProperty not covered in the types for " & propType, Exception)
                    
        
    prop.setPropertyFlags(prop.getPropertyFlags() or propFlags) #in case custom fprop require custom flags (see TMAP)
    prop