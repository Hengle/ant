#include <lua.hpp>
#include <cassert>
#include <cstring>

#include <bgfx/c99/bgfx.h>

#include "efkbgfx/renderer/bgfxrenderer.h"
#include "../../clibs/bgfx/bgfx_interface.h"
#include "../../clibs/fileinterface/fileinterface.h"
#include <Effekseer/Effekseer.DefaultEffectLoader.h>

class efk_ctx {
public:
    efk_ctx() = default;
    ~efk_ctx() = default;

    EffekseerRenderer::RendererRef renderer;
    Effekseer::ManagerRef manager;
    struct file_interface *fi;

    struct effect {
        Effekseer::EffectRef eff;
        Effekseer::Handle    handle;
    };
    std::vector<effect>   effects;
};

class EfkFileInterface : public Effekseer::FileInterface {
public:
    EfkFileInterface(struct file_interface *fi_) : fi(fi_) {}
    virtual ~EfkFileInterface() = default;
    virtual Effekseer::FileReaderRef OpenRead(const char16_t* path) override {
        char utf8_path[1024];
		Effekseer::ConvertUtf16ToUtf8(utf8_path, 1024, path);
        file_handle handle = file_open(fi, utf8_path, "rb");
        return Effekseer::MakeRefPtr<FileReader>(fi, handle);
    }

    virtual Effekseer::FileWriterRef OpenWrite(const char16_t *path) override {
        assert(false &&"invalid call");
        return nullptr;
    }

private:
    class FileReader : public Effekseer::FileReader{
    public:
        FileReader(struct file_interface* fi_, file_handle h_):fi(fi_), handle(h_){}
        virtual ~FileReader() {
            file_close(fi, handle);
        }
        virtual size_t Read(void* buffer, size_t size) override{
            return file_read(fi, handle, buffer, size);
        }
        virtual void Seek(int p) override{
            file_seek(fi, handle, p, SEEK_SET);
        }
        virtual int GetPosition() const override{
            return (int)file_tell(fi, handle);
        }
        virtual size_t GetLength() const override{
            const size_t ll = file_tell(fi, handle);
            file_seek(fi, handle, 0, SEEK_END);
            const size_t l = file_tell(fi, handle);
            file_seek(fi, handle, ll, SEEK_SET);
            return l;
        }
    private:
        struct file_interface* fi;
        file_handle handle;
    };
private:
    struct file_interface* fi;
};

static efk_ctx*
EC(lua_State *L){
    return (efk_ctx*)lua_touserdata(L, 1);
}

static int
lefkctx_render(lua_State *L){
    auto ctx = EC(L);
    auto viewmat = (Effekseer::Matrix44*)lua_touserdata(L, 2);
    auto projmat = (Effekseer::Matrix44*)lua_touserdata(L, 3);
    auto delta = (float)luaL_checknumber(L, 4);

    ctx->renderer->SetCameraMatrix(*viewmat);
    ctx->renderer->SetProjectionMatrix(*projmat);
    ctx->manager->Update(delta);
    ctx->renderer->BeginRendering();
    Effekseer::Manager::DrawParameter drawParameter;
    drawParameter.ZNear = 0.0f;
    drawParameter.ZFar = 1.0f;
    drawParameter.ViewProjectionMatrix = ctx->renderer->GetCameraProjectionMatrix();
    ctx->manager->Draw(drawParameter);
    ctx->renderer->EndRendering();
    return 0;
}

static int
lefkctx_destroy(lua_State *L){
    auto ctx = EC(L);
    ctx->manager.Reset();
    ctx->renderer.Reset();
    ctx->~efk_ctx();
    return 0;
}

static int
lefkctx_create_effect(lua_State *L){
    auto ctx = EC(L);
    auto filename = luaL_checkstring(L, 2);
    const float mag = (float)luaL_optnumber(L, 3, 1.f);
    char16_t u16_filename[1024];
    Effekseer::ConvertUtf8ToUtf16(u16_filename, 1024, filename);
    auto eff = Effekseer::Effect::Create(ctx->manager, u16_filename, mag);
    if (eff == nullptr){
        return luaL_error(L, "create effect failed, filename:%s", filename);
    }
    auto it = std::find_if(std::begin(ctx->effects), std::end(ctx->effects),
        [](const efk_ctx::effect &e){
            return (e.eff == nullptr);
        }
    );
    it = ctx->effects.emplace(it, efk_ctx::effect{eff, 0});
    auto handle = std::distance(it, ctx->effects.begin());
    lua_pushinteger(L, handle);
    return 1;
}

static bool
check_effect_valid(efk_ctx *ctx, int handle){
    return 0 <= handle && handle < ctx->effects.size();
}

static int
lefkctx_destroy_effect(lua_State *L){
    auto ctx = EC(L);
    auto handle = (int)luaL_checkinteger(L, 2);
    if (!check_effect_valid(ctx, handle)){
        return luaL_error(L, "invalid handle: %d", handle);
    }

    auto e = ctx->effects[handle];
    ctx->effects[handle] = {nullptr, INT_MAX};
    e.eff = nullptr;
    return 0;
}

static int
lefkctx_play(lua_State *L){
    auto ctx = EC(L);
    auto handle = (int)luaL_checkinteger(L, 2);
    assert(check_effect_valid(ctx, handle));

    auto effhandle = ctx->manager->Play(ctx->effects[handle].eff, 0, 0, 0);
    lua_pushinteger(L, effhandle);
    return 1;
}

static int
lefkctx_stop(lua_State *L){
    auto ctx = EC(L);
    auto effhandle = (Effekseer::Handle)luaL_checkinteger(L, 2);
    ctx->manager->StopEffect(effhandle);
    return 0;
}


static int
lefk_create(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);

    EffekseerRendererBGFX::InitArgs efkArgs;

    auto get_field = [L](const char* name, int idx, int luatype, auto op){
        auto ltype = lua_getfield(L, idx, name);
        if (luatype == ltype){
            op();
        } else {
            luaL_error(L, "invalid field:%s, miss match type:%s, %s", lua_typename(L, ltype), lua_typename(L, luatype));
        }

        lua_pop(L, 1);
    };
    
    get_field("max_count",  1, LUA_TNUMBER, [&](){efkArgs.squareMaxCount = (int)lua_tointeger(L, -1);});
    get_field("viewid",     1, LUA_TNUMBER, [&](){efkArgs.viewid = (bgfx_view_id_t)lua_tointeger(L, -1);});

    efkArgs.bgfx = bgfx_inf_;

    get_field("shader_load",    1, LUA_TLIGHTUSERDATA, [&](){efkArgs.shader_load = (decltype(efkArgs.shader_load))lua_touserdata(L, -1);});
    get_field("texture_load",   1, LUA_TLIGHTUSERDATA, [&](){efkArgs.texture_load = (decltype(efkArgs.texture_load))lua_touserdata(L, -1);});
    get_field("texture_get",    1, LUA_TLIGHTUSERDATA, [&](){efkArgs.texture_get = (decltype(efkArgs.texture_get))lua_touserdata(L, -1);});
    get_field("texture_unload", 1, LUA_TLIGHTUSERDATA, [&](){efkArgs.texture_unload = (decltype(efkArgs.texture_unload))lua_touserdata(L, -1);});
    get_field("texture_handle", 1, LUA_TLIGHTUSERDATA, [&](){efkArgs.texture_handle = (decltype(efkArgs.texture_handle))lua_touserdata(L, -1);});
    struct file_interface *fi = nullptr;
    get_field("userdata", 1, LUA_TTABLE, [&](){
        get_field("callback", -1, LUA_TUSERDATA, [&](){efkArgs.ud = lua_touserdata(L, -1);});
        get_field("filefactory", -1, LUA_TUSERDATA, [&](){fi = (struct file_interface*)lua_touserdata(L, -1);});
    });

    auto ctx = (efk_ctx*)lua_newuserdatauv(L, sizeof(efk_ctx), 0);
    if (luaL_newmetatable(L, "EFK_CTX")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_Reg l[] = {
            {"__gc",            lefkctx_destroy},
            {"render",          lefkctx_render},
            {"create_effect",   lefkctx_create_effect},
            {"destroy_effect",  lefkctx_destroy_effect},
            {"play",            lefkctx_play},
            {"stop",            lefkctx_stop},
            {nullptr, nullptr},
        };

        luaL_setfuncs(L, l, 0);
    }
    lua_setmetatable(L, -2);

    new (ctx) efk_ctx();

    ctx->fi = fi;

    ctx->renderer = EffekseerRendererBGFX::CreateRenderer(&efkArgs);
    if (ctx->renderer == nullptr){
        return luaL_error(L, "create efkbgfx renderer failed");
    }
	ctx->manager = Effekseer::Manager::Create(efkArgs.squareMaxCount);
	ctx->manager->GetSetting()->SetCoordinateSystem(Effekseer::CoordinateSystem::LH);

    auto efk_fi = Effekseer::MakeRefPtr<EfkFileInterface>(fi);
    ctx->manager->SetModelRenderer(CreateModelRenderer(ctx->renderer, &efkArgs));
    ctx->manager->SetSpriteRenderer(ctx->renderer->CreateSpriteRenderer());
    ctx->manager->SetRibbonRenderer(ctx->renderer->CreateRibbonRenderer());
    ctx->manager->SetRingRenderer(ctx->renderer->CreateRingRenderer());
    ctx->manager->SetTrackRenderer(ctx->renderer->CreateTrackRenderer());
    ctx->manager->SetEffectLoader(Effekseer::MakeRefPtr<Effekseer::DefaultEffectLoader>(efk_fi));
    ctx->manager->SetTextureLoader(ctx->renderer->CreateTextureLoader(efk_fi));
    ctx->manager->SetModelLoader(ctx->renderer->CreateModelLoader(efk_fi));
    ctx->manager->SetMaterialLoader(ctx->renderer->CreateMaterialLoader(efk_fi));
    ctx->manager->SetCurveLoader(Effekseer::MakeRefPtr<Effekseer::CurveLoader>());

    return 1;
}

extern "C" int
luaopen_efk(lua_State* L) {
    luaL_Reg lib[] = {
        { "create", lefk_create},
        { nullptr, nullptr },
    };
    luaL_newlib(L, lib);
    return 1;
}