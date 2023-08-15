module PonteAI

using InvertedIndices: Not
using DataStructures: Stack

"""
Represents a game state.
Teams are vectors of strengths; higher number = stronger.
"""
struct GameState
    myTeams::Vector{Int}
    opponentTeams::Vector{Int}
    chosenTeam::Int # index in OpponentTeams of the team chosen by the opponent, or 0
    function GameState(myTeams, opponentTeams, chosenTeam=0)
        return new(myTeams, opponentTeams, chosenTeam)
    end
end

function Base.:(==)(gs1::GameState, gs2::GameState)
    return (gs1.myTeams == gs2.myTeams) && 
            (gs1.opponentTeams == gs2.opponentTeams) &&
            (gs1.chosenTeam == gs2.chosenTeam)
end
Base.hash(gs::GameState) = hash(gs.myTeams, hash(gs.opponentTeams, hash(gs.chosenTeam)))

"""
Describes a part of an optimal strategy computed.
`bestScore` is the evaluated highest score reachable by optimal play.
`bestMoves` is a Vector with all moves that allow the player to reach `bestScore`.
"""
struct StrategyItem
    bestScore::Int
    bestMoves::Vector{Int}
end

"""
Type alias for a "strategy", i.e., a transposition table for the game.
"""
const Strategy = Dict{GameState, StrategyItem}

"""
    Return available moves. If there are no moves, the game is over.
"""
function moves(gs::GameState)
    return 1:length(gs.myTeams)
end

"""
Applies a move, returning a new GameState

Return:
    * a new gamestate (with fresh copies of the vectors)
    * a score increase / decrease determined by the move.
    * a bool to tell if the active player has changed in the new position. Note that in this game the same player may have to play twice in a row.
    * a bool to tell if the game is over
"""
function apply(gs::GameState, move)
    if gs.chosenTeam == 0
        # a "move" is merely choosing a team and passing the state over
        return GameState(gs.opponentTeams, gs.myTeams, move), 0, true
    else
        @assert gs.myTeams[move] != gs.opponentTeams[gs.chosenTeam] 
        iWin = gs.myTeams[move] > gs.opponentTeams[gs.chosenTeam]

        myTeams = gs.myTeams[Not(move)] # note that this must copy the vector, not mutate it
        opponentTeams = gs.opponentTeams[Not(gs.chosenTeam)]        
        # we may decide to "normalize" the teams by reindexing them into 1..n, to reduce the number of states; we choose not to for now.
        if iWin
            # I play again
            return GameState(myTeams, opponentTeams), +1, false
        else
            # opponent's turn
            return GameState(opponentTeams, myTeams), -1, true
        end
    end
end

function solve_game(initialState::GameState, strategy=Strategy())
    stack = Stack{GameState}()
    @debug stack
    push!(stack, initialState)
    while !isempty(stack)
        gs = first(stack) # peek
        @debug "Analyzing state $(gs)."
        incomplete = false
        bestScore::Int = typemin(Int)
        bestMoves::Vector{Int} = []
        possible_moves = moves(gs)
        if isempty(possible_moves)
            # game over
            strategy[gs] = StrategyItem(0, [])
            pop!(stack)
            continue
        end
        for move in possible_moves
            newgs, current_move_score, switchsides = apply(gs, move)
            if haskey(strategy, newgs)
                if incomplete
                    # there is little point in continuing the computation, since we won't be able to determine the value of this position. We'll just push new children into the stack.
                    continue
                end
                newstrat = strategy[newgs]
                score = current_move_score + (switchsides ? -newstrat.bestScore : newstrat.bestScore)
                if score == bestScore
                    push!(bestMoves, move)
                elseif score > bestScore
                    bestScore = score
                    bestMoves = [move]
                else
                    # this move is suboptimal, nothing to do
                end
            else
                incomplete = true
                push!(stack, newgs)
            end
        end
        if !incomplete
            strat = StrategyItem(bestScore, bestMoves)
            @debug "Determined strategy $(strat) for state $(gs)."
            strategy[gs] = strat
            pop!(stack)
        else
            @debug "Could not determine a strategy: incomplete state."
        end
        @debug stack
    end
    return strategy
end

end

# using PonteAI

# initial_state = GameState([1,4,5], [2,3,6])
# solve_game(initial_state)

