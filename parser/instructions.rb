class InstructionDescr
  attr_reader :name, :opcode, :op_count

  def initialize(name, opcode, op_count)
    @name = name
    @opcode = opcode
    @op_count = op_count
  end
end

$instructions_by_name = {}
$instructions_by_opcode = {}

def add_instruction(name, opcode, op_count)
  instr_descr = InstructionDescr.new(name, opcode, op_count)
  $instructions_by_name.store(name, instr_descr)
  $instructions_by_opcode.store(opcode, instr_descr)
end

add_instruction :PRINT_P, 0x05, 0
add_instruction :PRINT_I, 0x06, 0
add_instruction :PUSH_F, 0x07, 1

#
add_instruction :DIV_I, 0x08, 0
add_instruction :ADD_I, 0x10, 0
add_instruction :MUL_I, 0x11, 0
add_instruction :SUB_I, 0x12, 0

# Stack
add_instruction :PEEK_TOP, 0x09, 0 # push FP+offset(@stack top)
add_instruction :PEEK, 0x20, 1
add_instruction :POKE, 0x21, 1
add_instruction :POP, 0x22, 0
add_instruction :PUSH_I, 0x23, 1

# Control
add_instruction :CALL, 0x30, 1
add_instruction :BR, 0x31, 1
add_instruction :BZ, 0x32, 1
add_instruction :RET, 0x33, 0
add_instruction :RET_V, 0x34, 0
add_instruction :BE, 0x35, 2 # branch equals
add_instruction :BGE, 0x36, 2 # branch greater|equals
add_instruction :JUMP, 0x41, 1 # branch greater|equals


# Relational
add_instruction :CMP_GE_I, 0x37, 0
add_instruction :CMP_G_I, 0x38, 0
add_instruction :CMP_L_I, 0x39, 0
add_instruction :CMP_LE_I, 0x40, 0
add_instruction :CMP_E_I, 0x45, 0

# Boolean
add_instruction :OR, 0x47, 0
add_instruction :AND, 0x48, 0

add_instruction :CMP_GE_F, 0x49, 0
add_instruction :CMP_G_F, 0x50, 0
add_instruction :CMP_L_F, 0x51, 0
add_instruction :CMP_LE_F, 0x52, 0
add_instruction :CMP_E_F, 0x53, 0
add_instruction :CMP_E_F, 0x54, 0

# Misc
add_instruction :EXIT, 0x0, 0

add_instruction :POP_R, 0x25, 1

add_instruction :NOT, 0x55, 0

add_instruction :ALLOC, 0x56, 1

# IO
add_instruction :PRINT, 0x57, 0

add_instruction :MOD_I, 0x58, 0
add_instruction :MOD_F, 0x59, 0

add_instruction :CMP_NE_I, 0x60, 0

add_instruction :READ_I, 0x61, 1

add_instruction :DEC, 0x62, 1
add_instruction :JNZ, 0x63, 1

add_instruction :STO, 0x64, 0

# Float ops
add_instruction :PRINT_F, 0x65, 0
add_instruction :ADD_F, 0x42, 0
add_instruction :MUL_F, 0x43, 0
add_instruction :SUB_F, 0x44, 0

# VGA
add_instruction :PRINT_VRAM, 0x66, 0 # pop address, pop value, add value to address
add_instruction :CLEAR_VRAM, 0x68, 0 # pop address, pop value, add value to address
add_instruction :FLUSH_VRAM, 0x70, 0 # pop address, pop value, add value to address

add_instruction :SLEEP, 0x67, 0 # pop float, stop execution for that amount of seconds
add_instruction :RAND, 0x69, 1 # pop b, pop a, push rand int between a:b

# # Register addresses
# $registers = {
#     :AX => -1
# }