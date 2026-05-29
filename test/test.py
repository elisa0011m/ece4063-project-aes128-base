import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import os


# ----------------------------------------------------------------
# Helpers matching the serial interface tasks from tb_aes_top.v
# ----------------------------------------------------------------

async def send_128(dut, data: int, is_key: bool):
    """Load a 128-bit value byte-serially, MSB-first (mirrors send_128 task)"""
    for b in range(15, -1, -1):
        await FallingEdge(dut.clk)
        dut.ui_in.value  = (data >> (b * 8)) & 0xFF
        dut.uio_in.value = 0b00000001 if is_key else 0b00000010  # load_key or load_pt

    await FallingEdge(dut.clk)
    dut.uio_in.value = 0b00000000   # deassert load_key / load_pt


async def read_128(dut) -> int:
    """Read back 128-bit ciphertext byte-serially (mirrors read_128 task)"""
    result = 0

    # First byte already on data_out after done, no shift needed
    await FallingEdge(dut.clk)
    result = dut.uo_out.value.integer
    result <<= 8 * 15

    for b in range(1, 16):
        # Pulse out_shift
        await FallingEdge(dut.clk)
        dut.uio_in.value = 0b00001000   # out_shift

        await FallingEdge(dut.clk)
        dut.uio_in.value = 0b00000000   # deassert

        byte_val = dut.uo_out.value.integer
        result |= (byte_val << (8 * (15 - b)))

    return result


async def run_vector(dut, idx: int, pt: int, key: int, expected_ct: int,
                     pass_count: list, fail_count: list):
    """Run one full encrypt vector (mirrors run_vector task)"""

    # 1. Load key
    await send_128(dut, key, is_key=True)

    # 2. Load plaintext
    await send_128(dut, pt, is_key=False)

    # 3. Pulse start (uio_in[2])
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0b00000100
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0b00000000

    # 4. Wait for done (uio_out[5]) with timeout
    timeout = 0
    done = False
    while timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
        if (dut.uio_out.value.integer >> 5) & 1:
            done = True
            break

    if not done:
        cocotb.log.error(f"[TEST#{idx+1:02d}] TIMEOUT")
        fail_count[0] += 1
        return

    # 5. Read back ciphertext
    received_ct = await read_128(dut)

    # 6. Check
    if received_ct == expected_ct:
        cocotb.log.info(
            f"TEST {idx+1:02d} PASS: "
            f"pt={pt:032x} key={key:032x} ct={received_ct:032x}"
        )
        pass_count[0] += 1
    else:
        cocotb.log.error(
            f"[TEST#{idx+1:02d}] FAIL: pt={pt:032x} key={key:032x}\n"
            f"  Expected: {expected_ct:032x}\n"
            f"  Got:      {received_ct:032x}"
        )
        fail_count[0] += 1

    # Small gap between vectors (mirrors repeat(3) @posedge)
    for _ in range(3):
        await RisingEdge(dut.clk)


# ----------------------------------------------------------------
# Helper to load test vector files (mirrors $readmemh)
# ----------------------------------------------------------------

def load_vectors(filepath: str) -> list[int]:
    """Read a $readmemh-format hex file, one 128-bit value per line"""
    vectors = []
    with open(filepath, "r") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("//"):
                vectors.append(int(line.replace("_", ""), 16))
    return vectors


# ----------------------------------------------------------------
# Main test (mirrors the initial begin block)
# ----------------------------------------------------------------

@cocotb.test()
async def test_aes128(dut):

    # Start clock - 100 MHz, 10 ns period
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Load test vectors
    # tb_dir = os.path.dirname(__file__)
    tb_dir = os.getcwd()
    test_pt  = load_vectors(os.path.join(tb_dir, "pt_vectors.txt"))
    test_key = load_vectors(os.path.join(tb_dir, "key_vectors.txt"))
    test_ct  = load_vectors(os.path.join(tb_dir, "ct_vectors.txt"))

    NUM_VECTORS = len(test_pt)
    assert len(test_key) == NUM_VECTORS and len(test_ct) == NUM_VECTORS, \
        "Vector file length mismatch"

    # Initialise signals
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.ena.value    = 1
    dut.rst_n.value  = 0

    pass_count = [0]   # use list so run_vector can mutate it
    fail_count = [0]

    # Hold reset for 4 cycles (mirrors repeat(4) @posedge)
    for _ in range(4):
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1

    # Print header
    cocotb.log.info("=" * 74)
    cocotb.log.info("AES-128 Testbench (TinyTapeout, serialized interface)")
    cocotb.log.info("=" * 74)
    cocotb.log.info("Tests 1-21:  Fixed plaintext (all-zero), varying key")
    cocotb.log.info("Tests 22-42: Fixed key (all-zero), varying plaintext")
    cocotb.log.info("Tests 43-63: Fixed plaintext (all-zero), varying key")
    cocotb.log.info("-" * 74)

    # Run all vectors
    for i in range(NUM_VECTORS):
        await run_vector(dut, i, test_pt[i], test_key[i], test_ct[i],
                         pass_count, fail_count)

    # Summary
    cocotb.log.info("-" * 74)
    cocotb.log.info(f"[SUMMARY] Total: {pass_count[0]}/{NUM_VECTORS} tests passed")

    if fail_count[0] == 0:
        cocotb.log.info("ALL TESTS PASSED")
    else:
        cocotb.log.error(f"{fail_count[0]} TEST(S) FAILED")

    cocotb.log.info("=" * 74)

    # Final assertion so cocotb marks the test as failed if anything failed
    assert fail_count[0] == 0, f"{fail_count[0]} AES test vector(s) failed"