include ../unreal/prelude
import ../typegen/[uemeta]


#bind the type
const testActorUEType = UEType(name: "ATestActor", parent: "AActor", kind: uetClass, 
                    fields: @[
                        makeFieldAsUFun("SetColorByStringInMesh",
                        @[
                            makeFieldAsUProp("color", "FString")
                        ], 
                        "ATestActor"),
                        ])
genType(testActorUEType)

uClass ANimTestActor of ATestActor:
    (BlueprintType, Blueprintable)
    uprops(EditAnywhere, BlueprintReadWrite):
        name : FString 


proc regularNimFunction() = 
    UE_Log "This is a regular nim function"

uFunctions:
    proc tick(self:ANimTestActorPtr, deltaTime:float)  = 
        self.setColorByStringInMesh("(R=0,G=0.5,B=0.2,A=1)")
    
    proc beginPlay(self:ANimTestActorPtr) = 
        UE_Log "Que pasa another change did this carah"
        regularNimFunction()


