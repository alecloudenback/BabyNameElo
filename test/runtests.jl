using EloNames
using Test

@testset "probability" begin
    @test probability(1000,1000) ≈ 0.5
end