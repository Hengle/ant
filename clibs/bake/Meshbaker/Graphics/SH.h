//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "glm/glm.hpp"
#include "Constants.h"

namespace Graphics
{

// Constants
static const float CosineA0 = Pi;
static const float CosineA1 = (2.0f * Pi) / 3.0f;
static const float CosineA2 = Pi / 4.0f;

template<typename T, uint64_t N> class SH
{

protected:

    void Assign(const SH& other)
    {
        for(uint64_t i = 0; i < N; ++i)
            Coefficients[i] = other.Coefficients[i];
    }

public:

    T Coefficients[N];

    SH()
    {
        for(uint64_t i = 0; i < N; ++i)
            Coefficients[i] = T(0.0f);
    }

    // Operator overloads
    T& operator[](uint64_t idx)
    {
        return Coefficients[idx];
    }

    T operator[](uint64_t idx) const
    {
        return Coefficients[idx];
    }

    SH& operator+=(const SH& other)
    {
        for(uint64_t i = 0; i < N; ++i)
            Coefficients[i] += other.Coefficients[i];
        return *this;
    }

    SH operator+(const SH& other) const
    {
        SH result;
        for(uint64_t i = 0; i < N; ++i)
            result.Coefficients[i] = Coefficients[i] + other.Coefficients[i];
        return result;
    }

    SH& operator-=(const SH& other)
    {
        for(uint64_t i = 0; i < N; ++i)
            Coefficients[i] -= other.Coefficients[i];
        return *this;
    }

    SH operator-(const SH& other) const
    {
        SH result;
        for(uint64_t i = 0; i < N; ++i)
            result.Coefficients[i] = Coefficients[i] - other.Coefficients[i];
        return result;
    }

    SH& operator*=(const T& scale)
    {
        for(uint64_t i = 0; i < N; ++i)
            Coefficients[i] *= scale;
        return *this;
    }

    SH operator*(const SH& other) const
    {
        SH result;
        for(uint64_t i = 0; i < N; ++i)
            result.Coefficients[i] = Coefficients[i] * other.Coefficients[i];
        return result;
    }

    SH& operator*=(const SH& other)
    {
        for(uint64_t i = 0; i < N; ++i)
            Coefficients[i] *= other.Coefficients[i];
        return *this;
    }

    SH operator*(const T& scale) const
    {
        SH result;
        for(uint64_t i = 0; i < N; ++i)
            result.Coefficients[i] = Coefficients[i] * scale;
        return result;
    }

    SH& operator/=(const T& scale)
    {
        for(uint32_t i = 0; i < N; ++i)
            Coefficients[i] /= scale;
        return *this;
    }

    SH operator/(const T& scale) const
    {
        SH result;
        for(uint64_t i = 0; i < N; ++i)
            result.Coefficients[i] = Coefficients[i] / scale;
        return result;
    }

    SH operator/(const SH& other) const
    {
        SH result;
        for(uint64_t i = 0; i < N; ++i)
            result.Coefficients[i] = Coefficients[i] / other.Coefficients[i];
        return result;
    }

    SH& operator/=(const SH& other)
    {
        for(uint64_t i = 0; i < N; ++i)
            Coefficients[i] /= other.Coefficients[i];
        return *this;
    }

    // Dot products
    T Dot(const SH& other) const
    {
        T result = 0.0f;
        for(uint64_t i = 0; i < N; ++i)
            result += Coefficients[i] * other.Coefficients[i];
        return result;
    }

    static T Dot(const SH& a, const SH& b)
    {
        T result = 0.0f;
        for(uint64_t i = 0; i < N; ++i)
            result += a.Coefficients[i] * b.Coefficients[i];
        return result;
    }

    // Convolution with cosine kernel
    void ConvolveWithCosineKernel()
    {
        Coefficients[0] *= CosineA0;

        for(uint64_t i = 1; i < N; ++i)
            if(i < 4)
                Coefficients[i] *= CosineA1;
            else if(i < 9)
                Coefficients[i] *= CosineA2;
    }

    template<typename TSerializer>
    void Serialize(TSerializer& serializer)
    {
        SerializeRawArray(serializer, Coefficients, N);
    }
};

// Spherical Harmonics
typedef SH<float, 4> SH4;
typedef SH<glm::vec3, 4> SH4Color;
typedef SH<float, 9> SH9;
typedef SH<glm::vec3, 9> SH9Color;

// H-basis
typedef SH<float, 4> H4;
typedef SH<glm::vec3, 4> H4Color;
typedef SH<float, 6> H6;
typedef SH<glm::vec3, 6> H6Color;

// For proper alignment with shader constant buffers
struct ShaderSH9Color
{
    glm::vec4 Coefficients[9];

    ShaderSH9Color()
    {
    }

    ShaderSH9Color(const SH9Color& sh9Clr)
    {
        for(uint32_t i = 0; i < 9; ++i)
            Coefficients[i] = glm::vec4(sh9Clr.Coefficients[i], 0.0f);
    }
};

SH4 ProjectOntoSH4(const glm::vec3& dir);
SH4Color ProjectOntoSH4Color(const glm::vec3& dir, const glm::vec3& color);
glm::vec3 EvalSH4Cosine(const glm::vec3& dir, const SH4Color& sh);

SH9 ProjectOntoSH9(const glm::vec3& dir);
SH9Color ProjectOntoSH9Color(const glm::vec3& dir, const glm::vec3& color);
glm::vec3 EvalSH9Cosine(const glm::vec3& dir, const SH9Color& sh);

// H-basis functions
H4 ProjectOntoH4(const glm::vec3& dir);
H4Color ProjectOntoH4Color(const glm::vec3& dir, const glm::vec3& color);
float EvalH4(const H4& h, const glm::vec3& dir);
H4 ConvertToH4(const SH9& sh);
H4Color ConvertToH4(const SH9Color& sh);
H6 ConvertToH6(const SH9& sh);
H6Color ConvertToH6(const SH9Color& sh);

// Lighting environment generation functions
//SH9Color ProjectCubemapToSH(ID3D11Device* device, ID3D11ShaderResourceView* cubeMap);

}