#!/usr/bin/env ruby

require 'gdbm'
require 'digest/md5'
require 'json'

MAX_FILE_SIZE = 25 * 2**20

KEEP_OPEN = {
  '.JPG' => true,
  '.yaml' => true,
  'NONE' => true,
  '.html' => true,
  '.jpg' => true,
  '.h' => true,
  '.mp3' => true,
  '.zip' => true,
  '.png' => true,
  '.gz' => true,
  '.gif' => true,
  '.c' => true,
  '.php' => true,
  '.xml' => true,
  '.ini' => true,
  '.py' => true,
  '.txt' => true,
  '.htm' => true,
  '.pdf' => true,
  '.dat' => true,
  '.rb' => true,
  '.exe' => true,
  '.bmp' => true,
  '.css' => true,
  '.js' => true,
  '.dll' => true,
  '.doc' => true,
  '.docx' => true,
  '.GIF' => true,
  '.MP3' => true,
  '.XML' => true,
  'MISC' => true,
}

# find all files
file_list = Dir.glob(ARGV[0])

# tracked databases, per extension
@@dbs = {}

@@ext = GDBM.new('extensions.db')

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

checked = 0
db_miss = 0
db_hit = 0
skipped = 0

puts "Found #{file_list.count} files..."

file_list.each do |f|
  if File.file?(f)
    checked += 1

    ext = File.extname(f)
    ext = 'NONE' if ext.length == 0

    if @@ext[ext] == nil
      if File.exist?(ext + '.db')
        @@ext[ext] = 'y'
      elsif ext =~ /^\.[a-z\-\_]{1,8}_[a-z0-9]{8}$/
        ans = 'n'
        @@ext[ext] = ans
      else
        puts
        puts "From [#{f}]"
        puts "Track extension: '#{ext}' ?"
        ans = STDIN.gets
        @@ext[ext] = ans[0]
      end
    end

    unless @@ext[ext] == 'y'
      next
    end

    db = db_for(ext)

    meta = db[f]
    if meta
      db_hit += 1
      #meta = JSON.parse(meta)
      next
    else
      db_miss += 1
      meta = meta_for(f)
      db[f] = meta.to_json
    end
  else
    skipped += 1
  end
  if checked % 100 == 0
    print "#{checked} of #{file_list.count}\r"
    $stdout.flush
  end

end

puts
puts '========================'
puts "Checked #{checked} files"
puts "Added #{db_miss} files to the DB"
puts "Skipped #{skipped} files"
puts "#{db_hit} files already in the DB"

@@dbs.each do |ext, db|
  db.close
end
