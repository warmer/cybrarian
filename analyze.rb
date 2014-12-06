#!/usr/bin/env ruby

require_relative 'common.rb'

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

