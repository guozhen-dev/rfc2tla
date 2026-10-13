# RFC2TLA+ Artifact

This is the ASE 2026 Artifact Evaluation package for *RFC2TLA+: Extracting and Verifying Formal Models from RFC Documents using Continuous LLM Feedback*.
It contains the implementation, 22 construction-tool schemas, TLC, fixed experiment inputs, fault-injection patches, synthetic RFCs, and replayable tool-call traces.

## Reproduction scope

Our artifact evaluation focuses on the paper's core contribution: generating TLA+ specifications from LLM-generated RFC-derived construction actions and checking the generated models with TLC. Because GPT-5.1 Chat is deprecated and online inference is costly, we provide an offline replay with the recoreded traces, which makes no remote LLM or RAG request.

The retained replay set covers the 14 real RFCs and three synthetic RFCs, with one selected construction trace for each of `correct`, `buggy_deadlock`, and `buggy_invariant`. Protocol and RFC identifiers inside trace actions are consistently anonymized; directory and file names retain the experiment mapping. Each replay regenerates the CFSM, `.tla`, and `.cfg` files with the submitted implementation and invokes TLC. The purpose is to re-produce every generated TLA+ specification and its actual TLC result.

## Setup

Run all commands below from the `AE_submission` directory. Building the container requires internet access once for Debian and Python packages; replay is offline after the build.

```bash
docker build -t rfc2tla-ae .
mkdir -p ae-results
```

## TLA+ generation and TLC checking

The retained traces cover the correct and fault-injected variants of all 14 real RFCs and all three synthetic RFCs.

Generate all 51 retained models and run TLC:

```bash
./run_all.sh
```

Generated files are written under `ae-results/real/` and `ae-results/synthetic/`. The run script reports execution failures but does not classify TLC outcomes.

Check the saved TLC results separately:

```bash
./check_results.sh
```

The check script reads the existing analysis JSON files without rerunning any model. Each item is reported as `RFCxxxx_variant -> Check result (Correct|Wrong)`, and the script exits with nonzero if any result does not match the expected variant outcome.

### Run experiment on individual real RFC

A correct-run example is POP3:

```bash
mkdir -p ae-results/real-pop3-correct
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$PWD/ae-results:/results" \
  rfc2tla-ae \
  python main.py \
    --rfc-file experiments/exp0_setup/rfcs/rfc1939.txt \
    --protocol-name POP3 \
    --output-dir /results/real-pop3-correct \
    --three-pass --use-rag --run-tlc --anonymize \
    --replay-sequence traces/exp2_tla_verify/real/rfc1939/correct/POP3_sequence.json \
    --save-sequence \
    --sequence-file /results/real-pop3-correct/replayed_sequence.json
```

Expected: TLC reports no error, 115 generated states, and 90 distinct states.

All experiment variants, including `correct`, use `--anonymize`. 

The 14 original RFCs are in `artifacts/experiments/exp0_setup/rfcs/`; their 28 deadlock and invariant violation variants are in `artifacts/experiments/exp0_setup/rfcs_buggy/`. Selected real-RFC traces are grouped by RFC number and variant under `traces/exp2_tla_verify/real/`.

### Run experiment on individual synthetic RFC

An injected-invariant example is:

```bash
mkdir -p ae-results/synthetic-step-buggy-invariant
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$PWD/ae-results:/results" \
  rfc2tla-ae \
  python main.py \
    --rfc-file experiments/synthetic_rfcs/synth0_buggy_invariant.txt \
    --protocol-name STEP \
    --output-dir /results/synthetic-step-buggy-invariant \
    --three-pass --use-rag --run-tlc --anonymize \
    --replay-sequence traces/exp2_tla_verify/synthetic/synth0/buggy_invariant/STEP_sequence.json \
    --save-sequence \
    --sequence-file /results/synthetic-step-buggy-invariant/replayed_sequence.json
```

Expected: TLC detects an invariant violation (`MachineConstraints`). TLC correction remains enabled and is attempted; a detected injected fault is the expected synthetic fault-injection outcome. The other fixed synthetic inputs and traces follow the same `synth{0,1,2}/{correct,buggy_deadlock,buggy_invariant}` layout.


## Outputs

Each full LLM trace replay writes:

- `<protocol>_fsm_analysis.json`: extracted CFSM and structured TLC result under `verification_results`;
- `ProtocolModel.tla` and `ProtocolModel.cfg`: generated TLA+ model;
- `<protocol>_analysis.log`: construction and TLC log;
- `replayed_sequence.json`: the actions consumed during replay.

## Layout

- `artifacts/main.py`: command-line entry point.
- `run_all.sh`: regenerate all retained real and synthetic models and run TLC.
- `check_results.sh`: check the saved TLC outcomes without rerunning models.
- `artifacts/config/fsm_functions.json`: 22 construction-tool schemas.
- `artifacts/generator/`: three-pass orchestration and tool execution.
- `artifacts/model/`, `parser/`, and `tlaplus/`: CFSM, parsing, rendering, and TLC support.
- `artifacts/experiments/`: core replay drivers and fixed inputs.
- `artifacts/patches/`: documented fault-injection transformations.
- `traces/`: core traces for TLA+ generation and TLC checking.
