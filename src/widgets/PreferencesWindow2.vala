/* PreferencesWindow2.vala
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

// TODO: all preference pages inside stack should be Adw.PreferencePage

public class Terminal.PreferencePageItem : Object {
  public string      icon     { get; set; }
  public string      label    { get; set; }
  public string[]    keywords { get; set; }
  public Gtk.Widget  page     { get; set; }
}

public class Terminal.PreferencePageEntry : Gtk.ListBoxRow {
  public PreferencePageItem item { get; private set; }

  public PreferencePageEntry (PreferencePageItem item) {
    this.item = item;
    var g = new Gtk.Grid () {
      column_spacing = 12,
      margin_start = 6,
      margin_end = 6,
      margin_top = 6,
      margin_bottom = 6,
      valign = Gtk.Align.CENTER,
    };

    var i = new Gtk.Image.from_icon_name (this.item.icon);
    var l = new Gtk.Label (this.item.label) {
      hexpand = true,
      halign = Gtk.Align.START,
    };

    g.attach (i, 0, 0, 1, 1);
    g.attach (l, 1, 0, 1, 1);

    this.can_focus = false;
    this.child = g;
  }
}

[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/preferences-window3.ui")]
public class Terminal.PreferencesWindow2 : Adw.ApplicationWindow {

  [GtkChild] unowned Gtk.SearchBar  search_bar;
  [GtkChild] unowned Gtk.ListBox    side_list_box;
  [GtkChild] unowned Gtk.Widget     general_page;
  [GtkChild] unowned Gtk.Widget     appearance_page;
  //  [GtkChild] unowned Gtk.Widget     profile_page;
  [GtkChild] unowned Gtk.Widget     terminal_page;
  [GtkChild] unowned Gtk.Widget     advanced_page;
  [GtkChild] unowned Gtk.Stack      content_stack;


  public PreferencesWindow2 (Window window) {
    Object (
      application: window.application,
      transient_for: window,
      destroy_with_parent: true
    );

    this.search_bar.set_key_capture_widget (this);

    var store = new ListStore (typeof (PreferencePageItem));

    var first_child = new PreferencePageItem () {
      label = "General",
      icon = "settings-symbolic",
      keywords = {},
      page = general_page,
    };
    store.append (first_child);
    store.append (new PreferencePageItem () {
      label = "Appearance",
      icon = "preferences-desktop-appearance-symbolic",
      keywords = {},
      page = appearance_page,
    });
    //  store.append (new PreferencePageItem () {
    //    label = "Profile",
    //    icon = "system-users-symbolic",
    //    keywords = {},
    //    page = profile_page,
    //  });
    store.append (new PreferencePageItem () {
      label = "Terminal",
      icon = "utilities-terminal-symbolic",
      keywords = {},
      page = terminal_page,
    });
    store.append (new PreferencePageItem () {
      label = "Advanced",
      icon = "applications-science-symbolic",
      keywords = {},
      page = advanced_page,
    });

    this.side_list_box.bind_model (store, this.create_sidebar_entry);
    this.side_list_box.row_activated.connect (this.on_sidebar_row_activated);

    this.side_list_box.select_row (this.side_list_box.get_row_at_index (0));
  }

  private Gtk.Widget create_sidebar_entry (Object _item) {
    var item = _item as PreferencePageItem;

    return new PreferencePageEntry(item);
  }

  private void on_sidebar_row_activated (Gtk.ListBoxRow row) {
    if (row is PreferencePageEntry) {
      this.content_stack.set_visible_child ((row as PreferencePageEntry)?.item.page);
    }
  }
}
