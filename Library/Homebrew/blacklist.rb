
def blacklisted? name
  case name.downcase
  when 'vim', 'screen'
    "Apple distributes #{name} with OS X."
  when 'libxml', 'libarchive', 'libpcap'
    "Apple distributes #{name} with OS X, you can find it in /usr/lib."
  when 'libxlst', 'freetype', 'libpng' then <<-EOS.undent
    Apple distributes #{name} with OS X, you can find it in /usr/X11/lib.
    However not all build scripts look here, so you may need to call ENV.x11 or
    ENV.libxml2 in your formula's install function.
    EOS
  when /rubygems?/
    "Sorry RubyGems comes with OS X so we don't package it."
  when /wxwidgets?/ then <<-EOS.undent
    #{name} is blacklisted for creation
    An older version of wxWidgets is provided by Apple with OS X, but
    a formula for wxWidgets 2.8.10 is provided:

        brew install wxmac
    EOS
  when 'tex', 'tex-live', 'texlive' then <<-EOS.undent
    Installing TeX from source is weird and gross, requires a lot of patches,
    and only builds 32-bit (and thus can't use Homebrew deps on Snow Leopard.)

    We recommend using a MacTeX distribution: http://www.tug.org/mactex/
    EOS
  when 'mercurial', 'hg' then <<-EOS.undent
    Mercurial can be install thusly:

        brew install pip && pip install mercurial
    EOS
  when 'setuptools' then <<-EOS.undent
    When working with a Homebrew-built Python, distribute is preferred
    over setuptools, and can be used as the prerequisite for pip.

    Install distribute using:

        brew install distribute
    EOS
  end
end
