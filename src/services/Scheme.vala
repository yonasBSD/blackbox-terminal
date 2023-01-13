/* Scheme.vala
 *
 * Copyright 2022 Paulo Queiroz <pvaqueiroz@gmail.com>
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

public class Terminal.Scheme : Object, Json.Serializable {
  public string           name              { get; set; }
  public string?          comment           { get; set; }
  public Gdk.RGBA?        foreground_color  { get; set; }
  public Gdk.RGBA?        background_color  { get; set; }
  public Array<Gdk.RGBA>? palette           { get; set; }

  public bool is_dark {
    get {
      return get_color_brightness (this.foreground_color) > 0.5f;
    }
  }

  public override bool deserialize_property (
    string    name,
    out Value @value,
    ParamSpec spec,
    Json.Node node
  ) {
    // Supress "possibly unitialized value"
    @value = Value(spec.value_type);

    switch (name) {
      case "foreground-color":
      case "background-color": {
        var data = node.get_string ();
        var color = rgba_from_string (data);

        if (color == null) return false;

        @value = color;
        return true;
      }

      case "palette": {
        var arr = node.get_array ();

        var res = new Array<Gdk.RGBA> ();

        for (uint i = 0; i < arr.get_length (); i++) {
          var data = arr.get_string_element (i);
          var color = rgba_from_string (data);

          if (color == null) return false;

          res.append_val (color);
        }

        @value = res;
        return true;
      }
    }

    return default_deserialize_property (name, out @value, spec, node);
  }

  public static Scheme? from_file (File file) throws Error {
    size_t length;
    string data = file.read_all (out length);

    var scheme = (Scheme) Json.gobject_from_data (
      typeof (Scheme),
      data
    );

    if (
      scheme.name == null ||
      scheme.foreground_color == null ||
      scheme.background_color == null ||
      scheme.palette?.length != 16
    ) {
      return null;
    }

    return scheme;
  }
}
