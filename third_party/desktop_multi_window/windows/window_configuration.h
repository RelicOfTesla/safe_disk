#pragma once

#include <string>
#include <flutter/encodable_value.h>
#include <iostream>

struct WindowConfiguration {
  std::string arguments;
  bool hidden_at_launch = false;
  std::string title;
  int width = 1280;
  int height = 720;

  static WindowConfiguration FromEncodableMap(
      const flutter::EncodableMap* map) {
    WindowConfiguration config;

    if (!map) return config;

    try {
      auto it = map->find(flutter::EncodableValue("arguments"));
      if (it != map->end()) {
        config.arguments = std::get<std::string>(it->second);
      }

      it = map->find(flutter::EncodableValue("hiddenAtLaunch"));
      if (it != map->end()) {
        config.hidden_at_launch = std::get<bool>(it->second);
      }

      it = map->find(flutter::EncodableValue("title"));
      if (it != map->end()) {
        config.title = std::get<std::string>(it->second);
      }
      it = map->find(flutter::EncodableValue("width"));
      if (it != map->end()) {
        config.width = std::get<int32_t>(it->second);
      }
      it = map->find(flutter::EncodableValue("height"));
      if (it != map->end()) {
        config.height = std::get<int32_t>(it->second);
      }
    } catch (const std::exception& e) {
      std::cerr << "Failed to parse WindowConfiguration: " << e.what()
                << std::endl;
    }

    return config;
  }
};
