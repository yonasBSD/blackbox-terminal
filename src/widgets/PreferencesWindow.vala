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

[GtkTemplate (ui = "/com/raggesilver/BlackBox/layouts/preferences-window.ui")]
public class Terminal.PreferencesWindow : Adw.PreferencesWindow {
  [GtkChild] unowned Gtk.Switch pretty_switch;
  [GtkChild] unowned Gtk.Switch fill_tabs_switch;
  [GtkChild] unowned Gtk.Switch show_headerbar_switch;
  [GtkChild] unowned Gtk.Switch show_menu_button_switch;
  [GtkChild] unowned Gtk.Switch use_overlay_scrolling_switch;
  [GtkChild] unowned Gtk.Switch show_scrollbars_switch;
  [GtkChild] unowned Gtk.Switch pixel_scrolling_switch;
  [GtkChild] unowned Gtk.Switch remember_window_size_switch;
  [GtkChild] unowned Gtk.FontButton font_button;
  [GtkChild] unowned Gtk.SpinButton padding_spin_button;
  [GtkChild] unowned Gtk.DropDown cursor_shape_dropdown;

  [GtkChild] unowned Adw.ActionRow show_menu_button_action_row;
  [GtkChild] unowned Adw.ActionRow use_overlay_scrolling_action_row;
  [GtkChild] unowned Adw.ActionRow pixel_scrolling_action_row;
  [GtkChild] unowned Adw.ActionRow remember_window_size_row;

  [GtkChild] unowned Adw.PreferencesGroup theme_scheme_group;
  [GtkChild] unowned Gtk.FlowBox preview_flow_box;

  Window window;
  private HashTable<string, ColorSchemeThumbnail>? preview_cached;

  public PreferencesWindow(Gtk.Application app, Window window) {
    Object(
      application: app,
      modal: false
      //  type_hint: Gdk.WindowTypeHint.NORMAL
    );

    this.window = window;
    var settings = Settings.get_default ();

    if (IS_X11 ()) {
      remember_window_size_row.subtitle = Constants.X11_WINDOW_SIZE_WARNING;
    }

    this.theme_scheme_group.description =
      "Open <a href=\"file://%s\">themes folder</a>. Get more themes <a href=\"%s\">online</a>."
        .printf (
          Path.build_filename (DATADIR, "blackbox", "schemes", null),
          "https://github.com/storm119/Tilix-Themes"
        );

    settings.schema.bind("pretty", this.pretty_switch,
      "active", SettingsBindFlags.DEFAULT);

    settings.schema.bind("fill-tabs", this.fill_tabs_switch,
      "active", SettingsBindFlags.DEFAULT);

    settings.schema.bind("show-headerbar", this.show_headerbar_switch,
      "active", SettingsBindFlags.DEFAULT);

    settings.schema.bind(
      "show-menu-button",
      this.show_menu_button_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.notify["show-menu-button"].connect (() => {
      this.show_menu_button_action_row.subtitle =
        settings.show_menu_button
          ? null
          : Constants.MENU_BUTTON_ALTERNATIVE;
    });

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

    settings.schema.bind (
      "remember-window-size",
      this.remember_window_size_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.notify["remember-window-size"].connect (() => {
      this.on_remember_window_size_changed ();
    });

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

    // Themes

    ColorSchemeThumbnailProvider.init_resource ();
    this.preview_cached = new HashTable<string, ColorSchemeThumbnail> (
      str_hash,
      str_equal
    );

    // Add thumbnials into Gtk.FlowBox
    this.window.theme_provider.themes.for_each ((name, scheme) => {
      return_if_fail (scheme != null);

      var previewer = new ColorSchemeThumbnail (scheme);
      this.preview_flow_box.append (previewer);
      this.preview_cached[name] = previewer;

      previewer.selected = (previewer.scheme_name == settings.theme);
    });

    this.preview_flow_box.child_activated.connect ((child) => {
      var name = (child as ColorSchemeThumbnail)?.scheme_name;
      if (settings.theme == name) {
        return;
      }
      settings.theme = name;
    });

    settings.notify["theme"].connect (() => {
      this.preview_cached.for_each ((name, thumbnail) => {
        thumbnail.selected = (settings.theme == name);
      });
    });
  }

  private void on_remember_window_size_changed () {
    var settings = Settings.get_default ();

    if (IS_X11 ()) {
      remember_window_size_row.icon_name = settings.remember_window_size
        ? "dialog-warning-symbolic"
        : null;
    }
  }

  [GtkCallback]
  private void on_reset_request () {
    var d = new Gtk.MessageDialog (
      this,
      Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
      Gtk.MessageType.QUESTION,
      Gtk.ButtonsType.YES_NO,
      "Are you sure you want to reset all settings?"
    );

    var yes_button = d.get_widget_for_response (Gtk.ResponseType.YES);
    yes_button?.add_css_class ("destructive-action");

    var no_button = d.get_widget_for_response (Gtk.ResponseType.NO);
    no_button?.add_css_class ("suggested-action");

    d.set_default_response (Gtk.ResponseType.NO);

    d.response.connect ((response) => {
      if (response == Gtk.ResponseType.YES) {
        this.do_reset_preferences ();
      }
      d.destroy ();
    });

    d.present ();
  }

  private void do_reset_preferences () {
    var settings = Settings.get_default ();
    foreach (var key in settings.schema.settings_schema.list_keys ()) {
      settings.schema.reset (key);
    }
  }
}
