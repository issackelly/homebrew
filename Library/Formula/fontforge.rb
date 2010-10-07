require 'formula'

class Fontforge <Formula
  url 'http://downloads.sourceforge.net/project/fontforge/fontforge-source/fontforge_full-20100501.tar.bz2'
  homepage 'http://fontforge.sourceforge.net'
  md5 '5f3d20d645ec1aa2b7b4876386df8717'

  depends_on 'pkg-config'
  depends_on 'gettext'
  depends_on 'pango'
  depends_on 'potrace'

  def install

    # python module fails with -march=core2 and -msse4.1
    # ENV.minimal_optimization

    system "./configure", "--prefix=#{prefix}",
                          "--enable-double",
                          "--without-freetype-bytecode",
                          "--with-python",
                          "--enable-pyextension"

    inreplace "Makefile" do |s|
      s.gsub! "/Applications", "$(prefix)"
      s.gsub! "/usr/local/bin", "$(bindir)"

      # setup.py does the wrong thing with --root=$(DESTDIR)
      # We want everything to live under our prefix, so we remove the "-root"
      # to force everything under the prefix.
      s.gsub! 'python setup.py install --prefix=$(prefix) --root=$(DESTDIR)', 'python setup.py install --prefix=$(prefix)'
    end

    system "make"
    system "make install"
  end

  def caveats; <<-EOS.undent
    fontforge is an X11 application.

    To install the Mac OS X wrapper application run:
      $ brew linkapps
    or:
      $ sudo ln -s #{prefix}/FontForge.app /Applications
    EOS
  end
end
