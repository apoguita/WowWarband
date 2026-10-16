/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This file is free software; as a special exception the author gives
 * unlimited permission to copy and/or distribute it, with or without
 * modifications, as long as this notice is preserved.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

// This file is generated from DynamicModuleLoader.cpp.in.cmake by CMake.

#include "Log.h"

#include <algorithm>
#include <array>
#include <filesystem>
#include <string>
#include <string_view>
#include <vector>

#if AC_PLATFORM == AC_PLATFORM_WINDOWS
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
#else
#  include <dlfcn.h>
#  include <unistd.h>
#endif

namespace
{
using ModuleEntryPoint = void (*)();
using ModuleStringFunction = char const* (*)();

std::filesystem::path GetExecutableDirectory()
{
#if AC_PLATFORM == AC_PLATFORM_WINDOWS
    std::wstring path(MAX_PATH, L'\0');
    DWORD length = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
    if (!length || length >= path.size())
        return std::filesystem::current_path();

    path.resize(length);
    return std::filesystem::path(path).parent_path();
#else
    std::array<char, 4096> path{};
    ssize_t length = readlink("/proc/self/exe", path.data(), path.size() - 1);
    if (length <= 0)
        return std::filesystem::current_path();

    return std::filesystem::path(std::string(path.data(), static_cast<size_t>(length))).parent_path();
#endif
}

void* OpenModule(std::filesystem::path const& path)
{
#if AC_PLATFORM == AC_PLATFORM_WINDOWS
    return static_cast<void*>(LoadLibraryW(path.c_str()));
#else
    return dlopen(path.string().c_str(), RTLD_NOW | RTLD_LOCAL);
#endif
}

void* FindModuleSymbol(void* handle, char const* name)
{
#if AC_PLATFORM == AC_PLATFORM_WINDOWS
    return reinterpret_cast<void*>(GetProcAddress(static_cast<HMODULE>(handle), name));
#else
    return dlsym(handle, name);
#endif
}

void CloseModule(void* handle)
{
#if AC_PLATFORM == AC_PLATFORM_WINDOWS
    FreeLibrary(static_cast<HMODULE>(handle));
#else
    dlclose(handle);
#endif
}
}

void LoadDynamicModulesScripts()
{
    static std::vector<void*> loadedModules;
    std::filesystem::path const moduleDirectory = GetExecutableDirectory() / "scripts";
    std::vector<std::filesystem::path> libraries;

    std::error_code error;
    for (std::filesystem::directory_iterator entry(moduleDirectory, error), end; !error && entry != end; entry.increment(error))
    {
        if (!entry->is_regular_file())
            continue;

        std::filesystem::path const path = entry->path();
        std::string filename = path.filename().string();
        if (filename.starts_with("lib"))
            filename.erase(0, 3);

        if (filename.starts_with("mod_") && (path.extension() == ".dll" || path.extension() == ".so" || path.extension() == ".dylib"))
            libraries.push_back(path);
    }

    std::sort(libraries.begin(), libraries.end());

    for (std::filesystem::path const& libraryPath : libraries)
    {
        void* handle = OpenModule(libraryPath);
        if (!handle)
        {
            LOG_ERROR("server.loading", "Failed to load dynamic module '{}'.", libraryPath.string());
            continue;
        }

        auto getModuleName = reinterpret_cast<ModuleStringFunction>(FindModuleSymbol(handle, "GetScriptModule"));
        auto getBuildDirective = reinterpret_cast<ModuleStringFunction>(FindModuleSymbol(handle, "GetModulesBuildDirective"));
        auto addModuleScripts = reinterpret_cast<ModuleEntryPoint>(FindModuleSymbol(handle, "AddModulesScripts"));

        if (!getModuleName || !getBuildDirective || !addModuleScripts)
        {
            LOG_ERROR("server.loading", "Dynamic module '{}' is missing required exports.", libraryPath.string());
            CloseModule(handle);
            continue;
        }

        if (std::string_view(getBuildDirective()) != AC_BUILD_TYPE)
        {
            LOG_ERROR("server.loading", "Dynamic module '{}' was built for a different configuration.", getModuleName());
            CloseModule(handle);
            continue;
        }

        LOG_INFO("server.loading", "Loading dynamic module '{}'.", getModuleName());
        addModuleScripts();
        loadedModules.push_back(handle);
    }
}
