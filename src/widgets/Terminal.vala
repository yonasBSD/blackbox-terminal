/* Terminal.vala
 *
 * Copyright 2020 Paulo Queiroz <pvaqueiroz@gmail.com>
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
  public signal void ui_updated();
  public signal void new_window();

  public Pid pid;
  public Gdk.RGBA? fg;
  public Gdk.RGBA? bg;

  public Scheme scheme { get; set; }

  private weak Window window;

  public Terminal(Window window, string? command = null, string? cwd = null) {
    Object(allow_hyperlink: true);
    this.window = window;

    Marble.set_theming_for_data(this, "vte-terminal { padding: 10px; }");

    this.child_exited.connect(this.on_child_exited);
    this.button_press_event.connect(this.on_button_press);
    this.window.settings.notify["theme"].connect(this.update_ui);

    this.setup_regexes();
    this.connect_accels();
    this.update_ui();

    this.spawn(command, cwd);
  }

  private void on_child_exited() {
    this.destroy();
  }

  private bool on_button_press(Gdk.EventButton e) {
    string? url = this.match_check_event(e, null);

    if (
      url != null
      && e.button == Gdk.BUTTON_PRIMARY
      && (e.state & Gdk.ModifierType.CONTROL_MASK) != 0
    ) {
      try {
        Gtk.show_uri_on_window(this.window, url, e.time);
        return true;
      }
      catch (Error e) {
        warning(e.message);
      }
    }

    return false;
  }

  private void setup_regexes() {
    foreach (unowned string str in Constants.URL_REGEX_STRINGS) {
      try {
        var reg = new Vte.Regex.for_match(
          str, -1, PCRE2.Flags.MULTILINE
        );
        int id = this.match_add_regex(reg, 0);
        this.match_set_cursor_name(id, "pointer");
      }
      catch (Error e) {
        warning(e.message);
      }
    }
  }

  private void update_ui() {
    var ctx = this.get_style_context();
    var theme = this.window.theme_provicer.themes.get(this.window.settings.theme);

    if (theme == null)
    {
      warning("INVALID THEME '%s'", this.window.settings.theme);
      return;
    }

    this.bg = theme.background;
    this.fg = theme.foreground;

    if (this.bg == null &&
      !ctx.lookup_color("theme_base_color", out this.bg))
    {
      warning("Theme '%s' has no background, using fallback", theme.name);
      this.bg = { 0, 0, 0, 1 };
    }

    if (this.fg == null &&
      !ctx.lookup_color("theme_fg_color", out this.fg))
    {
      this.fg = { 1, 1, 1, 1 };
    }

    this.set_colors(this.fg, this.bg, theme.colors);

    this.ui_updated();
  }

  private void connect_accels() {
    this.key_press_event.connect(this.on_key_press);
  }

  private bool on_key_press(Gdk.EventKey e) {
    if ((e.state & Gdk.ModifierType.CONTROL_MASK) == 0) {
      return false;
    }
    switch (Gdk.keyval_name(e.keyval)) {
      case "C": {
        if (this.get_has_selection())
          this.copy_clipboard();
        return true;
      }
      case "V": {
        this.paste_clipboard();
        return true;
      }
      case "plus": {
        this.font_scale = double.min(10, this.font_scale + 0.1);
        return true;
      }
      case "underscore": {
        this.font_scale = double.max(0.1, this.font_scale - 0.1);
        return true;
      }
      case "N": {
        this.new_window();
        return true;
      }
    }
    return false;
  }

  private void spawn(string? command, string? cwd) {
    try {
      if (is_flatpak()) {
        string shell = fp_guess_shell() ?? "/usr/bin/bash";

        string[] real_argv = {
          "/usr/bin/flatpak-spawn",
          "--host",
          "--watch-bus"
        };

        var env = fp_get_env() ?? Environ.get();

        env += "G_MESSAGES_DEBUG=false";
        env += "TERM=xterm-256color";

        for (uint i = 0; i < env.length; i++)
          real_argv += @"--env=$(env[i])";

        real_argv += shell;
        if (command != null) {
          real_argv += "-c";
          real_argv += command;
        }
        else {
          real_argv += "--login";
        }

        spawn_sync(
          Vte.PtyFlags.NO_CTTY,
          cwd,
          real_argv,
          env,
          0,
          null, out pid, null);
      }
      else {
        var env = Environ.get();
        env += "G_MESSAGES_DEBUG=false";
        env += "TERM=xterm-256color";

        string[] argv = {
          Environ.get_variable(Environ.get(), "SHELL")
        };

        if (command != null)
        {
          argv += "-c";
          argv += command;
        }

        spawn_sync(
          Vte.PtyFlags.DEFAULT,
          cwd,
          argv,
          env,
          0,
          null, out pid, null);
      }
    }
    catch (Error e) {
      warning(e.message);
    }
  }
}
