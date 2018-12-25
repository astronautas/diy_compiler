class State
  attr_accessor :transitions, :transition_tbl
  attr_reader :name

  def initialize(name, transitions = [])
    @name = name
    @transitions = transitions
    @transition_tbl = Array.new(256)
  end

  def to_s
    @name
  end

  def ==(other)
    other.name == @name
  end
end

class Transition
  attr_accessor :target

  def initialize(condition, target)
    @condition = condition
    @target = target
  end

  def can_transition?(event_val)
    !!@condition.match(event_val)
  end
end