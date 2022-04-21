/* PreferencesWindow.vala
 *
 * Copyright 2020-2022 Paulo Queiroz <pvaqueiroz@gmail.com>
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

[GtkTemplate (ui = "/com/raggesilver/Terminal/layouts/preferences-window.ui")]
public class Terminal.PreferencesWindow : Adw.PreferencesWindow {
  [GtkChild] unowned Gtk.Switch pretty_switch;
  [GtkChild] unowned Gtk.Switch fill_tabs_switch;
  [GtkChild] unowned Gtk.Switch show_headerbar_switch;
  [GtkChild] unowned Gtk.Switch use_overlay_scrolling_switch;
  [GtkChild] unowned Gtk.Switch show_scrollbars_switch;
  [GtkChild] unowned Gtk.Switch pixel_scrolling_switch;
  [GtkChild] unowned Gtk.FontButton font_button;
  [GtkChild] unowned Gtk.ComboBoxText theme_combo;
  [GtkChild] unowned Gtk.SpinButton padding_spin_button;

  [GtkChild] unowned Adw.ExpanderRow scrollbars_expander_row;
  [GtkChild] unowned Adw.ActionRow use_overlay_scrolling_action_row;
  [GtkChild] unowned Adw.ActionRow pixel_scrolling_action_row;

  weak Window window;

  public PreferencesWindow(Gtk.Application app, Window window) {
    Object(
      application: app,
      modal: false
      //  type_hint: Gdk.WindowTypeHint.NORMAL
    );

    this.window = window;
    var settings = Settings.get_default ();

    settings.schema.bind("pretty", this.pretty_switch,
      "active", SettingsBindFlags.DEFAULT);

    settings.schema.bind("fill-tabs", this.fill_tabs_switch,
      "active", SettingsBindFlags.DEFAULT);

    settings.schema.bind("show-headerbar", this.show_headerbar_switch,
      "active", SettingsBindFlags.DEFAULT);

    // Scrolling ====

    settings.schema.bind (
      "show-scrollbars",
      this.show_scrollbars_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "use-overlay-scrolling",
      this.use_overlay_scrolling_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "pixel-scrolling",
      this.pixel_scrolling_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    // If "Show scrollbars" is off, we want to disable every other setting
    // related to scrolling
    settings.notify["show-scrollbars"].connect (() => {
      this.use_overlay_scrolling_action_row.sensitive = settings.show_scrollbars;
      this.pixel_scrolling_action_row.sensitive = settings.show_scrollbars;
    });
    settings.notify_property ("show-scrollbars");

    // Fonts ====

    settings.schema.bind("font", this.font_button,
      "font", SettingsBindFlags.DEFAULT);

    this.window.theme_provider.themes.foreach((key) => {
      this.theme_combo.insert(-1, key, key);
    });

    this.theme_combo.set_active_id(settings.theme);

    settings.schema.bind("theme", this.theme_combo,
      "active-id", SettingsBindFlags.DEFAULT);

    settings.schema.bind_with_mapping (
      "terminal-padding",
      this.padding_spin_button,
      "value",
      SettingsBindFlags.DEFAULT,
      // From settings to spin button
      (to_val, settings_vari) => {
        var pad = Padding.from_variant (settings_vari);

        to_val = pad.top;
        return true;
      },
      // From spin button to settings
      (spin_val, _) => {
        var pad = (uint) spin_val.get_double ();
        var _pad = Padding () {
          top = pad,
          right = pad,
          bottom = pad,
          left = pad
        };

        return _pad.to_variant ();
      },
      null,
      null
    );
  }
}
