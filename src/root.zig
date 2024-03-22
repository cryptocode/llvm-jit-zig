const std = @import("std");

const llvm = @cImport({
    @cInclude("llvm-c/Core.h");
    @cInclude("llvm-c/LLJIT.h");
    @cInclude("llvm-c/Support.h");
    @cInclude("llvm-c/Target.h");
});

pub fn createDemoModule() llvm.LLVMOrcThreadSafeModuleRef {
    const TSCtx: llvm.LLVMOrcThreadSafeContextRef = llvm.LLVMOrcCreateNewThreadSafeContext();

    // Get a reference to the underlying LLVMContext.
    const Ctx: llvm.LLVMContextRef = llvm.LLVMOrcThreadSafeContextGetContext(TSCtx);

    // Create a new c.LLVM module.
    const M: llvm.LLVMModuleRef = llvm.LLVMModuleCreateWithNameInContext("demo", Ctx);

    // Add a "sum" function":
    var ParamTypes = [_]?*llvm.LLVMOpaqueType{ llvm.LLVMInt32Type(), llvm.LLVMInt32Type() };
    const SumFunctionType: llvm.LLVMTypeRef = llvm.LLVMFunctionType(llvm.LLVMInt32Type(), &ParamTypes, 2, 0);
    const SumFunction: llvm.LLVMValueRef = llvm.LLVMAddFunction(M, "sum", SumFunctionType);

    // Add a basic block to the function.
    const EntryBB: llvm.LLVMBasicBlockRef = llvm.LLVMAppendBasicBlock(SumFunction, "entry");

    // Add an IR builder and point it at the end of the basic block.
    const Builder: llvm.LLVMBuilderRef = llvm.LLVMCreateBuilder();
    llvm.LLVMPositionBuilderAtEnd(Builder, EntryBB);

    // Add instruction using the two function parameters
    const Result: llvm.LLVMValueRef = llvm.LLVMBuildAdd(
        Builder,
        llvm.LLVMGetParam(SumFunction, 0),
        llvm.LLVMGetParam(SumFunction, 1),
        "result",
    );

    // Build the return instruction.
    _ = llvm.LLVMBuildRet(Builder, Result);

    // Free the builder.
    llvm.LLVMDisposeBuilder(Builder);

    // Our demo module is now complete. Wrap it and our ThreadSafeContext in a ThreadSafeModule.
    const TSM: llvm.LLVMOrcThreadSafeModuleRef = llvm.LLVMOrcCreateNewThreadSafeModule(M, TSCtx);

    // Dispose of our local ThreadSafeContext value. The underlying c.LLVMContext
    // will be kept alive by our ThreadSafeModule, TSM.
    llvm.LLVMOrcDisposeThreadSafeContext(TSCtx);

    // Return the result.
    return TSM;
}

pub fn add(a: i32, b: i32) !i32 {
    const TSM = createDemoModule();

    // Initialize native target codegen and asm printer.
    _ = llvm.LLVMInitializeNativeTarget();
    _ = llvm.LLVMInitializeNativeAsmPrinter();

    var J: llvm.LLVMOrcLLJITRef = undefined;
    if (llvm.LLVMOrcCreateLLJIT(&J, null) != null) return error.LLVMError;
    defer _ = llvm.LLVMOrcDisposeLLJIT(J);

    const MainJD: llvm.LLVMOrcJITDylibRef = llvm.LLVMOrcLLJITGetMainJITDylib(J);
    if (llvm.LLVMOrcLLJITAddLLVMIRModule(J, MainJD, TSM) != null) {
        llvm.LLVMOrcDisposeThreadSafeModule(TSM);
    }
    var SumAddr: llvm.LLVMOrcJITTargetAddress = undefined;
    if (llvm.LLVMOrcLLJITLookup(J, &SumAddr, "sum") != null) return error.LLVMError;

    const sum: *const fn (i32, i32) i32 = @ptrFromInt(SumAddr);
    return sum(a, b);
}
