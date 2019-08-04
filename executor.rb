require_relative 'compiler'
require_relative 'vm/vm'
require_relative 'vm/vm_no_gui'

code = compile(ARGV[0])
use_gui = ARGV[1]

if use_gui
  vm = VM.new(code)
else
  vm = VM_No_GUI.new(code)
end

vm.exec