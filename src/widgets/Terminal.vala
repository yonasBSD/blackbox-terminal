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
    this.settings.notify["theme"].connect (this.on_theme_changed);
    this.settings.notify["font"].connect (this.on_font_changed);
    this.settings.notify["terminal-padding"].connect (this.on_padding_changed);

    this.window.theme_provider.extra_padding_request.connect ((pad) => {
      this.extra_padding = pad;
      this.on_padding_changed ();
    });

    this.setup_drag_drop ();
    this.setup_regexes ();
    this.connect_accels ();
    this.on_theme_changed ();
    this.on_font_changed ();
    this.on_padding_changed ();

    this.spawn (command, cwd);
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

    if (vtype == typeof (File)) {
      var file = (File) value.get_object ();
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
    var ctx = this.get_style_context ();
    var theme_name = this.settings.theme;
    var theme = this.window.theme_provider.themes.get (theme_name);

    if (theme == null) {
      warning ("INVALID THEME '%s'", theme_name);
      return;
    }

    this.bg = theme.background;
    this.fg = theme.foreground;

    // TODO: check if something changed with ctx.lookup_color in
    // Gtk 4/libadwaita, and if named colors in libadwaita work as intended here
    if (
      this.bg == null &&
      !ctx.lookup_color ("theme_base_color", out this.bg)
    ) {
      warning ("Theme '%s' has no background, using fallback", theme.name);
      this.bg = { 0, 0, 0, 1 };
    }

    if (
      this.fg == null &&
      !ctx.lookup_color ("theme_fg_color", out this.fg)
    ) {
      this.fg = { 1, 1, 1, 1 };
    }

    this.set_colors (this.fg, this.bg, theme.colors);
  }

  private Gtk.CssProvider? padding_provider = null;
  private Padding extra_padding = { 0 };

  private void on_padding_changed () {
    var pad = this.settings.get_padding ();

    if (this.padding_provider != null) {
      this.get_style_context ().remove_provider (this.padding_provider);
      this.padding_provider = null;
    }

    this.padding_provider = Marble.get_css_provider_for_data(
      "vte-terminal { padding: %upx %upx %upx %upx; }".printf(
        pad.top + extra_padding.top,
        pad.right + extra_padding.right,
        pad.bottom + extra_padding.bottom,
        pad.left + extra_padding.left
      )
    );

    this.get_style_context ().add_provider (
      this.padding_provider,
      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    );
  }

  private void connect_accels () {
    var kpcontroller = new Gtk.EventControllerKey ();

    kpcontroller.key_pressed.connect (this.on_key_pressed);

    this.add_controller (kpcontroller);
  }

  private void spawn (string? command, string? cwd) {
    string[] argv;
    string[] envv;
    Vte.PtyFlags flags = Vte.PtyFlags.DEFAULT;

    // Spawning works differently on host vs flatpak
    if (is_flatpak ()) {
      string shell = fp_guess_shell () ?? "/usr/bin/bash";

      argv = {
        "/usr/bin/flatpak-spawn",
        "--host",
        "--watch-bus"
      };

      envv = fp_get_env () ?? Environ.get ();

      envv += "G_MESSAGES_DEBUG=false";
      envv += "TERM=xterm-256color";

      foreach (unowned string env in envv) {
        argv += @"--env=$(env)";
      }

      argv += shell;

      // TODO: I believe if this worked correctly, when the command finished
      // our terminal would be killed. It would be nice to check other
      // terminal apps and see if they kill the terminal once the command
      // exits or if they go back to the shell.
      if (command != null) {
        argv += "-c";
        argv += command;
      }
      else {
        argv += "--login";
      }

      flags = Vte.PtyFlags.NO_CTTY;
    }
    else {
      envv = Environ.get ();
      envv += "G_MESSAGES_DEBUG=false";
      envv += "TERM=xterm-256color";

      argv = { Environ.get_variable (envv, "SHELL") };

      if (command != null) {
        argv += "-c";
        argv += command;
      }

      flags = Vte.PtyFlags.DEFAULT;
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
      case "C": {
        this.do_copy_clipboard ();
        return true;
      }
      case "V": {
        this.do_paste_clipboard ();
        return true;
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
      var text = cb.read_text_async.end (res);
      if (text != null) {
        this.paste_text (text);
      }
    });
  }

  public void do_copy_clipboard () {
    if (this.get_has_selection ()) {
      warning ("Copying hasn't been implemented yet.");
      this.copy_clipboard_format (Vte.Format.TEXT);
    }
  }

  //  private void on_drag_data_received(
  //    Gdk.DragContext _context,
  //    int _x,
  //    int _y,
  //    Gtk.SelectionData data,
  //    uint target_type,
  //    uint _time
  //  ) {
  //    // This function was based on Tilix's code
  //    // https://github.com/gnunn1/tilix/blob/5008e73a278a97871ca3628ee782fbad445917e7/source/gx/tilix/terminal/terminal.d
  //    switch (target_type) {
  //      case DropTargets.URILIST:
  //        string[] uris = data.get_uris();
  //        string text;
  //        File file;

  //        foreach (string uri in uris) {
  //          file = File.new_for_uri(uri);
  //          if (file != null) {
  //            text = file.get_path();
  //          }
  //          else {
  //            try {
  //              text = Filename.from_uri(uri, null);
  //            }
  //            catch (Error e) {
  //              warning(e.message);
  //              text = uri;
  //            }
  //          }
  //          this.feed_child(Shell.quote(text).data);
  //          this.feed_child(" ".data);
  //        }
  //        break;
  //      case DropTargets.STRING:
  //      case DropTargets.TEXT:
  //        string? text = data.get_text();
  //        if (text != null) {
  //          this.feed_child(text.data);
  //        }
  //        break;
  //    }
  //  }

  //  private bool on_button_press(Gdk.EventButton e) {
  //    string? url = this.match_check_event(e, null);

  //    if (
  //      url != null
  //      && e.button == Gdk.BUTTON_PRIMARY
  //      && (e.state & Gdk.ModifierType.CONTROL_MASK) != 0
  //    ) {
  //      try {
  //        Gtk.show_uri_on_window(this.window, url, e.time);
  //        return true;
  //      }
  //      catch (Error e) {
  //        warning(e.message);
  //      }
  //    }

  //    return false;
  //  }

  //  private bool on_key_press(Gdk.EventKey e) {
  //    if ((e.state & Gdk.ModifierType.CONTROL_MASK) == 0) {
  //      return false;
  //    }
  //    switch (Gdk.keyval_name(e.keyval)) {
  //      case "C": {
  //        if (this.get_has_selection())
  //          this.copy_clipboard();
  //        return true;
  //      }
  //      case "V": {
  //        this.paste_clipboard();
  //        return true;
  //      }
  //      case "plus": {
  //        this.font_scale = double.min(10, this.font_scale + 0.1);
  //        return true;
  //      }
  //      case "underscore": {
  //        this.font_scale = double.max(0.1, this.font_scale - 0.1);
  //        return true;
  //      }
  //      case "N": {
  //        this.window.activate_action("new_window", null);
  //        return true;
  //      }
  //      case "T": {
  //        this.window.activate_action("new_tab", null);
  //        return true;
  //      }
  //    }
  //    return false;
  //  }
}
