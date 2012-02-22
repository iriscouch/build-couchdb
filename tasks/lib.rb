# Miscellaneous utilities
#

require 'uri'
require 'find'
require 'tmpdir'
require 'fileutils'

$stdout_old = $stdout
$stderr_old = $stderr

log_filename = "rake.log"
File.unlink(log_filename) if File.exists?(log_filename)

unless ARGV[0] == 'environment:shell' || ENV['raw']
  ["$stdout", "$stderr"].each do |std|
    rd, wr = IO.pipe
    if fork
      rd.close
      wr.sync = true
      eval "#{std}.reopen(wr)"
      eval "#{std}.sync = true"
      #Process.wait
    else
      # Child
      wr.close
      begin
        # Input must be forked.
        label = std[1..-1].upcase
        File.open(log_filename, 'a') do |f|
          f.sync = true
          while(line = rd.gets)
            eval "#{std}_old.puts(line)"
            f.puts([label, line].join(' '))
          end
        end
      ensure
        rd.close
        exit
      end
    end
  end
end

#
# Backward-compatibility stuff
#

unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

# This is the Ruby v1.9.1 Dir.mktmpdir.
if ! Dir.respond_to? :mktmpdir
  def Dir.mktmpdir(prefix_suffix=nil, tmpdir=nil)
    case prefix_suffix
    when nil
      prefix = "d"
      suffix = ""
    when String
      prefix = prefix_suffix
      suffix = ""
    when Array
      prefix = prefix_suffix[0]
      suffix = prefix_suffix[1]
    else
      raise ArgumentError, "unexpected prefix_suffix: #{prefix_suffix.inspect}"
    end
    tmpdir ||= Dir.tmpdir
    t = Time.now.strftime("%Y%m%d")
    n = nil
    begin
      path = "#{tmpdir}/#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}"
      path << "-#{n}" if n
      path << suffix
      Dir.mkdir(path, 0700)
    rescue Errno::EEXIST
      n ||= 0
      n += 1
      retry
    end

    if block_given?
      begin
        yield path
      ensure
        FileUtils.remove_entry_secure path
      end
    else
      path
    end
  end
end

#
# Sub-libraries
#

require_relative 'lib/distros'
require_relative 'lib/package_dep'

#
# Main code
#

# Return the directories needed in $PATH for this distro (:known_distro task must run already)
def path_dirs_for_distro(opts={})
  dirs = [ "#{BUILD}/bin" ]
  dirs << "#{COUCH_BUILD}/bin" if opts[:couch_too] && COUCH_BUILD != BUILD
  dirs = %w[ /opt/csw/gcc4/bin /opt/csw/bin /usr/ccs/bin ] + dirs if DISTRO[0] == :solaris
  return dirs
end

# Place a script in the install location to set the PATH, LD_LIBRARY_PATH, and whatever else.
# Requires the :known_distro task
def install_env_script(opts={})
  target = opts[:to] || raise("Need :to parameter")

  script = 'env.sh'
  dirs = { 'PATH' => { 'insert' => path_dirs_for_distro(:couch_too => true),
                       'append' => [] },
         }

  # XXX: Code duplication from :configure.
  dirs['DYLD_LIBRARY_PATH'] = {'insert' => ["#{target}/lib"]} if DISTRO[0] == :osx

  template = ERB.new(File.open("#{HERE}/templates/#{script}.erb").read())
  FileUtils.mkdir_p(target)
  File.open("#{target}/#{script}", 'w') do |outfile|
    outfile.write(template.result(binding))
    outfile.close
  end
end

# Run GNU Make
def gmake(cmd="")
  gmake = DISTRO[0] == :solaris ? 'gmake' : 'make'
  sh "#{gmake} #{cmd}"
end

# Mark a program as authorized to listen on a low port in Linux.
def set_port_cap file
  return unless [:ubuntu, :debian].include? DISTRO[0]
  sh "sudo setcap cap_net_bind_service=+ep #{File.expand_path file}"
end

# TODO: Get rid of this. Packages should be installed as a dependency of other software, declared by package_dep().
def install_packages packages
  case DISTRO[0]
    when :opensuse
      installed = %x[rpm -qa].split("\n")
      packages.select{|pkg| ! installed.detect{|d| d =~ /^#{Regexp.escape(pkg)}/ } }.each do |package|
        # puts "Installing #{package} ..."
        %x[sudo zypper install '#{package}']
      end
    when :solaris
      installed = `pkg-get -l`.split("\n")
      packages.select{|pkg| ! installed.include? pkg }.each do |package|
        sh "sudo pkg-get install #{package}"
      end
    else
      installed = `dpkg --list`.split("\n").map { |x| x.split[1] } # Hm, this is out of scope if defined outside.
      packages.select{ |pkg| ! installed.include? pkg }.each do |package|
      sh "sudo apt-get -y install #{package}"
    end
  end
end

def canonical_path path
  path.gsub(/[\.\d]*$/, '')
end


def ln_canonical path
  puts "#{path} => #{canonical_path path}"
  FileUtils.ln_sf path, canonical_path(path)
end

def show_file filename
  begin
    yield
  ensure
    puts "== Output of #{filename} =="
    sh "cat #{filename}"
    puts "== End of #{filename} =="
  end
end

def with_autoconf ver
  files = %w[ autoconf autoheader autom4te ].map { |x| "#{BUILD}/bin/#{x}#{ver}" }

  begin
    files.each { |x| ln_canonical x }
    yield
  ensure
    files.each do |x|
      puts "rm_f #{canonical_path x}"
      FileUtils.rm_f(canonical_path(x))
    end
  end
end

def copy_parts opts
  Dir.chdir opts[:source] do
    dirs = opts[:dirs].select{|dir| File.exist?(dir) }
    unless dirs.empty?
      sh "tar cf - #{dirs.join(' ')} | tar xvf - --directory #{opts[:target]}"
    end
  end
end

def in_build_dir label
  label = File.basename Dir.getwd if label.nil?
  Dir.mktmpdir "#{label}_build" do |dir|
    Dir.chdir dir do
      yield
    end
  end
end

def compress_beams source
  if ENV['compress_beams'] != 'false'
    Find.find(source) do |path|
      if File.file?(path) && path.match(/\.beam$/) && ENV['skip_compress_beam'].nil?
        sh "gzip -9 '#{path}'"
        sh "mv '#{path}'.gz '#{path}'"
      end
    end
  end
end

def record_manifest task_name
  return if ENV['manifest'].nil? || ENV['manifest'] == ""

  task_name = File.basename(task_name) if task_name =~ /\//

  sh "mkdir -p #{MANIFESTS}"
  seen = {}
  Dir.glob("#{MANIFESTS}/*").each do |manifest|
    File.new(manifest).each do |line|
      path = line.chomp
      raise "Woa! #{path} is in #{task_name} but was already seen in #{seen[path]}" if seen[path]
      seen[path] = File.basename(manifest)
    end
  end

  unseen = []
  Find.find(BUILD) do |path|
    if File.directory? path
      Find.prune if path == MANIFESTS
    else
      if seen[path]
        #puts "#{path} seen: #{seen[path]}"
      else
        unseen.push path
      end
    end
  end

  manifest = File.new("#{MANIFESTS}/#{task_name}", 'w')
  manifest.write(unseen.join("\n"))
  manifest.write("\n")
  manifest.close
end

def run_task name
  task = Rake::Task[name]
  task.reenable if task.methods.include?("reenable")
  task.invoke
end

def configure_cmd(source, opts={})
  libs = ["#{BUILD}/lib"]

  if DISTRO[0] == :solaris
    libs += %w[ /opt/csw/lib /opt/csw/gcc4/lib /opt/csw/lib/i386 ]
  end

  ldflags = libs.map do |lib|
    if DISTRO[0] == :osx && /^11\.\d+\.|^10\.8\./.match(DISTRO[1]) # 11.*
      "-L#{lib}"                        # llvm in OS X Lion
    else
      "-Xlinker -rpath=#{lib} -L#{lib}" # GCC
    end
  end

  ldflags = ldflags.join(' ')
  ldflags += ' -llber' if DISTRO[0] == :solaris

  env = "LDFLAGS='#{ldflags}' CPPFLAGS='-I#{BUILD}/include -I#{BUILD}/include/js'"

  # Determine whether to use a --prefix parameter. Default is to use it.
  prefix = ""
  prefix = "--prefix='#{COUCH_BUILD}'" if opts[:prefix] == :couch
  prefix = "--prefix='#{BUILD}'"       if opts[:prefix] == :deps

  js = "--with-js-include='#{BUILD}/include/js' --with-js-lib='#{BUILD}/lib'"

  return "env #{env} #{source}/configure #{prefix} #{js} --with-erlang=#{BUILD}/lib/erlang/usr/include"
end

def git_checkout_name(url)
  URI.escape(url, /[\/:]/)
end

def git_checkout(url_and_commit, opts={})
  remote, commit = url_and_commit.split
  checkout = "#{HERE}/git-build/#{git_checkout_name(remote + ':' + commit)}"
  return checkout if opts[:noop]

  fetch = false
  if File.directory?(checkout) || File.symlink?(checkout)
    puts "Using #{checkout} for build from Git"
    fetch = true
  elsif File.exists? checkout
    raise "Don't know what to do with #{checkout}"
  else
    sh "git clone '#{remote}' '#{checkout}'"
  end

  Dir.chdir checkout do
    sh "git fetch origin" if fetch
    sh "git checkout #{commit}"
    sh "git reset --hard"
    sh "git clean -f -d"
    # Forego a nice rm command to get OS-independence.
    #rm = (DISTRO[0] == :solaris) ? 'rm' : 'rm -v'
    rm = 'rm'
    sh "git ls-files --others -i --exclude-standard | xargs #{rm} || true"
  end

  return checkout
end

def otp_app_useful?(app)
  return false if app == 'hipe'

  otp_keep = ENV['otp_keep'] || ''
  return true if otp_keep == '*'

  return otp_keep.split.include?(app)
end

def skip_otp_app(app)
  skip = File.new("#{DEPS}/otp/lib/#{app}/SKIP", "w")
  skip.write("Not needed by CouchDB\n")
  skip.close
end

module Rake
  module TaskManager
    def in_explicit_namespace(name)
      oldscope = @scope;
      @scope = Array.new();
      # build scope name list from name here
      ns = NameSpace.new(self, @scope);
      yield(ns)
      ns
      ensure
        @scope = oldscope;
    end
  end
end

#
# Build Places
#

DEPS = "#{HERE}/dependencies"
BUILD = ENV['prefix'] || ENV['install'] || "#{HERE}/build"
JS_LIB = "#{BUILD}/bin/js-config"
ERL_BIN = "#{BUILD}/bin/erl"
ICU_BIN = "#{BUILD}/bin/icu-config"
CURL_BIN = "#{BUILD}/bin/curl"
COUCH_SOURCE = ENV['git'] ? git_checkout(ENV['git'], :noop => true) : "#{DEPS}/couchdb"
COUCH_BUILD = ENV['couchdb_build'] || BUILD
COUCH_BIN = "#{COUCH_BUILD}/bin/couchdb"
MANIFESTS = "#{BUILD}/manifests"

PIDS = "#{BUILD}/var/run/couchdb"

AUTOMAKE        = "#{BUILD}/bin/automake"
AUTOMAKE_SOURCE = "#{DEPS}/automake-1.11.2"

AUTOCONF_213 = "#{BUILD}/bin/autoconf2.13"
AUTOCONF_259 = "#{BUILD}/bin/autoconf2.59"
AUTOCONF_262 = "#{BUILD}/bin/autoconf2.62"
