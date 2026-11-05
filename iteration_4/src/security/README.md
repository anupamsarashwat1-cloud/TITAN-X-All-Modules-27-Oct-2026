# Security

## Description
The security subsystem provides root-of-trust and cryptographic acceleration.

## Working
Includes the Secure Boot engine, ECDSA, AES, TRNG, and eNVM controller. It verifies firmware signatures before allowing the CPU to boot.

## Need
Critical for establishing a secure execution environment and protecting against unauthorized code execution.

## Steps to Use / Integrate
1. Instantiate the secure boot module.
2. Connect to eNVM and crypto engines.
3. Tie the secure boot pass signal to the core reset.
