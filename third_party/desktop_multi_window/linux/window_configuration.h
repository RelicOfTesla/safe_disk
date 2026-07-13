#pragma once

#include <flutter_linux/flutter_linux.h>
#include <string>

struct WindowConfiguration {
  std::string arguments;
  bool hidden_at_launch = false;
  std::string title;
  int width = 1280;
  int height = 720;

  static WindowConfiguration FromFlValue(FlValue* value) {
    WindowConfiguration config;

    if (!value || fl_value_get_type(value) != FL_VALUE_TYPE_MAP) {
      return config;
    }

    FlValue* arguments_value = fl_value_lookup_string(value, "arguments");
    if (arguments_value &&
        fl_value_get_type(arguments_value) == FL_VALUE_TYPE_STRING) {
      config.arguments = fl_value_get_string(arguments_value);
    }

    FlValue* hidden_value = fl_value_lookup_string(value, "hiddenAtLaunch");
    if (hidden_value && fl_value_get_type(hidden_value) == FL_VALUE_TYPE_BOOL) {
      config.hidden_at_launch = fl_value_get_bool(hidden_value);
    }

    FlValue* title_value = fl_value_lookup_string(value, "title");
    if (title_value && fl_value_get_type(title_value) == FL_VALUE_TYPE_STRING) {
      config.title = fl_value_get_string(title_value);
    }
    FlValue* width_value = fl_value_lookup_string(value, "width");
    if (width_value && fl_value_get_type(width_value) == FL_VALUE_TYPE_INT) {
      config.width = static_cast<int>(fl_value_get_int(width_value));
    }
    FlValue* height_value = fl_value_lookup_string(value, "height");
    if (height_value && fl_value_get_type(height_value) == FL_VALUE_TYPE_INT) {
      config.height = static_cast<int>(fl_value_get_int(height_value));
    }

    return config;
  }

  FlValue* ToFlValue() const {
    g_autoptr(FlValue) result = fl_value_new_map();

    fl_value_set_string_take(result, "arguments",
                             fl_value_new_string(arguments.c_str()));

    fl_value_set_string_take(result, "hiddenAtLaunch",
                             fl_value_new_bool(hidden_at_launch));
    fl_value_set_string_take(result, "title", fl_value_new_string(title.c_str()));
    fl_value_set_string_take(result, "width", fl_value_new_int(width));
    fl_value_set_string_take(result, "height", fl_value_new_int(height));

    return fl_value_ref(result);
  }
};
