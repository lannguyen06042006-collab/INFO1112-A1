#!/bin/bash
#
# assembler.sh — INFO1112 Assignment 1 
#
# Converts a human-readable .vsc source file into its binary .bin
# equivalent, per Figures 1-3 of the assignment spec.
#
# Usage:
#   bash assembler.sh <filename.vsc>
#
# Output:
#   On success: writes <filename>.bin next to the input file, then prints
#               a classification line ("It is a QUIT program" / "It is an
#               ADD/SUB program"), a "************" separator, then
#               "The content of the .bin file", then every byte of the
#               .bin file as lowercase hex (via `xxd -p -c 1`), one per
#               line. Exits 0.
#   On failure: prints the required error message to STDOUT and exits 1.
#               No .bin file is produced.
#
# .bin layout (no header byte — pure memory image):
#   byte 0..n_values-1  -> static data bytes (only present when n_values=2)
#   remaining bytes      -> instructions, 2 bytes each

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

# dec_to_bin dec bits
#   Converts a decimal number into a binary string of fixed width, using
#   the weighted-sum method (8 4 2 1 ...).
#   Example: dec_to_bin 20 8 -> "00010100"
dec_to_bin() {
    local dec=$1
    local bits=$2
    local result=""
    local weight
    for (( i = bits - 1; i >= 0; i-- )); do
        weight=$(( 1 << i ))
        if (( dec >= weight )); then
            result+="1"
            dec=$(( dec - weight ))
        else
            result+="0"
        fi
    done
    echo "$result"
}

# bin_to_hex bin
#   Converts an 8-character binary string into a 2-digit hex string.
#   Example: bin_to_hex "00010100" -> "14"
bin_to_hex() {
    local bin=$1
    printf '%02x' "$(( 2#$bin ))"
}

# get_opcode name
#   Looks up the 6-bit binary opcode for a VSC instruction name, per
#   Figure 2 of the spec. Returns 1 if the name is not recognised.
get_opcode() {
    case "$1" in
        LOAD)  echo "000001" ;;
        STORE) echo "000010" ;;
        ADD)   echo "000011" ;;
        SUB)   echo "000100" ;;
        QUIT)  echo "001000" ;;
        PRINT) echo "001001" ;;
        *) return 1 ;;
    esac
}

# write_bytes outfile hexbyte...
#   Appends one or more hex-encoded bytes to a file, in order.
write_bytes() {
    local outfile=$1
    shift
    local hb
    for hb in "$@"; do
        printf "\\x$hb" >> "$outfile"
    done
}

# ---------------------------------------------------------------------------
# 1. Argument validation
# ---------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
    echo "usage: no argument is provided"
    exit 1
fi

if [[ $# -gt 1 ]]; then
    echo "usage: more than one arguments are provided"
    exit 1
fi

infile="$1"

if [[ ! -f "$infile" ]]; then
    echo "usage: input is not a file or it does not exist"
    exit 1
fi

if [[ "$infile" != *.vsc ]]; then
    echo "usage: input does not have the extension .vsc"
    exit 1
fi

outfile="${infile%.vsc}.bin"

# ---------------------------------------------------------------------------
# 2. Read all lines (stripping any trailing \r for Windows-edited files)
#
# Using a plain while-read loop instead of mapfile/readarray for
# portability (mapfile is Bash 4+ only). The `|| [[ -n "$line" ]]` guard
# makes sure we still capture a final line even without a trailing newline.
# ---------------------------------------------------------------------------

lines=()
while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=( "${line%$'\r'}" )
done < "$infile"

total_lines=${#lines[@]}

if (( total_lines == 0 )); then
    echo "usage: the file is empty – no .bin file is produced"
    exit 1
fi

# ---------------------------------------------------------------------------
# 3. Validate Line 1 (n_values)
# ---------------------------------------------------------------------------

nvalues_line="${lines[0]}"

if ! [[ "$nvalues_line" =~ ^[0-9]+$ ]]; then
    echo "Error: line 1 must be a positive integer."
    exit 1
fi

if [[ "$nvalues_line" != "0" && "$nvalues_line" != "2" ]]; then
    echo "Error: line 1 (n_values) must be 0 or 2."
    exit 1
fi

nvalues=$((10#$nvalues_line))
dataArray=()

# ---------------------------------------------------------------------------
# 4a. n_values == 0  -->  the ONLY valid program is a single QUIT,0,0 line
# ---------------------------------------------------------------------------

if (( nvalues == 0 )); then
    if (( total_lines != 2 )); then
        echo "Error: with n_values=0, the file must contain exactly one instruction line: QUIT,0,0"
        exit 1
    fi

    if [[ "${lines[1]}" != "QUIT,0,0" ]]; then
        echo "Error: with n_values=0, the only allowed instruction is an exact match of QUIT,0,0"
        exit 1
    fi

    # opcode 001000, reg 00, mem 00000000  ->  00100000 (0x20), 00000000 (0x00)
    dataArray+=( "20" "00" )

    : > "$outfile"
    write_bytes "$outfile" "${dataArray[@]}"

    echo "It is a QUIT program"
    echo "************"
    echo "The content of the .bin file"
    xxd -p -c 1 "$outfile"
    exit 0
fi

# ---------------------------------------------------------------------------
# 4b. n_values == 2  -->  lines 2 and 3 are static data, then instructions
# ---------------------------------------------------------------------------

if (( total_lines < 3 )); then
    echo "Error: n_values=2 requires two data lines (lines 2 and 3)."
    exit 1
fi

for idx in 1 2; do
    val="${lines[$idx]}"

    if ! [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "Error: line $((idx + 1)) must be a positive integer."
        exit 1
    fi

    val=$((10#$val))
    if (( val < 0 || val >= 128 )); then
        echo "Error: line $((idx + 1)) value ($val) must be in range [0,128)."
        exit 1
    fi

    dataArray+=( "$(bin_to_hex "$(dec_to_bin "$val" 8)")" )
done

# ---------------------------------------------------------------------------
# 5. Process instruction lines (line 4 onward)
# ---------------------------------------------------------------------------

instr_count=0
max_instr=100
found_quit=0
line_index=3   # 0-based; lines[3] is file line 4

while (( line_index < total_lines )); do
    line="${lines[$line_index]}"

    if (( instr_count >= max_instr )); then
        echo "Error: program exceeds maximum of $max_instr instructions."
        exit 1
    fi

    # Skip a genuinely blank trailing line (e.g. trailing newline in editor)
    if [[ -z "$line" ]]; then
        (( line_index++ ))
        continue
    fi

    # Length check: longest valid instruction line is 11 characters
    # (e.g. STORE,2,228). Anything longer is rejected before parsing.
    if (( ${#line} > 11 )); then
        echo "Error: line '$line' exceeds maximum valid instruction length."
        exit 1
    fi

    # Must begin with a known instruction keyword followed by a comma
    if ! [[ "$line" =~ ^(LOAD|STORE|ADD|SUB|QUIT|PRINT),[0-9]+,[0-9]+$ ]]; then
        echo "Error: invalid instruction '$line'."
        exit 1
    fi

    IFS=',' read -r ins reg mem <<< "$line"

    if ! opcode=$(get_opcode "$ins"); then
        echo "Error: unknown instruction '$ins'."
        exit 1
    fi

    if ! [[ "$reg" =~ ^[0-9]+$ ]]; then
        echo "Error: invalid (missing/non-numeric) register value in line '$line'."
        exit 1
    fi
    reg=$((10#$reg))
    if (( reg < 0 || reg > 3 )); then
        echo "Error: register value '$reg' out of range [0,3] in line '$line'."
        exit 1
    fi

    if ! [[ "$mem" =~ ^[0-9]+$ ]]; then
        echo "Error: invalid (missing/non-numeric) memory address in line '$line'."
        exit 1
    fi
    mem=$((10#$mem))
    if (( mem < 0 || mem > 255 )); then
        echo "Error: memory address '$mem' out of range [0,255] in line '$line'."
        exit 1
    fi

    regbin=$(dec_to_bin "$reg" 2)
    membin=$(dec_to_bin "$mem" 8)

    byte1="${opcode}${regbin}"
    byte2="$membin"

    dataArray+=( "$(bin_to_hex "$byte1")" )
    dataArray+=( "$(bin_to_hex "$byte2")" )

    (( instr_count++ ))

    if [[ "$ins" == "QUIT" ]]; then
        found_quit=1
        break
    fi

    (( line_index++ ))
done

if (( found_quit != 1 )); then
    echo "Error: program does not contain a terminating QUIT,0,0 instruction."
    exit 1
fi

# ---------------------------------------------------------------------------
# 6. Write the assembled bytes out as a batch (only reached if everything
#    above succeeded — nothing is written if any validation step failed)
# ---------------------------------------------------------------------------

: > "$outfile"
write_bytes "$outfile" "${dataArray[@]}"

echo "It is an ADD/SUB program"
echo "************"
echo "The content of the .bin file"
xxd -p -c 1 "$outfile"
