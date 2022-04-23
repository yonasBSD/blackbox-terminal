namespace Terminal {
  public bool IS_X11 () {
    return Gdk.Display.get_default ().get_type () == typeof (Gdk.X11.Display);
  }
}
