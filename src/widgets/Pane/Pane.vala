/* Pane.vala
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

public class Terminal.Pane {

    Terminal  term1;
    Terminal? term2 = null;
    Gtk.Paned paned;

    weak Window win;

    public Pane(Window win, Terminal? term = null) {
        this.win = win;
        this.paned = new Gtk.Paned(Gtk.Orientation.VERTICAL);

        if (term == null) {
            term = new Terminal(win, null);
        }

        this.paned.add1(term);
        this.paned.show_all();
        this.term1 = term;
    }

    // Add a new terminal to the bottom
    public void split_vertical() {
        this.paned.remove(this.term1);
    }

    // Add a new terminal to the right
    public void split_vertical() {}
}
