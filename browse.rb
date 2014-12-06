#!/usr/bin/env ruby

require 'gdbm'
require 'digest/md5'
require 'json'
require 'io/console'

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

  unless dir
    puts "ls: directory not found in index: #{ref}"
  end

  dir = JSON.parse(dir)

  to_read = dir['children']

  if objs and objs.size > 0
    objs.map!{|obj| File.join(ref, obj)}
    to_read.reject! {|file| not objs.include?(File.join(file))}
  end

  to_read.each do |path, detail|
    puts path.split(ref)[1]
  end
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
          print "\t"
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
