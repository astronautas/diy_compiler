def unify_types(type0, type1, token)
  type0_name = type0.respond_to?(:get_specialized_type) ? type0.get_specialized_type : type0.class.name
  type1_name = type1.respond_to?(:get_specialized_type) ? type1.get_specialized_type : type1.class.name

  # if type0.class.name != type1.class.name
  #   semantic_error(token, 'type mismatch %s vs %s' % [type0.class, type1.class])
  # end

  if type0.get_type_name != type1.get_type_name
    semantic_error(token, 'type mismatch %s vs %s' % [type0.get_type_name, type1.get_type_name])
  end

  type0
end

class Node
  def check_types
    raise 'not implemented for %s' % [self.class]
  end
end

class Program < Node
  def check_types
    @declarations.each(&:check_types)
  end
end

class DefMain
  def check_types
    @body.check_types
  end
end

class DefClass
  def check_types
    @body.each(&:check_types)
  end
end

class DefMethod
  def check_types
    @body.check_types
  end
end

class StmtBlock
  def check_types
    @stmts.each(&:check_types)
  end
end

class StmtLoop
  def check_types
    @header.check_types
    @body.check_types
  end
end

class WhileHeader
  def check_types
    unify_types(TypeBool.new(@token), @cond.check_types, @token)
  end
end

class ForHeader
  def check_types
    @start.check_types
    @cond.check_types if
    @incr_stmt.check_types

    unify_types(TypeInt.new(@token), @step.check_types, @token)
  end
end

class StmtIf
  def check_types
    unify_types(TypeBool.new(nil), @cond.check_types, @token)

    @body.check_types
    @elses.each(&:check_types)
  end
end

class StmtElseIf
  def check_types
    unify_types(TypeBool.new(nil), @cond.check_types, @cond.op)

    @body.check_types
  end
end

class StmtElse
  def check_types
    @body.check_types
  end
end

class StmtVarDecl
  def check_types
    unify_types(@target.type, @value.check_types, @type.token) if @value
  end
end

class StmtReturn
  def check_types
    value_type = @value ? @value.check_types : TypeVoid.new(@token)
    ret_type = @ancestral_method.ret_type ? @ancestral_method.ret_type : TypeVoid.new(@token)

    unify_types(value_type, ret_type, @token)
  end
end

class StmtAssignment
  def check_types
    unify_types(@target.type, @value.check_types, @token) if @target.respond_to?(:type)
  end
end

class StmtAssignmentPointer < StmtAssignment
  def check_types
    unify_types(@target.type.element_type, @value.check_types, @token) if @target.respond_to?(:type)
  end
end

class StmtBreak
  def check_types
  end
end

class StmtContinue
  def check_types
  end
end

class StmtExpr
  def check_types
    @expr.check_types
  end
end

class ExprVar
  def check_types
    if @target.respond_to?(:type)
      @target.type
    end
  end
end

class ExprVarPointer
  def check_types
    @target.type.element_type
  end
end

# Arithmetic exprs: + - * / %
# Relational exprs: > < >= <=
# Equality exprs: == !=
# Boolean exprs: && ||
class ExprBinary
  attr_reader :left_type
  attr_reader :right_type

  def check_types
    left_type = @left.check_types
    right_type = @right.check_types

    unify_types(left_type, right_type, @op)
    
    @left_type = left_type
    @right_type = right_type
    
    left_type
  end
end

class ExprArithmetic < ExprBinary
  def check_types
    super.check_types
  end
end

class ExprBooleanRelational
end

class ExprRelational
  def check_types
    @left_type = @left.check_types
    @right_type = @right.check_types
    unify_types(@left_type, @right_type, @op)

    TypeBool.new(nil)
  end
end

class ExprEquality
  def check_types
    @left_type = @left.check_types
    @right_type = @right.check_types
    unify_types(@left_type, @right_type, @op)

    TypeBool.new(nil)
  end
end

class ExprUnary
  def check_types
    unify_types(TypeBool.new(nil), @operand.check_types, @token)
  end
end

# Types
class TypePointer
  attr_reader :specialized_ops

  @@specialized_ops = {
      :MUL => :MUL_P,
      :PRINT => :PRINT_P
  }

  def specialized_ops(key)
    @@specialized_ops[key]
  end

  def check_types
    self
  end

  def get_specialized_type
    "#{self.class.name}_#{@element_type.class.name}_#{@dim_sizes.map{|expr_int| expr_int.lit.value  }.join("_")}"
  end

  def get_type_name
    s = StringIO.new

    s << "#{@element_type.get_type_name}^"

    @dim_sizes.each do |dim|
      s << "[#{dim.lit.value}]"
    end

    s.string
  end
end

class TypeBool
  attr_reader :specialized_ops

  @@specialized_ops = {
      :MUL => :MUL_I,
      :PRINT => :PRINT_I
  }

  def specialized_ops(key)
    @@specialized_ops[key]
  end

  def check_types
    self
  end

  def get_type_name
    "bool"
  end
end

class TypeInt
  attr_reader :specialized_ops

  @@specialized_ops = {
      :MUL => :MUL_I,
      :PRINT => :PRINT_I
  }

  def specialized_ops(key)
    @@specialized_ops[key]
  end

  def check_types
    self
  end

  def get_type_name
    "int"
  end
end

class TypeFloat
  attr_reader :specialized_ops

  @@specialized_ops = {
      :PRINT => :PRINT_F
  }

  def specialized_ops(key)
    @@specialized_ops[key]
  end

  def check_types
    self
  end

  def get_type_name
    "float"
  end
end

class ExprInt
  def check_types
    TypeInt.new(nil)
  end
end

class ExprString
  def check_types
    TypeString.new(nil)
  end
end

class ExprFloat
  def check_types
    TypeFloat.new(nil)
  end
end

class ExprBool
  def check_types
    TypeBool.new(nil)
  end
end

class ExprArray
  def check_types
    @size_exprs.each do |size_expr|
      unify_types(size_expr.check_types, TypeInt.new(@token), @token)
    end

    #@type = TypeInt.new(@token)
    TypePointer.new(@type, @size_exprs, @token)
  end
end

class ExprFn
  def check_types
    if @target.is_a?(DefMethod)
      param_count = @target.params.size
      arg_count = @args.size

      if param_count != arg_count
        semantic_error(@class_name.name, 'invalid argument count: %s vs %s' % [param_count, arg_count])
      end

      # Even if param count != arg count, check the types
      min_check = [param_count, arg_count].min

      (0...min_check).each do |i|
        param_type = @target.params[i].type
        arg_type = @args[i].check_types

        unify_types(param_type, arg_type, @token)
      end

      @target.ret_type
    end
  end
end

# IO
class StmtIO_OpRead
  def check_types
  end
end

class StmtIO_OpWrite < StmtIO_Op
  attr_accessor :target_type

  def check_types
    @target_type = @exprs[0].check_types
  end
end

class StmtPrintVram < StmtIO_Op
  def check_types
    @x.check_types
    @y.check_types
    @color_val.check_types
  end
end

class StmtClearVram < StmtIO_Op
  def check_types
  end
end

class StmtFlushVram< StmtIO_Op
  def check_types
  end
end

class StmtSleep
  def check_types
    unify_types(@time.check_types, TypeFloat.new(@token), @token)
  end
end

class StmtRand < Node
  def check_types
    unify_types(@target.check_types, TypeInt.new(@token), @token)
    unify_types(@from.check_types, TypeInt.new(@token), @token)
    unify_types(@to.check_types, TypeInt.new(@token), @token)
  end
end
