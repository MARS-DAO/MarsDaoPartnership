#!/bin/bash

screen -d -m -A -S ganache ganache-cli --gasLimit 12000000 --accounts 10 --defaultBalanceEther 100000 --hardfork 'istanbul' --mnemonic brownie --chainId 56 --fork https://bsc-dataseed.binance.org/
sleep 1
truffle test --stacktrace
ps aux | grep ganache | grep -v grep | awk '{print $2}' | xargs kill -9
screen -wipe &> /dev/null