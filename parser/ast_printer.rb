class ASTPrinter
  def initialize
    @indent = 0
  end

  def print(field_name, value)
    if value.is_a?(Node)
      print_node(field_name, value)
    elsif value.is_a?(Array)
      print_array(field_name, value)
    elsif value.is_a?(Token)
      print_value(field_name, value.value)
    elsif value.is_a?(Symbol)
      print_value(field_name, value)
    else
      raise 'error'
    end
  end

  def print_array(field_name, array)
    if array.empty?
      print_value(field_name, '[]')
      return
    end

    array.each_with_index do |value, index|
      print('%s[%i]' % [field_name, index], value)
    end
  end

  def print_line(text)
    STDOUT.print '  ' * @indent
    STDOUT.puts text
  end

  def print_node(field_name, node)
    print_line('%s: %s:' % [field_name, node.class])
    @indent += 1
    node.print(self)
    @indent -= 1
  end  

  def print_value(field_name, value)
    print_line('%s: %s' % [field_name, value])
  end  
end

