# CosmWasm CodeQL Security Queries

> CodeQL query pack for automated security analysis of CosmWasm smart contracts on Rust.

## Quick Start

```bash
# 1. Install CodeQL CLI (>= 2.23.3)
# 2. Create database from your CosmWasm contract
codeql database create ./cosmwasm-db --language=rust --source-root=./your-contract

# 3. Analyze with this pack
codeql database analyze ./cosmwasm-db lucasamorimca/cosmwasm-codeql \
  --format=sarif-latest --output=results.sarif
```

## Supported Queries

### Access Control

| ID | Name | Severity | CWE |
|----|------|----------|-----|
| `cosmwasm/missing-execute-authorization` | Missing authorization in execute handler | error | [CWE-862](https://cwe.mitre.org/data/definitions/862.html) |
| `cosmwasm/missing-migrate-authorization` | Missing authorization in migrate handler | error | [CWE-862](https://cwe.mitre.org/data/definitions/862.html) |
| `cosmwasm/unprotected-execute-dispatch` | Unprotected execute message dispatch | warning | [CWE-285](https://cwe.mitre.org/data/definitions/285.html) |

### Data Safety

| ID | Name | Severity | CWE |
|----|------|----------|-----|
| `cosmwasm/unchecked-cosmwasm-arithmetic` | Unchecked arithmetic on CosmWasm integers | warning | [CWE-190](https://cwe.mitre.org/data/definitions/190.html) |
| `cosmwasm/unchecked-storage-unwrap` | Unchecked unwrap on storage operation | warning | [CWE-252](https://cwe.mitre.org/data/definitions/252.html) |
| `cosmwasm/missing-address-validation` | Missing address validation | warning | [CWE-20](https://cwe.mitre.org/data/definitions/20.html) |
| `cosmwasm/storage-key-collision` | Storage key collision | error | N/A |

### Cross-Contract & IBC

| ID | Name | Severity | CWE |
|----|------|----------|-----|
| `cosmwasm/ibc-cei-violation` | IBC handler CEI pattern violation | error | [CWE-841](https://cwe.mitre.org/data/definitions/841.html) |
| `cosmwasm/submsg-without-reply-handler` | SubMsg with reply but no reply handler | warning | N/A |
| `cosmwasm/reply-handler-ignoring-errors` | Reply handler ignoring errors | warning | [CWE-390](https://cwe.mitre.org/data/definitions/390.html) |

## GitHub Actions Integration

Add this workflow to your CosmWasm project:

```yaml
# .github/workflows/cosmwasm-security.yml
name: CosmWasm Security Scan
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: rust
          packs: lucasamorimca/cosmwasm-codeql@0.1.0
      - name: Perform Analysis
        uses: github/codeql-action/analyze@v3
```

Results appear in the **Security** tab of your repository.

## Local Analysis

```bash
# Create database (no build needed — uses Rust source extraction)
codeql database create ./db --language=rust --source-root=./my-contract

# Run all queries
codeql database analyze ./db lucasamorimca/cosmwasm-codeql \
  --format=sarif-latest --output=results.sarif

# Run specific query
codeql query run --database=./db \
  --additional-packs=. \
  src/queries/access-control/MissingExecuteAuthorization.ql
```

## Requirements

- CodeQL CLI >= 2.23.3
- Rust source code (no compilation required)
- CosmWasm contracts using `cosmwasm-std` and `cw-storage-plus`

## Testing

```bash
# Run the full test suite (requires CodeQL CLI)
bash test/run-tests.sh

# Rebuild databases from scratch
bash test/run-tests.sh --rebuild
```

## How Detection Works

The pack uses CodeQL's Rust AST analysis to identify vulnerability patterns:

- **Entry points**: Detected by function name convention (`execute`, `migrate`, `instantiate`, `reply`, `ibc_*`) with parameter count matching
- **Authorization**: Checks for `info.sender` comparisons, assert/ensure macros, and auth helper function calls
- **Storage ops**: Matches `save`/`load`/`may_load`/`update`/`remove` method calls
- **Arithmetic**: Heuristic matching on operand names (amount, balance, supply, etc.) with `+`/`-`/`*` operators

## Contributing

1. Fork the repository
2. Add or modify queries in `src/queries/`
3. Add test cases to `test/fixtures/`
4. Run `bash test/run-tests.sh` to validate
5. Submit a pull request

## License

Apache-2.0
