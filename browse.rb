#!/usr/bin/env ruby

require 'gdbm'
require 'digest/md5'
require 'json'

dbs = {}

# which extension to browse?
ARGV.each do |db_path|
  unless File.exist?(db_path)
    puts "#{db_path} does not exist"
    exit
  end

  dbs[db_path] = GDBM.new(db_path)
end

dbs.each do |name, db|
  db.each do |key, value|
    m = JSON.parse(value)
    puts "#{key}: #{m['size']}\t#{m['md5']}\t#{m['name']}\t#{m['dirs']}"
  end

  db.close
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
