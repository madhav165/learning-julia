using SearchLight, SocEstimator.Elevations
using CSV

Base.convert(::Type{String}, _::Missing) = ""
Base.convert(::Type{Int}, _::Missing) = 0
Base.convert(::Type{Int}, s::String) = parse(Int, s)
Base.convert(::Type{Float64}, s::Float64) = parse(Float64, s)

function seed()
  for row in CSV.Rows(joinpath(@__DIR__, "sample_elevations.csv"), limit = 1_000)
    e = Main.Elevations.Elevation()

    e.distance = row.distance
    e.elevation = row.elevation

    save(e)
  end
end