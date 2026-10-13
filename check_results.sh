#!/bin/bash
set -u

if [ ! -f Dockerfile ]; then
    echo "Run this script from the AE_submission directory." >&2
    exit 1
fi

failures=0

check_one() {
    local output=$1
    local variant="${output##*/}"
    local case_path="${output%/*}"
    local case_name="${case_path##*/}"
    if [[ "$case_name" == rfc* ]]; then
        case_name="RFC${case_name#rfc}"
    fi
    local label="${case_name}_${variant}"
    local analysis_files=("$PWD/ae-results/$output/"*_fsm_analysis.json)
    local analysis_file="${analysis_files[0]}"
    local result_ok=false

    if [ -f "$analysis_file" ]; then
        case "$variant" in
            correct)
                grep -Fq "\"success\": true" "$analysis_file" && result_ok=true
                ;;
            buggy_deadlock)
                grep -Fq "\"deadlock_found\": true" "$analysis_file" && result_ok=true
                ;;
            buggy_invariant)
                if grep -Fq "\"invariant_violations\": [" "$analysis_file" &&
                   ! grep -Fq "\"invariant_violations\": []" "$analysis_file"; then
                    result_ok=true
                fi
                ;;
        esac
    fi

    if [ "$result_ok" = true ]; then
        echo "$label -> Check result (Correct)"
    else
        echo "$label -> Check result (Wrong)"
        failures=$((failures + 1))
    fi
}

for rfc in 1939 9431 1661 2131 2637 959 4271 5321 3977 9293 4340 9051 3261 7826; do
    for variant in correct buggy_deadlock buggy_invariant; do
        check_one "real/rfc${rfc}/${variant}"
    done
done

for synth in synth0 synth1 synth2; do
    for variant in correct buggy_deadlock buggy_invariant; do
        check_one "synthetic/${synth}/${variant}"
    done
done

if [ "$failures" -ne 0 ]; then
    echo "$failures TLC result(s) did not match the expected outcome." >&2
    exit 1
fi
echo "All 51 TLC results matched the expected outcomes."
