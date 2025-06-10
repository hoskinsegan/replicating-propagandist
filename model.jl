using Distributed  #---- change 4, add Distributed
using DelimitedFiles  #---- change 5, use DelimitedFiles instead of CSV
using CSV          #---- change 5, add CSV
@everywhere using Statistics  #---- change 11, add Statistics for mean

addprocs(3-length(procs())) 

@everywhere using Distributions

@everywhere mutable struct Player   #---- change 1, type to mutable struct
  belief
  result
  friends
  goodfriends
  #n
end

@everywhere mutable struct Game   #---- change 1, type to mutable struct
  binom_n
  epsilon
  players
  observers
#  converged
#  round_converged
end

@everywhere Game() = Game(0,0,[],[])

@everywhere function Update(game,player)
  for i in player.goodfriends
    top = (1-player.belief)*((.5-game.epsilon)/(.5+game.epsilon))^(2*game.players[i].result-game.binom_n)
    player.belief = 1/(1+top/player.belief)
  end
end

@everywhere function Round(game,propagandist)
  for x in game.players
    y = []
    for z in x.friends
      if game.players[z].belief > .5
        y = vcat(y,z)
      end
    end
    x.goodfriends = y
    if x.belief > .5
      x.result = rand(Binomial(game.binom_n,.5+game.epsilon))
    end
  end
  for x in game.observers
    y = []
    for z in x.friends
      if game.players[z].belief > .5
        y = vcat(y,z)
      end
    end
    if propagandist
      for z = 1:length(game.players)
        if game.players[z].result < game.binom_n/2
          y = vcat(y,z)
        end
      end
    end
    x.goodfriends = y
  end
  for x in game.players
    Update(game,x)
  end
  for x in game.observers
    Update(game,x)
  end
end

@everywhere function InitializeGame(game,network,popSize,binom_n,epsilon)
  game.binom_n = binom_n
  game.epsilon = epsilon
  game.players = Array{Player}(undef, popSize)   #---- change 10, Array{Player}(popSize) to Array{Player}(undef, popSize)
  game.observers = Array{Player}(undef, popSize)   #---- change 10, Array{Player}(popSize) to Array{Player}(undef, popSize)
#  game.converged = 0
#  game.round_converged = 0

  if network == "cycle"
    game.players[1] = Player(rand(),0,[1,2,popSize],[])
    game.players[popSize] = Player(rand(),0,[popSize-1,popSize, 1],[])

    for i = 2:(popSize-1)
      game.players[i] = Player(rand(),0,[i-1,i, i+1],[])
    end
    y = Array{Int64}(undef, 0)   #---- change 2, type to Array{Int64}(undef, 0)
    for i = 1:popSize
      y = vcat(y,i)
      game.observers[i] = Player(rand()/2,0,y,[])
    end
  elseif network == "complete"
    x = []
    for j = 1:popSize
      x = vcat(x,j)
    end
    for i = 1:popSize
      game.players[i] = Player(rand(),0,x,[])
    end
    y = Array{Int64}(undef, 0)   #---- change 2, type to Array{Int64}(undef, 0)
    for i = 1:popSize
      y = vcat(y,i)
      game.observers[i] = Player(rand()/2,0,y,[])
    end
  else
    error("no such network type")
  end
end

@everywhere function reInitializeGame(game)
#  game.converged = 0
#  game.round_converged = 0

  for x in game.players
    x.belief = rand()
  end
  for x in game.observers
    x.belief = rand()/2
  end
end

@everywhere function DoIt(popSize, networkType, epsilon, binom_n, runs,propagandist)
  #numberConverged = 0
  #sumRoundConverged = 0

  Zollman = Game()

  InitializeGame(Zollman,networkType,popSize,binom_n,epsilon)
  results=Array{Int64}(undef, 0, popSize+1)   #---- change 3, type to Array{Int64}(undef, 0, popSize+1)

  for x = 1:runs
    roundCounter = 0
    convergenceCheck = 0

    while convergenceCheck == 0
      y=[]
      for x in Zollman.players
        y=vcat(y, x.belief)
      end
      if minimum(y) >= .99
        convergenceCheck = 1
        #sumRoundConverged = sumRoundConverged + roundCounter
        summary = Array{Float64}(undef, 1, 0)   #---- change 9, Array(Float64,(1,0)) to Array{Float64}(undef, 1, 0)
        summary = hcat(summary,roundCounter)
        for x in Zollman.observers
          summary = hcat(summary,x.belief)
        end
        results = vcat(results,summary)

        #numberConverged = numberConverged + 1
      elseif maximum(y) <= .5
        convergenceCheck = 1
      end

      Round(Zollman,propagandist)
      roundCounter += 1
    end

    reInitializeGame(Zollman)
  end

  mean(results,dims=1)      #---- change 7, mean(results,1) to mean(results,dims=1)
  #println("Portion Converged: ", numberConverged/runs)
  #println("Average Round Converged: ", sumRoundConverged/numberConverged)
end


println("ARGS: ", length(ARGS))   # This is new

if length(ARGS) == 0   #### NO ARGS, RUN THE ORIGINAL "CAILIN" CODE
  for popSize in [30]
    results = Array{Any}(undef, 0, popSize+1)   #---- change 8, Array(Any,(0,popSize+6)) to Array{Any}(undef, 0, popSize+1)  NOTE popsize+1 matches other array for hcat
    for binom_n in [10]
      for epsilon in [.05]
        for prop in [false]
          proc2 = @spawn DoIt(popSize,"complete",epsilon,binom_n,500,prop)
          proc1 = @spawn DoIt(popSize,"complete",epsilon,binom_n,500,prop)
          println(hcat([popSize "complete" epsilon binom_n prop], mean([fetch(proc1),fetch(proc2)])))
          results = vcat(results,DoIt(popSize,"cycle",epsilon,binom_n,1000,prop))
        end
      end
    end
    writedlm("Cailin extra data no prop popSize$popSize.csv", results, ',') #---- change 6, writecsv to writedlm
  end
elseif length(ARGS) == 6  #### ARGS, RUN THE NEW CODE 
  # Command line mode: julia model.jl popSize networkType epsilon binom_n runs propagandist
  popSize = parse(Int, ARGS[1])
  networkType = ARGS[2]
  epsilon = parse(Float64, ARGS[3])
  binom_n = parse(Int, ARGS[4])
  runs = parse(Int, ARGS[5])
  propagandist = parse(Bool, ARGS[6])
  
  results_from_args = DoIt(popSize, networkType, epsilon, binom_n, runs, propagandist)
  filename = "Results_$(propagandist ? "Prop" : "NoProp")_Size$(popSize)_Binom$(binom_n)_Eps$(epsilon)_$(networkType).csv"
  writedlm(filename, results_from_args, ',')
  println("Results written to: $filename")
else
  println("Usage: julia model.jl")
  println("   or: julia model.jl popSize networkType epsilon binom_n runs propagandist")
  println("Example: julia model.jl 6 cycle 0.05 10 100 false")
end

#writedlm("Results NoProp Size$popSize Binom$binom_n Eps$epsilon Complete.txt", DoIt(6,"complete",epsilon,binom_n,10,false))
#writedlm("Results NoProp Size$popSize Binom$binom_n Eps$epsilon Cycle.txt", DoIt(6,"cycle",epsilon,binom_n,10,false))
#writedlm("Results Prop Size$popSize Binom$binom_n Eps$epsilon Complete.txt", DoIt(6,"complete",epsilon,binom_n,10,true))
#writedlm("Results Prop Size$popSize Binom$binom_n Eps$epsilon Cycle.txt", DoIt(6,"cycle",epsilon,binom_n,10,true))

#writedlm("results.csv",DoIt)