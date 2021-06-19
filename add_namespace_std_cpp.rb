#!/usr/bin/ruby

require 'optparse'

opt = OptionParser.new
OPTS = {}

OPTS[:d] = "."
excluded = Array.new

def usage()
	print <<-"EOB"
Usage: add_namespace_std_cpp.rb std_words_file [-d DIR] [-e PATTERN] [-n]
    -d DIR      source code directory
    -e PATTERN  excluded file pattern
    -v          verbose mode
    -n          no backup flag

	EOB
end

opt.on('-d VAL') {|v| OPTS[:d] = v }
opt.on('-e VAL') {|v| excluded.push v }
opt.on('-v') {|v| OPTS[:v] = v }
opt.on('-n') {|v| OPTS[:n] = v }
opt.on('-h', '--help') {
	usage
	exit
}

opt.parse!(ARGV)

if !ARGV[0]
	usage
	exit
end

$std_words = []
std_words_file_name = ARGV[0]
file = File.open(std_words_file_name, "r")
while line = file.gets
	line.chomp!
	if line == ""
		next
	elsif line =~ /^\s+$/
		next
	elsif line =~ /#/
		next
	end
	$std_words.push line
end
file.close

def conv_c_header(include_line)
	c_headers = [
		"<assert.h>",
		"<ctype.h>",
		"<errno.h>",
		"<fenv.h>",
		"<float.h>",
		"<limits.h>",
		"<math.h>",
		"<setjmp.h>",
		"<stdarg.h>",
		"<stddef.h>",
		"<stdint.h>",
		"<stdio.h>",
		"<stdlib.h>",
		"<string.h>",
		"<time.h>",
		"<wchar.h>",
	]
	c_headers.each {|h|
		if include_line.include?(h)
			new_header = '<c' + h.sub(/</, '').sub(/\.h/, '')
			return include_line.sub(Regexp.new(h), new_header)
		end
	}
	include_line
end

def add_std_namespace(file_name, count)
	file = File.open(file_name, "r")
	lines = []
	exists = false
	while line = file.gets
		if line =~ /#include/
			line = conv_c_header(line)
			lines.push(line)
			next
		end
		lines.push(line)
		$std_words.each {|w|
			regex_w = Regexp.new('\b' + w)
			if line =~ regex_w
				exists = true
			end
		}
	end
	file.close
	if !exists
		return
	end

	if !OPTS[:n]
		File.rename(file_name, file_name + ".bak")
	end

	if OPTS[:v]
		printf("[%d/%d] %s\n", count, $max_count, file_name)
	end

	file = File.open(file_name, "w")
	lines.each {|line|
		if line =~ /#include/
			file << line
			next
		end
		if line =~ /using\s+namespace\s+std\s*;/
			next
		end
		$std_words.each {|w|
			regex_w = Regexp.new('\b' + w)
			if line =~ regex_w
				s = w.match('\w+').to_s
				line.gsub!(Regexp.new('\b' + s + '\b'), "std::" + s)
				line.gsub!(/std::std::/, "std::")
			end
		}
		file << line
	}
	file.close
end


Dir.chdir(OPTS[:d])

$max_count = 0
Dir.glob("**/*.{cpp,cc,cxx}") {|fname|
	$max_count += 1
}

count = 0
Dir.glob("**/*.{cpp,cc,cxx}") {|fname|
	count += 1
	excluded_flag = false
	excluded.each {|ex|
		if fname =~ Regexp.new(ex)
			excluded_flag = true
			break
		end
	}
	if !excluded_flag
		add_std_namespace(fname, count)
	end
}
