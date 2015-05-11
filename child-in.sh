#!/bin/bash

echo -n -e \\x4\\x65\\x63\\x68\\x6F\\x0\\x3\\x61\\x62\\x63 > test.data
perl6 -Ilib t/child-echo.pl6 <test.data
rm test.data 
