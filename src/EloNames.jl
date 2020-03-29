module EloNames

using Distributions
using FIGlet
using CSV
using DataFrames
using StatsBase

import REPL
using REPL.TerminalMenus

const out_csv = joinpath(pwd(),"EloNames_matchup_results.csv")

const baby_ascii = raw"
           _)_
        .-'(/ '-.
       /    `    \
      /  -     -  \
     (`  a     a  `)
      \     ^     /
       '. '---' .'
       .-`'---'`-.
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
    elo=1200
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



function matchup(name1,name2,names,next)
    options = [
        name1.name,
        name2.name,
        "Main Menu",
    ]
    menu = RadioMenu(options)
    choice = request("Pick winner:", menu)
    
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
