#!/bin/bash
## Simple script to compile the timescaleDB toolkit
# First, ensure rust is set up
pgrx_flag="pg14"

case "${PG_VERSION}" in
  *12*)
    pgrx_flag="pg12"
    ;;
  *13*)
    pgrx_flag="pg13"
    ;;
  *14*)
    pgrx_flag="pg14"
    ;;
  *15*)
    pgrx_flag="pg15"
    ;;
  *16*)
    pgrx_flag="pg16"
    ;;
esac

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# cargo-pgrx is required
cargo install --version '=0.10.2' --force cargo-pgrx
# set up pgrx dev environment
cargo pgrx init --$pgrx_flag pg_config
git clone https://github.com/timescale/timescaledb-toolkit && cd timescaledb-toolkit/extension
cargo pgrx install --release && cargo run --manifest-path ../tools/post-install/Cargo.toml -- pg_config
