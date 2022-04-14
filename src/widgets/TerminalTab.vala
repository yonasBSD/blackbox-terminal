/* TerminalTab.vala
 *
 * Copyright 2021-2022 Paulo Queiroz
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

public class Terminal.TerminalTab : Gtk.Box {

  public signal void close_request();

  public string title { get; protected set; }

  public weak Window window;
  public Terminal terminal;

  public TerminalTab(Window window, string? cwd) {
    Object(
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 0,
      width_request: 300,
      height_request: 300
    );

    this.window = window;
    this.terminal = new Terminal(this.window, null, cwd);

    // Hack to stop vala-language-server from complaining
    var twig = this.terminal as Gtk.Widget;
    //  this.set_child(twig);
    this.append(twig);
    twig.grab_focus();

    //  this.window.settings.notify.connect(this.apply_settings);

    //  var click = new Gtk.GestureClick() {
    //    button = Gdk.BUTTON_SECONDARY,
    //  };

    //  click.released.connect(this.show_menu);

    //  this.add_controller(click);

    //  this.button_press_event.connect(this.show_menu);

    //  this.terminal.notify["window-title"].connect(() => {
    //    this.title = this.terminal.window_title;
    //  });

    this.terminal.exit.connect(() => {
      this.close_request();
    });
  }

  void apply_settings() {
    //  this.terminal.font_desc = Pango.FontDescription.from_string(
    //    this.window.settings.font
    //  );
  }

  public void show_menu(int n_pressed, double x, double y) {
    //  warning("I was called %d", n_pressed);

    var b = new Gtk.Builder.from_resource(
      "/com/raggesilver/Terminal/layouts/menu.ui"
    );
    var pop = b.get_object("popover") as Gtk.Popover;
    //  pop.set_relative_to(this);

    Gdk.Rectangle r = {0};
    r.x = (int) x;
    r.y = (int) y;

    pop.set_parent(this);
    pop.set_pointing_to(r);
    pop.present();
  }
}
