#!/bin/bash
truffle migrate --reset --network $1
echo "please wait...60 sec"
sleep 60

truffle run verify MarsDaoPartnership --network $1

echo "done"