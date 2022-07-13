/* Terminal.vala
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

public class Terminal.Terminal : Vte.Terminal {

  /**
   * List of available drop targets for Terminal
   */
  private enum DropTargets {
    URILIST,
    STRING,
    TEXT,
  }

  // Signals

  /**
   * This signal is emitted when the terminal process exits. Something should
   * listen for this signal and close the tab that contains this terminal.
   */
  public signal void exit ();

  // Properties

  public Scheme scheme  { get; set; }
  public Pid    pid     { get; protected set; }

  // Fields

  public Gdk.RGBA? fg;
  public Gdk.RGBA? bg;
  public Window window;

  Settings settings;

  public Terminal (Window window, string? command = null, string? cwd = null) {
    Object (allow_hyperlink: true, receives_default: true);

    this.window = window;

    this.hexpand = true;
    this.vexpand = true;
    this.halign = Gtk.Align.FILL;
    this.valign = Gtk.Align.FILL;

    this.child_exited.connect (this.on_child_exited);

    this.settings = Settings.get_default ();
    ThemeProvider.get_default ().notify ["current-theme"].connect (this.on_theme_changed);
    this.settings.notify["font"].connect (this.on_font_changed);
    this.settings.notify["terminal-padding"].connect (this.on_padding_changed);

    this.settings.bind_property (
      "cursor-shape",
      this,
      "cursor-shape",
      BindingFlags.SYNC_CREATE,
      null,
      null
    );

    this.setup_drag_drop ();
    this.setup_regexes ();
    this.connect_accels ();
    this.bind_data ();
    this.on_theme_changed ();
    this.on_font_changed ();
    this.on_padding_changed ();

    try {
      this.spawn (command, cwd);
    }
    catch (Error e) {
      warning ("%s", e.message);
    }
  }

  // Methods ===================================================================

  private void setup_drag_drop () {
    var target = new Gtk.DropTarget (Type.INVALID, Gdk.DragAction.COPY);

    target.set_gtypes ({
      typeof (File),
      typeof (string),
    });

    target.on_drop.connect (this.on_drag_data_received);

    this.add_controller (target);
  }

  private bool on_drag_data_received (
    Gtk.DropTarget target,
    Value value,
    double x,
    double y
  ) {
    var vtype = value.type ();

    if (vtype == typeof (GLib.File)) {
      var file = (GLib.File) value.get_object ();
      var path = file?.get_path ();

      if (path != null) {
        this.feed_child (Shell.quote (path).data);
        this.feed_child (" ".data);
      }

      return true;
    }
    else if (vtype == typeof (string)) {
      var text = value.get_string ();

      if (text != null) {
        this.feed_child (text.data);
      }

      return true;
    }

    warning ("You dropped something Terminal can't handle yet :(");
    return false;
  }

  private void setup_regexes () {
    foreach (unowned string str in Constants.URL_REGEX_STRINGS) {
      try {
        var reg = new Vte.Regex.for_match (
          str, -1, PCRE2.Flags.MULTILINE
        );
        int id = this.match_add_regex (reg, 0);
        this.match_set_cursor_name (id, "pointer");
      }
      catch (Error e) {
        warning (e.message);
      }
    }
  }

  private void on_font_changed () {
    this.font_desc = Pango.FontDescription.from_string (
      this.settings.font
    );
  }

  private void on_theme_changed () {
    var theme_provider = ThemeProvider.get_default ();
    var theme_name = theme_provider.current_theme;
    var theme = theme_provider.themes.get (theme_name);

    if (theme == null) {
      warning ("INVALID THEME '%s'", theme_name);
      return;
    }

    this.bg = theme.background_color;
    this.fg = theme.foreground_color;

    this.set_colors (this.fg, this.bg, theme.palette.data);
  }

  private Gtk.CssProvider? padding_provider = null;
  private void on_padding_changed () {
    var pad = this.settings.get_padding ();

    if (this.padding_provider != null) {
      this.get_style_context ().remove_provider (this.padding_provider);
      this.padding_provider = null;
    }

    this.padding_provider = Marble.get_css_provider_for_data(
      "vte-terminal { padding: %upx %upx %upx %upx; }".printf(
        pad.top,
        pad.right,
        pad.bottom,
        pad.left
      )
    );

    this.get_style_context ().add_provider (
      this.padding_provider,
      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    );
  }

  private void bind_data () {
    this.settings.schema.bind (
      "terminal-cell-width",
      this,
      "cell-width-scale",
      SettingsBindFlags.DEFAULT
    );

    this.settings.schema.bind (
      "terminal-cell-height",
      this,
      "cell-height-scale",
      SettingsBindFlags.DEFAULT
    );
  }

  private void connect_accels () {
    var kpcontroller = new Gtk.EventControllerKey ();

    kpcontroller.key_pressed.connect (this.on_key_pressed);

    this.add_controller (kpcontroller);

    var middle_click_controller = new Gtk.GestureClick () {
      button = Gdk.BUTTON_MIDDLE,
    };

    middle_click_controller.pressed.connect (this.on_middle_click_pressed);

    this.add_controller (middle_click_controller);
  }

  private void spawn (string? command, string? cwd) throws Error {
    string[] argv;
    string[] envv;
    Vte.PtyFlags flags = Vte.PtyFlags.DEFAULT;

    var settings = Settings.get_default ();
    string[]? custom_shell_commandv = null;

    string shell;

    if (
      settings.use_custom_command &&
      settings.custom_shell_command != ""
    ) {
      Shell.parse_argv (settings.custom_shell_command, out custom_shell_commandv);
    }

    // Spawning works differently on host vs flatpak
    if (is_flatpak ()) {
      shell = fp_guess_shell () ?? "/usr/bin/bash";

      flags = Vte.PtyFlags.NO_CTTY;

      argv = {
        "/usr/bin/flatpak-spawn",
        "--host",
        "--watch-bus"
      };

      envv = fp_get_env () ?? Environ.get ();

      envv += "G_MESSAGES_DEBUG=false";
      envv += "TERM=xterm-256color";
      envv += @"TERM_PROGRAM=$(APP_NAME)";

      foreach (unowned string env in envv) {
        argv += @"--env=$(env)";
      }
    }
    else {
      envv = Environ.get ();
      envv += "G_MESSAGES_DEBUG=false";
      envv += "TERM=xterm-256color";
      envv += @"TERM_PROGRAM=$(APP_NAME)";

      shell = Environ.get_variable (envv, "SHELL");

      argv = {};

      flags = Vte.PtyFlags.DEFAULT;
    }

    if (custom_shell_commandv != null) {
      foreach (unowned string s in custom_shell_commandv) {
        argv += s;
      }
    }
    else {
      argv += shell;
      if (settings.command_as_login_shell && command == null) {
        argv += "--login";
      }
    }
    if (command != null) {
      argv += "-c";
      argv += command;
    }

    this.spawn_async (
      flags,
      cwd,
      argv,
      envv,
      0,
      null,
      -1,
      null,
      // For some reason, if I try using `err` here vala will generate the
      // following line at the top of this lambda function:
      //
      // g_return_if_fail (err != NULL);
      //
      // Which is insane, and does not work, since we expect error to be null
      // almost always.
      (_, _pid /*, err */) => {
        this.pid = _pid;
      }
    );
  }

  // Signal callbacks ==========================================================

  private void on_child_exited () {
    this.pid = -1;
    this.exit ();
  }

  private void on_middle_click_pressed () {
    if (Gtk.Settings.get_default ().gtk_enable_primary_paste) {
      this.do_paste_from_selection ();
    }
  }

  private bool on_key_pressed (
    uint keyval,
    uint keycode,
    Gdk.ModifierType state
  ) {

    if ((state & Gdk.ModifierType.ALT_MASK) > 0) {
      switch (Gdk.keyval_name (keyval)) {
        case "1": //alt+[1-8]
        case "2":
        case "3":
        case "4":
        case "5":
        case "6":
        case "7":
        case "8":
        case "9": {
          this.window.focus_nth_tab (int.parse (Gdk.keyval_name (keyval)));
          return true;
        }
      }
    }

    if ((state & Gdk.ModifierType.CONTROL_MASK) == 0) {
      return false;
    }

    switch (Gdk.keyval_name (keyval)) {
      case "c": {
        if (
          this.get_has_selection () &&
          Settings.get_default ().easy_copy_paste
        ) {
          this.do_copy_clipboard ();
          return true;
        }
        return false;
      }
      case "v": {
        if (Settings.get_default ().easy_copy_paste) {
          this.do_paste_clipboard ();
          this.unselect_all ();
          return true;
        }
        return false;
      }
      case "plus": {
        this.font_scale = double.min (10, this.font_scale + 0.1);
        return true;
      }
      case "underscore": {
        this.font_scale = double.max (0.1, this.font_scale - 0.1);
        return true;
      }
      case "N": {
        this.window.activate_action ("new_window", null);
        return true;
      }
      case "T": {
        this.window.activate_action ("new_tab", null);
        return true;
      }
      case "W": {
        this.exit ();
        return true;
      }
    }

    return false;
  }

  public void do_paste_clipboard () {
    // FIXME: https://gitlab.gnome.org/GNOME/vte/-/issues/2557
    // this.paste_clipboard ();
    var cb = Gdk.Display.get_default ().get_clipboard ();
    cb.read_text_async.begin (null, (_, res) => {
      try {
        var text = cb.read_text_async.end (res);
        if (text != null) {
          this.paste_text (text);
        }
      }
      catch (Error e) {
        warning ("%s", e.message);
      }
    });
  }

  public void do_copy_clipboard () {
    if (this.get_has_selection ()) {
      Gdk.Display.get_default ().get_clipboard ()
        .set_text (this.get_text_selected ());
    }
  }

  public void do_paste_from_selection () {
    if (this.get_has_selection ()) {
      this.paste_text (this.get_text_selected ());
    }
  }
}
