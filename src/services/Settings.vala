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
  public bool    command_as_login_shell { get; set; }
  public bool    easy_copy_paste        { get; set; }
  public bool    fill_tabs              { get; set; }
  public bool    hide_single_tab        { get; set; }
  public bool    pixel_scrolling        { get; set; }
  public bool    pretty                 { get; set; }
  public bool    remember_window_size   { get; set; }
  public bool    show_headerbar         { get; set; }
  public bool    show_menu_button       { get; set; }
  public bool    show_scrollbars        { get; set; }
  public bool    stealth_single_tab     { get; set; }
  public bool    use_custom_command     { get; set; }
  public bool    use_overlay_scrolling  { get; set; }
  public bool    was_fullscreened       { get; set; }
  public bool    was_maximized          { get; set; }
  public double  terminal_cell_height   { get; set; }
  public double  terminal_cell_width    { get; set; }
  public string  custom_shell_command   { get; set; }
  public string  font                   { get; set; }
  public string  theme_dark             { get; set; }
  public string  theme_light            { get; set; }
  public uint    cursor_shape           { get; set; }
  public uint    style_preference       { get; set; }
  public uint    window_height          { get; set; }
  public uint    window_width           { get; set; }
  public Variant terminal_padding       { get; set; }

  public bool floating_controls                       { get; set; }
  public uint floating_controls_hover_area            { get; set; }
  public uint delay_before_showing_floating_controls  { get; set; }

  private static Settings instance = null;

  private Settings () {
    base ("com.raggesilver.BlackBox");
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

public class Terminal.SearchSettings : Marble.Settings {
  public bool    clear_selection_on_exit  { get; set; }
  public bool    fixed                    { get; set; }
  public bool    match_case_sensitive     { get; set; }
  public bool    match_whole_words        { get; set; }
  public bool    match_regex              { get; set; }
  public bool    wrap_around              { get; set; }

  private static SearchSettings instance = null;

  private SearchSettings () {
    base ("com.raggesilver.BlackBox.terminal.search");
  }

  public static SearchSettings get_default () {
    if (SearchSettings.instance == null) {
      SearchSettings.instance = new SearchSettings ();
    }
    return SearchSettings.instance;
  }
}
