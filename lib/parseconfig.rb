#
# Author::      BJ Dierkes <derks@datafolklabs.com>
# Copyright::   Copyright (c) 2006,2013 BJ Dierkes
# License::     MIT
# URL::         https://github.com/datafolklabs/ruby-parseconfig
#

# This class was written to simplify the parsing of configuration
# files in the format of "param = value".  Please review the
# demo files included with this package.
#
# For further information please refer to the './doc' directory
# as well as the ChangeLog and README files included.
#

# Note: A group is a set of parameters defined for a subpart of a
# config file

class ParseConfig

  Version = '1.0.5'

  attr_accessor :config_file, :params, :groups

  # Initialize the class with the path to the 'config_file'
  # The class objects are dynamically generated by the
  # name of the 'param' in the config file.  Therefore, if
  # the config file is 'param = value' then the itializer
  # will eval "@param = value"
  #
  def initialize(config_file=nil)
    @config_file = config_file
    @params = {}
    @groups = []

    if(self.config_file)
      self.validate_config()
      self.import_config()
    end
  end

  # Validate the config file, and contents
  def validate_config()
    unless File.readable?(self.config_file)
      raise Errno::EACCES, "#{self.config_file} is not readable"
    end

    # FIX ME: need to validate contents/structure?
  end

  # Import data from the config to our config object.
  def import_config()
    # The config is top down.. anything after a [group] gets added as part
    # of that group until a new [group] is found.
    group = nil
    open(self.config_file) { |f| f.each_with_index do |line, i|
      line.strip!

      # force_encoding not available in all versions of ruby
      begin
        if i.eql? 0 and line.include?("\xef\xbb\xbf".force_encoding("UTF-8"))
          line.delete!("\xef\xbb\xbf".force_encoding("UTF-8"))
        end
      rescue NoMethodError
      end

      unless (/^\#/.match(line))
        if(/\s*=\s*/.match(line))
          param, value = line.split(/\s*=\s*/, 2)
          var_name = "#{param}".chomp.strip
          value = value.chomp.strip
          new_value = ''
          if (value)
            if value =~ /^['"](.*)['"]$/
              new_value = $1
            else
              new_value = value
            end
          else
            new_value = ''
          end

          if group
            self.add_to_group(group.to_sym, var_name.to_sym, new_value)
          else
            self.add(var_name.to_sym, new_value)
          end

        elsif(/^\[(.+)\]$/.match(line).to_a != [])
          group = /^\[(.+)\]$/.match(line).to_a[1]
          self.add(group.to_sym, {})

        end
      end
    end }
  end

  # This method will provide the value held by the object "@param"
  # where "@param" is actually the name of the param in the config
  # file.
  #
  # DEPRECATED - will be removed in future versions
  #
  def get_value(param)
    puts "ParseConfig Deprecation Warning: get_value() is deprecated. Use " + \
         "config[:param] or config[:group][:param] instead."
    return self.params[param]
  end

  # This method is a shortcut to accessing the @params variable
  def [](param)
    return self.params[param]
  end

  # This method returns all parameters/groups defined in a config file.
  def get_params()
    return self.params.keys
  end

  # List available sub-groups of the config.
  def get_groups()
    return self.groups
  end

  # This method adds an element to the config object (not the config file)
  # By adding a Hash, you create a new group
  def add(param_name, value)
    param_name = param_name.to_sym
    if value.class == Hash
     value = symbolize_nested_hash_keys value
      if self.params.has_key?(param_name)
        if self.params[param_name].class == Hash
          self.params[param_name].merge!(value)
        elsif self.params.has_key?(param_name)
          if self.params[param_name].class != value.class
            raise ArgumentError, "#{param_name} already exists, and is of different type!"
          end
        end
      else
        self.params[param_name] = value
      end
      if ! self.groups.include?(param_name)
        self.groups.push(param_name)
      end
    else
      self.params[param_name] = value
    end
  end
  
  def symbolize_nested_hash_keys param
    modify_hash_key = lambda do |hash|
      return Hash[hash.map {|k,v| [k.to_sym,((v.is_a? Hash) ? modify_hash_key.call(v) : v)]}]
    end
    modify_hash_key.call(param)
  end
  # Add parameters to a group. Note that parameters with the same name
  # could be placed in different groups
  def add_to_group(group, param_name, value)
    group = group.to_sym
    param_name = param_name.to_sym
    if ! self.groups.include?(group)
      self.add(group, {})
    end
    value = symbolize_nested_hash_keys value if value.is_a? Hash
    self.params[group][param_name] = value
  end

  # Writes out the config file to output_stream
  def write(output_stream=STDOUT, quoted=true)
    self.params.each do |name,value|
      if value.class.to_s != 'Hash'
        if quoted == true
          output_stream.puts "#{name} = \"#{value}\""
        else
          output_stream.puts "#{name} = #{value}"
        end
      end
    end
    output_stream.puts "\n"

    self.groups.each do |group|
      output_stream.puts "[#{group}]"
      self.params[group].each do |param, value|
        if quoted == true
          output_stream.puts "#{param} = \"#{value}\""
        else
          output_stream.puts "#{param} = #{value}"
        end
      end
      output_stream.puts "\n"
    end
  end

  # Public: Compare this ParseConfig to some other ParseConfig. For two config to
  # be equivalent, they must have the same sections with the same parameters
  #
  # other - The other ParseConfig.
  #
  # Returns true if ParseConfig are equivalent and false if they differ.

  def eql?(other)
    self.params == other.params && self.groups == other.groups
  end
  alias == eql?
end
