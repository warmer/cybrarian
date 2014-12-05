#!/usr/bin/env ruby

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

dbs = {}

# which extension to browse?
ARGV.each do |db_path|
  unless File.exist?(db_path)
    puts "#{db_path} does not exist"
    exit
  end

  dbs[db_path] = GDBM.new(db_path)
end

dup_bytes = 0
tot_bytes = 0

dbs.each do |name, db|
  files = {}

  db.each do |key, value|
    m = JSON.parse(value)
    tot_bytes += m['size']
    md5 = m['md5']
    if files[md5]
      flist = files[md5]
      flist.each do |file|
        if file['size'] == m['size']
          puts "Likely duplicated (#{pretty_bytes(file['size'])}): #{file['name']}"
          dup_bytes += file['size']
        end
      end
    else
      files[md5] = [m]
    end
  end

  db.close
end

puts "Total duplication found: #{pretty_bytes(dup_bytes)}"
puts "Total size of index: #{pretty_bytes(tot_bytes)}"

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
