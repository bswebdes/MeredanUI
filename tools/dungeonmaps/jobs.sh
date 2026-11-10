#!/bin/bash
# inst floor scale X1 Z1 X2 Z2 [zmin zmax] [noadt]
declare -A THR=([2970]=0.30 [3001]=0.0)
run() { local inst=$1 fl=$2 sc=$3 x1=$4 z1=$5 x2=$6 z2=$7 zmin=$8 zmax=$9 noadt=${10}
  local env="MASK=new/$inst/m_$fl.png"; [ -n "$noadt" ] && env="$env NOADT=1"
  env $env python3 -I worldmap.py new/$inst new/$inst/c_$fl.png $sc $x1 $z1 $x2 $z2 $zmin $zmax | sed "s/^/$inst $fl: /"
  python3 -I parchment2.py new/$inst/c_$fl.png new/$inst/m_$fl.png final/${inst}_$fl.png ${THR[$inst]:-0} | sed "s/^/$inst $fl: /"
}
run 3065 1 1.0 16780 16420 17370 17210 -1000 1000 noadt &
run 2999 1 1.0 16540 15140 17127 15793 40 400 &
run 2998 1 0.7 18473 20540 19627 21327 &
run 2959 1 0.6 16273 16440 17293 17727 &
run 2970 1 0.6 13650 29950 15050 30900 &
run 2974 1 0.6 13073 13173 14460 13927 270 1000 &
run 2974 2 0.6 13073 13173 14460 13927 -100 270 noadt &
run 3001 1 0.45 17600 22400 19200 24000 &
run 3039 1 0.6 20607 23640 22027 24927 &
wait
