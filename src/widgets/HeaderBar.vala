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

[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/header-bar.ui")]
public class Terminal.HeaderBar : Adw.Bin {

  [GtkChild] public unowned Adw.TabBar tab_bar;

  public Window   window        { get; set; }
  public Settings settings      { get; construct set; }
  public bool     floating_mode { get; set; default = false; }

  public bool single_tab_mode {
    get {
      var settings = Settings.get_default ();
      return (
        (this.window == null || this.window.tab_view.n_pages <= 1) &&
        settings.fill_tabs
      );
    }
  }

  static construct {
    set_css_name ("headerbar");
  }

  construct {
    this.settings = Settings.get_default ();
  }

  public HeaderBar (Window window) {
    Object (window: window);

    this.connect_signals ();
  }

  private void connect_signals () {
    var settings = Settings.get_default ();

    this.window.tab_view.notify ["n-pages"]
      .connect (this.notify_single_tab_mode);

    settings.notify ["fill-tabs"].connect (this.notify_single_tab_mode);

    settings.notify ["headerbar-drag-area"].connect (
      this.on_drag_area_changed
    );
    this.on_drag_area_changed ();

    this.notify ["single-tab-mode"].connect (this.on_single_tab_mode_changed);
    this.on_single_tab_mode_changed ();

    var mcc = new Gtk.GestureClick () {
      button = Gdk.BUTTON_MIDDLE,
    };
    mcc.pressed.connect (() => {
      this.window.new_tab (null, null);
    });
    this.add_controller (mcc);
  }

  [GtkCallback]
  private void unfullscreen () {
    this.window.unfullscreen ();
  }

  [GtkCallback]
  private bool show_window_controls (
    bool fullscreened,
    bool _is_floating,
    bool _is_single_tab_mode,
    bool is_header_bar_controls
  ) {
    return (
      (this.window == null || !fullscreened) &&
      (!_is_floating) &&
      (!is_header_bar_controls || _is_single_tab_mode)
    );
  }

  [GtkCallback]
  private string get_visible_stack_name (bool is_single_tab_mode) {
    return is_single_tab_mode ? "single-tab-page" : "multi-tab-page";
  }

  private void notify_single_tab_mode () {
    this.notify_property ("single-tab-mode");
  }

  private void on_drag_area_changed () {
    var drag_area = Settings.get_default ().headerbar_drag_area;

    set_css_class (this, "with-dragarea", drag_area);
  }

  private void on_single_tab_mode_changed () {
    bool single_tab_enabled = this.single_tab_mode;

    set_css_class (this, "single-tab-mode", single_tab_enabled);
  }
}
