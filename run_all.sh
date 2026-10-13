#!/bin/bash
set -u

if [ ! -f Dockerfile ]; then
    echo "Run this script from the AE_submission directory." >&2
    exit 1
fi

mkdir -p ae-results
failures=0

run_one() {
    local input=$1
    local protocol=$2
    local trace=$3
    local output=$4

    rm -rf "$PWD/ae-results/$output"
    echo "[run] $output"
    if ! docker run --rm \
      --user "$(id -u):$(id -g)" \
      -v "$PWD/ae-results:/results" \
      rfc2tla-ae \
      python main.py \
        --rfc-file "$input" \
        --protocol-name "$protocol" \
        --output-dir "/results/$output" \
        --three-pass --use-rag --run-tlc --anonymize --segment-delay 0 \
        --replay-sequence "$trace" \
        --save-sequence \
        --sequence-file "/results/$output/replayed_sequence.json"; then
        echo "[run failed] $output" >&2
        failures=$((failures + 1))
    fi
}

for item in \
    "1939 POP3" "9431 MQTT" "1661 PPP" "2131 DHCP" \
    "2637 PPTP" "959 FTP" "4271 BGP" "5321 SMTP" \
    "3977 NNTP" "9293 TCP" "4340 DCCP" "9051 IMAP" \
    "3261 SIP" "7826 RTSP"; do
    set -- $item
    rfc=$1
    protocol=$2
    for variant in correct buggy_deadlock buggy_invariant; do
        if [ "$variant" = correct ]; then
            input="experiments/exp0_setup/rfcs/rfc${rfc}.txt"
        else
            input="experiments/exp0_setup/rfcs_buggy/rfc${rfc}_${variant}.txt"
        fi
        run_one \
          "$input" \
          "$protocol" \
          "traces/exp2_tla_verify/real/rfc${rfc}/${variant}/${protocol}_sequence.json" \
          "real/rfc${rfc}/${variant}"
    done
done

for item in "synth0 STEP" "synth1 DTAP" "synth2 CDLP"; do
    set -- $item
    synth=$1
    protocol=$2
    for variant in correct buggy_deadlock buggy_invariant; do
        run_one \
          "experiments/synthetic_rfcs/${synth}_${variant}.txt" \
          "$protocol" \
          "traces/exp2_tla_verify/synthetic/${synth}/${variant}/${protocol}_sequence.json" \
          "synthetic/${synth}/${variant}"
    done
done

echo "Generated TLA+, CFG, analysis logs, and TLC results under ae-results/."
if [ "$failures" -ne 0 ]; then
    echo "$failures run(s) failed." >&2
    exit 1
fi
echo "All 51 runs completed. Run ./check_results.sh to check the TLC outcomes."
