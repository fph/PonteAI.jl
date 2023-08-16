# PonteAI

[![Build Status](https://github.com/fph/PonteAI.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/fph/PonteAI.jl/actions/workflows/CI.yml?query=branch%3Amain)

This program computes the optimal strategy for an abstract version of the "Gioco del Ponte", a historical game played in Pisa.

# Description of the game

This is a two-player, zero-sum game. Each player controls a set of $n$ *teams*, each of which we can represent with an integer representing its strength. When two teams battle, one of them wins. In the simplest, deterministic version of the game, we can assume that the team with the highest strength always wins, so for instance team 5 will always beat team 3.

A possible initial state with $n=3$ is the following:
```
Player A control teams [1, 4, 5]
Player B control teams [2, 3, 6]
```
The game is composed of $n$ rounds. Player A starts the first round by choosing one team from their own set. Player B answers by choosing one of their own teams. The two teams battle; the winner gets one point. The two teams that battle are removed from their respective set. This concludes the first round; the winner will be the first one to choose in the next round. An example full game goes as follows:

```
Player A controls teams [1, 4, 5]
Player B controls teams [2, 3, 6]
Player A will choose first.

Round 1:
Player A chooses team 4.
Player B chooses team 3.
4 > 3, so player A wins the round.

State after round 1:
Player A controls teams [1, 5]
Player B controls teams [3, 6]
Player A has 1 point, and will choose first next round.

Round 2:
Player A chooses team 5.
Player B chooses team 6.
6 > 5, so player B wins the round.

State after round 2:
Player A controls teams [1]
Player B controls teams [3]
Player A and B are tied 1-1, and B will choose first next round.

Round 3:
Player B chooses team 3 (the only remaining one)
Player A chooses team 1 (the only remaining one)
3 > 1, so player B wins the round

State after round 3:
No more teams are left; player B wins the game 2-1.
```

# Game state

We always describe the game state from the point of view of the player that has to make the next move. We use a structure `GameState` with three members:

* `gs.myTeams::Vector[Int]` and `gs.opponentTeams::Vector[Int]`: vectors of teams, e.g., `[1, 5]` and `[3, 6]`
* `gs.chosenTeam::Int`: this can contain the number `0`, which means that the active player is the first one to choose their team this round, or an index in `1, ..., length(gs.opponentTeams)`, which represents the fact that the opponent has chosen team `gs.opponentTeams[gs.chosenTeam]` and we must respond to it.

We do not keep track of the current score.

For instance, in the sample game above, at the beginning of round 2 the game state from the point of view of the active player A is
```
gs.myTeams: [1, 5]
gs.opponentTeams: [3, 6]
gs.chosenTeam: 0
```

After player A chooses team 5, the game state (from the point of view of the new active player B) becomes
```
gs.myTeams: [3, 6]
gs.opponentTeams: [1, 5]
gs.chosenTeam: 2
```

In contrast to most games, note that a player can make two consecutive moves in certain cases: for instance, in our running example, player B is the second to move in round 2, choosing team 6, and then the first to move in round 3, choosing team 3.

# Canonicalization

In this version of the game, only the ordering of team strengths matters. Hence when describing a game state we can replace `gs.myTeams` and `gs.opponentTeams` so that they contain consecutive numbers; in the above example we can replace the state
```
gs.myTeams: [3, 6]
gs.opponentTeams: [1, 5]
gs.chosenTeam: 2
```
with
```
gs.myTeams: [2, 4]
gs.opponentTeams: [1, 3]
gs.chosenTeam: 2
```
This reduces the number of positions to analyze.

# Optimal strategy

For each game state, we can compute an optimal `StrategyItem` by identifying two parameters:

* `si.bestScore`: the maximum score difference than we can achieve with optimal play. For instance, starting from an initial state with $n=3$, if we have a strategy to win all three rounds then `bestScore` is `3`, and if we can win only one round out of 3 `bestScore` is `-1`, i.e., `1 - 2`.
* `si.bestMove`: a vector containing all possible first moves that allow us to reach the maximum score `si.bestScore`.

For instance, from the game state at the beginning of our running example
```
gs.myTeams: [1, 4, 5]
gs.opponentTeams: [2, 3, 6]
gs.chosenTeam: 0
```
one can compute that
```
si.bestScore: -1 # I can win only one round, with optimal play from both sides.
si.bestMove: [1, 2, 3]  # It does not matter which move I play in the first round, all are equally good
```

Similarly, after player A has chosen team 5 in our sample playthrough, the state from the point of view of player B is
```
gs.myTeams: [3, 6]
gs.opponentTeams: [1, 5]
gs.chosenTeam: 2
```
and one can compute
```
gs.bestScore: 2
gs.bestMove: [1]
```
that is, player B can win both remaining rounds, and to do so they must answer with team 3 (the first in their list of teams). Answering with team 6 won't work.

A `Strategy` is map `GameState => StrategyItem`.

# Using the software

```
using PonteAI

n = 3

s = solve_game(3)
save('optimal_strategy.csv', s)
```

With these commands, we save in a CSV file the computed optimal strategy for each possible state of a game with `n=3`, i.e., 
```
myTeams	    opponentTeams	chosenTeam	bestScore	bestMove
[1, 2, 3]	[4, 5, 6]	    0	        -3	        [1, 2, 3]
[1, 2, 4]	[3, 5, 6]   	0	        -3	        [1, 2, 3]
[1, 2, 5]	[3, 4, 6]   	0	        -1	        [1, 2]
[1, 2, 6]	[3, 4, 5]	    0	        -1	        [1, 2, 3]
[1, 3, 4]	[2, 5, 6]	    0	        -1	        [2, 3]
[1, 3, 5]	[2, 4, 6]	    0	        -1	        [1, 2, 3]
...
...
[1]	        [2]         	1       	-1      	[1]
[2]     	[1]         	1          	 1       	[1]
[]	        []          	0	         0	        []
```
