import sys
from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.cachehierarchies.classic.private_l1_cache_hierarchy import PrivateL1CacheHierarchy
from gem5.components.memory.single_channel import SingleChannelDDR3_1600
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.isas import ISA
from gem5.simulate.simulator import Simulator
from gem5.resources.resource import CustomResource

# Argumenti: <vlen_biti> <l1_velikost> <pot_do_binarke>
# Primer: gem5.opt cpu_benchmark.py 256 8KiB ./workload/scaled_dot_product/scaled_dot_product.bin
if len(sys.argv) < 4:
    print("Uporaba: cpu_benchmark.py <vlen> <l1d_size> <binary>")
    print("Primer:  cpu_benchmark.py 512 8KiB ./workload/scaled_dot_product/scaled_dot_product.bin")
    sys.exit(1)

vlen    = int(sys.argv[1])   # velikost vektorskega registra v bitih (npr. 256)
l1_size = sys.argv[2]         # velikost L1 podatkovnega predpomnilnika (npr. "8KiB")
binary  = sys.argv[3]         # pot do prevedene RISC-V binarke

# L1 predpomnilnik — enak za podatke in navodila
cache_hierarchy = PrivateL1CacheHierarchy(l1d_size=l1_size, l1i_size=l1_size)

# Glavni pomnilnik DDR3
memory = SingleChannelDDR3_1600("7GiB")

# O3 procesor z nastavljenim VLEN (privzete nastavitve kot zahteva naloga)
processor = SimpleProcessor(cpu_type=CPUTypes.O3, num_cores=1, isa=ISA.RISCV)
for core in processor.get_cores():
    core.get_simobject().isa[0].vlen = vlen

board = SimpleBoard(
    clk_freq="3GHz",
    processor=processor,
    memory=memory,
    cache_hierarchy=cache_hierarchy
)

board.set_se_binary_workload(CustomResource(binary))

simulator = Simulator(board=board)
simulator.run()
