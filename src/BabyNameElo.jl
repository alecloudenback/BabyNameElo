module BabyNameElo

using FIGlet
using CSV
using DataFrames
using StatsBase
using Setfield
using ProgressMeter 
using PrettyTables

import REPL
using REPL.TerminalMenus

const out_csv = joinpath(pwd(),"BabyNameElo_matchup_results.csv")
const result_csv = joinpath(pwd(),"Name_Results.csv")
const elo_start = 1200.0
const K = 32

const baby_ascii = raw"
           _)_
        .-'(/ '-.
       /    `    \
      /  -     -  \
     (`  a     a  `)     __________
      \     ^     /     /          \
       '. '---' .'     <  Goodbye! |
       .-`'---'`-.      \_________/
      /           \
     /  / '   ' \  \
   _/  /|       |\  \_
  `/|\` |+++++++|`/|\`
       /\       /\
       | `-._.-` |
       \   / \   /
       |_ |   | _|
       | _|   |_ |
       (ooO   Ooo)
"

@enum Gender boy girl

Base.@kwdef struct Name1
    name::String
    elo=elo_start
    gender
    played=0
end

Name = Name1

struct Matchup1
    winner
    loser
    gender
end
Matchup = Matchup1

"Calculate the probability of winning"
function  probability(elo1,elo2)
    return 1.0 / (1 + 10 ^ (1.0 * (elo1 - elo2) / 400))
end

"Caclulate new Elo scores given a winner and loser"
function new_elos(name_winner,name_loser)
    prob = probability(name_winner.elo,name_loser.elo)
    e1 = name_winner.elo + K * (1-prob)
    e2 = name_loser.elo  + K * (0-(1-prob))

    return e1, e2
end

"Loop through the file that has the match results and recalculate Elos"
function process_results(src_path,names)
    if isfile(src_path)
        results = CSV.read(src_path,header=["winner","loser","gender"])
        size(results)
        if size(results,1) > 0 
            # reset names in case this has been run already in the same session
            
            for gender in [boy,girl]
                @showprogress "resetting $gender names" for (k,v) in names[gender]
                    new = @set v.elo = elo_start
                    names[gender][k] = @set new.played = 0
                end
            end
            matchnum = 1
            @showprogress "calculating updated ratings" for r in eachrow(results)
                gender = r.gender == "boy" ? boy : girl
                n1 = names[gender][r.winner]
                n2 = names[gender][r.loser]
                e1, e2 = new_elos(n1,n2)

                # update first (winner) name
                new1 = @set n1.elo = e1
                new1 = @set new1.played += 1
                names[gender][r.winner] = new1

                #update second (loser) name
                new2 = @set n2.elo = e2
                new2 = @set new2.played += 1
                names[gender][r.loser] = new2
            end
        end
    end

    return names
end

"Write the calculated scores to disk"
function write_elo_results(out_path,names,next)
    boy_results = [(name = v.name,elo=v.elo,gender="boy",contests=v.played) for (k,v) in  names[boy]]
    girl_results = [(name = v.name,elo=v.elo,gender="girl",contests=v.played) for (k,v) in  names[girl]]
    sort!(girl_results,by = x -> x.elo, rev=true)
    sort!(boy_results,by = x -> x.elo, rev=true)
    
    # warn users if the number of matchups is below some arbitrary number so that they
    # know that the results are not really valid.
    min_played = min(
        minimum([x.contests for x in boy_results]),
        minimum([x.contests for x in girl_results]))

    if min_played <= 5
        println("WARNING! You should play more matchups to get a better result. \n Some names have only
            been matched up $min_played times.")
    end

    CSV.write(out_path,DataFrame([boy_results;girl_results]))
    println("Updating rankings saved to $out_path")

    # Display a summary in the console as well
    top_n = 15
    for r in [boy_results,girl_results]
        println("Top $(r[1].gender) results (out of $(length(r)) names):")
        header=["Name","Score","Num Contests"]
        pretty_table(r[1:top_n],header,header_crayon = crayon"yellow bold", formatter=ft_printf("%4.1f",2))

    end

    next(names)
end

"Load the set of names"
function load_names(path=nothing)
    if isnothing(path)
        path = joinpath(dirname(pathof(BabyNameElo)), "sample_names.csv")
    end
    df = CSV.read(path)
    df.name = strip.(df.name)
    boys = Dict()
    girls = Dict()
    for r in eachrow(df)
        if r.gender == "boy"
            boys[r.name] = Name(name = r.name, gender = boy)
        else
            girls[r.name] = Name(name = r.name, gender = girl)
        end
    end

    return Dict(boy=> boys,
                girl => girls,        
    )
end

"Randomly pick boy/girl and then select two names to compare. Liklihood of 
being selected is inversely propotional to number of games played so far"
function random_matchup(names)
    gender = rand([boy,girl])
    
    #weight the sample inversely to num of comparisons so far
    sub_names = collect(values(names[gender]))
    played = [n.played for n in sub_names]
    weights = AnalyticWeights(
        (1.01 .- played ./ max(1,maximum(played))) .^2
    )
    
    ns = sample(sub_names,weights,2,replace=false)
    matchup(ns[1],ns[2],names,random_matchup)
end

function girl_matchup(names)
    gender = girl

    #weight the sample inversely to num of comparisons so far
    sub_names = collect(values(names[gender]))
    played = [n.played for n in sub_names]
    weights = AnalyticWeights(
        (1.01 .- played ./ max(1,maximum(played))) .^2
    )
    
    ns = sample(sub_names,weights,2,replace=false)
    matchup(ns[1],ns[2],names,girl_matchup)
end

function boy_matchup(names)
    gender = boy
    
    #weight the sample inversely to num of comparisons so far
    sub_names = collect(values(names[gender]))
    played = [n.played for n in sub_names]
    weights = AnalyticWeights(
        (1.01 .- played ./ max(1,maximum(played))) .^2
    )
    
    ns = sample(sub_names,weights,2,replace=false)
    matchup(ns[1],ns[2],names,boy_matchup)
end

"Given two names, ask user to pick a winner and process the result"
function matchup(name1,name2,names,next)
    options = [
        name1.name,
        name2.name,
        "Main Menu",
    ]
    @assert name1.gender == name2.gender

    gender_str = name1.gender == boy ? "boy ♂ " : "girl ♀ "
    menu = RadioMenu(options)
    choice = request("Pick winner for $gender_str", menu)
    
    if choice == 1 
        m = Matchup(name1.name,name2.name,name1.gender)
    elseif choice == 2
        m = Matchup(name2.name,name1.name,name1.gender)
    elseif choice == 3 
        main_menu(names)
    else
        return
    end

    # increment the number of matches played to assist in weighting sample
    names[name1.gender][name1.name] = @set name1.played += 1
    names[name2.gender][name2.name] = @set name2.played += 1

    write_result(out_csv,m,names,next)

    return
end

"Write the result of a matchup to disk"
function write_result(out,m,names,next)
    # show matchup
    gen = m.gender == boy ? "boy" : "girl"
    df = DataFrame([(winner= m.winner,loser=m.loser,gender=gen)])

    # create file if it doesn't exist
    if ~isfile(out)
        touch(out)
    end
    CSV.write(out, df, writeheader = false, append = true,delim=',')
    next(names)
end

"Start the program - this is the main entry point."
function start(last_name="Baby Name",name_source=nothing)
    FIGlet.render("Little $last_name", "train")
    names = load_names(name_source)
    names = process_results(out_csv,names)
    main_menu(names)

end


"Show the main menu"
function main_menu(names)
    options = [
        "Random matchup",
        "Boy matchup",
        "Girl matchup",
        "Export Rankings",
        "Exit",
    ]
    menu = RadioMenu(options)
    choice = request("Select an option:", menu)
    
    println("You selected $(options[choice])")
    if choice == 1
        random_matchup(names)
    elseif choice == 2
        boy_matchup(names)
    elseif choice == 3
        girl_matchup(names)
    elseif choice == 4
        process_results(out_csv,names)
        write_elo_results(result_csv,names, main_menu)
    elseif choice == 5
        print(baby_ascii)
        exit()
    else
        println("I'm unsure of what to do with that selection. Returning to main menu.")
        main_menu(names)
    end
end

export start

end # module
