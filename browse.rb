#!/usr/bin/env ruby

require 'gdbm'
require 'digest/md5'
require 'json'
require 'io/console'
require_relative 'common.rb'

def char_in
  input = nil
  begin
    STDIN.echo = false
    STDIN.raw!

    input = STDIN.getc.chr
    if input == "\e"
      input << STDIN.read_nonblock(3) rescue nil
      input << STDIN.read_nonblock(2) rescue nil
    end
  ensure
    STDIN.echo = true
    STDIN.cooked!
  end

  return input
end

def ls(ref, objs)
  dir = @@dir_db[ref]

  puts "ls: directory not found in index: #{ref}" unless dir

  dir = JSON.parse(dir)

  # finds all items in the given directory
  to_read = dir['children']

  # ls specific items in the directory
  if objs and objs.size > 0
    # TODO: recursively call any items that are also directories
    objs.map!{|obj| File.join(ref, obj)}
    # TODO: print 'no such file or directory' when obj not found
    to_read.reject! {|file| not objs.include?(File.join(file))}
  end

  ref += '/' unless ref[-1] == '/'

  line = ''
  to_read.each do |path, detail|
    line += ' ' unless line == ''
    line += blue(path.split(ref)[1]) if detail['dir']
    line += path.split(ref)[1] if detail['file']
  end
  puts line
end

def cd(ref, args)
  if args.length != 1
    puts 'cd: requires single argument'

    return ref
  end

  dest = args[0]

  dir = File.join(ref, dest)

  meta = @@dir_db[dir]

  if meta
    ref = dir
  else
    puts "cd: directory not found in index: #{dir}"
  end

  ref
end

def do_cmd(path, args)
  cmd = args[0]

  case cmd
    when 'ls'
      ls(path, args[1..-1])
    when 'cd'
      path = cd(path, args[1..-1])
    when 'exit'
      exit 0
    else
      puts "Unknown command: #{cmd}"
  end

  path
end

def auto_complete(path, input, cursor)
  args = input.strip.split
  cmd = args[0]
  puts "## DEBUG ##"
  puts args.inspect
  puts path.inspect
  puts cursor.inspect
  puts "## DEBUG ##"
  prompt(path, input)

  # TODO: add '/' to the end of all paths so they match and display easier (when split)

  case cmd
    when 'cd'
      meta = JSON.parse(@@dir_db[path])
      children = meta['children']
      if children
        children = children.reject {|dir, meta| !meta or !meta['dir'] }
        # for now, ignore the cursor location
        if args.size == 1
          # only 'cd' - nothing else has been typed yet
          if children.size == 1
            dest = children.keys[0].split(path)[1]
            input = "cd #{dest}"
            cursor = input.size
            prompt(path, input)
          else
            puts "\n#{input}"
            prompt(path, args)
          end
        elsif args.size == 2
          frag = args[1]
          matches = children.select do |name, meta|
            meta['dir'] and name =~ /^#{frag}/
          end
          puts "## DEBUG ##"
          puts "Matches: #{matches}"
          puts "## DEBUG ##"
          prompt(path, input)

          # multiple matches returned
          if matches.size > 1
            puts "## DEBUG ##"
            puts "matches.size: #{matches.size}"
            puts "## DEBUG ##"

            options = matches.keys.sort.join(' ')
            puts blue(options)
            prompt(path, input)
          # a single match returned
          elsif matches.size == 1
            puts "## DEBUG ##"
            puts "matches.size: #{matches.size}"
            puts "## DEBUG ##"



            dest = matches.keys[0]
            input = "cd #{dest}"
            cursor = input.size
            prompt(path, input)
          # no matches
          else
            puts "## DEBUG ##"
            puts "matches.size: #{matches.size}"
            puts "## DEBUG ##"


            # do nothing
          end
          # part of a directory has been typed - look for matches
          prompt(path, input)
        end
      end
      # if no children - nothing to do
  end # case

  [input, cursor]
end

def prompt(path, cmd = '')
  print "\r#{path}> #{cmd}"
end

def backspace(path, cmd, cursor)
  prompt(path, cmd)
  print " " + "\e[D" * (1 + cmd.length - cursor)
end

def right
  print "\e[C"
end

def left
  print "\e[D"
end

def clear_prompt(path, cmd)
  prompt(path)
  cmd.length.times { print " " }
  cmd.length.times { left }
end

path = '/'
@@dir_db = GDBM.new('DIRS.db')

if ARGV.length > 0
  path = do_cmd(path, ARGV)
else
  begin
    state = `stty -g`
    `stty raw -echo -icanon isig`

    history = []
    hist_position = 0

    loop do
      history[hist_position] = ''
      cmd = history[hist_position]
      cursor = 0

      prompt(path)

      loop do
        char = char_in
        case char
        when "\t"
          cmd, cursor = auto_complete(path, cmd, cursor)
        when "\r"
          print "\r\n"
          break
        when "\n"
          print "\r\n"
          break
        when "\e"
          puts 'Just an escape'
        when "\e[A"
          # up
          if hist_position > 0
            clear_prompt(path, cmd)
            hist_position -= 1
            cmd = "#{history[hist_position]}"
            cursor = cmd.length
            prompt(path, cmd)
          end
        when "\e[B"
          # down
          if (hist_position + 1) < history.size
            clear_prompt(path, cmd)
            hist_position += 1
            cmd = "#{history[hist_position]}"
            cursor = cmd.length
            prompt(path, cmd)
          end
        when "\e[C"
          # right
          if cursor < cmd.length
            cursor += 1
            right
          end
        when "\e[D"
          # left
          if cursor > 0
            cursor -= 1
            left
          end
        when "\eOH"
          # Home
          cursor.times { left }
          cursor = 0
        when "\eOF"
          # End
          (cmd.length - cursor).times { right }
          cursor = cmd.length
        when "\177"
          if cursor > 0
            cmd = cmd[0...(cursor-1)] + cmd[cursor..-1]
            cursor -= 1
            backspace(path, cmd, cursor)
          end
        when "\004"
          puts 'DEL'
        when "\e[3~"
          puts "ALT DELETE"
        when /^.$/
          after = cmd[cursor..-1]
          print char + after
          after.length.times { left }
          cmd.insert(cursor, char)
          cursor += 1
        else
          puts "Something else: #{char.inspect}"
        end
      end

      cmd = cmd.strip
      if cmd.length > 0
        hist_position = history.size
        history[-1] = cmd
        #puts "history: #{history}; pos: #{hist_position}"
        path = do_cmd(path, cmd.strip.split)
      end

      print "\r"
    end
  ensure
    `stty #{state}`
  end
end

@@dir_db.close

system('stty -raw echo')
