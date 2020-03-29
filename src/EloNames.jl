module EloNames

using Distributions
using FIGlet
using CSV
using DataFrames
using StatsBase
using Setfield
using ProgressMeter 
using PrettyTables

import REPL
using REPL.TerminalMenus

const out_csv = joinpath(pwd(),"EloNames_matchup_results.csv")
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
    return 1.0 / (1 + 1.0 * 10^ (1.0 * (elo1 - elo2) / 400))
end

function new_elos(name_winner,name_loser)
    prob = probability(name_winner.elo,name_loser.elo)
    e1 = name_winner.elo + K * (1-prob)
    e2 = name_loser.elo  + K * (0-(1-prob))

    return e1, e2
end

function process_results(path,names)
    results = CSV.read(out_csv,header=["winner","loser","gender"])
    # reset names in case this has been run already in the same session
     
    for gender in [boy,girl]
        @showprogress "resetting $gender names" for (k,v) in names[gender]
            @set v.elo = elo_start
            @set v.played = 0
        end
    end
    matchnum = 1
    @showprogress "calculating updated ratings" for r in eachrow(results)
        gender = r.gender == "boy" ? boy : girl
        n1 = names[gender][r.winner]
        n2 = names[gender][r.loser]
        e1, e2 = new_elos(n1,n2)
        new1 = @set n1.elo = e1
        new1 = @set new1.played += 1

        names[gender][r.winner] = new1
        new2 = @set n2.elo = e2
        new2 = @set new2.played += 1
        names[gender][r.loser] = new2
    end

    boy_results = [(name = v.name,elo=v.elo,gender="boy",contests=v.played) for (k,v) in  names[boy]]
    girl_results = [(name = v.name,elo=v.elo,gender="girl",contests=v.played) for (k,v) in  names[girl]]

    
    CSV.write(result_csv,DataFrame([boy_results;girl_results]))
    println("Updating rankings saved to $result_csv")
    main_menu(names)
end

function load_names()
    path = joinpath(dirname(pathof(EloNames)), "names.csv")
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

function random_matchup(names)
    gender = rand([boy,girl])
    ns = sample(collect(values(names[gender])),2,replace=false)
    matchup(ns[1],ns[2],names,random_matchup)
end

function girl_matchup(names)
    gender = girl
    ns = sample(collect(values(names[gender])),2,replace=false)
    matchup(ns[1],ns[2],names,girl_matchup)
end

function boy_matchup(names)
    gender = boy
    ns = sample(collect(values(names[gender])),2,replace=false)
    matchup(ns[1],ns[2],names,boy_matchup)
end


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

    write_result(out_csv,m,names,next)

    return
end

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


function start()
    FIGlet.render(" Little Loudenback", "train")
    names = load_names()
    main_menu(names)

end



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
        process_results(result_csv,names)
    elseif choice == 5
        print(baby_ascii)
        exit()
    else
        println("I'm unsure of what to do with that selection. Returning to main menu.")
        main_menu(names)
    end
end

export probability, start

end # module
