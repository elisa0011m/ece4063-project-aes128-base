<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works
"Loads 128-bit key and plaintext over 16 byte-serial cycles each, then performs AES-128 encryption iteratively (one round per clock). Ciphertext is read back byte-serially after done asserts."

## How to test
"Load key via load_key + data_in for 16 cycles MSB-first. Load plaintext via load_pt + data_in for 16 cycles. Pulse start. Wait for done. Read 16 ciphertext bytes via data_out, advancing with out_shift."

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
