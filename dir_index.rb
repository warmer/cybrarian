#!/usr/bin/env ruby

require_relative 'common.rb'

require 'gdbm'
require 'digest/md5'
require 'json'

def dir_add(dir, file)
  entry = @@dir_db[dir]

  if entry
    entry = JSON.parse(entry)
  else
    # this directory has not been seen before
    entry = {'children' => {}, 'size' => 0}

    # add this directory to its parent
    dir_add(File.dirname(dir), dir) unless dir == '/'
  end

  # don't add a child that is already indexed
  return if entry['children'][file]

  if File.file?(file)
    entry['children'][file] = {'dir' => false, 'file' => true}
    entry['size'] += File.size(file)
  elsif File.directory?(file)
    entry['children'][file] = {'dir' => true, 'file' => false}
  end

  @@dir_db[dir] = entry.to_json
end

dbs = {}

@@dir_db = GDBM.new('DIRS.db')

# which extensions to browse?
ARGV.each do |db_path|
  unless File.exist?(db_path)
    puts "#{db_path} does not exist"
    exit
  end

  dbs[db_path] = GDBM.new(db_path)
end

# Look at every file within every database
# Find the parent directory of the given file's absolute path
# If the parent directory does not exist in the dir_db, create an entry
# and recursively include all parent directories until the next dir is found
dbs.each do |name, db|
  files = {}

  db.each do |full_path, value|
    m = JSON.parse(value)

    dir_add(File.dirname(full_path), full_path)
  end

  db.close
end

@@dir_db.close

