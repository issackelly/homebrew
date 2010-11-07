require 'set'
require 'blacklist'
require 'formula'
require 'hardware'

class FormulaInstaller
  @@attempted = Set.new

  def initialize
    @install_deps = true
  end

  attr_writer :install_deps

  def self.expand_deps f
    deps = []
    f.deps.collect do |dep|
      dep = Formula.factory dep
      deps += expand_deps dep
      deps << dep
    end
    deps
  end

  def pyerr dep
    brew_pip = ' brew install pip &&' unless Formula.factory('pip').installed?
    <<-EOS.undent
    Unsatisfied dependency, #{dep}
    Homebrew does not provide Python dependencies, pip does:

        #{brew_pip} pip install #{dep}
    EOS
  end
  def plerr dep; <<-EOS.undent
    Unsatisfied dependency, #{dep}
    Homebrew does not provide Perl dependencies, cpan does:

        cpan -i #{dep}
    EOS
  end
  def rberr dep; <<-EOS.undent
    Unsatisfied dependency "#{dep}"
    Homebrew does not provide Ruby dependencies, rubygems does:

        gem install #{dep}
    EOS
  end
  def jrberr dep; <<-EOS.undent
    Unsatisfied dependency "#{dep}"
    Homebrew does not provide JRuby dependencies, rubygems does:

        jruby -S gem install #{dep}
    EOS
  end

  def check_external_deps f
    return unless f.external_deps

    f.external_deps[:python].each do |dep|
      raise pyerr(dep) unless quiet_system "/usr/bin/env", "python", "-c", "import #{dep}"
    end
    f.external_deps[:perl].each do |dep|
      raise plerr(dep) unless quiet_system "/usr/bin/env", "perl", "-e", "use #{dep}"
    end
    f.external_deps[:ruby].each do |dep|
      raise rberr(dep) unless quiet_system "/usr/bin/env", "ruby", "-rubygems", "-e", "require '#{dep}'"
    end
    f.external_deps[:jruby].each do |dep|
      raise jrberr(dep) unless quiet_system "/usr/bin/env", "jruby", "-rubygems", "-e", "require '#{dep}'"
    end
  end

  def check_formula_deps f
    FormulaInstaller.expand_deps(f).each do |dep|
      begin
        install_private dep unless dep.installed?
      rescue
        #TODO continue if this is an optional dep
        raise
      end
    end
  end

  def install f
    if @install_deps
      check_external_deps f
      check_formula_deps f
    end
    install_private f
  end

  private

  def install_private f
    return if @@attempted.include? f.name
    @@attempted << f.name

    # 1. formulae can modify ENV, so we must ensure that each
    #    installation has a pristine ENV when it starts, forking now is
    #    the easiest way to do this
    # 2. formulae have access to __END__ the only way to allow this is
    #    to make the formula script the executed script
    read, write = IO.pipe
    # I'm guessing this is not a good way to do this, but I'm no UNIX guru
    ENV['HOMEBREW_ERROR_PIPE'] = write.to_i.to_s

    begin
      fork do
        begin
          read.close
          exec '/usr/bin/nice',
                '/usr/bin/ruby', '-I', HOMEBREW_REPOSITORY+"Library/Homebrew",
                '-rinstall', f.path,
                '--', *ARGV.options_only
        rescue => e
          Marshal.dump(e, write)
          write.close
          exit! 1
        end
      end
      ignore_interrupts do # because child proc will get it and marshall it back
        write.close
        Process.wait
        data = read.read
        raise Marshal.load(data) unless data.nil? or data.empty?
        raise "Suspicious installation failure" unless $?.success?
      end
    end
  end
end


def brew_install
  check_for_blacklisted_formula(ARGV.named)

  case Hardware.cpu_type when :ppc, :dunno
    abort "Sorry, Homebrew does not support your computer's CPU architecture.\n"+
          "For PPC support, see: http://github.com/sceaga/homebrew/tree/powerpc"
  end

  raise "Cannot write to #{HOMEBREW_CELLAR}" if HOMEBREW_CELLAR.exist? and not HOMEBREW_CELLAR.writable?
  raise "Cannot write to #{HOMEBREW_PREFIX}" unless HOMEBREW_PREFIX.writable?

  begin
    if MACOS_VERSION >= 10.6
      if llvm_build < RECOMMENDED_LLVM
        opoo "You should upgrade to Xcode 3.2.3"
      end
    else
      if (gcc_40_build < RECOMMENDED_GCC_40) or (gcc_42_build < RECOMMENDED_GCC_42)
        opoo "You should upgrade to Xcode 3.1.4"
      end
    end
  rescue
    # the reason we don't abort is some formula don't require Xcode
    # TODO allow formula to declare themselves as "not needing Xcode"
    opoo "Xcode is not installed! Builds may fail!"
  end

  if macports_or_fink_installed?
    opoo "It appears you have MacPorts or Fink installed."
    puts "Software installed with MacPorts and Fink are known to cause problems."
    puts "If you experience issues try uninstalling these tools."
  end

  installer = FormulaInstaller.new
  installer.install_deps = !ARGV.include?('--ignore-dependencies')

  ARGV.formulae.each do |f|
    if not f.installed? or ARGV.force?
      installer.install f
    else
      puts "Formula already installed: #{f.prefix}"
    end
  end
end
