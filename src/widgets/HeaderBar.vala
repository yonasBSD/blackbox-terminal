/* HeaderBar.vala
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
  static GLib.Menu? _window_menu = null;

  public GLib.Menu get_window_menu_model () {
    if (_window_menu == null) {
      var more_menu = new GLib.Menu ();
      var section1 = new GLib.Menu ();
      var section2 = new GLib.Menu ();

      section1.append (_("Fullscreen"), "win.fullscreen");
      section1.append (_("Preferences"), "win.edit_preferences");
      section2.append (_("Help"), "win.show-help-overlay");
      section2.append (_("About"), "app.about");
      more_menu.append_section (null, section1);
      more_menu.append_section (null, section2);

      _window_menu = more_menu;
    }

    return _window_menu;
  }
}

public abstract class Terminal.BaseHeaderBar : Gtk.Box {
  public virtual Gtk.MenuButton  menu_button     { get; protected set; }
  public virtual Gtk.Button      new_tab_button  { get; protected set; }

  protected Adw.TabBar  tab_bar;
  protected Window      window;

  construct {
    // Menu button
    this.menu_button = new Gtk.MenuButton () {
      can_focus = false,
      menu_model = get_window_menu_model (),
      icon_name = "open-menu-symbolic",

      hexpand = false,
      halign = Gtk.Align.END,
    };

    Settings.get_default ().schema.bind (
      "show-menu-button",
      this.menu_button,
      "visible",
      SettingsBindFlags.GET
    );

    // New tab button
    // FIXME: bundle a new tab icon
    this.new_tab_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
  }

  protected BaseHeaderBar (Window window) {
    Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);

    this.window = window;
    this.tab_bar = this.window.tab_bar;
  }
}

public class Terminal.HeaderBar : BaseHeaderBar {

  private Gtk.WindowControls left_controls;
  private Gtk.WindowControls right_controls;

  private Gtk.Button unfullscreen_button;

  // Adw.HeaderBar allows us to set a center widget. This widget may expand and
  // take all the available space. However, if there are any other widgets on
  // either side of the header bar, the center widget will shrink equally on
  // both sides. This causes issue #38.
  //
  // https://gitlab.gnome.org/raggesilver/blackbox/-/issues/38
  //
  // Terminal.HeaderBar implementation takes care of this problem by disabling
  // Adw.HeaderBar's window controls and adding a single Gtk.Box as title
  // widget. Inside this box we manually add window controls, so no one knows
  // there's anything different.

  public HeaderBar (Window window) {
    base (window);

    var hb = new Adw.HeaderBar ();
    hb.show_start_title_buttons = false;
    hb.show_end_title_buttons = false;
    hb.add_css_class ("flat");

    tab_bar.halign = Gtk.Align.FILL;
    tab_bar.hexpand = true;
    hb.halign = Gtk.Align.FILL;
    hb.hexpand = true;

    this.unfullscreen_button = new Gtk.Button () {
      icon_name = "view-restore-symbolic",
      halign = Gtk.Align.END,
    };

    this.left_controls = new Gtk.WindowControls (Gtk.PackType.START);
    this.right_controls = new Gtk.WindowControls (Gtk.PackType.END);

    var layout = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
    layout.halign = Gtk.Align.FILL;
    layout.hexpand = true;

    layout.append (this.left_controls);
    layout.append (tab_bar);
    layout.append (this.new_tab_button);
    layout.append (this.unfullscreen_button);
    layout.append (this.menu_button);
    layout.append (this.right_controls);

    hb.title_widget = layout;
    this.append (hb);
    this.add_css_class ("custom-headerbar");

    this.connect_signals ();
  }

  private void connect_signals () {
    // window.fullscreened -> unfullscreen_button visibility
    this.window.bind_property (
      "fullscreened",
      this.unfullscreen_button,
      "visible",
      GLib.BindingFlags.SYNC_CREATE,
      null,
      null
    );
    // !window.fullscreened -> left_controls visibility
    this.window.bind_property (
      "fullscreened",
      this.left_controls,
      "visible",
      GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.INVERT_BOOLEAN,
      null,
      null
    );
    // !window.fullscreened -> right_controls visibility
    this.window.bind_property (
      "fullscreened",
      this.right_controls,
      "visible",
      GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.INVERT_BOOLEAN,
      null,
      null
    );

    this.unfullscreen_button.clicked.connect (this.on_unmaximize);
  }

  private void on_unmaximize () {
    this.window.unfullscreen ();
  }
}
