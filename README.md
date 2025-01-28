# ENS DAO Steward Comp Tx Distro Contract

Smart contract system for managing and distributing monthly USDC compensation to ENS DAO stewards.

## Overview

This contract enables automated monthly USDC payments to ENS DAO stewards, with the following key features:

- Monthly USDC payments to designated stewards
- Role-based compensation tracking
- Batch payment processing
- Emergency pause functionality
- Comprehensive test coverage

## Contract Structure

- `StewardCompensation.sol`: Main contract handling compensation logic
- `test/StewardCompensation.t.sol`: Foundry tests
- `test/MockERC20.sol`: Test helper for USDC simulation
- `DETAIL_SPEC.md`: Detailed technical specification

## Key Features

### Recipient Management

- Add/update/remove stewards
- Track roles and payment amounts
- Maximum monthly amount caps

### Payment Processing

- Period-based payments
- Batch processing support
- Payment status tracking

### Security

- Owner-controlled recipient management
- Timestamp validation
- SafeERC20 implementation
- Emergency pause capability

## Testing

The contract includes comprehensive test coverage:

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv
```

Test coverage includes:

- Recipient management
- Payment processing
- Active recipient queries
- Payment period management
- Emergency controls

## Documentation

For detailed technical specifications and implementation details, see [DETAIL_SPEC.md](./DETAIL_SPEC.md).

## License

MIT
