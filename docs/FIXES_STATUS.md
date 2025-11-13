# MDE4CPP Build Fixes Status

## ✅ Fixed Issues

### 1. OCL Parser - FIXED ✅
**Problem**: CMake couldn't find `ANTLR_RELEASE` library  
**Root Cause**: The ANTLR shared library (`libantlr4-runtime.so`) was being built but not copied to `application/bin/` where CMake was looking for it. The gradle task only copied from `antlr4/bin/bin` but the library was actually in `antlr4/bin/lib`.

**Fix Applied**: Modified `/home/krish/Projects/RP/MDE4CPP/src/common/parser/build.gradle` to also copy shared libraries from the `lib` directory to `application/bin`:
```gradle
// Also copy shared libraries from lib directory (some platforms install .so/.dylib in lib)
copy {
    from "antlr4/bin/lib"
    into System.getenv('MDE4CPP_HOME')+"/application/bin"
    include "**/*.so", "**/*.dylib"
}
```

**Verification**: ✅ `gradlew :src:ocl:oclParser:compileOclParser` now builds successfully

---

## 🔧 In Progress

### 2. FoundationalModelLibrary - CMake NOTFOUND Variables
**Problem**: CMake reports variables set to NOTFOUND  
**Analysis Needed**: 
- Check what CMakeLists.txt is generated
- Determine which variables are missing
- Likely missing library dependencies (fUML, PSCS, etc.)

**Next Steps**:
1. Generate FoundationalModelLibrary code
2. Check generated CMakeLists.txt
3. Identify missing library paths
4. Fix CMake configuration or ensure dependencies are built first

---

## 📋 Remaining Issues

### 3. UML4CPP Profile - Acceleo UnsupportedOperationException
**Problem**: `org.eclipse.acceleo.engine.AcceleoRuntimeException: java.lang.UnsupportedOperationException`  
**Error Location**: `setGetHelper.generateGetImplementation(Class)(null.mtl:0)`

**Analysis**: This is an Acceleo template execution error. The `UnsupportedOperationException` suggests:
- Incompatibility between Acceleo version and the model structure
- Issues with OCL expression handling in Acceleo templates
- Possible Eclipse/Acceleo version mismatch

**Potential Fixes**:
1. Check Acceleo version compatibility
2. Update Eclipse/Acceleo plugins if needed
3. Check if there are known issues with this specific profile generation
4. May need to update Acceleo templates or generator code

### 4. Standard Profile - Acceleo UnsupportedOperationException  
**Problem**: Same as #3 - Acceleo template execution failure  
**Error Location**: Same `setGetHelper.generateGetImplementation` template

**Fix**: Same as #3 - likely a shared issue with Acceleo template execution

### 5. PSSM - Missing fUML Headers
**Problem**: `fatal error: fUML/FUMLFactory.hpp: No such file or directory`  
**Error**: PSSM compilation fails because fUML headers are not found

**Analysis**: 
- PSSM depends on fUML but fUML headers may not be in the include path
- Build order dependency - fUML may not be fully built/installed before PSSM compiles
- Include path configuration issue

**Potential Fixes**:
1. Ensure fUML is fully built before PSSM
2. Check include paths in PSSM CMakeLists.txt
3. Verify fUML headers are installed to `application/include`
4. Fix build dependencies in build.gradle

---

## Recommended Fix Order

1. ✅ OCL Parser (DONE)
2. FoundationalModelLibrary (CMake configuration)
3. PSSM (Include path/dependency fix)
4. UML4CPP Profile & Standard Profile (Acceleo template fix - likely one fix for both)

---

## Files Modified

1. `/home/krish/Projects/RP/MDE4CPP/src/common/parser/build.gradle` - Added copy task for ANTLR shared libraries

---

## Next Actions

1. Continue investigating FoundationalModelLibrary CMake error
2. Fix PSSM include path issues
3. Research and fix Acceleo template compatibility issues
4. Test all fixes with full `buildAll` command

