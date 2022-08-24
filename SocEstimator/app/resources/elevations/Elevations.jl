module Elevations

import SearchLight: AbstractModel, DbId
import Base: @kwdef

export Elevation

@kwdef mutable struct Elevation <: AbstractModel
  id::DbId = DbId()
  distance::Float64 = 0
  elevation::Float64 = 0
end

end
