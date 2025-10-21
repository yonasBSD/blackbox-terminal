/* ShortcutEditor.vala
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

 class Terminal.Action : Object {
  public string    name;
  public string?   label;
  public string[]  accelerators;

  public Action () {
    Object ();
  }
}

[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/shortcut-row.ui")]
class Terminal.ShortcutRow : Adw.ActionRow {

  public Action? action { get; set; default = null; }

  [GtkChild] unowned Gtk.Box accelerators_box;
  //  [GtkChild] unowned Gtk.MenuButton menu_button;
  [GtkChild] unowned Gtk.PopoverMenu popover;

  construct {
    this.notify ["action"].connect (this.update_ui);
  }

  public void update_ui () {
    this.title = this.action?.label ?? this.action?.name ?? "";

    // Remove previous ShortcutLabels
    {
      var c = this.accelerators_box.get_first_child ();
      while (c != null) {
        this.accelerators_box.remove (c);
        c = c.get_next_sibling ();
      }
    }

    {
      var menu = new Menu ();

      var mi = new MenuItem (_("Add Keybinding"), null);
      mi.set_action_and_target_value (
        ACTION_SHORTCUT_EDITOR_ADD_KEYBINDING,
        this.action.name
      );
      menu.append_item (mi);

      mi = new MenuItem (_("Reset Keybindings"), null);
      mi.set_action_and_target_value (
        ACTION_SHORTCUT_EDITOR_RESET,
        this.action.name
      );
      menu.append_item (mi);

      var keymap = Keymap.get_default ();
      var accels = keymap.get_accelerators_for_action (this.action.name);

      if (accels != null) {
        var section = new Menu ();
        foreach (unowned string accel in accels) {
          if (accel != null) {
            mi = new MenuItem (
              _("Remove %s").printf (get_accel_as_label (accel)),
              null
            );
            mi.set_action_and_target_value (
              ACTION_SHORTCUT_EDITOR_REMOVE_KEYBINDING,
              accel
            );
            section.append_item (mi);
          }
        }
        if (section.get_n_items () > 0) {
          menu.append_section (null, section);
        }
      }

      this.popover.set_menu_model (menu);
    }

    if (
      this.action != null &&
      (
        this.action.accelerators.length == 0 ||
        this.action.accelerators [0] == null
      )
    ) {
      this.accelerators_box.append (new Gtk.Label (_("Disabled")) {
        css_classes = { "dim-label" },
      });
    } else {
      foreach (unowned string accel in this.action.accelerators) {
        this.accelerators_box.append (new Gtk.ShortcutLabel (accel) {
          halign = Gtk.Align.END,
        });
      }
    }
  }
}

[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/shortcut-editor.ui")]
public class Terminal.ShortcutEditor : Adw.PreferencesPage {
  public Gtk.Window window { get; set; }
  public Gtk.Application app { get; set; }

  [GtkChild] unowned Gtk.ListBox list_box;

  static Gee.HashMap<string, string> action_map;

  ListStore store = new ListStore (typeof (Action));

  static construct {
    action_map = new Gee.HashMap<string, string> ();

    action_map.@set (ACTION_FOCUS_NEXT_TAB, _("Focus Next Tab"));
    action_map.@set (ACTION_FOCUS_PREVIOUS_TAB, _("Focus Previous Tab"));
    action_map.@set (ACTION_NEW_WINDOW, _("New Window"));
    action_map.@set (ACTION_WIN_SWITCH_HEADER_BAR_MODE, _("Toggle Header Bar"));
    action_map.@set (ACTION_WIN_NEW_TAB, _("New Tab"));
    action_map.@set (ACTION_WIN_EDIT_PREFERENCES, _("Preferences"));
    action_map.@set (ACTION_WIN_COPY, _("Copy"));
    action_map.@set (ACTION_WIN_PASTE, _("Paste"));
    action_map.@set (ACTION_WIN_SEARCH, _("Search"));
    action_map.@set (ACTION_WIN_FULLSCREEN, _("Fullscreen"));
    action_map.@set (ACTION_WIN_SHOW_HELP_OVERLAY, _("Keyboard Shortcuts"));
    action_map.@set (ACTION_WIN_ZOOM_IN, _("Zoom In"));
    action_map.@set (ACTION_WIN_ZOOM_OUT, _("Zoom Out"));
    action_map.@set (ACTION_WIN_ZOOM_DEFAULT, _("Reset Zoom"));
    action_map.@set (ACTION_WIN_CLOSE_TAB, _("Close Tab"));
    action_map.@set (ACTION_WIN_RENAME_TAB, _("Rename Tab"));
    action_map.@set (ACTION_WIN_MOVE_TAB_LEFT, _("Move Tab Left"));
    action_map.@set (ACTION_WIN_MOVE_TAB_RIGHT, _("Move Tab Right"));

    action_map.@set (ACTION_WIN_SWITCH_TAB_1, _("Switch to Tab %u").printf (1));
    action_map.@set (ACTION_WIN_SWITCH_TAB_2, _("Switch to Tab %u").printf (2));
    action_map.@set (ACTION_WIN_SWITCH_TAB_3, _("Switch to Tab %u").printf (3));
    action_map.@set (ACTION_WIN_SWITCH_TAB_4, _("Switch to Tab %u").printf (4));
    action_map.@set (ACTION_WIN_SWITCH_TAB_5, _("Switch to Tab %u").printf (5));
    action_map.@set (ACTION_WIN_SWITCH_TAB_6, _("Switch to Tab %u").printf (6));
    action_map.@set (ACTION_WIN_SWITCH_TAB_7, _("Switch to Tab %u").printf (7));
    action_map.@set (ACTION_WIN_SWITCH_TAB_8, _("Switch to Tab %u").printf (8));
    action_map.@set (ACTION_WIN_SWITCH_TAB_9, _("Switch to Tab %u").printf (9));
    action_map.@set (ACTION_WIN_SWITCH_TAB_LAST, _("Switch to Last Tab"));
  }

  construct {
    this.build_ui ();

    this.list_box.margin_bottom = 32;

    this.install_action (
      ACTION_SHORTCUT_EDITOR_RESET,
      "s",
      (Gtk.WidgetActionActivateFunc) on_shortcut_editor_reset
    );

    this.install_action (
      ACTION_SHORTCUT_EDITOR_RESET_ALL,
      null,
      (Gtk.WidgetActionActivateFunc) on_shortcut_editor_reset_all
    );

    this.install_action (
      ACTION_SHORTCUT_EDITOR_REMOVE_KEYBINDING,
      "s",
      (Gtk.WidgetActionActivateFunc) on_shortcut_editor_remove_keybinding
    );

    this.install_action (
      ACTION_SHORTCUT_EDITOR_ADD_KEYBINDING,
      "s",
      (Gtk.WidgetActionActivateFunc) on_shortcut_editor_add_keybinding
    );
  }

  void on_shortcut_editor_add_keybinding (string _, Variant action) {
    var action_name = action.get_string ();
    var keymap = Keymap.get_default ();

    var w = new ShortcutDialog () {
      shortcut_name = action_map [action_name] ?? action_name,
    };

    string? new_accel = null;

    w.shortcut_set.connect ((_new_accel) => {
      new_accel = _new_accel;
    });

    w.response.connect ((response) => {
      if (response == Gtk.ResponseType.APPLY) {
        keymap.add_shortcut_for_action.begin (
          action_name,
          new_accel,
          (o, res) => {
            if (keymap.add_shortcut_for_action.end (res)) {
              this.apply_save_and_refresh ();
            }
          }
        );
      }
    });

    w.present (this.window);
  }

  void on_shortcut_editor_remove_keybinding (string _, Variant _accel) {
    var keymap = Keymap.get_default ();

    var accel = _accel.get_string ();
    var action = keymap.get_action_for_shortcut (accel);

    if (action != null) {
      keymap.remove_shortcut_from_action (action, accel);
      this.apply_save_and_refresh ();
    }
  }

  void on_shortcut_editor_reset_all () {
    this.request_reset_all.begin ();
  }

  async void request_reset_all () {
    Adw.AlertDialog dlg = new Adw.AlertDialog (
                                                  _("Reset All Shortcuts?"),
                                                  _("This will reset all shortcuts to default and overwrite your config file. This action is irreversible."));

    dlg.add_response ("cancel", _("Cancel"));
    dlg.add_response ("reset", _("Reset"));
    dlg.set_close_response ("cancel");
    dlg.set_response_appearance ("reset", Adw.ResponseAppearance.DESTRUCTIVE);

    dlg.response.connect ((response) => {
      if (response == "reset") {
        var keymap = Keymap.get_default ();
        keymap.reset_user_keymap ();
        this.apply_save_and_refresh ();
      }
    });

    dlg.present (this.window);
  }

  void on_shortcut_editor_reset (string _action_name, Variant shortcut_name) {
    this.request_shortcut_reset.begin (shortcut_name.get_string ());
  }

  async void request_shortcut_reset (string action_name) {
    var keymap = Keymap.get_default ();
    yield keymap.reset_shortcuts_for_action (action_name);
    this.apply_save_and_refresh ();
  }

  void apply_save_and_refresh () {
    var keymap = Keymap.get_default ();
    keymap.save ();
    keymap.apply (this.app);
    this.populate_list ();
  }

  void build_ui () {
    this.list_box.bind_model (
      this.store,
      (_action) => {
        return new ShortcutRow () {
          action = _action as Action,
        };
      }
    );

    this.populate_list ();
  }

  void populate_list (bool clear = true) {
    if (clear) {
      this.store.remove_all ();
    }

    var keymap = Keymap.get_default ();
    foreach (string action in keymap.keymap.get_keys ()) {
      var a = new Action ();

      a.name = action;
      a.label = action_map [action];
      a.accelerators = keymap.get_accelerators_for_action (action);

      this.store.insert_sorted (a, (CompareDataFunc<Action>) store_stort_func);
    }
  }

  static int store_stort_func (Action action_a, Action action_b) {
    if (action_a.label != null && action_b != null) {
      return strcmp (action_a.label, action_b.label);
    }
    return strcmp (action_a.name, action_b.name);
  }
}
