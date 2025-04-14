globals
[
  pg-B ;; probability of good experimental result (for trying B) if B is better - .5 + advantage-B
  pg-A ;; probability of good experimental result (for trying B) if A is better - .5 - advantage-B (symmetry here is optional)
  average-credences ;; a list to store the average credence after each run
  final-credences ;; A list of lists to store the final credence of each turtle for each run
  total-runs ;; Specifies the total number of simulation runs desired
  current-run
  total-successes
  total-failures
  no-convergence
  percent-success
  average-p-credence
  average-p-credences-list
  running-average-p-credence
  time-to-finish
  time-to-finish-list
  average-time-to-finish
]

turtles-own [
  credence ;; credence that B is better
  last-credence ;; credence B is better before most recent update - there to make it easier to see changes
  likelihood-positive
  likelihood-negative
  odds
  last-odds
  my-positive
  incoming-positive
  total-positive
  my-negative
  incoming-negative
  total-negative
  prop-positives
  prop-negatives
  sci-positives
  sci-negatives
  pos-updates
  neg-updates
]

breed [policymakers policymaker]
breed [scientists scientist]
breed [propagandists propagandist]

undirected-link-breed [Sci-Scis Sci-Sci]
undirected-link-breed [Sci-Pols Sci-Pol]
undirected-link-breed [Prop-Scis Prop-Sci]
undirected-link-breed [Prop-Pols Prop-Pol]

; THIS BLOCK OF PROCESSES DOES SETUP-Y STUFF

to setup
  ca
  ifelse network-type = "cycle" [
    setup-cycle
  ] [
    ifelse network-type = "wheel" [
      setup-wheel
    ] [
      if network-type = "complete" [
        setup-complete ; Assuming "connected" refers to a fully connected network, and renamed accordingly
      ]
    ]
  ]
  set average-p-credences-list []
  set average-credences []
  set final-credences []
  set time-to-finish-list []
  setup-policymakers
  setup-propagandists
  set current-run 0
  set total-successes 0
  set total-failures 0
  set total-runs 10000 ;; Example: total runs set to 100, adjust based on your experiment needs
end


; SCIENTIST NETWORK SETUPS

to setup-cycle
 clear-turtles
  reset-ticks
  update-real-probabilities
  ask patches [ set pcolor blue ]
  create-scientists number-turtles
  layout-circle sort scientists 8
   ; Shift the circle to the right
  let shift-x max-pxcor / 2 - 14 ; Adjust this to move the circle rightward, closer to the edge
  ask scientists [
    setxy xcor + shift-x ycor
  ]
  create-cycle-network
  ask scientists [
    set shape "circle"
    set color green
    initialize-beliefs
  ]
end


to create-cycle-network
  ask scientists [
    let target who + 1
    if target > number-turtles - 1 [ set target 0 ]
    create-Sci-Sci-with scientist target [
      set color red ; Set the color of Sci-Sci links to red
    ]
  ]
end

to setup-wheel
  clear-turtles
  reset-ticks
  update-real-probabilities
  ask patches [ set pcolor blue ]
  create-scientists ( number-turtles - 1 ) ;; create circle turtles
  layout-circle sort turtles 8
   ; Shift the circle to the right
  let shift-x max-pxcor / 2 - 14 ; Adjust this to move the circle rightward, closer to the edge
  ask scientists [
    setxy xcor + shift-x ycor
  ]
  create-scientists 1  ;; create center turtle
  create-wheel-network
  ask scientists [
    set shape "circle"
    set color green
    initialize-beliefs
  ]
  ask scientist ( number-turtles - 1 ) [ set color green ] ;; change color of central turtle
end

to create-wheel-network
  ;
  let central-turtle number-turtles - 1

  ; Create the ring among non-central scientists
  ask scientists with [who != central-turtle] [
    let target1 (who - 1) mod (count turtles - 1)
    let target2 (who + 1) mod (count turtles)
    if target1 = 0 [set target1 (count turtles - 1)]
    if target2 = 0 [set target2 1]
    create-Sci-Sci-with scientist (ifelse-value (target1 = 0) [(count turtles - 1)] [target1])
    create-Sci-Sci-with scientist (ifelse-value (target2 > (count turtles - 1)) [1] [target2])
  ]

  ; Connect the central scientist to all other scientists
  ask turtle central-turtle [
    ask other scientists [create-link-with turtle central-turtle]
  ]
end

to setup-complete
  clear-turtles
  reset-ticks
  update-real-probabilities
  ask patches [ set pcolor blue ]
  create-scientists number-turtles
  layout-circle sort scientists 8
   ; Shift the circle to the right
  let shift-x max-pxcor / 2 - 14 ; Adjust this to move the circle rightward, closer to the edge
  ask scientists [
    setxy xcor + shift-x ycor
  ]
  create-complete-network
  ask scientists [
    set shape "circle"
    set color green
    initialize-beliefs
  ]
end

to create-complete-network
  ; For each turtle, create a link to every other turtle.
  ask scientists [
    let current-turtle self ; Store a reference to the current turtle
    ask scientists with [self != current-turtle] [
      create-Sci-Sci-with current-turtle [
      set color red ; Set the color of Sci-Sci links to blue
    ]
  ]
    ]

end

; POLICYMAKER SETUP

to setup-policymakers
  ; Determine starting positions
  let base-xcor max-pxcor - 5 ; Adjust to move policymakers further to the right if needed
  let start-ycor 0 ; Adjust starting ycor to align with the middle of the world
  let spacing 4 ; Adjust the spacing between policymakers as needed

  ; Create policymakers in a vertical line
  create-policymakers 5 [
    set shape "square"
    set color green
    ; This will position them in a vertical line to the right
    let my-index who - min [who] of policymakers ; Calculate relative index for vertical positioning
    set xcor base-xcor
    set ycor start-ycor + (my-index * spacing) - ((count policymakers - 1) / 2.0 * spacing)
    set credence random-float .5
    set label precision credence 3
  ]
  link-pol-to-sci
end

to setup-propagandists
  create-propagandists 1 [
    set shape "face neutral"
    set color white
    set size 4
    ;; position the propagandist in the middle at the top
    setxy 0 (max-pycor - 6)
  ]
  link-prop-to-sci
  link-prop-to-pol
end


to link-pol-to-sci
  ; For each policymaker, select policymaker-connectedness scientists and create links
  ask policymakers [
    let target-scientists n-of policymaker-connectedness scientists
    print (word "Policymaker " who " is linking to " count target-scientists " scientists.")
    ask target-scientists [ create-Sci-Pol-with myself ]
  ]
end

to link-prop-to-sci
  ask propagandists [
    ask scientists [
      create-Prop-Sci-with myself
    ]
  ]
end

to link-prop-to-pol
  ask propagandists [
    ask policymakers [
      create-Prop-Pol-with myself
    ]
  ]
end


; OTHER SETUP PROCESSES

to initialize-beliefs   ; Scientist starting belief setting process
  set credence random-float 1
  set label precision credence 3
end

to update-real-probabilities
  set pg-B .5 + advantage-B ; actual probability of a good result from B, if B is better
  set pg-A .5 - advantage-B ; actual probability of a good result from B, if A is better
end


;; THIS IS THE GO PROCESS

to go
  set percent-success ( total-successes / total-runs )
  if current-run >= total-runs [
    stop
  ]

  ask turtles [
    set my-positive 0                ; reset all of everybody's counters
    set my-negative 0
    set incoming-positive 0
    set incoming-negative 0
    set total-positive 0
    set total-negative 0
    set prop-positives 0
    set prop-negatives 0
    set sci-positives 0
    set sci-negatives 0
    set pos-updates 0
    set neg-updates 0
  ]

  ask scientists [
    set color green

    ; run your trials, but only if you're >.5 on B

    if credence > .5  [
      experiment
    ]
  ]                        ;; Crucial change to fix the not-quite-replication of O'C and W is here

  ask scientists [        ;; separated the experimenting and updating processes so that everybody runs all their experiments first before anybody updates
    receive-information-S  ; get results from neighbors

    if credence != 1 and credence != 0 [    ; to prevent divide by zero errors I was getting in the update-credences process
      update-credences    ; update for scientists
    ]
    set label precision credence 3
  ]

  ask propagandists [
    gather-propaganda
  ]

  ask policymakers [
    receive-information-P
    if credence != 1 and credence != 0 [    ; to prevent divide by zero errors I was getting in the update-credences process
      update-credences
    ]
    set label precision credence 3
  ]

  tick
  check-completion  ;; see if the run has hit end conditions
end

; ; THIS BLOCK OF PROCESSES IS ONES CALLED BY GO


to experiment
  repeat trial-size [     ; run the set number of trials
    ifelse random-float 1 < pg-B [           ; generate random result ; if you get a positive result then
      set my-positive my-positive + 1     ; add one to total positive results
    ]
    [ set my-negative my-negative + 1
    ]
  ]
  if my-negative > my-positive [
    set color red
  ]
end


to check-completion
  if (all? scientists [credence <= 0.5 ]) [
    finish-model
  ]
  if (all? scientists [credence >= .99]) [
    finish-model
  ]
  if (ticks >= 500) [
    finish-model
  ]
end




; THIS IS THE COMMUNICATION PROCESS

to receive-information-S
  set incoming-positive sum [ my-positive ] of Sci-Sci-neighbors
  set incoming-negative sum [ my-negative ] of Sci-Sci-neighbors
  set total-positive incoming-positive + my-positive
  set total-negative incoming-negative + my-negative
end

to gather-propaganda
  set my-positive sum [my-positive] of prop-sci-neighbors with [my-negative > my-positive]
  set my-negative sum [my-negative] of prop-sci-neighbors with [my-negative > my-positive]
end


to receive-information-P
  set sci-positives sum [my-positive] of Sci-Pol-neighbors
  set sci-negatives sum [my-negative] of sci-pol-neighbors
  set prop-positives sum [my-positive] of prop-pol-neighbors
  set prop-negatives sum [my-negative] of prop-pol-neighbors
  set incoming-positive (sci-positives + prop-positives)
  set incoming-negative (sci-negatives + prop-negatives)
  set total-positive incoming-positive
  set total-negative incoming-negative
end



; THIS IS THE CREDENCE UPDATE PROCESS

to update-credences
  ; Store the prior credence
  set last-credence credence

  ; Calculate the likelihood ratio for the positive and negative results
  set likelihood-positive pg-B / pg-A
  set likelihood-negative (1 - pg-B) / (1 - pg-A)

  ; calculate B-side of initial odds B:A, with A-side set to 1
  set odds credence / (1 - credence)
  ; store prior odds
  set last-odds odds


  ; update the odds with each result one at a time
  repeat total-positive [                 ; update on each positive result
    set odds odds * likelihood-positive
    set pos-updates (pos-updates + 1)
  ]

  repeat total-negative [       ; update on each negative result
    set odds odds * likelihood-negative
    set neg-updates (neg-updates + 1)
  ]
    set credence odds / (1 + odds)     ; update credences given new odds

  ; Update the turtle's label to reflect the new credence
  set label precision credence 3
end




; THESE ARE THE END AND RESTART PROCESSES

to finish-model
  record-results


  if current-run < total-runs [
    reset-for-next-model-run
  ]
  if current-run >= total-runs [
    print "All runs completed."
  ]
end

to record-results
  if (all? scientists [credence <= 0.5 ]) [
    set total-failures total-failures + 1
  ]
  if (all? scientists [credence >= .99 ]) [
    set total-successes total-successes + 1
  ]
  if ticks >= 500 [
    set no-convergence no-convergence + 1
  ]
  ;; calculate and record average policymaker credence at the end of the run
calculate-average-p-credence
  set running-average-p-credence mean average-p-credences-list

  ;; record time to completion of run
  set time-to-finish ticks
  set time-to-finish-list lput time-to-finish time-to-finish-list   ;; add time to finish of current run to the list
  set average-time-to-finish mean time-to-finish-list

end

to calculate-average-p-credence
  let total-credence sum [credence] of policymakers   ;; sum the credences
  let num-policymakers count policymakers              ;; count the policymakers
  let avg-credence total-credence / num-policymakers    ;; compute the average
  set average-p-credences-list lput avg-credence average-p-credences-list   ;; add average from current run to the list
end

to reset-for-next-model-run
  ; Clear turtles and links
  ask turtles [ die ]
  ask links [ die ]

  ; Reset patches to initial state, if necessary
  ask patches [ set pcolor blue ] ; Example: Resetting patch color

  ; Reinitialize global variables specific to each run
  set average-credences []
  set final-credences []

  set current-run current-run + 1

  ; Call a modified setup procedure that doesn't reset run-tracking variables
  setup-no-reset
end



to setup-no-reset
   ifelse network-type = "cycle" [
    setup-cycle
  ] [
    ifelse network-type = "wheel" [
      setup-wheel
    ] [
      if network-type = "complete" [
        setup-complete ; Assuming "connected" refers to a fully connected network, and renamed accordingly
      ]
    ]
  ]
  set average-credences []
  set final-credences []
  setup-propagandists
  setup-policymakers
  link-prop-to-sci
  link-prop-to-pol
end
@#$#@#$#@
GRAPHICS-WINDOW
246
10
891
656
-1
-1
12.5
1
10
1
1
1
0
0
1
1
-25
25
-25
25
0
0
1
ticks
30.0

BUTTON
25
34
91
67
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
107
34
170
67
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
110
90
173
123
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
27
238
199
271
advantage-B
advantage-B
0
.2
0.05
0.001
1
NIL
HORIZONTAL

SLIDER
28
293
200
326
trial-size
trial-size
1
50
10.0
1
1
NIL
HORIZONTAL

CHOOSER
53
383
191
428
network-type
network-type
"cycle" "wheel" "complete"
0

MONITOR
904
70
992
115
NIL
current-run
17
1
11

SLIDER
26
337
198
370
number-turtles
number-turtles
2
20
20.0
1
1
NIL
HORIZONTAL

MONITOR
900
125
1011
170
NIL
total-successes
17
1
11

MONITOR
1014
125
1108
170
NIL
total-failures
17
1
11

MONITOR
903
239
1019
284
NIL
no-convergence
17
1
11

MONITOR
902
183
1019
228
NIL
percent-success
17
1
11

SLIDER
13
459
241
492
policymaker-connectedness
policymaker-connectedness
0
20
12.0
1
1
NIL
HORIZONTAL

MONITOR
905
18
1101
63
NIL
running-average-p-credence
17
1
11

MONITOR
903
359
1059
404
NIL
average-time-to-finish
2
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
