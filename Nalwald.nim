import uci

uciLoop()

# import strformat

# const depthDivider = [60, 30, 25, 20, 15, 10, 9, 8, 7, 6, 6, 5, 5, 5, 4]

# for depth in 0..<32:
#     var s =  fmt"{depth:>2}" & ": "
#     for m in 0..<40:
#         let newDepth = max(0, depth - 1 - depth div depthDivider[min(m, depthDivider.high)])
#         s &= fmt"{newDepth:>2}" & ", "
#     echo s