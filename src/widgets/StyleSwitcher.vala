/* StyleSwitcher.vala
 *
 * Copyright 2023 Paulo Queiroz <pvaqueiroz@gmail.com>
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


[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/style-switcher.ui")]
public class Terminal.StyleSwitcher : Gtk.Widget {

  [GtkChild] unowned Gtk.CheckButton system_selector;
  [GtkChild] unowned Gtk.CheckButton light_selector;
  [GtkChild] unowned Gtk.CheckButton dark_selector;

  public uint style { get; set; }
  public bool show_system { get; set; default = true; }

  static construct {
    set_layout_manager_type (typeof (Gtk.BinLayout));
    set_css_name ("themeswitcher");
  }

  construct {
    this.notify ["style"].connect (this.on_style_changed);

    var s = Settings.get_default ();
    s.bind_property ("style-preference",
                     this,
                     "style",
                     GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL,
                     null,
                     null);
  }

  private void on_style_changed () {
    this.freeze_notify ();
    if (this.style == ApplicationStyle.SYSTEM) {
      this.system_selector.active = true;
      this.light_selector.active = false;
      this.dark_selector.active = false;
    }
    else if (this.style == ApplicationStyle.LIGHT) {
      this.system_selector.active = false;
      this.light_selector.active = true;
      this.dark_selector.active = false;
    }
    else {
      this.system_selector.active = false;
      this.light_selector.active = false;
      this.dark_selector.active = true;
    }
    this.thaw_notify ();
  }

  [GtkCallback]
  private void theme_check_active_changed () {
    if (this.system_selector.active) {
      if (this.style != ApplicationStyle.SYSTEM) {
        this.style = (uint) ApplicationStyle.SYSTEM;
      }
    }
    else if (this.light_selector.active) {
      if (this.style != ApplicationStyle.LIGHT) {
        this.style = (uint) ApplicationStyle.LIGHT;
      }
    }
    else {
      if (this.style != ApplicationStyle.DARK) {
        this.style = (uint) ApplicationStyle.DARK;
      }
    }
  }
}
