local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "moltenvk" {
    rootdir = ROOT,
    macos = {
        includes = {
            "3rd/MoltenVK/MoltenVK/include",
            "3rd/MoltenVK/Common",
            "3rd/MoltenVK/MoltenVKShaderConverter/SPIRV-Cross",
            "3rd/MoltenVK/MoltenVKShaderConverter/include",
            "3rd/MoltenVK/MoltenVKShaderConverter/glslang/External/spirv-tools/include",
            "3rd/MoltenVK/MoltenVKShaderConverter/glslang",
            "3rd/MoltenVK/MoltenVKShaderConverter",
            "3rd/MoltenVK/External/cereal/include",
            "3rd/MoltenVK/MoltenVK/MoltenVK/API",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Commands",
            "3rd/MoltenVK/MoltenVK/MoltenVK/GPUObjects",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Layers",
            "3rd/MoltenVK/MoltenVK/MoltenVK/OS",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Utility",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Vulkan",
            "3rd/MoltenVK/MoltenVKShaderConverter/glslang/OGLCompilersDLL",         
        },
        sources = {
            "3rd/MoltenVK/MoltenVK/MoltenVK/Commands/*.mm",
            "3rd/MoltenVK/MoltenVK/MoltenVK/GPUObjects/*.mm",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Layers/*.mm",
            "3rd/MoltenVK/MoltenVK/MoltenVK/OS/*.mm",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Utility/*.m",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Utility/*.mm",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Utility/*.cpp",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Vulkan/*.mm",
            "3rd/MoltenVK/Common/*.mm",
            "3rd/MoltenVK/MoltenVKShaderConverter/SPIRV-Cross/*.cpp",
            "/3rd/MoltenVK/MoltenVKShaderConverter/SPIRV-Cross/main.cpp",
            "3rd/MoltenVK/MoltenVKShaderConverter/glslang/SPIRV/*.cpp",
            "3rd/MoltenVK/MoltenVKShaderConverter/MoltenVKShaderConverter/*.cpp",
            "3rd/MoltenVK/MoltenVKShaderConverter/MoltenVKShaderConverter/*.mm",
            "3rd/MoltenVK/MoltenVKShaderConverter/glslang/glslang/MachineIndependent/*.cpp",
            "3rd/MoltenVK/MoltenVKShaderConverter/glslang/glslang/MachineIndependent/preprocessor/*.cpp",
            "3rd/MoltenVK/MoltenVKShaderConverter/glslang/glslang/GenericCodeGen/*.cpp",
            "3rd/MoltenVK/MoltenVKShaderConverter/glslang/glslang/OSDependent/Unix/*.cpp",
            "3rd/MoltenVK/MoltenVKShaderConverter/glslang/OGLCompilersDLL/*.cpp",
        },
        frameworks = {
            "IOSurface",
            "IOKit",
            "SystemConfiguration",
            "QuartzCore",
            "Foundation",
            "Metal",
        },
    },
    ios = {
        includes = {
            "3rd/MoltenVK/MoltenVK/MoltenVK/Layers",
            "3rd/MoltenVK/MoltenVK/MoltenVK/API",
            "3rd/MoltenVK/MoltenVK/MoltenVK/GPUObjects",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Utility",
            "3rd/MoltenVK/MoltenVK/MoltenVK/OS",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Commands",
            "3rd/MoltenVK/Common",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Vulkan",       
            "3rd/MoltenVK/MoltenVK/include",
            "3rd/MoltenVK/MoltenVKShaderConverter",
            "3rd/MoltenVK/MoltenVKShaderConverter/SPIRV-Cross",
            "3rd/MoltenVK/External/cereal/include",
        },
        sources = {
            "3rd/MoltenVK/MoltenVK/MoltenVK/Utility/*.m",
            "3rd/MoltenVK/MoltenVK/MoltenVK/OS/*.m",
            "3rd/MoltenVK/MoltenVK/MoltenVK/GPUObjects/*.mm",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Utility/*.mm",
            "3rd/MoltenVK/MoltenVK/MoltenVK/OS/*.mm",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Vulkan/*.mm",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Commands/*.mm",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Utility/*.cpp",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Layers/*.mm",
            "3rd/MoltenVK/MoltenVK/MoltenVK/Utility/*.cpp",
            "3rd/MoltenVK/Common/*.mm",
        },
        frameworks = {
            "IOSurface",
            "SystemConfiguration",
            "QuartzCore",
            "Foundation",
            "Metal",
            "UIKit"
        },
    },
}

lm:lua_source "render_core"{
    includes = {
        ROOT .. "3rd/bgfx/include",
        ROOT .. "3rd/bx/include",
        ROOT .. "clibs/bgfx",
        ROOT .. "3rd/math3d",
        ROOT .. "clibs/foundation",
        ROOT .. "clibs/luabind",
        ROOT .. "3rd/glm",
        ROOT .. "3rd/luaecs",
        ROOT .. "clibs/ecs",
        ROOT .. "pkg/ant.bundle/src",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
    },
    objdeps = "compile_ecs",
    sources = {
        "render/material.c",
        "render/render.cpp",
    },
    --[[
    macos = {
        deps = {
            "moltenvk",
        }
    },
    ios = {
        deps = {
            "moltenvk",
        }
    }
    ]]
}

lm:lua_source "render" {
    includes = {
        ROOT .. "3rd/math3d",
        ROOT .. "clibs/luabind",
        ROOT .. "3rd/luaecs",
        ROOT .. "3rd/glm",
        ROOT .. "clibs/ecs",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
    },
    sources = {
        "cull.cpp",
    },
    deps = "render_core",
}