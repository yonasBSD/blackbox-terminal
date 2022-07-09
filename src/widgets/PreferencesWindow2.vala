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

bool dark_themes_filter_func (Gtk.FlowBoxChild child) {
  var thumbnail = child as Terminal.ColorSchemeThumbnail;
  return thumbnail.scheme.is_dark;
}

bool light_themes_filter_func (Gtk.FlowBoxChild child) {
  var thumbnail = child as Terminal.ColorSchemeThumbnail;
  return !thumbnail.scheme.is_dark;
}

[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/preferences-window4.ui")]
public class Terminal.PreferencesWindow2 : Adw.PreferencesWindow {
  [GtkChild] unowned Adw.ActionRow        pixel_scrolling_action_row;
  [GtkChild] unowned Adw.ActionRow        show_menu_button_action_row;
  [GtkChild] unowned Adw.ActionRow        use_overlay_scrolling_action_row;
  [GtkChild] unowned Adw.ComboRow         cursor_shape_combo_row;
  [GtkChild] unowned Adw.ComboRow         style_preference_combo_row;
  [GtkChild] unowned Adw.PreferencesGroup theme_scheme_group;
  [GtkChild] unowned Gtk.Adjustment       cell_height_spacing_adjustment;
  [GtkChild] unowned Gtk.Adjustment       cell_width_spacing_adjustment;
  [GtkChild] unowned Gtk.Adjustment       floating_controls_delay_adjustment;
  [GtkChild] unowned Gtk.Adjustment       floating_controls_hover_area_adjustment;
  [GtkChild] unowned Gtk.CheckButton      filter_themes_check_button;
  [GtkChild] unowned Gtk.FlowBox          preview_flow_box;
  [GtkChild] unowned Gtk.Label            font_label;
  [GtkChild] unowned Gtk.SpinButton       padding_spin_button;
  [GtkChild] unowned Gtk.Switch           easy_copy_paste_switch;
  [GtkChild] unowned Gtk.Switch           fill_tabs_switch;
  [GtkChild] unowned Gtk.Switch           floating_controls_switch;
  [GtkChild] unowned Gtk.Switch           hide_single_tab_switch;
  [GtkChild] unowned Gtk.Switch           pixel_scrolling_switch;
  [GtkChild] unowned Gtk.Switch           pretty_switch;
  [GtkChild] unowned Gtk.Switch           remember_window_size_switch;
  [GtkChild] unowned Gtk.Switch           show_headerbar_switch;
  [GtkChild] unowned Gtk.Switch           show_menu_button_switch;
  [GtkChild] unowned Gtk.Switch           show_scrollbars_switch;
  [GtkChild] unowned Gtk.Switch           stealth_single_tab_switch;
  [GtkChild] unowned Gtk.Switch           use_overlay_scrolling_switch;
  [GtkChild] unowned Gtk.ToggleButton     dark_theme_toggle;
  [GtkChild] unowned Gtk.ToggleButton     light_theme_toggle;

  private Window window;
  private HashTable<string, ColorSchemeThumbnail> preview_cached;

  public string selected_theme {
    get {
      return this.light_theme_toggle.active
        ? Settings.get_default ().theme_light
        : Settings.get_default ().theme_dark;
    }
    set {
      if (this.light_theme_toggle.active) {
        Settings.get_default ().theme_light = value;
      }
      else {
        Settings.get_default ().theme_dark = value;
      }
    }
  }

  public PreferencesWindow2 (Window window) {
    Object (
      application: window.application,
      transient_for: window,
      destroy_with_parent: true
    );

    this.window = window;

    this.build_ui ();
    this.bind_data ();
  }

  // Build UI

  private void build_ui () {
    //  this.theme_scheme_group.description +=
    //  _("\n\nOpen <a href=\"file://%s\">themes folder</a>. Get more themes <a href=\"%s\">online</a>.")
    //    .printf (
    //      Path.build_filename (DATADIR, "blackbox", "schemes", null),
    //      "https://github.com/storm119/Tilix-Themes"
    //    );

    ColorSchemeThumbnailProvider.init_resource ();
    this.preview_cached = new HashTable<string, ColorSchemeThumbnail> (
      str_hash,
      str_equal
    );

    //  var model = new GLib.ListStore (typeof (ColorSchemeThumbnail));

    this.window.theme_provider.themes.for_each ((name, scheme) => {
      if (scheme != null) {
        var t = new ColorSchemeThumbnail (scheme);

        this.bind_property (
          "selected-theme",
          t,
          "selected",
          BindingFlags.SYNC_CREATE,
          (_, from, ref to) => {
            to = from.get_string () == t.scheme.name;
            return true;
          },
          null
        );

        //  model.append (t);
        this.preview_flow_box.append (t);
      }
    });

    this.preview_flow_box.set_sort_func ((child1, child2) => {
      var a = child1 as ColorSchemeThumbnail;
      var b = child2 as ColorSchemeThumbnail;

      return strcmp (a.scheme.name, b.scheme.name);
    });

    //  this.preview_flow_box.bind_model (model, (_thumbnail) => {
    //    return _thumbnail as ColorSchemeThumbnail;
    //  });
  }

  // Connections

  private void bind_data () {
    var settings = Settings.get_default ();

    settings.schema.bind (
      "font",
      this.font_label,
      "label",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "pretty",
      this.pretty_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "fill-tabs",
      this.fill_tabs_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "show-menu-button",
      this.show_menu_button_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "show-headerbar",
      this.show_headerbar_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "easy-copy-paste",
      this.easy_copy_paste_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "hide-single-tab",
      this.hide_single_tab_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "stealth-single-tab",
      this.stealth_single_tab_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

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

    // 0 = Block, 1 = IBeam, 2 = Underline
    settings.schema.bind(
      "cursor-shape",
      this.cursor_shape_combo_row,
      "selected",
      SettingsBindFlags.DEFAULT
    );

    //  0 = Follow System, 1 = Light Style, 2 = Dark Style
    settings.schema.bind(
      "style-preference",
      this.style_preference_combo_row,
      "selected",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "floating-controls",
      this.floating_controls_switch,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "floating-controls-hover-area",
      this.floating_controls_hover_area_adjustment,
      "value",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "delay-before-showing-floating-controls",
      this.floating_controls_delay_adjustment,
      "value",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "terminal-cell-width",
      this.cell_width_spacing_adjustment,
      "value",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "terminal-cell-height",
      this.cell_height_spacing_adjustment,
      "value",
      SettingsBindFlags.DEFAULT
    );

    this.preview_flow_box.child_activated.connect ((child) => {
      var name = (child as ColorSchemeThumbnail)?.scheme.name;
      this.selected_theme = name;
    });

    this.notify["selected-theme"].connect (() => {
      this.preview_cached.for_each ((name, thumbnail) => {
        thumbnail.selected = (name == this.selected_theme);
      });
    });

    this.light_theme_toggle.notify["active"].connect (() => {
      this.notify_property ("selected-theme");
      this.set_themes_filter_func ();
    });

    settings.notify["theme-light"].connect (() => {
      if (this.light_theme_toggle.active) {
        this.notify_property ("selected-theme");
      }
    });

    settings.notify["theme-dark"].connect (() => {
      if (this.dark_theme_toggle.active) {
        this.notify_property ("selected-theme");
      }
    });

    if (ThemeProvider.get_default ().is_dark_style_active) {
      this.dark_theme_toggle.active = true;
    }
    else {
      this.light_theme_toggle.active = true;
    }

    ThemeProvider.get_default ().notify ["is-dark-style-active"].connect (() => {
      if (ThemeProvider.get_default ().is_dark_style_active) {
        this.dark_theme_toggle.active = true;
      }
      else {
        this.light_theme_toggle.active = true;
      }
    });

    // themes-filter-func

    this.filter_themes_check_button.notify ["active"].connect (() => {
      this.set_themes_filter_func ();
    });

    this.set_themes_filter_func ();
  }

  // Methods

  private void set_themes_filter_func () {
    if (!this.filter_themes_check_button.active) {
      this.preview_flow_box.set_filter_func (null);
    }
    else {
      if (this.light_theme_toggle.active) {
        this.preview_flow_box.set_filter_func (light_themes_filter_func);
      }
      else {
        this.preview_flow_box.set_filter_func (dark_themes_filter_func);

      }
    }
  }

  private void do_reset_preferences () {
    var settings = Settings.get_default ();
    foreach (var key in settings.schema.settings_schema.list_keys ()) {
      settings.schema.reset (key);
    }
  }

  // Callbacks

  [GtkCallback]
  private void on_font_row_activated () {
    var fc = new Gtk.FontChooserDialog (_("Terminal Font"), this) {
      level = Gtk.FontChooserLevel.FAMILY | Gtk.FontChooserLevel.SIZE,
      // Setting the font seems to have no effect
      font = Settings.get_default ().font,
    };

    fc.set_filter_func ((desc) => {
      return desc.is_monospace ();
    });

    fc.response.connect_after ((response) => {
      if (response == Gtk.ResponseType.OK && fc.font != null) {
        Settings.get_default ().font = fc.font;
      }
      fc.destroy ();
    });

    fc.show ();
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

  [GtkCallback]
  private void on_get_more_themes_online () {
    Gtk.show_uri (
      this,
      "https://github.com/storm119/Tilix-Themes",
      (int32) (get_monotonic_time () / 1000)
    );
  }

  [GtkCallback]
  private void on_open_themes_folder () {
    Gtk.show_uri (
      this,
      "file://" + Path.build_filename (DATADIR, "blackbox", "schemes", null),
      (int32) (get_monotonic_time () / 1000)
    );
  }
}
