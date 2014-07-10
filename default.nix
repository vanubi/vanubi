let
  pkgs = import <nixpkgs> {};
in with pkgs;
stdenv.mkDerivation {
  name = "vanubi-0.0.13";

  buildInputs = [ pkgconfig vala which autoconf automake libtool glib gtk3 gnome3.gtksourceview 
                  gnome3.vte libwnck3 asciidoc python3Packages.pygments
  ];

  configureScript = "./autogen.sh";

  meta = with stdenv.lib; {
    homepage = http://vanubi.github.io/vanubi;
    description = "Programming editor";
    platforms = platforms.linux;
    maintainers = [ maintainers.lethalman ];
  };
}
