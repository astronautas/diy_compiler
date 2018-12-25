require_relative 'instructions'

class CodeWriter
  attr_reader :code

  def initialize
    @code = []

    $registers = {
        :REG1 => -1,
        :REG2 => -2,
        :SP => -3
    }

  end

  def finalize_registers
    @code.each_with_index do |instruction, idx|
      if $registers.key?(instruction)
        @code[idx] = $registers[instruction]
      end
    end
  end

  def dump
    puts 'binary form:'
    puts @code.inspect
    puts ''

    offset = 0
    puts 'textual form:'

    while offset < @code.size
      opcode = @code[offset]
      instr_descr = $instructions_by_opcode.fetch(opcode)

      if instr_descr.name == :PUSH_F
        ops = @code[offset + 1, instr_descr.op_count]
        puts '%3i: %-10s %s' % [offset, instr_descr.name, ops.join(', ')]
      else
        ops = @code[offset + 1, instr_descr.op_count]
        puts '%3i: %-10s %s' % [offset, instr_descr.name, ops.join(', ')]
      end

      offset += 1 + instr_descr.op_count
    end
  end

  def new_label
    label = Label.new
    # label.offsets << @code.size

    label
  end

  def new_label_finalize
    @code.size
  end

  def finalize_label(label)
    label.value = @code.size

    # Replace label instances with actual opcode lines to operate with
    label.offsets.each do |offset|
      @code[offset] = label.value
    end
  end

  def write(instr, *ops)
    instr_descr = $instructions_by_name.fetch(instr)

    if instr_descr.op_count != ops.size
      raise 'invalid operand count'
    end

    # Compile instruction
    @code << instr_descr.opcode

    ops.each do |op|
      if !op.is_a?(Label) # not a label
        @code << op
      elsif op.value.nil?
        op.offsets << @code.size
        @code << 666 # delimiter?
      else
        @code << op.value # label
      end
    end
  end
end

class Label
  attr_reader :offsets
  attr_accessor :value

  def initialize
    @offsets = []
  end
end

class Node
  def gen_code(w)
    raise 'not implemented for %s' % [self.class]
  end
end

class ExprVoid
  def gen_code(w)
  end
end

class Program
  def gen_code(w)

    $entry_point = w.new_label

    w.write(:PUSH_I, $entry_point)
    w.write(:PUSH_I, 123) # placeholder for fp
    w.write(:PUSH_I, 456) # placeholder for sp

    # Will be later replaced by entry point line in OPS
    w.write(:CALL, 0)

    #w.finalize_label(ret_label)
    w.write(:EXIT)

    @declarations.each {|decl| decl.gen_code(w)}
  end
end

class DefClass
  def gen_code(w)
    @body.each do |decl|
      decl.gen_code(w)
    end
  end
end

class DefMain
  def gen_code(w)
    w.finalize_label($entry_point) # starting program point

    # super.pre_gen_code(w)
    w.write(:ALLOC, @num_locals)

    @body.gen_code(w)

    w.write(:RET)
  end
end

class DefMethod
  attr_accessor :entry_label

  def gen_code(w)
    @entry_label = w.new_label_finalize

    w.write(:ALLOC, @num_locals)

    @body.gen_code(w)

    w.write(:RET)
  end
end

class Param
  def gen_code(w)
  end
end

class StmtAssignment
  def gen_code(w)
    @value.gen_code(w) # result gets pushed to the top of the stack
    #declaration = @target.declaration

    if @target.type.instance_of?(TypeInt)
      w.write(:POKE, @target.stack_slot) # let's store the top at var pos
    elsif @target.type.instance_of?(TypePointer)

      # TODO: should be offsets, not dim sizes
      @dim_sizes.each_with_index do |offset, idx|
        offset.gen_code(w)

        if idx+1 < @target.type.dim_sizes.length
          next_dims = @target.type.dim_sizes[idx+1..-1]
          next_dims.each { |dim| dim.gen_code(w); w.write(:MUL_I); }
        end

        if idx > 0 && @dim_sizes.length > 1
          w.write(:ADD_I)
        end
      end

      # @dim_sizes.each_with_index do |offset, idx|
      #   offset.gen_code(w)
      #
      #   if idx+1 < @dim_sizes.length
      #     @target.type.dim_sizes[idx+1].gen_code(w)
      #   else
      #     w.write(:PUSH_I, 1)
      #   end
      #
      #   w.write(:MUL_I)
      #
      #   if idx > 0
      #     w.write(:ADD_I)
      #   end
      # end

      w.write(:PEEK, @target.stack_slot) # pop pointer value = ABS address of first array element
      w.write(:ADD_I) # abs address pointing to concrete slot on the top
      w.write(:STO) # pop offset, pop value and store at ABS address

    else
      w.write(:POKE, @target.stack_slot) # fraction
    end
  end
end

class StmtVarDecl
  attr_accessor :stack_slot

  def gen_code(w)
    if @value
      w.write(:PEEK, :SP) # save SP. This would allow to point to the first array element
      w.write(:POKE, :REG2)

      @value.gen_code(w) # result gets pushed to the top of the stack

      if @target.type.instance_of?(TypeInt)
        w.write(:POKE, @target.stack_slot) # let's store the top at var pos
      elsif @target.type.instance_of?(TypeFloat)
        w.write(:POKE, @target.stack_slot)
      elsif @target.type.instance_of?(TypePointer)
        w.write(:PEEK, :REG2)
        w.write(:POKE, @target.stack_slot) # move abs address from reg2 to pointer slot in the stack
      else
        w.write(:POKE, @target.stack_slot) # fraction
      end
    end
  end
end

# Conditionals
class StmtIf
  attr_reader :whole_tree_ending

  def gen_code(w)
    @end_label = w.new_label
    @cond.gen_code(w)
    w.write(:BZ, @end_label) # skip body if cond eval to false

    @body.gen_code(w)

    # If body is evaluated, skip other elseifs and else
    @whole_tree_ending = w.new_label
    w.write(:JUMP, @whole_tree_ending)

    # Generate else(-s) code
    w.finalize_label(@end_label)

    if @elses
      @elses.each do |else_stmt|
        else_stmt.gen_code(w)
      end
    end

    w.finalize_label(@whole_tree_ending)
  end
end

class StmtElseIf
  def gen_code(w)
    @end_label = w.new_label
    @cond.gen_code(w)

    # jump to next elseif if cond is false
    w.write(:BZ, @end_label)

    @body.gen_code(w)

    # If body is evaluated, skip other elseifs and else
    w.write(:JUMP, @parent_conditional.whole_tree_ending)

    w.finalize_label(@end_label)
  end
end

class StmtElse
  def gen_code(w)
    @body.gen_code(w)
  end
end

# Loops
class StmtLoop
  attr_accessor :start_label, :end_label, :post_body_label

  def gen_code(w)
    start_label, end_label, post_action = @header.gen_code(w)

    @start_label = start_label
    @end_label = end_label
    @post_body_label = w.new_label

    @body.gen_code(w)

    @post_body_label = w.finalize_label(@post_body_label)

    if post_action
      post_action.gen_code(w)
    end


    w.write(:JUMP, start_label) # let's get back to the condition
    w.finalize_label(end_label) # mark ending of a loop
  end
end

class WhileHeader
  def gen_code(w)
    @start_label = w.new_label_finalize
    @cond.gen_code(w) # condition eval code, gets pushed to stack top
    @end_label = w.new_label

    w.write(:BZ, @end_label) # jumps to the end if condition is false

    [@start_label, @end_label, nil]
  end
end

class ForHeader
  def gen_code(w)
    @end_label = w.new_label

    # e.g. int i = 0
    start.gen_code(w)

    @start_label = w.new_label_finalize

    # We made earlier for loops act like while loops
    @cond.gen_code(w)

    # Skip loop if condition is true
    w.write(:BR, @end_label)

    # start = start + 1
    #@incr_stmt.gen_code(w)

    [@start_label, @end_label, @incr_stmt]
  end
end

# EXPRESSIONS
class ExprFn
  def gen_code(w)
    # Put call address on the stack. Gets removed by CALL
    if @target.respond_to?(:entry_label)
      w.write(:PUSH_I, @target.entry_label)
      w.write(:PUSH_I, 123) # placeholder for fp
      w.write(:PUSH_I, 456) # placeholder for sp
    else
      w.write(:PUSH_I, :ERR)
    end

    @args.each {|a| a.gen_code(w)}

    w.write(:CALL, @args.size)
  end
end

class ExprBinary
  def gen_code(w)
    @left.gen_code(w)
    @right.gen_code(w)

    case @op.type.name
    when :OP_ADD;
      if @left_type.instance_of?(TypeInt)
        w.write(:ADD_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:ADD_F)
      end
    when :OP_MULT;
      if @left_type.instance_of?(TypeInt)
        w.write(:MUL_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:MUL_F)
      end
    when :OP_MINUS;
      if @left_type.instance_of?(TypeInt)
        w.write(:SUB_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:SUB_F)
      end
    when :OP_MOD;
      if @left_type.instance_of?(TypeInt)
        w.write(:MOD_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:MOD_F)
      end
    else; raise 'invalid binary operation: %s' % [@op]
    end
  end
end

class ExprArithmetic
  def gen_code(w)
    @left.gen_code(w)
    @right.gen_code(w)

    case @op.type.name
    when :OP_ADD;
      if @left_type.instance_of?(TypeInt)
        w.write(:ADD_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:ADD_F)
      end
    when :OP_MULT;
      if @left_type.instance_of?(TypeInt)
        w.write(:MUL_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:MUL_F)
      end
    when :OP_MINUS;
      if @left_type.instance_of?(TypeInt)
        w.write(:SUB_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:SUB_F)
      end
    when :OP_DIVISION
      w.write(:DIV_I)
    when :OP_MOD;
      if @left_type.instance_of?(TypeInt)
        w.write(:MOD_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:MOD_F)
      end
    else; raise 'invalid binary operation: %s' % [@op]
    end
  end
end

class ExprBooleanRelational
  def gen_code(w)
    @left.gen_code(w)
    @right.gen_code(w)

    case @op.type.name
    when :OP_OR;
        w.write(:OR)
    when :OP_AND;
        w.write(:AND)
    else; raise 'invalid binary operation: %s' % [@op]
    end
  end
end

class ExprEquality
  def gen_code(w)
    @left.gen_code(w)
    @right.gen_code(w)

    case @op.type.name
    when :OP_EQUALITY;
      if @left_type.instance_of?(TypeInt) || @left_type.instance_of?(TypeBool)
        w.write(:CMP_E_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:CMP_E_F)
      end
    when :OP_NOT_EQ;
      if @left_type.instance_of?(TypeInt) || @left_type.instance_of?(TypeBool)
        w.write(:CMP_NE_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:CMP_NE_F)
      end
    else; raise 'invalid binary operation: %s' % [@op]
    end
  end
end

class ExprRelational
  def gen_code(w)
    @left.gen_code(w)
    @right.gen_code(w)

    case @op.type.name
    when :OP_GREATER_EQUAL;
      if @left_type.instance_of?(TypeInt)
        w.write(:CMP_GE_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:CMP_GE_F)
      end
    when :OP_GREATER;
      if @left_type.instance_of?(TypeInt)
        w.write(:CMP_G_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:CMP_G_F)
      end
    when :OP_LESSER;
      if @left_type.instance_of?(TypeInt)
        w.write(:CMP_L_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:CMP_L_F)
      end
    when :OP_LESSER_EQUAL;
      if @left_type.instance_of?(TypeInt)
        w.write(:CMP_LE_I)
      elsif @left_type.instance_of?(TypeFloat)
        w.write(:CMP_LE_F)
      end
    else; raise 'invalid binary operation: %s' % [@op]
    end
  end
end

class ExprUnary
  def gen_code(w)
    @operand.gen_code(w)
    w.write(:NOT)
  end
end

class ExprConst
end

class ExprBool
  def gen_code(w)
    w.write(:PUSH_I, @lit.value == "true" ? 1 : 0)
  end
end

# abc -> 0cba
class ExprString
  def gen_code(w)
    #w.write(:PUSH_I, 0) # termination

    @lit.value.chars.reverse.each do |char|
      w.write(:PUSH_I, char.ord) if char != '"' and char != "'"
    end
  end
end

class ExprFloat
  def gen_code(w)
    #serial = [@lit.value.to_f].pack('D').unpack('b*').first.to_i
    serial = [@lit.value.to_f].pack('F').unpack('V').first

    w.write(:PUSH_F, serial)
  end
end

class ExprInt
  def gen_code(w)
    w.write(:PUSH_I, @lit.value.to_i)
  end
end

class ExprPrio
  def gen_code(w)
    @inner.gen_code(w)
  end
end

class ExprVar
  def gen_code(w)
    if @target.respond_to?(:stack_slot)

      if @target.type.instance_of?(TypeInt)
        w.write(:PEEK, @target.stack_slot) # move to top of stack
      else
        w.write(:PEEK, @target.stack_slot) # move to top of stack fraction
        #w.write(:PEEK, @target.stack_slot + 1) # move to top of stack base
      end
    else
      w.write(:PEEK,  :ERR)
    end
  end
end

class ExprVarPointer
  def gen_code(w)
    # Generate dimensional offset
    # offset(0)*dim(1)...*dim(n) + offset(1)*dim(2)...*dim(n) ... + offset(n)
    @offsets.each_with_index do |offset, idx|
      offset.gen_code(w)

      if idx+1 < @target.type.dim_sizes.length
        next_dims = @target.type.dim_sizes[idx+1..-1]
        next_dims.each { |dim| dim.gen_code(w); w.write(:MUL_I); }
      end

      if idx > 0 && @offsets.length > 1
        w.write(:ADD_I)
      end

      # if next_dims.length != 0
      #   next_dims.each do |dim|
      #     dim.gen_code(w)
      #     w.write(:MUL_I)
      #   end
      # else
      #   w.write(:PUSH_I, 1)
      # end
      #
      # if idx+1 < @target.type.dim_sizes.length
      #   @target.type.dim_sizes[idx+1].gen_code(w)
      # else
      # end
      #
      # w.write(:MUL_I)
    end

    w.write(:PEEK, @target.stack_slot)
    w.write(:ADD_I)

    w.write(:PEEK_TOP) # pop abs address. push value, which's located at that abs address to the stack top
  end
end

# Array declaration
class ExprArray
  def gen_code(w)

      # We need to allocate times dim0*dim1*dim2...*dimn (e.g. int[5][4] -> 5*4 element to allocate)
      @size_exprs.each_with_index do |size_expr, idx|
        size_expr.gen_code(w)

        if idx > 0
          w.write(:MUL_I)
        end
      end


      # Now that size is on the top, allocate
      w.write(:POKE, :REG1)

      # Push the array to the stack
      label = w.new_label_finalize
      #w.write(:POP) # clear the previous placeholder | reg1 value
      w.write(:PUSH_I, 0)
      w.write(:DEC, :REG1)
      w.write(:PEEK, :REG1)

      w.write(:JNZ, label)
  end
end

class Param
  attr_accessor :stack_slot
end

class StmtAssign
  def gen_code(w)
    @value.gen_code(w)
    w.write(:POKE, @target.stack_slot)
  end
end

class StmtBlock
  def gen_code(w)
    @stmts.each {|s| s.gen_code(w)}
  end
end

class StmtBreak
  def gen_code(w)
    w.write(:JUMP, @target_loop.end_label)
  end
end

class StmtContinue
  def gen_code(w)
    w.write(:JUMP, @target_loop.post_body_label)
  end
end

class StmtExpr
  def gen_code(w)
    @expr.gen_code(w)
  end
end

class StmtLet
  attr_accessor :stack_slot

  def gen_code(w)
  end
end

class StmtReturn
  def gen_code(w)

    # Here, the top of the stack should be the return address. Save it in temp register
    if @value
      @value.gen_code(w)
      w.write(:RET_V)
    else
      w.write(:RET)
    end
  end
end

# IO
class StmtIO_OpWrite
  def gen_code(w)
    expr = @exprs[0]

    if @target_type && @target_type.respond_to?(:specialized_ops)
      expr.gen_code(w)

      w.write(@target_type.specialized_ops(:PRINT))
    else
      w.write(:PUSH_I, 0) # terminator
      expr.gen_code(w)

      w.write(:PRINT)
    end
  end
end

class StmtIO_OpRead
  def gen_code(w)
    w.write(:READ_I, @variables[0].target.stack_slot) # extend to multiple variables
  end
end

class StmtPrintVram < StmtIO_Op
  def gen_code(w)

    @x.gen_code(w)
    @y.gen_code(w)
    @color_val.gen_code(w)

    w.write(:PRINT_VRAM)
  end
end

class StmtClearVram
  def gen_code(w)
    w.write(:CLEAR_VRAM)
  end
end

class StmtFlushVram
  def gen_code(w)
    w.write(:FLUSH_VRAM)
  end
end

class StmtSleep
  def gen_code(w)
    @time.gen_code(w)
    w.write(:SLEEP)
  end
end

class StmtRand < Node
  def gen_code(w)
    @from.gen_code(w)
    @to.gen_code(w)
    w.write(:RAND, @target.target.stack_slot)
  end
end