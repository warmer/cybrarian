require 'gdbm'
require 'digest/md5'
require 'json'

def pretty_bytes(raw)
  pretty = "#{raw} bytes"
  if raw > 2**30
    pretty = "#{((raw * 1.0) / 2**30).round(3)} GB"
  elsif raw > 2**20
    pretty = "#{((raw * 1.0) / 2**20).round(3)} MB"
  elsif raw > 2**10
    pretty = "#{((raw * 1.0) / 2**10).round(3)} KB"
  end

  pretty
end

def color(txt = '', code)
  "\033[#{code}m#{txt}\033[0m"
end

def red(txt)
  color(txt, '31')
end

def green(txt)
  color(txt, '32')
end

def blue(txt)
  color(txt, '34')
end

def db_for(ext)
  unless ext and ext != ""
    ext = 'NONE'
  end

  @@dbs[ext] ||= GDBM.new(ext + '.db')
end

def dirs_for(f, root = '/')
  dirs = []

  f = File.dirname(f)
  while f != root
    dirs << File.basename(f)
    f = File.dirname(f)
  end

  dirs
end

def meta_for(f)
  meta = {}

  meta[:name] = File.basename(f)
  meta[:size] = File.size(f)
  meta[:atime] = File.atime(f)
  meta[:ctime] = File.ctime(f)
  meta[:mtime] = File.mtime(f)
  meta[:apath] = File.absolute_path(f)
  meta[:dirs] = dirs_for(f)
  if File.size(f) <= MAX_FILE_SIZE
    meta[:md5] = Digest::MD5.hexdigest( File.read(f) )
  else
    meta[:md5] = nil
  end

  meta
end
