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

[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/preferences-window.ui")]
public class Terminal.PreferencesWindow : Adw.PreferencesDialog {
  [GtkChild] unowned Adw.ComboRow             cursor_shape_combo_row;
  [GtkChild] unowned Adw.ComboRow             cursor_blink_mode_combo_row;
  [GtkChild] unowned Adw.ComboRow             scrollback_mode_combo_row;
  [GtkChild] unowned Adw.ComboRow             working_directory_mode_combo_row;
  [GtkChild] unowned Adw.ComboRow             style_preference_combo_row;
  [GtkChild] unowned Adw.EntryRow             custom_command_entry_row;
  [GtkChild] unowned Adw.EntryRow             custom_working_directory_entry_row;
  [GtkChild] unowned Gtk.Adjustment           cell_height_spacing_adjustment;
  [GtkChild] unowned Gtk.Adjustment           cell_width_spacing_adjustment;
  [GtkChild] unowned Gtk.Adjustment           custom_scrollback_adjustment;
  [GtkChild] unowned Gtk.Adjustment           floating_controls_delay_adjustment;
  [GtkChild] unowned Gtk.Adjustment           floating_controls_hover_area_adjustment;
  [GtkChild] unowned Gtk.CheckButton          filter_themes_check_button;
  [GtkChild] unowned Gtk.FlowBox              preview_flow_box;
  [GtkChild] unowned Gtk.Label                font_label;
  [GtkChild] unowned Gtk.Label                no_sixel_support_label;
  [GtkChild] unowned Adw.SpinRow              custom_scrollback_spin_row;
  [GtkChild] unowned Adw.SpinRow              padding_spin_row;
  [GtkChild] unowned Adw.SwitchRow            easy_copy_paste_switch_row;
  [GtkChild] unowned Adw.SwitchRow            fill_tabs_switch_row;
  [GtkChild] unowned Adw.SwitchRow            floating_controls_switch_row;
  [GtkChild] unowned Adw.SwitchRow            use_sixel_switch_row;
  [GtkChild] unowned Adw.SwitchRow            pretty_switch_row;
  [GtkChild] unowned Adw.SwitchRow            bold_is_bright_switch_row;
  [GtkChild] unowned Adw.SpinRow              opacity_spin_row;
  [GtkChild] unowned Adw.SwitchRow            remember_window_size_switch_row;
  [GtkChild] unowned Adw.SwitchRow            run_command_as_login_switch_row;
  [GtkChild] unowned Adw.SwitchRow            show_headerbar_switch_row;
  [GtkChild] unowned Adw.SwitchRow            context_aware_header_bar_switch_row;
  [GtkChild] unowned Adw.SwitchRow            show_menu_button_switch_row;
  [GtkChild] unowned Adw.SwitchRow            show_scrollbars_switch_row;
  [GtkChild] unowned Adw.SwitchRow            use_custom_shell_command_switch_row;
  [GtkChild] unowned Adw.SwitchRow            use_overlay_scrolling_switch_row;
  [GtkChild] unowned Adw.SwitchRow            drag_area_switch_row;
  [GtkChild] unowned Adw.SwitchRow            terminal_bell_switch_row;
  [GtkChild] unowned Adw.SwitchRow            notify_process_completion_switch_row;
  [GtkChild] unowned Gtk.ToggleButton         dark_theme_toggle;
  [GtkChild] unowned Gtk.ToggleButton         light_theme_toggle;
  [GtkChild] unowned ShortcutEditor           shortcut_editor;
  [GtkChild] unowned Adw.SwitchRow            hide_cursor_while_typing_row;

  private Window window;

  public bool     show_custom_scrollback_row  { get; set; default = false; }
  public string   selected_theme {
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

  static construct {
    typeof (ShortcutEditor).class_ref ();
  }

  construct {
    if (DEVEL) {
      this.add_css_class ("devel");
    }
  }

  public PreferencesWindow (Window window, Gtk.Application app) {

    this.window = window;
    this.shortcut_editor.window = window;
    this.shortcut_editor.app = app;

    this.custom_scrollback_adjustment.upper = uint.MAX;

    this.build_ui ();
    this.bind_data ();
  }

  // Build UI

  private void build_ui () {
    ColorSchemeThumbnailProvider.init_resource ();

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

      return strcmp (a.scheme.name.down (), b.scheme.name.down ());
    });
  }

  // Connections

  private void bind_data () {
    var settings = Settings.get_default ();

    bool is_sixel_supported =
      (Vte.get_feature_flags () & Vte.FeatureFlags.FLAG_SIXEL) != 0;

    // Only enable Sixel action row if VTE was built with Sixel support
    this.use_sixel_switch_row.sensitive = is_sixel_supported;
    this.no_sixel_support_label.visible = !is_sixel_supported;

    settings.schema.bind (
      "font",
      this.font_label,
      "label",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "command-as-login-shell",
      this.run_command_as_login_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "custom-shell-command",
      this.custom_command_entry_row,
      "text",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "use-custom-command",
      this.custom_command_entry_row,
      "sensitive",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "use-custom-command",
      this.use_custom_shell_command_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "notify-process-completion",
      this.notify_process_completion_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "pretty",
      this.pretty_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "theme-bold-is-bright",
      this.bold_is_bright_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind_with_mapping(
      "opacity",
      this.opacity_spin_row,
      "value",
      SettingsBindFlags.DEFAULT,
      // From settings to spin button
      (to_val, settings_variant) => {
        to_val = settings_variant.get_uint32();
        return true;
      },
      // From spin button to settings
      (value) => {
        return new GLib.Variant.uint32((uint)value.get_double());
      },
      null,
      null
    );

    settings.schema.bind(
      "terminal-bell",
      this.terminal_bell_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );
    
    settings.schema.bind(
      "terminal-hide-cursor-while-typing",
      this.hide_cursor_while_typing_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "fill-tabs",
      this.fill_tabs_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "show-menu-button",
      this.show_menu_button_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "show-headerbar",
      this.show_headerbar_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "context-aware-header-bar",
      this.context_aware_header_bar_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "headerbar-drag-area",
      this.drag_area_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind(
      "easy-copy-paste",
      this.easy_copy_paste_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "show-scrollbars",
      this.show_scrollbars_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "use-overlay-scrolling",
      this.use_overlay_scrolling_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "scrollback-lines",
      this.custom_scrollback_spin_row,
      "value",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind_with_mapping (
      "scrollback-lines",
      this.custom_scrollback_spin_row,
      "value",
      GLib.SettingsBindFlags.DEFAULT,
      (to_value, settings_vari) => {
        to_value = (double) settings_vari.get_uint32 ();
        return true;
      },
      (value) => {;
        return new Variant.uint32 ((uint32) value.get_double ());
      },
      null,
      null
    );

    settings.schema.bind (
      "use-sixel",
      this.use_sixel_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "remember-window-size",
      this.remember_window_size_switch_row,
      "active",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind_with_mapping (
      "terminal-padding",
      this.padding_spin_row,
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

    settings.bind_property (
      "scrollback-mode",
      this,
      "show-custom-scrollback-row",
      BindingFlags.SYNC_CREATE,
      // scrollback-mode -> show-custom-scrollback-row
      (_, from_value, ref to_value) => {
        to_value = from_value.get_uint () == 0;
        return true;
      },
      null
    );

    // 0 = Fixed, 1 = Unlimited, 2 = Disabled
    settings.schema.bind(
      "scrollback-mode",
      this.scrollback_mode_combo_row,
      "selected",
      SettingsBindFlags.DEFAULT
    );

    // 0 = Previous Session, 1 = Home Directory, 2 = Custom
    settings.schema.bind (
      "working-directory-mode",
      this.working_directory_mode_combo_row,
      "selected",
      SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
      "custom-working-directory",
      this.custom_working_directory_entry_row,
      "text",
      SettingsBindFlags.DEFAULT
    );

    settings.bind_property (
      "scrollback-mode",
      this.scrollback_mode_combo_row,
      "subtitle",
      BindingFlags.SYNC_CREATE,
      // scrollback-mode -> subtitle
      (_, mode_value, ref subtitle) => {
        subtitle = mode_value.get_uint () == ScrollbackMode.UNLIMITED
          ? Constants.INFINITE_SCROLLBACK_WARNING
          : "";
        return true;
      },
      null
    );

    // 0 = Block, 1 = IBeam, 2 = Underline
    settings.schema.bind(
      "cursor-shape",
      this.cursor_shape_combo_row,
      "selected",
      SettingsBindFlags.DEFAULT
    );

    // 0 = Follow System, 1 = On, 2 = Off
    settings.schema.bind(
      "cursor-blink-mode",
      this.cursor_blink_mode_combo_row,
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
      this.floating_controls_switch_row,
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

    settings.notify ["custom-working-directory"].connect (() => {
      if (this.is_custom_working_directory_valid ()) {
        this.custom_working_directory_entry_row.remove_css_class ("error");
      }
      else {
        this.custom_working_directory_entry_row.add_css_class ("error");
      }
    });
    settings.notify_property ("custom-working-directory");

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

  private bool is_custom_working_directory_valid () {
    string filename = Settings.get_default ().custom_working_directory;

    return GLib.FileUtils.test (
      filename,
      GLib.FileTest.EXISTS | GLib.FileTest.IS_DIR
    );
  }

  // Callbacks

  [GtkCallback]
  private void on_font_row_activated () {
    var fc = new Gtk.FontDialog () {
      title = _("Terminal Font"),
      modal = true,
    };

    Pango.FontDescription? fd = Pango.FontDescription.from_string (Settings.get_default ().font);

    fc.set_filter (new Gtk.CustomFilter (item => {
      Pango.FontFamily font_family = ((Pango.FontFace) item).get_family ();
      return font_family.is_monospace ();
    }));

    fc.choose_font.begin (window, fd, null, (obj, res) => {
        try {
          var fontdesc = fc.choose_font.end (res);
          Settings.get_default ().font = fontdesc.to_string ();
        } catch (Error e) {
          critical ("Could not close font dialog: %s", e.message);
        }
    });
  }


  [GtkCallback]
  private void on_reset_request () {
    var d = new Adw.AlertDialog (
      _("Reset Preferences"),
      _("Are you sure you want to reset all settings?")
    );

    d.add_responses ("cancel", _("Cancel"), "reset", _("Reset Preferences"));
    d.set_default_response ("cancel");
    d.set_response_appearance ("reset", Adw.ResponseAppearance.DESTRUCTIVE);

    d.response.connect ((response) => {
      if (response == "reset") {
        this.do_reset_preferences ();
      }
      d.destroy ();
    });

    d.present (this);
  }

  [GtkCallback]
  private void on_get_more_themes_online () {
    new Gtk.UriLauncher ("https://github.com/storm119/Tilix-Themes")
      .launch.begin (null, null);
  }

  [GtkCallback]
  private void on_open_themes_folder () {
    new Gtk.FileLauncher (
      GLib.File.new_for_path (Constants.get_user_schemes_dir ())
    )
      .launch.begin (null, null);
  }

  [GtkCallback]
  private bool show_custom_working_directory_entry_row (
    WorkingDirectoryMode cwd_mode
  ) {
    return cwd_mode == WorkingDirectoryMode.CUSTOM;
  }

  [GtkCallback]
  private string explain_working_directory_mode (
    WorkingDirectoryMode cwd_mode
  ) {
    switch (cwd_mode) {
      case WorkingDirectoryMode.PREVIOUS_SESSION:
        return _("Reuse previous tab's directory.");
        case WorkingDirectoryMode.HOME_DIRECTORY:
        return _("Use the current user's home as working directory.");
      case WorkingDirectoryMode.CUSTOM:
        return _("Use a custom path as working directory.");
      default:
        return "";
    }
  }

  [GtkCallback]
  private void set_custom_working_dir_to_home () {
    Settings.get_default ()
      .custom_working_directory = GLib.Environment.get_home_dir ();
  }
}

