/* File.vala
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

public class Terminal.File : Object {

  public GLib.File  file { get; protected set; }

  public string path {
    owned get {
      return this.file.get_path ();
    }
  }

  public File (string path) {
    Object ();

    this.file = GLib.File.new_for_path (path);
  }

  public File.new_from_file (GLib.File _file) {
    Object ();

    this.file = _file;
  }

  public string? read_all (out size_t bytes_read) throws Error {
    bytes_read = 0;

    var @is = FileStream.open (this.path, "r");
    @is.seek (0, FileSeek.END);

    size_t size = @is.tell ();
    @is.rewind ();

    var buf = new uint8[size];
    var read = @is.read (buf, 1);

    bytes_read = read;

    if (read != size) {
      warning ("Invalid read size");
    }

    return read == 0
      ? null
      : ((string) buf).make_valid ((ssize_t) read);
  }

  public void write_plus (string str) throws Error {
    var iostream = this.file.replace_readwrite (null, false, FileCreateFlags.NONE);
    var os = iostream.output_stream;
    os.write_all (str.data, null, null);
  }
}
