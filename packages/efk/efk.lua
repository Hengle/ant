local ecs   = ...
local world = ecs.world
local w     = world.w

local efk_cb    = require "effekseer.callback"
local efk       = require "efk"
local fs        = require "filesystem"
local bgfx      = require "bgfx"
local image     = require "image"
local datalist  = require "datalist"
local math3d    = require "math3d"
local fileinterface = require "fileinterface"

local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local viewidmgr = renderpkg.viewidmgr

local assetmgr  = import_package "ant.asset"

local cr        = import_package "ant.compile_resource"

local itimer    = ecs.import.interface "ant.timer|itimer"

local efk_sys = ecs.system "efk_system"

local FxFiles = {}
do
    local FxNames = {
        sprite_unlit ={
            vs = "sprite_unlit_vs.fx.sc",
            fs = "model_unlit_ps.fx.sc",
            varying_path = "sprite_Unlit_varying.def.sc",
        },
        sprite_lit = {
            vs = "sprite_lit_vs.fx.sc", 
            fs = "model_lit_ps.fx.sc",
            varying_path = "sprite_Lit_varying.def.sc",
        },
        sprite_distortion = {
            vs = "sprite_distortion_vs.fx.sc", 
            fs = "model_distortion_ps.fx.sc",
            varying_path = "sprite_BackDistortion_varying.def.sc",
        },
        sprite_adv_unlit = {
            vs = "ad_sprite_unlit_vs.fx.sc", 
            fs = "ad_model_unlit_ps.fx.sc",
            varying_path = "sprite_AdvancedUnlit_varying.def.sc",
        },
        sprite_adv_lit = {
            vs = "ad_sprite_lit_vs.fx.sc", 
            fs = "ad_model_lit_ps.fx.sc",
            varying_path = "sprite_AdvancedLit_varying.def.sc",
        },
        sprite_adv_distortion = {
            vs = "ad_sprite_distortion_vs.fx.sc", 
            fs = "ad_model_distortion_ps.fx.sc",
            varying_path = "sprite_AdvancedBackDistortion_varying.def.sc",
        },

        model_unlit = {
            vs = "model_unlit_vs.fx.sc", 
            fs = "model_unlit_ps.fx.sc",
            varying_path = "model_Unlit_varying.def.sc",
        },
        model_lit = {
            vs = "model_lit_vs.fx.sc", 
            fs = "model_lit_ps.fx.sc",
            varying_path = "model_Lit_varying.def.sc",
        },
        model_distortion = {
            vs = "model_distortion_vs.fx.sc", 
            fs = "model_distortion_ps.fx.sc",
            varying_path = "model_BackDistortion_varying.def.sc",
        },
        model_adv_unlit = {
            vs = "ad_model_unlit_vs.fx.sc", 
            fs = "ad_model_unlit_ps.fx.sc",
            varying_path = "model_AdvancedUnlit_varying.def.sc",
        },
        model_adv_lit = {
            vs = "ad_model_lit_vs.fx.sc", 
            fs = "ad_model_lit_ps.fx.sc",
            varying_path = "model_Advancedlit_varying.def.sc",
        },
        model_adv_distortion = {
            vs = "ad_model_distortion_vs.fx.sc",
            fs = "ad_model_distortion_ps.fx.sc",
            varying_path = "model_AdvancedBackDistortion_varying.def.sc",
        },
    }

    for name, fx in pairs(FxNames) do
        local pkgpath = "/pkg/ant.efk/efkbgfx/shaders/"
        FxFiles[name] = assetmgr.load_fx{
            vs = pkgpath .. fx.vs,
            fs = pkgpath .. fx.fs,
            varying_path = pkgpath .. fx.varying_path,
        }
    end
end

local function preopen(filename)
    local _ <close> = fs.switch_sync()
    return cr.compile(filename):string()
end

local filefactory = fileinterface.factory { preopen = preopen }

local function shader_load(materialfile, shadername, stagetype)
    assert(materialfile == nil)
    local fx = assert(FxFiles[shadername], ("unkonw shader name:%s"):format(shadername))
    return fx[stagetype]
end

local TEXTURE_LOADED = {}
local function texture_load(texname, srgb)
    --TODO: need use srgb texture
    local _ <close> = fs.switch_sync()
    assert(texname:match "^/pkg" ~= nil)
    local filecontent = cr.read_file(texname)
    local cfg = datalist.parse(cr.read_file(texname .. "|main.cfg"))
    local ti = cfg.info
    if texname:lower():match "%.png$" then
        if ti.format == "RG8" then
            filecontent = image.png.gray2rgb(filecontent)
        else
            filecontent = image.convert(filecontent, "RGBA8")
        end
    end

    local mem = bgfx.memory_buffer(filecontent)
    local handle = bgfx.create_texture(mem, cfg.flag)
    TEXTURE_LOADED[handle] = texname
    return (handle & 0xffff)
end

local function texture_unload(texhandle)
    local tex = TEXTURE_LOADED[texhandle]
    assetmgr.unload(tex)
end

local function error_handle(msg)
    error(msg)
end

local function texture_find(_, id)
    return id
end

local effect_viewid<const> = viewidmgr.get "effect_view"
local efk_cb_handle, efk_ctx
function efk_sys:init()
    efk_cb_handle =  efk_cb.callback{
        shader_load     = shader_load,
        texture_load    = texture_load,
        texture_unload  = texture_unload,
        texture_map     = setmetatable({}, {__index = texture_find}),
        error           = error_handle,
    }

    efk_ctx = efk.create{
        max_count       = 2000,
        viewid          = effect_viewid,
        shader_load     = efk_cb.shader_load,
        texture_load    = efk_cb.texture_load,
        texture_get     = efk_cb.texture_get,
        texture_unload  = efk_cb.texture_unload,
        texture_handle  = efk_cb.texture_handle,
        userdata        = {
            callback = efk_cb_handle,
            filefactory = filefactory,
        }
    }
end

local function read_file(filename)
    local f<close> = fs.open(fs.path(filename), "rb")
    return f:read "a"
end

local function load_efk(filename)
    --TODO: not share every effect??
    return {
        handle = efk_ctx:create_effect(filename)
    }
end

function efk_sys:entity_init()
    for e in w:select "INIT efk:update" do
        assert(type(e.efk) == "string")
        effect_file_root = fs.path(e.efk):parent_path()
        e.efk = load_efk(e.efk)
        effect_file_root = nil
    end
end

local mq_vr_mb = world:sub{"viewrect_changed", "main_queue"}
local camera_changed = world:sub{"main_queue", "camera_changed"}
local camera_frustum_mb

local function update_framebuffer_texutre()
    local mq = w:singleton("main_queue", "render_target:in camera_ref:in")
    local rt = mq.render_target
    local fb = fbmgr.get(rt.fb_idx)
    efk_cb_handle.background = fb[1].handle

    local ce = world:entity(mq.camera_ref)
    local projmat = ce.camera.projmat
    local col3, col4 = math3d.index(projmat, 3, 4)
    local m33, m34 = math3d.index(col3, 3, 4)
    local m43, m44 = math3d.index(col4, 3, 4)
    efk_cb_handle.depth = {
        handle = fbmgr.get_depth(rt.fb_idx).handle,
        1.0, --depth buffer scale
        0.0, --depth buffer offset
        m33, m34,
        m43, m44,
    }
end

function efk_sys:init_world()
    local mq = w:singleton("main_queue", "camera_ref:in")
    camera_frustum_mb = world:sub{"camera_changed", mq.cameraref, "frustum"}
    --let it init
    world:pub{"camera_changed", mq.cameraref, "frustum"}
end

function efk_sys:camera_usage()
    for _, _, cameraref in camera_changed:unpack() do
        camera_frustum_mb = world:sub{"camera_changed", cameraref, "frustum"}
        update_framebuffer_texutre()
    end

    for _ in camera_frustum_mb:each() do
        update_framebuffer_texutre()
    end

    for _ in mq_vr_mb:each() do
        update_framebuffer_texutre()
    end
end

--TODO: need remove, should put it on the ltask
function efk_sys:render_submit()
    local mq = w:singleton("main_queue", "camera_ref:in render_target:in")
    local ce = world:entity(mq.camera_ref)
    local camera = ce.camera
    local vr = mq.render_target.view_rect
    bgfx.set_view_rect(effect_viewid, vr.x, vr.y, vr.w, vr.h)
    efk_ctx:render(math3d.value_ptr(camera.viewmat), math3d.value_ptr(camera.projmat), itimer.delta())
end


local iefk = ecs.interface "iefk"
function iefk.play(e, p)
    return efk_ctx:play(e.efk.handle, p)
end

function iefk.stop(efkhandle)
    efk_ctx:stop(efkhandle)
end