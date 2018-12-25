require_relative 'fst'

class Token
  attr_accessor :line, :type, :value

  def initialize(line=nil, type=nil, value=nil)
    @line = line
    @type = type
    @value = value
  end
end

class Lexer
  def initialize(source, starting_state, ignored_states = [], post_processing_mappings, filename,
                 error_fallback_states)

    @ignored_states = ignored_states
    @starting_state = starting_state
    @error_fallback_states = error_fallback_states
    @state = starting_state
    @source = source.split('')
    @buffer = ''
    @id = 0
    @line = 1
    @filename = filename

    @escape_map = {
        "n" => "\n".ord
    }

    @escape_map['\''] = '\''
    @escape_map['t'] = "\t".ord

    @ignored_symbols = [/ /, /\r\n|\r|\n/]
    @post_processing_mappings = post_processing_mappings
  end

  def get_lexem
    return Token.new(@line, State.new(:EOF, []), nil) if @source.empty?

    reset

    while !@complete && (@current_char = @source.shift)
      apply_transition(@current_char)
    end

    # Certain states are not terminal states, some can enter the error state
    # TIP: could be injected
    if @state.name == :ERROR_INT
      error("Incorrect integer format")
    end

    if @state.name == :STRING_C
      error("Unclosed string")
    end

    if @state.name == :STRING_ESC
      error("A symbol could not be escaped")
    end

    # If we match some ignored state, we still need to fetch
    # a normal lexeme as the user of get expects to receive a lexeme
    if !@ignored_states.include?(@state)
      post_process_ids
      post_process_exp

      @id += 1

      Token.new(@line, @state, @buffer)
    else
      get_lexem
    end
  end

  def apply_transition(char)
    # transitions = @state.transitions.select { |el| el.can_transition?(char) }
    next_state = @state.transition_tbl[char.ord]

    if !next_state.nil?
      # Handle escapes
      if @state.name == :STRING_ESC
        char = @escape_map[char].ord
      end

      @state = next_state

      @buffer << char unless @state.name == :STRING_ESC

      # If we have a newline, increment the counter
      if /(\r\n|\r|\n)/.match(char.to_s)
        @line += 1
      end
    else
      # If there's no transition in :MAIN, it's error.
      # In other states, it's complete (i.e. end of current lexeme)
      if @state.name == :MAIN
        error
      else
        complete(1)
      end
    end
  end

  def post_process_ids
    if @state.name == :ID
      if (new_state = @post_processing_mappings[@buffer])
        @state = new_state
      end
    end
  end

  def post_process_exp
    if @state.name == :FLOAT_SCIENTIFIC || @state.name == :FLOAT_SCIENTIFIC_NEG
      base = (@buffer[/(.+)(?=e)/, 1]).to_f
      exp = (@buffer[/(?<=e)(.*)/, 1]).to_i

      @buffer = (base ** exp).to_s
      @state = :LIT_FLOAT
    end
  end

  def complete(go_back = 0)
    if go_back == 1
      @source.unshift(@current_char) # go one symbol back
    end

    @complete = true
  end

  def error(cause = "")
    puts "Analysis error on #{@line} line in #{File.basename(@filename)}"

    if cause
      puts cause
    end

    exit(0)
  end

  def reset
    @current_char = ''
    @complete = false
    @buffer = ''
    @state = @starting_state
  end
end