/* TerminalTab.vala
 *
 * Copyright 2021 Paulo Queiroz
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

public class Terminal.TerminalTab : Gtk.EventBox {
  public signal void close();

  public string title { get; protected set; }

  public weak Window window;
  public Terminal terminal;

  public TerminalTab(Window window, string? cwd) {
    Object();

    this.window = window;
    this.terminal = new Terminal(this.window, null, cwd);

    this.add(this.terminal);
    this.show_all();

    this.window.settings.notify.connect(this.apply_settings);
    this.button_press_event.connect(this.show_menu);

    this.terminal.notify["window-title"].connect(() => {
      this.title = this.terminal.window_title;
    });

    this.terminal.destroy.connect(() => {
      this.close();
    });
  }

  void apply_settings() {
    this.terminal.font_desc = Pango.FontDescription.from_string(
      this.window.settings.font
    );
  }

  public bool show_menu(Gdk.Event e) {
    if (e.button.button != Gdk.BUTTON_SECONDARY)
      return false;

    var b = new Gtk.Builder.from_resource(
      "/com/raggesilver/Terminal/layouts/menu.ui"
    );
    var pop = b.get_object("popover") as Gtk.Popover;
    pop.set_relative_to(this);

    Gdk.Rectangle r = {0};
    r.x = (int)e.button.x;
    r.y = (int)e.button.y;

    pop.set_pointing_to(r);
    pop.popup();

    return true;
  }
}
