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

  public Terminal (Window window, string? command = null, string? cwd = null) {
    Object (allow_hyperlink: true);

    this.window = window;

    this.hexpand = true;
    this.vexpand = true;
    this.halign = Gtk.Align.FILL;
    this.valign = Gtk.Align.FILL;

    //  Marble.set_theming_for_data(this, "vte-terminal { padding: 10px; }");

    this.child_exited.connect (this.on_child_exited);
    //  this.button_press_event.connect(this.on_button_press);

    // FIXME: we should save settings in the Terminal namespace, not in a Window
    this.window.settings.notify["theme"].connect (this.update_ui);

    this.setup_drag_drop ();
    this.setup_regexes ();
    this.connect_accels ();
    this.update_ui ();

    this.spawn (command, cwd);
  }

  // Methods ===================================================================

  private void setup_drag_drop () {
    var target = new Gtk.DropTarget (Type.INVALID, Gdk.DragAction.COPY);

    //  target.
    //  Gtk.TargetEntry[] drag_targets = {
    //    { "text/uri-list", Gtk.TargetFlags.OTHER_APP, DropTargets.URILIST },
    //    { "STRING", Gtk.TargetFlags.OTHER_APP, DropTargets.STRING },
    //    { "text/plain", Gtk.TargetFlags.OTHER_APP, DropTargets.TEXT },
    //  };



    //  Gtk.drag_dest_set(
    //    this, Gtk.DestDefaults.ALL, drag_targets, Gdk.DragAction.COPY
    //  );
    //  this.drag_data_received.connect(this.on_drag_data_received);
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

  private void update_ui () {
    var ctx = this.get_style_context ();
    var theme = this.window.theme_provider.themes.get (
      this.window.settings.theme
  );

    if (theme == null) {
      warning ("INVALID THEME '%s'", this.window.settings.theme);
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

    if ((state & Gdk.ModifierType.CONTROL_MASK) == 0) {
      return false;
    }

    switch (Gdk.keyval_name (keyval)) {
      case "C": {
        if (this.get_has_selection ()) {
          warning ("Copying hasn't been implemented yet.");
          this.copy_clipboard_format (Vte.Format.TEXT);
        }
        return true;
      }
      case "V": {
        // FIXME: https://gitlab.gnome.org/GNOME/vte/-/issues/2557
        // this.paste_clipboard ();
        var cb = Gdk.Display.get_default ().get_clipboard ();
        cb.read_text_async.begin (null, (_, res) => {
          var text = cb.read_text_async.end (res);
          if (text != null) {
            this.paste_text (text);
          }
        });
        return true;
      }
    }

    return false;
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
