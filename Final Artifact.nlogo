;Final Report
;April 2022
;Autonomous corn farming
;agent-based model
;Mohammed Essakini
;SRN 17037420




breed [ storages storage ]
breed [ robots robot ]
breed [ robot-rooms robot-room ]


breed [corns corn]
breed [pests pest]


turtles-own   [
  product             ; the finished product [corn] the agent has
  product-year

]

robots-own
[
  energy              ; what robots use to drive with
  laden?              ; whether the robot is carrying anything
  destination         ; where the robot is currently going
  idleness            ; a counter of time this robot has spend idle
  pruductivity-year   ; keeps track of the idelness in a string each tick
  pruductivity-year_base ; keeps track of the idelness in a string each calculated year cycle
  behaviour
]

patches-own
[
  plantable
  soil-quality
  moisture
  Ph
  fertilizer
]

globals [sum-quality planted total-planted planted-year years-harvest years season corns-lost-to-pests total-corns-lost-to-pests corns-lost-to-pests-year pest-dead]

to setup
  clear-all

  if show-soil-map? = false [import-drawing "bg.jpeg"] ;; shows the soil map if set to true before setup

  ask patches
  [
    setup-field -25 -11 7 20    ;; setup first field
    setup-field -25 -11 -20 -7  ;; setup second field
  ]

  create-robot-rooms 1 [ setxy -25 0 set shape "box" set color yellow set size 5 ] ;create the robot's room

  create-robots number-of-robots   ;create robots based on number of robtos slider
  [ ; creates a variable number of robots and sets their values
    setxy random-xcor random-ycor
    set color grey
    set destination "none"
    set laden? false
    set energy full-charge
    set size 3
    set shape "person"

    ask robots [set destination one-of patches with [plantable = true]]
  ]

  create-storages 1 [ setxy 0 -9 set shape "box" set color magenta set size 4] ;create the corn storage room

  reset-ticks
end

to go

  harvest
  move
  ifelse systematic-plant? = false [ plant]
  ;else
  [plant-systematic]
  grow
  return-home
  recharge
  collectharvest
  ifelse pests? [pests-come][ask pests [die]]
  pestcontrol
  label-agents
  season-change

  recalculating-soil-quality

  if make-trails? [ask robots [pd]]

  ask robots [if xcor > 10 [ set heading towardsxy  0 9  ]] ;set xcor 0 - 9


  if ticks mod  1284 = 0 [ set years years + 1 ]
  if ticks mod  1284 = 0 [ set planted-year planted set planted 0]
  tick
end

to harvest
  ask robots
  [
    ifelse product < harvest-capacity [

      set color grey
      if energy >= full-charge / 2 [
        set behaviour "harvest looking"
        if any? corns with
        [
          size >= harvest-size
        ]
        ;then
        [
          set destination min-one-of other corns with [size > harvest-size]  [distance myself] ;; drive towards the harvest sized crop closest to myself
          set behaviour "facing"
        ]
      ]
      if any? corns-here with [size > harvest-size]
      [
        set behaviour "harvesting"
        set product product + 1
        ask corns-here [die]

        set destination "none"
      ]
    ]
    ;else if my product storage is full, go to the warehouse to drop it off
    [set destination one-of storages set color red set behaviour "facing"]
  ]
end



; Robots move toward their destination set by the set-robots-destination procedure
to move
  ask robots[

    ifelse can-move? 1
    [
      forward 1
      set behaviour "move"

      ask patch-here [
        if plantable = true[ if soil-quality > 10 [care-for-land 1000 1000]]
        ;; adds fertilizer to the land
      ]


      if destination != nobody and destination != "none"
      [
        set behaviour "Facing"
        face destination
      ]
    ]
    ;else if at the edge of the view, turn arounD
    [set heading random 180]

  ifelse product > 0 [ ; if the are carrying something, robots lose two energy
    set laden? true
    set energy energy - 2
  ]
  [
    set laden? false ; otherwise, if they are not carrying something they lose 1 energy,
    set energy energy - 1
    ;if destinationset idleness idleness + 1 ; and increase their idleness score by 1 each tick.

  ]
     if ticks mod  1284 = 0 [ set pruductivity-year_base pruductivity-year set pruductivity-year 0 ]; plot
  ]
end

to setup-field [xcordinatemin xcordinatemax ycordinatemin ycordinatemax] ;; sets up a field of corn within x and y cordinate boundaries
  if
  pxcor > xcordinatemin
  and pxcor < xcordinatemax
  and pycor > ycordinatemin
  and pycor < ycordinatemax
  [ set plantable true set soil-quality random-float 50 set moisture random-float .4 set Ph random-float .4 set fertilizer random-float .4]

end

to plant
  ask robots
  [ ; ask all the robots to implement the following

    if not any? corns-here
    [
      ifelse season = "Summer" or season = "Spring" [;; makes it less likely to plant late in the year, but more likely to plant in Spring
        set behaviour "plant looking"
        if [plantable] of patch-here = true
        [

          ask patch-here
          [
            set planted planted + 1
            set total-planted total-planted + 1
            sprout-corns 1 [ set shape "circle" set color black set size 1.4 ]
            ;set behaviour "planting"
          ]
          set destination "none"


        ]
      ]
      ;else if its Winter or Autum
      [set destination "none"]
    ]
    if destination = "none"
    [
      let choice random 2
      if choice = 1
      [
        set destination one-of other patches with [plantable = true and not any? corns-here ]
        ;at instances it give the robot destination nobody
      ]
      if choice = 2
      [
        set destination one-of patches with [soil-quality > 8.5 ];take cares of patch with low soil quality
      ]
    ]

  ]


end

to grow ;; controls how fast the crops grow, faster in summer, slower the rest
  ask corns [
    if size < 1.8 [
      ifelse season = "Summer" [if size < 2 [set size (size + .0001 + ([soil-quality] of patch-here / (1.5 + .001))) ]  ]
      [set size size + .0001  ]

      if size > harvest-size - .03
      [
        set shape "plant"
        set color yellow
      ]
      if size > harvest-size [set size harvest-size + .2 set color orange + 3]
    ]
    ask patch-here [set moisture moisture - 10 set fertilizer fertilizer -  10  set soil-quality soil-quality - 10]
  ]

end

to return-home
  ; When their energy level becomes low, robots must return to a robot room to recharge.
  ask robots
  [

    if energy < 200  [ set destination one-of robot-rooms set color green + 2 ]
  ]
end

to recharge
  ; They recharge at a rate of recharge-rate (a slider) units per simulation cycle.
  ask robot-rooms [
    ask robots in-radius 2 [
      set laden? false

      set energy energy + recharge-rate ;; here is where we set the rate of charge
      set idleness idleness + 1
      set pruductivity-year pruductivity-year + 1
      if energy >= full-charge
      [
        set destination "none"
      ]
    ]
  ]
end

to collectharvest
;; the storgage facility collects the harvest from all the robots in a 2 patch radius
  ask storages
  [
    if any? robots in-radius 2 [

      let targets robots in-radius 2 with [ product > 1]

      set product product +  sum [product] of targets
      set product-year product-year + sum [product] of targets
      ask targets
      [

        set product 0
        harvest ;; them sends the robots back out to harvest
      ]
    ]
    if ticks mod  1284 = 0 [ set years-harvest product set product 0   ]
  ]
end

to pests-come ;;  creates a pest 10 ticks in 1000 (1% OF the times)
  if random 1000 < 10
  [
    ask one-of patches
    [
      sprout-pests 1 [
        set color red
        set size 2
        set shape "bug"
      ]
    ]
  ]
  ask pests ;; then has the bugs move around randomly and eat corn.
  [
    fd 1 rt random 45 lt random 45
    ask corns-here with [size > 1.5] [set corns-lost-to-pests corns-lost-to-pests + 1 set total-corns-lost-to-pests total-corns-lost-to-pests + 1 die]

  ]
  if ticks mod  1284 = 0 [ set corns-lost-to-pests-year corns-lost-to-pests set corns-lost-to-pests 0]
end

to pestcontrol ;; robots hunt pest in a forward cone 60 degrees by 3 patches
  ask robots
  [
  if any? pests in-cone 3 60
  [
      set color blue
      set destination one-of pests in-cone 3 60
      ask n-of 1 pests in-cone 3 60 [die] set pest-dead pest-dead + 1

  ]
  ]
end

to label-agents ; places tbhe labels on the agents if switched on
  ifelse show-agent-name?
  [
    ask turtles [ if breed != corns [set label (word breed " "  who) set label-color black ]]
  ]
  [
    ask turtles [ set label "" ]
  ]
end

to season-change ;; a year in this model is 1284 ticks. This is arbitrary, but made the simulation look realistic. This means a tick is = 1/4th of a day.

  if ticks mod 1284 > 0 and ticks mod 1284 <= 321 [set season "Spring"]

  if ticks mod 1284 > 321 and ticks mod 1284 <= 642 [set season "Summer"]

  if ticks mod 1284 > 642 and ticks mod 1284 < 963 [set season "Autum" ]

  if ticks mod 1284 > 963 and ticks mod 1284 < 1284 [set season "Winter"]

  if crops-die-at-years'-end [if ticks mod 1284 = 1[ ask corns [die]]]

end

to recalculating-soil-quality
  ask patches  with [plantable = true]
    [

      set soil-quality (soil-quality - moisture - Ph + fertilizer)

      if soil-quality > 49 [ set soil-quality 50] ;;constrains the top end
      if soil-quality < 0 [set soil-quality 0] ;; constrains the bottom end

    ]

  if ticks mod  1284 = 0 [ set sum-quality sum-quality + sum [soil-quality] of patches  set sum-quality sum-quality / count patches with [plantable = true]   ] ; ------------------------------------------

end

to water [aSum]
  ask patch-here [set moisture moisture + aSum]
end

to fertilize [aSum]
  ask patch-here [set fertilizer fertilizer + aSum]
end

to care-for-land [sumFertilizer sumWater]
  ask robots
  [
    water sumFertilizer
    fertilize sumWater
  ]
end

to plant-systematic

    if season = "Summer" or season = "Spring"
    [
      ask patches with
      [
        plantable = true
        and not any? corns-here
        and pxcor = min [pxcor] of patches with
        [
          plantable = true and not any? corns-here
        ]
      ]
      ;; if we select one of the right type of stops, move a robot there to plant
      [
        ask one-of robots
        [
          move-to myself
        ]
          plant
      ]
    ]

end
@#$#@#$#@
GRAPHICS-WINDOW
255
10
873
429
-1
-1
10.0
1
10
1
1
1
0
0
0
1
-30
30
-20
20
0
0
1
ticks
30.0

BUTTON
30
10
95
43
setup
setup\n\n
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
100
10
202
43
go
\n go\n if show-soil-map? [ask patches [set pcolor scale-color red soil-quality 0 50]]\n\nifelse show-soil-map? = true\n[\nask turtles [ht] \n]\n[\n   \nask turtles [show-turtle]\n] \n\n\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
540
455
635
500
Harvested Corn
sum [ product-year ] of storages
17
1
11

SLIDER
10
230
205
263
full-charge
full-charge
0
1000
411.0
1
1
energy
HORIZONTAL

SWITCH
10
335
205
368
make-trails?
make-trails?
1
1
-1000

MONITOR
705
455
832
500
Corns lost to pests
total-corns-lost-to-pests
17
1
11

SWITCH
10
300
205
333
show-agent-name?
show-agent-name?
1
1
-1000

SLIDER
10
195
205
228
number-of-robots
number-of-robots
1
20
1.0
1
1
NIL
HORIZONTAL

SLIDER
11
467
151
500
harvest-size
harvest-size
1.40
1.8
1.51
.01
1
NIL
HORIZONTAL

SWITCH
10
370
100
403
pests?
pests?
0
1
-1000

PLOT
890
10
1290
215
Integrated Pest Management
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Pests" 1.0 0 -2674135 true "" "plot count pests"
"Mature Corn in the Field" 1.0 0 -7500403 true "" "plot count corns with [size >= harvest-size]"

TEXTBOX
260
445
427
469
Robot color ID
20
0.0
1

TEXTBOX
261
509
428
538
Red = returning corn to storage
11
14.0
1

TEXTBOX
260
473
427
502
Grey = planting, or harvesting corn
11
4.0
1

TEXTBOX
258
553
425
573
Green = recharging batteries
11
68.0
1

SLIDER
8
556
153
589
harvest-capacity
harvest-capacity
0
100
25.0
1
1
NIL
HORIZONTAL

TEXTBOX
11
438
178
467
The minimum size of corn to harvest
11
0.0
1

TEXTBOX
12
512
179
552
How much corn a robot can harvest before returning to storage
11
0.0
1

MONITOR
790
15
867
60
NIL
Season
17
1
11

SWITCH
10
265
205
298
crops-die-at-years'-end
crops-die-at-years'-end
1
1
-1000

SWITCH
10
405
150
438
show-soil-map?
show-soil-map?
1
1
-1000

PLOT
1295
10
1600
235
Soil-Quality
NIL
NIL
1.0
50.0
0.0
15.0
true
false
"set-plot-y-range 0 1\nset-plot-x-range 0 max [soil-quality] of patches with [plantable = true] + 0.01" ""
PENS
"Soil-quality" 1.0 1 -16777216 true "" "histogram [soil-quality] of patches with [plantable = true] "

SWITCH
10
145
155
178
systematic-plant?
systematic-plant?
1
1
-1000

SLIDER
5
595
155
628
recharge-rate
recharge-rate
0
200
147.0
1
1
NIL
HORIZONTAL

MONITOR
475
455
535
500
Year
years
17
1
11

MONITOR
840
455
907
500
Pest-killed
pest-dead
17
1
11

PLOT
1290
410
1490
560
Year Harvest
Year
Harvest
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "plotxy years years-harvest"

PLOT
1290
250
1490
400
Year Corns lost to pest  
Year
Corns lost
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "plotxy years corns-lost-to-pests-year"

BUTTON
140
55
203
88
go
go\n\n if show-soil-map? [ask patches [set pcolor scale-color red soil-quality 0 50]]\n\nifelse show-soil-map? = true\n[\nask turtles [ht]\n]\n[\n   \nask turtles [show-turtle]\n]\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1510
410
1710
560
Year Planted
Year
Palnted
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "plotxy years planted-year"

MONITOR
645
455
702
500
Planted
total-planted
17
1
11

PLOT
1510
250
1710
400
quality year 
year
qaulity 
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy years sum-quality"

TEXTBOX
258
533
408
551
Blue = bug detected
11
105.0
1

PLOT
890
230
1285
405
Robots productivity 
Year
Anount
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Robot-Idelness" 1.0 0 -13345367 true "" "plotxy years  sum [ pruductivity-year_base ] of robots / number-of-robots"
"Planted-year" 1.0 0 -7858858 true "" "plotxy years planted-year / number-of-robots"
"Harvest-year" 1.0 0 -16645118 true "" "plotxy years years-harvest / number-of-robots"
"Lost-year" 1.0 0 -4079321 true "" "plotxy years corns-lost-to-pests-year "

@#$#@#$#@
## WHAT IS IT?




## HOW IT WORKS


## HOW TO USE IT

Press SETUP and then GO. Examine the graphs, and watch the robots move through the farm.

The MAKE-TRAILS? switch asks Robots to trace their routes on the ground so we can inspect how they travel.

SHOW-AGENT-NAME? shows names of the different agents in the View.

The NUMBER-OF-ROBOTS slider sets how many robots are in the factory at the start.

The FULL-CHARGE slider sets what a full battery is in the model. The higher the value the longer robots go between charges, but also, the longer it takes them to charge up.

Sometimes, to keep a factory moving, a robot needs to go just when needed, even if not fully charged. The JUST-IN-TIME-ROBOT-SUPPLY sets the amount of energy a robot needs to have at the charging station to be selected to meet critical factory needs. The lower it is, the more robots will be available to meet the needs, but they also won't last very long due to their low charge. Tweak this to balance the factory.

## THINGS TO NOTICE

Even though the robots move to semi-random locations after charging, and there is no central controller tracking all the robots locations/allocating orders, the robots do a good job of moving the process through the system with internal bottlenecks.

Note how the external factor of the delivery of new material can slow or stop production.

Also notice the percent of time idle. Note when this goes up or down across various bottlenecks or model parameters.

## THINGS TO TRY

Does increasing the number of robots increase or decrease idleness?

Can you think of a way to reduce idleness in the factory?

Try changing the JUST-IN-TIME-ROBOT-SUPPLY slider up and down. How does it impact the idleness graph?

Try setting the FULL-CHARGE to the max. How does it impact the idleness graph?

## EXTENDING THE MODEL

Does reorganizing the machines change idleness? How else could you improve efficiency? Improve resilience? What happens if one of the machines occasionally breaks? For instance:

Implement shifts, so that robots recharge at two different times.

change of season more random, to simulate climate change.

Right now, robots have to go back to the charging room to recharge. Try adding recharging robots that can bring the charge to the worker robots.

The machines are in a particular arrangement, optimize for idleness or productivity by rearranging the storage or recharging station.

Currently, robots can always make it back to the robot room to recharge, because they can go into negative energy. This may not be the most realistic model. Change the model so that robots can get stranded if they do not leave for the robot room in time by editing the return-home function.

Python: right now, the robots don't learn, which makes them like a conveyor belt. Using the python extension, implement some learning into the model.

## NETLOGO FEATURES


## RELATED MODELS


This model builds on Robot Factory (Martin & Wilensky, 2022), which is based on Hölldobler and Wilson's The Ants (1990).


## CREDITS AND REFERENCES


## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Martin, K. (2021).  NetLogo Robotic Farm Model.  Penn State University, State College, PA.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2022 Kit Martin.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.



<!-- 2022 Cite: Martin, K. -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

ant
true
0
Polygon -7500403 true true 136 61 129 46 144 30 119 45 124 60 114 82 97 37 132 10 93 36 111 84 127 105 172 105 189 84 208 35 171 11 202 35 204 37 186 82 177 60 180 44 159 32 170 44 165 60
Polygon -7500403 true true 150 95 135 103 139 117 125 149 137 180 135 196 150 204 166 195 161 180 174 150 158 116 164 102
Polygon -7500403 true true 149 186 128 197 114 232 134 270 149 282 166 270 185 232 171 195 149 186
Polygon -16777216 true false 225 66 230 107 159 122 161 127 234 111 236 106
Polygon -16777216 true false 78 58 99 116 139 123 137 128 95 119
Polygon -16777216 true false 48 103 90 147 129 147 130 151 86 151
Polygon -16777216 true false 65 224 92 171 134 160 135 164 95 175
Polygon -16777216 true false 235 222 210 170 163 162 161 166 208 174
Polygon -16777216 true false 249 107 211 147 168 147 168 150 213 150

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

box 2
false
0
Polygon -7500403 true true 150 285 270 225 270 90 150 150
Polygon -13791810 true false 150 150 30 90 150 30 270 90
Polygon -13345367 true false 30 90 30 225 150 285 150 150

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
NetLogo 6.2.2
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
1
@#$#@#$#@
