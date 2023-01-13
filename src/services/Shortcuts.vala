/* Shortcuts.vala
 *
 * Copyright 2022 Paulo Queiroz <pvaqueiroz@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Terminal {
  public const string ACTION_FOCUS_NEXT_TAB             = "app.focus-next-tab";
  public const string ACTION_FOCUS_PREVIOUS_TAB         = "app.focus-previous-tab";
  public const string ACTION_NEW_WINDOW                 = "app.new-window";

  public const string ACTION_WIN_SWITCH_HEADER_BAR_MODE = "win.switch-headerbar-mode";
  public const string ACTION_WIN_NEW_TAB                = "win.new_tab";
  public const string ACTION_WIN_EDIT_PREFERENCES       = "win.edit_preferences";
  public const string ACTION_WIN_COPY                   = "win.copy";
  public const string ACTION_WIN_PASTE                  = "win.paste";
  public const string ACTION_WIN_SEARCH                 = "win.search";
  public const string ACTION_WIN_FULLSCREEN             = "win.fullscreen";
  public const string ACTION_WIN_SHOW_HELP_OVERLAY      = "win.show-help-overlay";
  public const string ACTION_WIN_ZOOM_IN                = "win.zoom-in";
  public const string ACTION_WIN_ZOOM_OUT               = "win.zoom-out";
  public const string ACTION_WIN_ZOOM_DEFAULT           = "win.zoom-default";
  public const string ACTION_WIN_CLOSE_TAB              = "win.close-tab";

  public const string ACTION_WIN_SWITCH_TAB_1           = "win.switch-tab-1";
  public const string ACTION_WIN_SWITCH_TAB_2           = "win.switch-tab-2";
  public const string ACTION_WIN_SWITCH_TAB_3           = "win.switch-tab-3";
  public const string ACTION_WIN_SWITCH_TAB_4           = "win.switch-tab-4";
  public const string ACTION_WIN_SWITCH_TAB_5           = "win.switch-tab-5";
  public const string ACTION_WIN_SWITCH_TAB_6           = "win.switch-tab-6";
  public const string ACTION_WIN_SWITCH_TAB_7           = "win.switch-tab-7";
  public const string ACTION_WIN_SWITCH_TAB_8           = "win.switch-tab-8";
  public const string ACTION_WIN_SWITCH_TAB_9           = "win.switch-tab-9";
  public const string ACTION_WIN_SWITCH_TAB_LAST        = "win.switch-tab-last";
}

// We load the user's keybindings and use them to override the default keymap.
// This way, if we release a new version with an extra action that isn't present
// in the user's file, we'll just use the default shortcut.

public class Terminal.Keymap : Object, Json.Serializable {
  // User defined keybindings
  public Gee.MultiMap<string, string?> keymap { get; protected set; }
  // Black Box's default keybindings.
  private Gee.MultiMap<string, string?> default_keymap;

  construct {
    this.default_keymap = new Gee.HashMultiMap<string, string> ();

    this.default_keymap.set (ACTION_FOCUS_NEXT_TAB,              "<Control>Tab");
    this.default_keymap.set (ACTION_FOCUS_PREVIOUS_TAB,          "<Shift><Control>Tab");
    this.default_keymap.set (ACTION_NEW_WINDOW,                  "<Shift><Control>n");
    this.default_keymap.set (ACTION_WIN_SWITCH_HEADER_BAR_MODE,  "<Shift><Control>h");
    this.default_keymap.set (ACTION_WIN_NEW_TAB,                 "<Shift><Control>t");
    this.default_keymap.set (ACTION_WIN_EDIT_PREFERENCES,        "<Control>comma");
    this.default_keymap.set (ACTION_WIN_COPY,                    "<Shift><Control>c");
    this.default_keymap.set (ACTION_WIN_PASTE,                   "<Shift><Control>v");
    this.default_keymap.set (ACTION_WIN_SEARCH,                  "<Shift><Control>f");
    this.default_keymap.set (ACTION_WIN_FULLSCREEN,              "F11");
    this.default_keymap.set (ACTION_WIN_SHOW_HELP_OVERLAY,       "<Shift><Control>question");
    this.default_keymap.set (ACTION_WIN_ZOOM_IN,                 "<Shift><Control>plus");
    this.default_keymap.set (ACTION_WIN_ZOOM_OUT,                "<Control>minus");
    this.default_keymap.set (ACTION_WIN_ZOOM_DEFAULT,            "<Shift><Control>0");
    this.default_keymap.set (ACTION_WIN_CLOSE_TAB,               "<Shift><Control>w");

    this.default_keymap.set (ACTION_WIN_SWITCH_TAB_1,            "<Alt>1");
    this.default_keymap.set (ACTION_WIN_SWITCH_TAB_2,            "<Alt>2");
    this.default_keymap.set (ACTION_WIN_SWITCH_TAB_3,            "<Alt>3");
    this.default_keymap.set (ACTION_WIN_SWITCH_TAB_4,            "<Alt>4");
    this.default_keymap.set (ACTION_WIN_SWITCH_TAB_5,            "<Alt>5");
    this.default_keymap.set (ACTION_WIN_SWITCH_TAB_6,            "<Alt>6");
    this.default_keymap.set (ACTION_WIN_SWITCH_TAB_7,            "<Alt>7");
    this.default_keymap.set (ACTION_WIN_SWITCH_TAB_8,            "<Alt>8");
    this.default_keymap.set (ACTION_WIN_SWITCH_TAB_9,            null);
    this.default_keymap.set (ACTION_WIN_SWITCH_TAB_LAST,         "<Alt>9");
  }

  // Private constructor
  private Keymap () {}

  private static Keymap? instance = null;

  public static Keymap get_default () {
    if (instance != null) {
      return instance;
    }

    // FIXME: initialize `keymap` prop in `construct` and just instanciate
    // Keymap manually if there's no user-keymap.json

    var f = new File (Constants.get_user_keybindings_path ());

    if (FileUtils.test (f.path, FileTest.EXISTS | FileTest.IS_REGULAR)) {
      try {
        string data = f.read_all (null);

        instance = (Keymap) Json.gobject_from_data (
          typeof (Keymap),
          data
        );
        instance.sanitize_user_keymap ();

        return instance;
      }
      catch (Error e) {
        warning ("Failed to read user keymap: %s", e.message);
      }
    }

    message ("User keybindings file not found, falling back to default");

    instance = new Keymap ();
    instance.reset_user_keymap ();

    return instance;
  }

  // If a user has custom keybindings and Black Box introduces a new action,
  // that user won't have the new action on their config file. In that scenario,
  // we'll add the new default keybinding to the user's file, unless the new
  // key combination is already in use, in which case we'll set it to null.
  private void sanitize_user_keymap () {
    bool did_sanitize = false;

    foreach (string action in this.default_keymap.get_keys ()) {
      if (!this.keymap.contains (action)) {
        foreach (string? accel in this.default_keymap.@get (action)) {
          // If the default shortcut for the new action is not null and not in
          if (accel == null || this.get_action_for_shortcut (accel) == null) {
            did_sanitize = true;
            this.keymap.@set (action, accel);
          }
        }
      }
      // If we still did not find a suitable default for this action, set it to
      // null.
      if (!this.keymap.contains (action)) {
        this.keymap.@set (action, null);
      }
    }

    if (did_sanitize) {
      debug ("Sanitizing user keymap");
      this.save ();
    }
  }

  public void reset_user_keymap () {
    this.keymap = new Gee.HashMultiMap<string, string> ();
    foreach (string action in this.default_keymap.get_keys ()) {
      message (action);
      foreach (string? accel in this.default_keymap.@get (action)) {
        this.keymap.@set (action, accel);
      }
    }
  }

  public void apply (Gtk.Application app) {
    foreach (string key in this.keymap.get_keys ()) {
      string[] accelerators = this.keymap.@get (key).to_array ();
      string[] filtered_accelerators = {};

      foreach (string? accel in accelerators) {
        if (accel != null) {
          filtered_accelerators += accel;
        }
      }

      app.set_accels_for_action (key, accelerators);
    }
  }

  public void save () {
    var data = Json.gobject_to_data (this, null);
    var f = new File (Constants.get_user_keybindings_path ());

    try {
      f.write_plus (data);
      debug ("Save:\n%s", data);
    }
    catch (Error e) {
      warning ("Could not save user keymap: %s", e.message);
    }
  }

  public string[]? get_default_shortcut_for_action (string action) {
    return this.default_keymap.contains (action)
      ? this.default_keymap.@get (action).to_array ()
      : null;
  }

  public string?[] get_accelerators_for_action (string action) {
    string[] empty = {};

    if (this.keymap.contains (action)) {
      var user_accelerators = this.keymap.@get (action).to_array ();
      if (user_accelerators.length > 0) {
        return user_accelerators;
      }
    }

    return empty;
  }

  public void set_shortcut_for_action (string action, string? accel) {
    this.keymap.remove_all (action);
    this.keymap.@set (action, accel);
  }

  public string? get_action_for_shortcut (string shortcut) {
    foreach (string action in this.keymap.get_keys ()) {
      if (this.keymap.@get (action).contains (shortcut)) {
        return action;
      }
    }
    return null;
  }

  public void reset_shortcut_for_action (string action) {
    string[]? _default = this.get_default_shortcut_for_action (action);

    if (_default == null) {
      this.set_shortcut_for_action (action, null);
    }
    else {
      foreach (unowned string shortcut in _default) {
        this.set_shortcut_for_action (action, shortcut);
      }
    }
  }

  public override bool deserialize_property (
    string    name,
    out Value @value,
    ParamSpec spec,
    Json.Node node
  ) {
    debug ("Deserializing %s", name);
    switch (name) {
      case "keymap": {
        var map = new Gee.HashMultiMap<string, string?> ();

        // keymap object
        var obj = node.get_object ();
        // foeach key/value pair
        obj?.foreach_member ((_obj, key, val) => {
          // get the accelerators array
          var arr = val.get_array ();
          if (arr == null) return;

          if (arr.get_length () == 0) {
            map.@set (key, null);
          }

          // add each accelerator for this action
          arr.foreach_element ((_arr, i, element) => {
            var str = element.get_string ();
            if (str != null) {
              map.@set (key, str);
            }
          });
        });

        @value = map;

        return true;
      }
    }
    return default_deserialize_property (name, out @value, spec, node);
  }

  public override Json.Node serialize_property (
    string name,
    Value @value,
    ParamSpec spec
  ) {
    switch (name) {
      case "keymap": {
        var keymap_object = new Json.Object ();

        foreach (string key in this.keymap.get_keys ()) {
          string[] accelerators = this.keymap.@get (key).to_array ();

          var arr = new Json.Array ();

          foreach (unowned string accel in accelerators) {
            if (accel != null) {
              arr.add_string_element (accel);
            }
          }

          keymap_object.set_array_member (key, arr);
        }

        var keymap_node = new Json.Node (Json.NodeType.OBJECT);
        keymap_node.set_object (keymap_object);

        return keymap_node;
      }
    }

    return default_serialize_property (name, value, spec);
  }
}
