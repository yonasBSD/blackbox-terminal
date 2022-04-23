/* Settings.vala
 *
 * Copyright 2022 Paulo Queiroz
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

public class Terminal.Settings : Marble.Settings {
  public bool    fill_tabs              { get; set; }
  public bool    pixel_scrolling        { get; set; }
  public bool    pretty                 { get; set; }
  public bool    show_headerbar         { get; set; }
  public bool    remember_window_size   { get; set; }
  public bool    show_scrollbars        { get; set; }
  public bool    use_overlay_scrolling  { get; set; }
  public string  font                   { get; set; }
  public string  theme                  { get; set; }
  public uint    window_width           { get; set; }
  public uint    window_height          { get; set; }
  public Variant terminal_padding       { get; set; }

  private static Settings instance = null;

  private Settings () {
    base ("com.raggesilver.Terminal");
  }

  public static Settings get_default () {
    if (Settings.instance == null) {
      Settings.instance = new Settings ();
    }
    return Settings.instance;
  }

  public Padding get_padding () {
    return Padding.from_variant (this.terminal_padding);
  }

  public void set_padding (Padding padding) {
    this.terminal_padding = padding.to_variant ();
  }
}
