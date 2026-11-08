#!/usr/bin/env python3
"""Run a Lua file with the system's liblua5.4 via ctypes. Usage: runlua.py file.lua [args...]"""
import ctypes, sys

lua = ctypes.CDLL("liblua5.4.so.0")
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_pushstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_setglobal.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_createtable.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
lua.lua_rawseti.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_longlong]

L = lua.luaL_newstate()
lua.luaL_openlibs(L)

# arg table
lua.lua_createtable(L, len(sys.argv), 0)
for i, a in enumerate(sys.argv[2:], start=1):
    lua.lua_pushstring(L, a.encode())
    lua.lua_rawseti(L, -2, i)
lua.lua_setglobal(L, b"arg")

if lua.luaL_loadfilex(L, sys.argv[1].encode(), None) != 0:
    print("LOAD ERROR:", lua.lua_tolstring(L, -1, None).decode())
    sys.exit(2)
if lua.lua_pcallk(L, 0, 0, 0, None, None) != 0:
    print("RUNTIME ERROR:", lua.lua_tolstring(L, -1, None).decode())
    sys.exit(1)
