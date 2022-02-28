#!/bin/bash
truffle migrate --reset --network $1
echo "please wait...30 sec"
sleep 60

#truffle run verify MarsDAO --network $1
truffle run verify MarsDaoSwap --network $1

echo "done"