class Scope
  def initialize(parent_scope = nil)
    @members = {}
    @parent_scope = parent_scope
  end

  # Add a variable to this scope
  def add(name, node)
    raise ArgumentError.new unless name.is_a?(Token)
    raise ArgumentError.new unless node.is_a?(Node)

    # Should point to last added variable, as its the stack
    if node.respond_to?(:stack_slot)
      node.stack_slot = $curr_stack_slot
      $curr_stack_slot += node.type.get_stack_slot_size
    end

    # If there's another variable with same name in this scope, it's error
    if @members[name.value]
      semantic_error(name, "duplicate variable `%s'" % [name.value])
    else
      @members[name.value] = node
    end
  end

  def resolve(name)
    raise ArgumentError.new unless name.is_a?(Token)

    if node = @members[name.value]
      node
    elsif @parent_scope
      @parent_scope.resolve(name)
    else
      semantic_error(name, "undeclared variable `%s'" % [name.value])
    end
  end
end

class Node
  def resolve_names(scope)
    raise 'not implemented for %s' % [self.class]
  end
end

class Program < Node
  def resolve_names(scope)
    $curr_stack_slot = 0 #global variable stack

    # Class declarations are like variables, you should be able to access them in the program scope
    @declarations.each { |class_declr| scope.add(class_declr.name, class_declr) }
    @declarations.each { |class_declr| class_declr.resolve_names(scope) }

    true
  end
end

class Def < Node
end

class DefClass < Def
  def resolve_names(scope)
    inner_scope = Scope.new(scope)

    inner_scope.add(Token.new(nil, :ID, "this"), self)

    @body.each do |body_decl|
      # StmtVarDecl and Assign have ExprVar as variable name
      if body_decl.name.respond_to?(:value)
        scope.add(Token.new(nil, :ID, "#{@name.value}.#{body_decl.name.value}"), body_decl)
      else
        scope.add(Token.new(nil, :ID, "#{@name.value}.#{body_decl.name.name.value}"), body_decl)
      end

      body_decl.resolve_names(scope)
    end
  end
end

class DefConstructor
  def resolve_names(scope)
    inner_scope = Scope.new(scope)
    $curr_stack_slot = 0

    @params.each { |param| inner_scope.add(param.name, param) }
    @body.resolve_names(inner_scope)

    @num_locals = $curr_stack_slot
  end
end

class DefMain
  attr_accessor :num_locals

  def resolve_names(scope)
    inner_scope = Scope.new(scope)
    $curr_stack_slot = 0

    @params.each { |param| inner_scope.add(param.name, param) }
    @body.resolve_names(inner_scope)

    @num_locals = $curr_stack_slot
  end
end

class DefMethod < Def
  attr_accessor :num_locals

  def resolve_names(scope)
    #scope.add(@name, self)
    inner_scope = Scope.new(scope)
    $curr_stack_slot = 0

    @params.each { |param| inner_scope.add(param.name, param) }
    @body.resolve_names(inner_scope)

    @num_locals = $curr_stack_slot
  end
end

class StmtIf < Stmt
  def resolve_names(scope)
    inner_scope = Scope.new(scope)

    @cond.resolve_names(inner_scope)
    @body.resolve_names(inner_scope)

    # Elses are not ifs children from a scope point of view
    @elses.each { |else_stmt| else_stmt.resolve_names(scope) }
  end
end

class StmtElseIf < Stmt
  def resolve_names(scope)
    inner_scope = Scope.new(scope)

    @cond.resolve_names(inner_scope)
    @body.resolve_names(inner_scope)
  end
end

class StmtElse < Stmt
  def resolve_names(scope)
    inner_scope = Scope.new(scope)

    @body.resolve_names(inner_scope)
  end
end

class StmtBlock < Stmt
  def resolve_names(scope)
    inner_scope = Scope.new(scope)

    @stmts.each { |stmt| stmt.resolve_names(inner_scope)}
  end
end

class StmtBreak
  def resolve_names(scope)
  end
end

class StmtContinue
  def resolve_names(scope)
  end
end

class StmtAssignment < Stmt
  attr_accessor :target

  def resolve_names(scope)
    @target = scope.resolve(@name.name)
    @value.resolve_names(scope)
  end
end

class StmtAssignmentPointer < StmtAssignment
  def resolve_names(scope)
    super
    @dim_sizes.each{|offset| offset.resolve_names(scope) }
  end
end

class StmtExpr
  def resolve_names(scope)
    @expr.resolve_names(scope)
  end
end

class StmtVarDecl < Stmt
  def resolve_names(scope)
    @target = scope.add(@name.name, self)
    @name.target = @target
    @value.resolve_names(scope) if @value
    @declaration = get_declaration
  end

  def get_declaration
    # if @target.value.instance_of?(ExprVar)
    #   @target.value.target.get_declaration
    # else
    #   @target
    # end
  end
end

class StmtReturn < Stmt
  def resolve_names(scope)
    @value.resolve_names(scope) if @value
  end
end

class StmtLoop < Stmt
  def resolve_names(scope)
    inner_scope = Scope.new(scope)

    @header.resolve_names(inner_scope)
    @body.resolve_names(inner_scope)
  end
end

class WhileHeader < Node
  def resolve_names(scope)
    @cond.resolve_names(scope)
  end
end

# For header shares scope with body
class ForHeader < Node
  def resolve_names(scope)
    @start.resolve_names(scope)
    @to.resolve_names(scope)
    @step.resolve_names(scope)
    #@cond.resolve_names(scope)
    @incr_stmt.resolve_names(scope)
  end
end

# Foreach header shares scope with the body
class ForEachHeader < Node
  def resolve_names(scope)
    @var.resolve_names(scope)
    @in_exp.resolve_names(scope)
  end
end

class ExprBinary < Expr
  def resolve_names(scope)
    @left.resolve_names(scope)
    @right.resolve_names(scope)
  end
end

class ExprUnary
  def resolve_names(scope)
    @operand.resolve_names(scope)
  end
end

class ExprVar
  attr_accessor :target

  def resolve_names(scope)
    @target = scope.resolve(@name)
  end
end

class ExprVarPointer < ExprVar
  def resolve_names(scope)
    #super.resolve_names(scope)
    @target = scope.resolve(@name)
    @offsets.each { |offset| offset.resolve_names(scope) }
  end
end

class ExprConst
  def resolve_names(scope)
  end
end

class ExprArray < Expr
  def resolve_names(scope)
    #@size_exprs.each { |expr| expr.resolve_names(scope) }
  end
end

class ExprFn < Expr
  def resolve_names(scope)
    scope.resolve(@class_name.name) # TODO later, this will be tough with polymorphism

    if @class_name
      @target = scope.resolve(
          Token.new(@method_name.line, :ID, "#{@class_name.name.value}.#{@method_name.value}"))

      @args.each { |arg| arg.resolve_names(scope)}
    else
      raise 'Not implemented'
    end
  end
end

# IO
class StmtIO_OpRead
  def resolve_names(scope)
    @variables.each do |var|
      var.resolve_names(scope)
    end
  end
end

class StmtIO_OpWrite < StmtIO_Op
  def resolve_names(scope)
    @exprs.each { |expr| expr.resolve_names(scope) }
  end
end

class StmtPrintVram < StmtIO_Op
  def resolve_names(scope)
    @x.resolve_names(scope)
    @y.resolve_names(scope)
    @color_val.resolve_names(scope)
  end
end

class StmtClearVram < StmtIO_Op
  def resolve_names(scope)
  end
end

class StmtFlushVram < StmtIO_Op
  def resolve_names(scope)
  end
end

class StmtSleep
  def resolve_names(scope)
    @time.resolve_names(scope)
  end
end

class StmtRand < Node
  def resolve_names(scope)
    @target.resolve_names(scope)
    @from.resolve_names(scope)
    @to.resolve_names(scope)
  end
end

