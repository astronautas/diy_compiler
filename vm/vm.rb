require 'gosu'

class TetrisUI < Gosu::Window
  @@ui_scaling = 30

  @@colors = {
      0 => 0xff_000000,
      1 => 0xff_ffffff,
      2 => 0xff_006400,
      4 => 0xff_00FFFF,
      3 => 0xff_FFFF00,
      5 => 0xff_0000FF,
      6 => 0xff_ffa500,
      7 => 0xff_BA55D3,
      8 => 0xff_ff0000
  }

  def initialize(vram, stdin_buffer)
    super(vram.length * @@ui_scaling, vram.length * @@ui_scaling)

    @vram = vram
    @stdin_buffer = stdin_buffer
    @pressed_btn = 0

    @default_pressed_delay = 6
    @pressed_delay = @default_pressed_delay

    self.caption = "Tetris"

    @keymap = {
        4 => 97,
        7 => 100,
        44 => 32,
        20 => 113 # q
    }
  end

  def update
    if @pressed_delay > 0
      @pressed_delay -= 1
    else
      if button_down?(4)
        @stdin_buffer << @keymap[4]
      elsif button_down?(7)
        @stdin_buffer << @keymap[7]
      elsif button_down?(44)
        @stdin_buffer << @keymap[44]
      end

      @pressed_delay = @default_pressed_delay
    end
  end

  def button_down(id)
    @stdin_buffer << @keymap[id]
    @pressed_delay = @default_pressed_delay
    #print "[VM] #{@keymap[id]}"
  end

  def button_up(id)
    @pressed_btn = false
  end

  def draw
    @vram.each_with_index do |x_items, x|
      x_items.each_with_index do |y_value, y|
        draw_rect(x * @@ui_scaling, y * @@ui_scaling, 1 * @@ui_scaling, 1 * @@ui_scaling, @@colors[y_value])
      end
    end
  end
end

class VM
  @@mem_size = 10000
  @@vram_size = 20
  @@stack_size = 5000

  def initialize(code)
    @code_base = 200
    @mem = Array.new(@@mem_size, 0)
    @mem[@code_base, code.size] = code
    @ip = @code_base
    @sp = @@stack_size
    @fp = @sp
    @running = true

    @stdin_buffer = []

    @vram = Array.new(@@vram_size, 0) { Array.new(@@vram_size, 0)}
    @vram_buffer = Array.new(@@vram_size, 0) { Array.new(@@vram_size, 0)}

    @registers = {
        -1 => 0,
        -2 => 0,
        -3 => 0
    }

    @rand_generator = Random.new
  end

  def reset_vram(vram)
    @vram.each_with_index do |x_items, x|
      x_items.each_with_index do |y_value, y|
        @vram[x][y] = 0
      end
    end
  end

  def get_sp
    @sp
  end

  def exec
    @ui = TetrisUI.new(@vram, @stdin_buffer)

    Thread.new do
      @ui.show
    end

    while @running
      exec_one
    end
  end

  def exec_call(num_args)
    @sp -= num_args
    target = @mem[@sp - 3]
    @mem[@sp - 3] = @ip # return address
    @mem[@sp - 2] = @fp # preserve frame pointer
    @mem[@sp - 1] = @sp - 3 # preserve stack pointer

    goto_code(target)
    @fp = @sp
  end

  def exec_ret(value)
    old_ip = @mem[@fp - 3]
    old_fp = @mem[@fp - 2]
    old_sp = @mem[@fp - 1]
    @ip = old_ip
    @fp = old_fp
    @sp = old_sp
    push(value)
  end

  def is_memory_not_exhausted
    if @mem.length - @sp > @@stack_size
      raise Exception.new("StackOverflow (exhausted allocated stack size).")
    end
  end

  def exec_one
    @registers[-3] = @sp

    #is_memory_not_exhausted
    opcode = read_code

    if opcode.nil?
      raise Exception.new("StackOverflow (exhausted allocated stack size).")
    end

    # puts "---"
    # puts 'ip %s %s (doing %s inst)' % [@ip, $instructions_by_opcode.fetch(opcode).name, @ip - 1 - 200]
    #puts "Stack top: #{@mem[@sp]}"
    #puts 'stack fp:%4i sp:%4i | mem:%s' % [@fp, @sp, @mem[@fp, 20].join(' ')]
    # puts "---"

    op = $instructions_by_opcode.fetch(opcode).name

    case op

    # Integer arithmetic
    when :ADD_I; b = pop; a = pop; push(a + b)
    when :MUL_I; b = pop; a = pop; push(a * b)
    when :SUB_I; b = pop; a = pop; push(a - b)
    when :MOD_I; b = pop; a = pop; push(a % b)
    when :DIV_I; b = pop; a = pop; push(a / b)

    # Floating Point Arithmetic
    when :SUB_F; b = unpack_float(pop); a = unpack_float(pop); push(pack_float(a - b));
    when :ADD_F; b = unpack_float(pop); a = unpack_float(pop); push(pack_float(a + b));
    when :MUL_F; b = unpack_float(pop); a = unpack_float(pop); push(pack_float(a * b));
    when :DIV_F; b = unpack_float(pop); a = unpack_float(pop); push(pack_float(a / b));

    when :DEC;
      idx = read_code

      if idx < 0
        @registers[idx] -= 1
      else
        @mem[@fp + idx] += 1
      end

    when :CMP_L_I;
      b = pop;
      a = pop;
      push(a < b ? 1 : 0)
    when :CMP_LE_I; b = pop; a = pop; push(a <= b ? 1 : 0)
    when :CMP_G_I; b = pop; a = pop; push(a > b ? 1 : 0)
    when :CMP_GE_I; b = pop; a = pop; push(a >= b ? 1 : 0)
    when :CMP_E_I; b = pop; a = pop; push(a == b ? 1 : 0)
    when :CMP_NE_I; b = pop; a = pop; push(a != b ? 1 : 0)

    when :OR; b = pop; a = pop; push((!(a.zero?) || !(b.zero?)) ? 1 : 0)
    when :AND; b = pop; a = pop; push((!(a.zero?) && !(b.zero?)) ? 1 : 0)
    when :NOT; push(pop == 1 ? 0 : 1)

    when :PEEK_TOP; addr_abs = pop; value = @mem[addr_abs]; push(value)

    when :PEEK; idx = read_code;
      if idx < 0
        a = @registers[idx];
      else
        a = @mem[@fp + idx];
      end

      push(a)
    when :POKE;
      idx = read_code

      if idx < 0
        @registers[idx] = pop
      else
        @mem[@fp + idx] = pop
      end
    when :POP; @sp -= 1
    when :PUSH_I; a = read_code; push(a)
    when :PUSH_F; a = read_code; push(a)
    when :ALLOC; num = read_code; @sp += num
    when :STO; abs_addr = pop; value = pop; @mem[abs_addr] = value;
    when :CALL; exec_call(read_code)
    when :RET; exec_ret(0)
    when :RET_V; exec_ret(pop)

    when :JUMP; target = read_code; goto_code(target)
    when :JNZ;
      target = read_code
      cond_val = pop
      if cond_val != 0;
        goto_code(target);
      end
    when :BR; target = read_code; if pop == 1; goto_code(target); end
    when :BZ
      target = read_code
      val = pop

      if val == 0;
        goto_code(target);
      end
    when :EXIT; @running = false;

    # IO
    when :PRINT; exec_print
    when :PRINT_P; value = pop; print(value)
    when :PRINT_I; value = pop; print(value)
    when :PRINT_F; value = unpack_float(pop); print '%.5f' % value
    when :READ_I; exec_read_i
    when :PRINT_VRAM; color = pop; y = pop; x = pop; @vram_buffer[x][y] = color;
    when :FLUSH_VRAM; exec_flush_vram;
    when :CLEAR_VRAM; reset_vram(@vram);
    when :SLEEP; value = unpack_float(pop); sleep(value);
    when :RAND; idx=read_code; to = pop; from = pop; rand = @rand_generator.rand(from..to); @mem[@fp + idx] = rand;
    else; raise 'bad instruction %02x' % [opcode]
    end
  end

  def exec_flush_vram
    @vram_buffer.each_with_index do |x_items, x|
      x_items.each_with_index do |y_value, y|
        @vram[x][y] = @vram_buffer[x][y]
      end
    end
  end

  def unpack_float(binary_float)
    [binary_float].pack('V').unpack('F').first
  end

  def pack_float(binary_float)
    [binary_float].pack('F').unpack('V').first
  end

  def add_float
  end

  def exec_read_i
    #value = $stdin.gets.to_i # user input
    value = (@stdin_buffer.shift or 55)
    # value = 20 # user input
    idx = read_code

    @mem[@fp + idx] = value
  end

  # Print till nul-terminator
  def exec_print
    while true
      value = pop

      if value == 0
        break
      end

      print value.chr
    end
    # while value = pop and value != 0
    #   print value.chr
    # end
  end

  def goto_code(target)
    @ip = target + @code_base
  end

  def pop
    @sp -= 1
    @mem[@sp]
  end

  def push(value)
    @mem[@sp] = value
    @sp += 1
  end

  def read_code
    result = @mem[@ip]
    @ip += 1
    result
  end
end

