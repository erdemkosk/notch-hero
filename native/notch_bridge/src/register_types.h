#pragma once

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_notch_bridge_module(ModuleInitializationLevel p_level);
void uninitialize_notch_bridge_module(ModuleInitializationLevel p_level);
