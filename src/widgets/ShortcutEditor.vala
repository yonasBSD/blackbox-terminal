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

class Terminal.ShortcutRow : Gtk.Box {
  Gtk.Box accelerators_box;

  public string title { get; private set; }
  public string subtitle { get; private set; }

  public Action? action { get; set; default = null; }

  construct {
    this.add_css_class ("shortcut-row");

    var title_label = new Gtk.Label (this.title) {
      css_classes = {"title"},
      halign = Gtk.Align.START,
    };

    var subtitle_label = new Gtk.Label (this.subtitle) {
      css_classes = {"subtitle"},
      halign = Gtk.Align.START,
    };

    this.bind_property (
      "title",
      title_label,
      "label",
      BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
      null,
      null
    );

    this.bind_property (
      "subtitle",
      subtitle_label,
      "label",
      BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
      null,
      null
    );

    this.bind_property (
      "subtitle",
      subtitle_label,
      "visible",
      BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
      // subtitle -> visible
      (_, from_value, ref to_value) => {
        var sub = from_value.get_string ();
        to_value = sub != null && sub != "";
        return true;
      },
      null
    );

    var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
      valign = Gtk.Align.CENTER,
      halign = Gtk.Align.START,
      hexpand = true,
      margin_top = 6,
      margin_bottom = 6,
    };

    vbox.append (title_label);
    vbox.append (subtitle_label);

    this.append (vbox);

    this.accelerators_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
      valign = Gtk.Align.CENTER,
    };

    this.append (this.accelerators_box);

    this.notify ["action"].connect (this.update_ui);
  }

  public ShortcutRow () {
    Object (
      orientation: Gtk.Orientation.HORIZONTAL,
      spacing: 6
    );
  }

  public void update_ui () {
    this.title = this.action?.label ?? this.action?.name ?? "";
    //  this.subtitle = this.action?.label != null ? this.action?.name : "";

    var c = this.accelerators_box.get_first_child ();

    while (c != null) {
      this.accelerators_box.remove (c);
      c = c.get_next_sibling ();
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
        this.accelerators_box.append (new Gtk.ShortcutLabel (accel));
      }
    }
  }
}

[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/shortcut-editor.ui")]
public class Terminal.ShortcutEditor : Adw.PreferencesPage {
  public Gtk.Application app { get; construct set; }

  [GtkChild] unowned Adw.PreferencesGroup shortcuts_group;

  static Gee.HashMap<string, string> action_map;

  // We keep track of all action rows we insert into the preferences group to
  // alow us to remove them on UI refresh later.
  Gee.ArrayList<unowned Adw.ActionRow> action_rows;

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
    this.action_rows = new Gee.ArrayList<unowned Adw.ActionRow> ();
    this.build_ui ();
  }

  void edit_shortcut (uint pos) {
    var action = this.store.get_item (pos) as Action;

    var w = new ShortcutDialog () {
      shortcut_name = action.label ?? action.name,
      current_accel = action.accelerators [0],
      transient_for = this.app.get_active_window (),
    };

    string? new_accel = null;

    w.shortcut_set.connect ((accel) => {
      new_accel = accel;
    });

    w.response.connect ((response) => {
      var keymap = Keymap.get_default ();

      if (response == Gtk.ResponseType.APPLY) {
        debug ("Bind \"%s\" to %s", action.name, new_accel);
        keymap.set_shortcut_for_action (action.name, new_accel);

        action.accelerators = Keymap.get_default ().keymap.@get (action.name).to_array ();
      }

      if (response != Gtk.ResponseType.CANCEL) {
        keymap.save ();
        keymap.apply (this.app);
        store.remove (pos);
        store.insert_sorted (action, (CompareDataFunc<Action>) store_stort_func);
      }
    });

    w.show ();
  }

  void build_ui () {
    var selection = new Gtk.NoSelection (store);

    var factory = new Gtk.SignalListItemFactory ();

    factory.setup.connect ((_, _list_item) => {
      var list_item = _list_item as Gtk.ListItem;
      var row = new ShortcutRow ();

      list_item.set_child (row);
    });

    factory.bind.connect ((_, _list_item) => {
      var list_item = _list_item as Gtk.ListItem;
      var action = list_item.get_item () as Action;
      var row = list_item.get_child () as ShortcutRow;

      row.action = action;
    });

    var list = new Gtk.ListView (selection, factory) {
      css_classes = { "card" },
      show_separators = true,
      single_click_activate = true,
    };

    list.activate.connect (this.edit_shortcut);

    this.shortcuts_group.add (list as Gtk.Widget);

    var keymap = Keymap.get_default ();
    foreach (string action in keymap.keymap.get_keys ()) {
      var a = new Action ();

      a.name = action;
      a.label = action_map [action];
      a.accelerators = keymap.get_accelerators_for_action (action);

      store.append (a);
    }

    store.sort ((CompareDataFunc<Action>) store_stort_func);
  }

  static int store_stort_func (Action action_a, Action action_b) {
    if (action_a.label != null && action_b != null) {
      return strcmp (action_a.label, action_b.label);
    }
    return strcmp (action_a.name, action_b.name);
  }
}
