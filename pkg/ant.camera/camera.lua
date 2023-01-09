local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mu, mc    = mathpkg.util, mathpkg.constant

local defcomp 	= import_package "ant.general".default
local imaterial = ecs.import.interface "ant.asset|imaterial"

local INV_Z<const> = true

local ic = ecs.interface "icamera"

local defaultcamera<const> = {
    name = "default_camera",
    eyepos  = mc.ZERO_PT,
    viewdir = mc.ZAXIS,
    updir   = mc.YAXIS,
    frustum = defcomp.frustum(),
}

function ic.create(info)
    info = info or defaultcamera
    local frustum = info.frustum
    if not frustum then
        frustum = defcomp.frustum()
    else
        local df = frustum.ortho and defcomp.ortho_frustum() or defcomp.frustum()
        for k ,v in pairs(df) do
            if not frustum[k] then
                frustum[k] = v
            end
        end
    end

    local policy = {
        "ant.general|name",
        "ant.camera|camera",
    }

    local exposure = info.exposure
    if exposure then
        policy[#policy+1] = "ant.camera|exposure"
    end

    local viewdir = info.viewdir or defaultcamera.viewdir
    local eyepos = info.eyepos or defaultcamera.eyepos
    local updir = info.updir or defaultcamera.updir

    return ecs.create_entity {
        policy = policy,
        data = {
            scene = {
                r = math3d.torotation(math3d.vector(viewdir)),
                t = eyepos,
                updir = updir,
            },
            exposure = exposure,
            camera = {
                frustum = frustum,
                clip_range = info.clip_range,
                dof     = info.dof,
                -- exposure = {
                --     type = 
                -- },
            },
            name = info.name or "DEFAULT_CAMERA",
        }
    }
end

function ic.calc_viewmat(ce)
    w:extend(ce, "scene:in")
    local scene = ce.scene
    local srt = scene
    return math3d.lookto(srt.t, math3d.todirection(srt.r), scene.updir)
end

function ic.calc_projmat(ce)
    w:extend(ce, "camera:in")
    local camera = ce.camera
    return math3d.projmat(camera.frustum)
end

function ic.calc_viewproj(ce)
    w:extend(ce, "camera:in scene:in")
    local scene = ce.scene
    local srt = scene
    local viewmat = math3d.lookto(srt.t, math3d.todirection(srt.r), scene.updir)
    local projmat = math3d.projmat(ce.camera.frustum)
    return math3d.mul(projmat, viewmat)
end

function ic.get_frustum(ce)
    w:extend(ce, "camera:in")
    return ce.camera.frustum
end

local function mark_camera_changed(ce, changed)
    w:extend(ce, "camera_changed?out")
    ce.camera_changed = changed
    w:submit(ce)
end

function ic.set_frustum(ce, frustum)
    w:extend(ce, "camera:in")
    local camera = ce.camera
    camera.frustum = {}
    for k, v in pairs(frustum) do
        camera.frustum[k] = v
    end
    mark_camera_changed(ce, true)
end

local function frustum_changed(ce, name, value)
    w:extend(ce, "camera:in")
    local camera = assert(ce.camera)
    local f = camera.frustum
    f[name] = value

    mark_camera_changed(ce, true)
end

function ic.set_frustum_aspect(ce, aspect)
    frustum_changed(ce, "aspect", aspect)
end

function ic.set_frustum_fov(ce, fov)
    frustum_changed(ce, "fov", fov)
end

function ic.set_frustum_near(ce, n)
    frustum_changed(ce, "n", n)
end

function ic.set_frustum_far(ce, f)
    frustum_changed(ce, "f", f)
end

local iom = ecs.import.interface "ant.objcontroller|iobj_motion"
function ic.lookto(ce, ...)
    iom.lookto(ce, ...)
end

function ic.focus_aabb(ce, aabb)
    local aabb_min, aabb_max= math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
    local center = math3d.mul(0.5, math3d.add(aabb_min, aabb_max))
    local nviewdir = math3d.sub(aabb_max, center)
    local viewdir = math3d.normalize(math3d.inverse(nviewdir))

    local pos = math3d.muladd(3, nviewdir, center)
    iom.lookto(ce, pos, viewdir)
end

function ic.focus_obj(ce, e)
    w:extend(e, "scene:in")
    local aabb = e.scene.scene_aabb
    if aabb then
        ic.focus_aabb(ce, aabb)
    end
end

local cameraview_sys = ecs.system "camera_view_system"

function cameraview_sys:start_frame()
    for ce in w:select "camera_changed?out" do
        ce.camerac_hanged = nil
    end
end

function cameraview_sys:entity_init()
    for e in w:select "INIT camera:in camera_changed?out" do
        local camera = e.camera
        camera.viewmat       = math3d.ref(math3d.matrix())
        camera.projmat       = math3d.ref(math3d.matrix())
        camera.viewprojmat   = math3d.ref(math3d.matrix())

        e.camera_changed    = true
    end
end

local function update_camera(e)
    local camera = e.camera
    camera.viewmat.m = math3d.inverse(e.scene.worldmat)
    camera.projmat.m = math3d.projmat(camera.frustum, INV_Z)
    camera.viewprojmat.m = math3d.mul(camera.projmat, camera.viewmat)
end

local function update_camera_info(e)
    local sa = imaterial.system_attribs()
    local camerapos = iom.get_position(e)
	local f = ic.get_frustum(e)
	sa:update("u_eyepos", camerapos)
    local nn, ff = f.n, f.f
    local inv_nn, inv_ff = 1.0/nn, 1.0/ff
	sa:update("u_camera_param", math3d.vector(nn, ff, inv_nn, inv_ff))
end

function cameraview_sys:update_mainview_camera()
    for v in w:select "main_queue camera_ref:in" do
        local e <close> = w:entity(v.camera_ref, "scene_changed?in camera_changed?in camera:in scene:in")
        if e.scene_changed or e.camera_changed then
            update_camera(e)
            update_camera_info(e)
        end
    end
end