/* ThemeProvider.vala
 *
 * Copyright 2020-2022 Paulo Queiroz
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
 */

public enum Terminal.SchemePaletteColorIndex {
  BACKGROUND = 0,
  RED = 1,
  GREEN = 2,
  YELLOW = 3,
  BLUE = 4,
  PURPLE = 5,
  CYAN = 6,
  FOREGROUND = 7,
  LIGHT_BACKGROUND = 8,
  LIGHT_RED = 9,
  LIGHT_GREEN = 10,
  LIGHT_YELLOW = 11,
  LIGHT_BLUE = 12,
  LIGHT_PURPLE = 13,
  LIGHT_CYAN = 14,
  LIGHT_FOREGROUND = 15,
}

namespace Terminal {
  public Gdk.RGBA? rgba_from_string (string? color) {
    if (color == null) {
      return null;
    }

    Gdk.RGBA c = { 0 };

    if (c.parse (color)) {
      return c;
    }
    return null;
  }

  public double get_color_brightness (Gdk.RGBA c) {
    return ((c.red * 299) + (c.green * 587) + (c.blue * 114)) / 1000;
  }
}

public class Terminal.ThemeProvider : Object {
  private Settings                    settings;
  private Gtk.CssProvider?            theme_provider = null;
  public  HashTable<string, Scheme?>  themes;

  public bool is_dark_style_active { get; private set; }

  public string current_theme {
    get {
      return this.is_dark_style_active
        ? Settings.get_default ().theme_dark
        : Settings.get_default ().theme_light;
    }
  }

  private static ThemeProvider instance = null;

  private ThemeProvider () {
    this.settings = Settings.get_default ();
    this.themes = new HashTable<string, Scheme?> (str_hash, str_equal);

    try {
      this.ensure_user_schemes_dir_exists ();
      this.load_themes ();
    }
    catch (Error e) {
      warning (e.message);
    }

    this.is_dark_style_active = Adw.StyleManager.get_default ().dark;
    Adw.StyleManager.get_default ().notify ["dark"].connect (() => {
      this.is_dark_style_active = Adw.StyleManager.get_default ().dark;
    });

    this.notify ["current-theme"].connect (() => {
      this.apply_theming ();
    });
    this.settings.notify ["pretty"].connect (this.apply_theming);

    this.notify ["is-dark-style-active"].connect (() => {
      this.notify_property ("current-theme");
    });

    this.settings.notify ["theme-light"].connect (() => {
      if (!this.is_dark_style_active) {
        this.notify_property ("current-theme");
      }
    });

    this.settings.notify ["theme-dark"].connect (() => {
      if (this.is_dark_style_active) {
        this.notify_property ("current-theme");
      }
    });

    // React to style-preference changes
    this.settings.schema.bind_with_mapping (
      "style-preference",
      Adw.StyleManager.get_default (),
      "color-scheme",
      SettingsBindFlags.GET,
      // From settings to Adw.StyleManager
      (to_val, settings_vari) => {
        var style_pref = settings_vari.get_uint32 ();
        to_val = style_pref == 0
          ? Adw.ColorScheme.DEFAULT
          : style_pref == 1
            ? Adw.ColorScheme.FORCE_LIGHT
            : Adw.ColorScheme.FORCE_DARK;
        return true;
      },
      // This function will never get called as this property is only GET
      () => { return false; },
      null,
      null
    );

    this.apply_theming ();
  }

  public static ThemeProvider get_default () {
    if (instance == null) {
      instance = new ThemeProvider ();
    }
    return instance;
  }

  private void load_themes () throws Error {
    string[] paths = {
      Constants.get_user_schemes_dir (),
      Constants.get_app_schemes_dir (),
    };

    foreach (unowned string path in paths) {
      if (!FileUtils.test (path, FileTest.IS_DIR)) {
        continue;
      }

      var dir = Dir.open (path);
      string? file_name = null;

      while ((file_name = dir.read_name ()) != null) {
        if (!file_name.has_suffix (".json")) continue;

        debug ("Found theme file '%s'", file_name);

        try {
          this.load_theme (new File.new_from_file (
            GLib.File.new_build_filename (path, file_name, null)
          ));
        }
        catch (Error e) {
          warning ("Failed to load theme %s: %s", file_name, e.message);
        }
      }
    }
  }

  private void load_theme (File f) throws Error {
    var theme = Scheme.from_file (f);

    if (theme != null) {
      this.themes.set (theme.name, theme);
    }
    else {
      debug ("%s missing a required property", f.path);
    }
  }

  public void apply_theming () {
    if (this.theme_provider != null) {
      Gtk.StyleContext.remove_provider_for_display (
        Gdk.Display.get_default (),
        this.theme_provider
      );
      this.theme_provider = null;
    }

    var theme = this.themes [this.current_theme];

    if (
      theme == null ||
      !this.settings.pretty ||
      !this.is_safe_to_be_pretty (theme)
    ) {
      return;
    }

    this.theme_provider = Marble.get_css_provider_for_data (
      this.generate_gtk_theme (theme)
    );

    if (this.theme_provider == null) return;

    Gtk.StyleContext.add_provider_for_display (
      Gdk.Display.get_default (),
      this.theme_provider,
      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    );
  }

  // If the current style is dark and a light theme is loaded, all window text
  // and icons will be illegible. Same goes for light style with dark theme
  // selected. In those cases, we need to disable theme integration.
  private bool is_safe_to_be_pretty (Scheme theme) {
    return this.is_dark_style_active == theme.is_dark;
  }

  private void ensure_user_schemes_dir_exists () {
    var path = Constants.get_user_schemes_dir ();

    if (!FileUtils.test (path, FileTest.IS_DIR)) {
      var f = GLib.File.new_for_path (path);

      try {
        f.make_directory_with_parents ();
      }
      catch (Error e) {
        warning ("%s", e.message);
      }
    }
  }

  /**
   * generate_gtk_theme
   *
   * Copyright 2021 Christian Hergert <chergert@redhat.com>
   * Copyright 2022 Paulo Queiroz
   *
   * The following function is work derived from GNOME Text Editor, which is
   * also licensed under the GNU General Public License version 3.
   *
   * Additionally, sourced from:
   *   https://gitlab.gnome.org/GNOME/gnome-text-editor/-/blob/86ceeeda2c35c3b504cfdf817d8119bd41782587/src/editor-recoloring.c
   */

  private string generate_gtk_theme (Scheme scheme) {
    string theme = """
      @define-color window_bg_color         %1$s;
      @define-color window_fg_color         %2$s;

      @define-color card_fg_color           @window_fg_color;
      @define-color headerbar_fg_color      @window_fg_color;
      @define-color headerbar_border_color  @window_fg_color;
      @define-color popover_fg_color        @window_fg_color;
      @define-color dialog_fg_color         @window_fg_color;
      @define-color dark_fill_bg_color      @headerbar_bg_color;
      @define-color view_bg_color           @card_bg_color;
      @define-color view_fg_color           @window_fg_color;

      /* @define-color borders                 mix(@window_fg_color, @window_bg_color, 0.8); */
    """.printf (
      scheme.background_color.to_string (),
      scheme.foreground_color.to_string ()
    );

    // Libadwaita sets border colors to foreground color at 15% opacity. This
    // works beautifuly for all background colors, but it breaks the borders we
    // draw

    if (this.is_dark_style_active) {
      theme += """
        @define-color headerbar_bg_color    darker(@window_bg_color);
        @define-color popover_bg_color      mix(@window_bg_color, white, 0.07);
        @define-color dialog_bg_color       mix(@window_bg_color, white, 0.07);
        @define-color card_bg_color         alpha(white, .08);
        @define-color view_bg_color         darker(@window_bg_color);

        @define-color accent_color            %3$s;
        @define-color accent_bg_color         %3$s;
        @define-color accent_fg_color         white;
        @define-color destructive_color       %1$s;
        @define-color success_color           %2$s;
        @define-color warning_color           %4$s;
      """.printf(
        /** 1 */
        scheme.palette.index (SchemePaletteColorIndex.LIGHT_RED).to_string (),
        /** 2 */
        scheme.palette.index (SchemePaletteColorIndex.LIGHT_GREEN).to_string (),
        /** 3 */
        scheme.palette.index (SchemePaletteColorIndex.LIGHT_BLUE).to_string (),
        /** 4 */
        scheme.palette.index (SchemePaletteColorIndex.LIGHT_YELLOW).to_string ()
      );
    }
    else {
      theme += """
        @define-color headerbar_bg_color    mix(@window_bg_color, @window_fg_color, .1);
        @define-color popover_bg_color      mix(@window_bg_color, white, .1);
        @define-color dialog_bg_color       @window_bg_color;
        @define-color card_bg_color         alpha(white, .6);

        @define-color accent_color            %3$s;
        @define-color accent_bg_color         %3$s;
        @define-color accent_fg_color         white;
        @define-color destructive_color       %1$s;
        @define-color success_color           %2$s;
        @define-color warning_color           %4$s;
      """.printf(
        /** 1 */
        scheme.palette.index (SchemePaletteColorIndex.RED).to_string (),
        /** 2 */
        scheme.palette.index (SchemePaletteColorIndex.GREEN).to_string (),
        /** 3 */
        scheme.palette.index (SchemePaletteColorIndex.BLUE).to_string (),
        /** 4 */
        scheme.palette.index (SchemePaletteColorIndex.YELLOW).to_string ()
      );
    }

    theme += """
      @define-color error_color             @destructive_color;
      @define-color destructive_bg_color    @destructive_color;
      @define-color success_bg_color        @success_color;
      @define-color warning_bg_color        @warning_color;
    """;

    return theme;
  }
}
