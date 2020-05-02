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

const Gdk.RGBA solarized_palette[] = {
  /*
   * Solarized palette (1.0.0beta2):
   * http://ethanschoonover.com/solarized
   */
  { 0.02745,  0.211764, 0.258823, 1 },
  { 0.862745, 0.196078, 0.184313, 1 },
  { 0.521568, 0.6,      0,        1 },
  { 0.709803, 0.537254, 0,        1 },
  { 0.149019, 0.545098, 0.823529, 1 },
  { 0.82745,  0.211764, 0.509803, 1 },
  { 0.164705, 0.631372, 0.596078, 1 },
  { 0.933333, 0.909803, 0.835294, 1 },
  { 0,        0.168627, 0.211764, 1 },
  { 0.796078, 0.294117, 0.086274, 1 },
  { 0.345098, 0.431372, 0.458823, 1 },
  { 0.396078, 0.482352, 0.513725, 1 },
  { 0.513725, 0.580392, 0.588235, 1 },
  { 0.423529, 0.443137, 0.768627, 1 },
  { 0.57647,  0.631372, 0.631372, 1 },
  { 0.992156, 0.964705, 0.890196, 1 },
};

const Gdk.RGBA dracula_palette[] = {
    { 0, 0, 0, 1 },
    { 1, 0.3333333333333333, 0.3333333333333333, 1 },
    { 0.3137254901960784, 0.9803921568627451, 0.4823529411764706, 1 },
    { 0.9450980392156862, 0.9803921568627451, 0.5490196078431373, 1 },
    { 0.7411764705882353, 0.5764705882352941, 0.9764705882352941, 1 },
    { 1, 0.4745098039215686, 0.7764705882352941, 1 },
    { 0.5450980392156862, 0.9137254901960784, 0.9921568627450981, 1 },
    { 0.7333333333333333, 0.7333333333333333, 0.7333333333333333, 1 },
    { 0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 1 },
    { 1, 0.3333333333333333, 0.3333333333333333, 1 },
    { 0.3137254901960784, 0.9803921568627451, 0.4823529411764706, 1 },
    { 0.9450980392156862, 0.9803921568627451, 0.5490196078431373, 1 },
    { 0.7411764705882353, 0.5764705882352941, 0.9764705882352941, 1 },
    { 1, 0.4745098039215686, 0.7764705882352941, 1 },
    { 0.5450980392156862, 0.9137254901960784, 0.9921568627450981, 1 },
    { 1, 1, 1, 1 }
};

const Gdk.RGBA dracula_colors[] = {
    // FG
    { 0.9725490196078431, 0.9725490196078431, 0.9490196078431372, 1 },
    // BG
    { 0.11764705882352941, 0.12156862745098039, 0.1607843137254902, 1 },
};

public class Terminal.Terminal : Vte.Terminal
{
    public signal void ui_updated();
    public signal void new_window();

    public Pid pid;
    public Gdk.RGBA fg;
    public Gdk.RGBA bg;

    public Terminal(string? command = null)
    {
        Object();

        this.child_exited.connect((s) => {
            debug("Child exited with code %d", s);
            this.destroy();
        });

        this.style_updated.connect(this.update_ui);

        this.spawn(command);

        this.connect_accels();
        this.update_ui();

        foreach (var c in dracula_palette)
            message("[COLOR]: %s", c.to_string());
    }

    private void update_ui()
    {
        var ctx = this.get_style_context();

        if (!ctx.lookup_color("theme_base_color", out this.bg) ||
            !ctx.lookup_color("theme_fg_color", out this.fg))
            return;

        this.fg = dracula_colors[0];
        this.bg = dracula_colors[1];

        this.set_colors(dracula_colors[0], dracula_colors[1], dracula_palette);

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
                    SpawnFlags.DO_NOT_REAP_CHILD,
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
