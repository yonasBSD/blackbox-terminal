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

namespace Terminal
{
    public bool is_flatpak()
    {
        return (FileUtils.test("/.flatpak-info", FileTest.EXISTS));
    }

    /* fp_guess_shell
     *
     * Copyright 2019 Christian Hergert <chergert@redhat.com>
     *
     * The following function is a derivative work of the code from
     * https://gitlab.gnome.org/chergert/flatterm which is licensed under the
     * Apache License, Version 2.0 <LICENSE-APACHE or
     * https://opensource.org/licenses/MIT>, at your option. This file may not
     * be copied, modified, or distributed except according to those terms.
     *
     * SPDX-License-Identifier: (MIT OR Apache-2.0)
     */
    public string? fp_guess_shell(Cancellable? cancellable = null) throws Error
    {
        if (!is_flatpak())
            return (Vte.get_user_shell());

        string[] argv = { "flatpak-spawn", "--host", "getent", "passwd",
            Environment.get_user_name() };

        var launcher = new GLib.SubprocessLauncher(
            SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE
        );

        launcher.unsetenv("G_MESSAGES_DEBUG");
        var sp = launcher.spawnv(argv);

        if (sp == null)
            return (null);

        string? buf = null;
        if (!sp.communicate_utf8(null, cancellable, out buf, null))
            return (null);

        var parts = buf.split(":");

        if (parts.length < 7)
        {
            return (null);
        }

        return (parts[6].strip());
    }

    public string[]? fp_get_env(Cancellable? cancellable = null) throws Error
    {
        if (!is_flatpak())
            return (Environ.get());

        string[] argv = { "flatpak-spawn", "--host", "env" };

        var launcher = new GLib.SubprocessLauncher(
            SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE
        );

        launcher.setenv("G_MESSAGES_DEBUG", "false", true);

        var sp = launcher.spawnv(argv);

        if (sp == null)
            return (null);

        string? buf = null;
        if (!sp.communicate_utf8(null, cancellable, out buf, null))
            return (null);

        string[] arr = buf.strip().split("\n");

        return (arr);
    }
}

public class Terminal.Terminal : Vte.Terminal
{
    public signal void ui_updated();
    public signal void new_window();

    public Pid pid;
    public Gdk.RGBA? fg;
    public Gdk.RGBA? bg;

    public Scheme scheme { get; set; }

    private weak Window window;

    public Terminal(Window window, string? command = null)
    {
        Object();

        this.window = window;

        this.child_exited.connect((s) => {
            debug("Child exited with code %d", s);
            this.destroy();
        });

        this.style_updated.connect(this.update_ui);
        this.window.settings.notify["theme"].connect(this.update_ui);

        this.spawn(command);

        this.connect_accels();
        this.update_ui();
    }

    private void update_ui()
    {
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

    private void connect_accels()
    {
        this.key_press_event.connect(this.on_key_press);
    }

    private bool on_key_press(Gdk.EventKey e)
    {
        if ((e.state & Gdk.ModifierType.CONTROL_MASK) == 0)
            return (false);
        switch (Gdk.keyval_name(e.keyval))
        {
            case "C": {
                if (this.get_has_selection())
                    this.copy_clipboard();
                return (true);
            }
            case "V": {
                this.paste_clipboard();
                return (true);
            }
            case "plus": {
                this.font_scale = double.min(10, this.font_scale + 0.1);
                return (true);
            }
            case "underscore": {
                this.font_scale = double.max(0.1, this.font_scale - 0.1);
                return (true);
            }
            case "N": {
                this.new_window();
                return (true);
            }
        }
        return (false);
    }

    private void spawn(string? command = null)
    {
        try
        {
            if (is_flatpak())
            {
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
                if (command != null)
                {
                    real_argv += "-c";
                    real_argv += command;
                }
                else
                    real_argv += "--login";

                spawn_sync(
                    Vte.PtyFlags.NO_CTTY,
                    null,
                    real_argv,
                    env,
                    0,
                    null, out pid, null);
            }
            else
            {
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

                spawn_sync(Vte.PtyFlags.DEFAULT,
                    null,
                    argv,
                    env,
                    0,
                    null, out pid, null);
            }
        }
        catch (Error e)
        {
            warning(e.message);
        }
    }
}
